const admin = require("firebase-admin");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const twilio = require("twilio");

admin.initializeApp();
const db = admin.firestore();

const TWILIO_ACCOUNT_SID = defineSecret("TWILIO_ACCOUNT_SID");
const TWILIO_AUTH_TOKEN = defineSecret("TWILIO_AUTH_TOKEN");
const TWILIO_FROM_NUMBER = defineSecret("TWILIO_FROM_NUMBER");

const ALERT_RATE_WINDOW_MS = 90 * 1000;

const functionOptions = {
  region: "asia-southeast1",
  timeoutSeconds: 30,
  memory: "256MiB",
  secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER],
  invoker: "public",
};

function normalizePhoneNumber(raw) {
  const cleaned = String(raw || "").replace(/[^\d+]/g, "").trim();
  if (!cleaned) return null;
  if (cleaned.startsWith("+")) {
    if (/^\+\d{10,15}$/.test(cleaned)) return cleaned;
    return null;
  }
  if (/^0\d{10}$/.test(cleaned)) {
    return `+63${cleaned.substring(1)}`;
  }
  if (/^63\d{10}$/.test(cleaned)) {
    return `+${cleaned}`;
  }
  if (/^\d{10,15}$/.test(cleaned)) {
    return `+${cleaned}`;
  }
  return null;
}

function redactPhone(num) {
  if (!num || num.length < 4) return "***";
  return `***${num.slice(-4)}`;
}

/**
 * @param {string} uid Teacher Firebase Auth UID
 * @param {object} payload Request body / callable data
 * @return {Promise<object>}
 */
async function runSendSmsAlert(uid, payload) {
  const learnerFirebaseUid = String(payload.learnerFirebaseUid || "").trim();
  const classId = Number(payload.classId || 0);
  const learnerName = String(payload.learnerName || "").trim();
  const className = String(payload.className || "").trim();
  const title = String(payload.title || "").trim();
  const body = String(payload.body || "").trim();
  const alertType = String(payload.alertType || "teacherAlert").trim();
  if (!learnerFirebaseUid || !classId || !title || !body) {
    const err = new Error("Missing required fields.");
    err.code = "invalid-argument";
    throw err;
  }

  const enrollment = await db.collection("class_enrollments_cloud")
      .where("teacherFirebaseUid", "==", uid)
      .where("learnerFirebaseUid", "==", learnerFirebaseUid)
      .where("classId", "==", classId)
      .limit(1)
      .get();
  if (enrollment.empty) {
    const err = new Error("Teacher not authorized.");
    err.code = "permission-denied";
    throw err;
  }

  const limiterId = `${uid}_${learnerFirebaseUid}`;
  const limiterRef = db.collection("sms_alert_rate").doc(limiterId);
  const limiterSnap = await limiterRef.get();
  const now = Date.now();
  if (limiterSnap.exists) {
    const lastSentAt = Number(limiterSnap.data()?.lastSentAtMs || 0);
    if (lastSentAt > 0 && now - lastSentAt < ALERT_RATE_WINDOW_MS) {
      const err = new Error(
          "SMS alert cooldown active. Please wait before sending again.",
      );
      err.code = "resource-exhausted";
      throw err;
    }
  }

  const profileSnap = await db.collection("learner_profiles")
      .doc(learnerFirebaseUid)
      .get();
  const contactsRaw = profileSnap.data()?.emergencyContacts || [];
  const normalized = Array.isArray(contactsRaw) ? contactsRaw
      .map((c) => normalizePhoneNumber(c))
      .filter((c) => !!c) : [];
  const deduped = [...new Set(normalized)].slice(0, 2);
  const invalidContacts = Array.isArray(contactsRaw) ?
    contactsRaw.filter((c) => !normalizePhoneNumber(c)) : [];
  if (!deduped.length) {
    return {
      attempted: 0,
      sent: 0,
      failed: 0,
      invalidContacts,
      message: "No valid emergency contact numbers.",
    };
  }

  const twilioClient = twilio(
      TWILIO_ACCOUNT_SID.value(),
      TWILIO_AUTH_TOKEN.value(),
  );
  const fromNumber = TWILIO_FROM_NUMBER.value();
  const smsText =
    `[TapTalk] ${title}\n${body}\nLearner: ${learnerName}\nClass: ${className}`;

  let sent = 0;
  let failed = 0;
  const batch = db.batch();
  for (const to of deduped) {
    try {
      const resp = await twilioClient.messages.create({
        from: fromNumber,
        to,
        body: smsText,
      });
      sent++;
      const logRef = db.collection("sms_alert_logs").doc();
      batch.set(logRef, {
        teacherFirebaseUid: uid,
        learnerFirebaseUid,
        learnerName,
        classId,
        className,
        alertType,
        title,
        status: "sent",
        toRedacted: redactPhone(to),
        providerSid: resp.sid || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      failed++;
      const logRef = db.collection("sms_alert_logs").doc();
      batch.set(logRef, {
        teacherFirebaseUid: uid,
        learnerFirebaseUid,
        learnerName,
        classId,
        className,
        alertType,
        title,
        status: "failed",
        toRedacted: redactPhone(to),
        error: String(e?.message || e),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
  await batch.commit();
  await limiterRef.set(
      {
        teacherFirebaseUid: uid,
        learnerFirebaseUid,
        lastSentAtMs: now,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  return {
    attempted: deduped.length,
    sent,
    failed,
    invalidContacts,
  };
}

function mapErrorToHttps(err) {
  const code = err.code || "internal";
  if (code === "invalid-argument" ||
      code === "permission-denied" ||
      code === "resource-exhausted") {
    throw new HttpsError(code, err.message);
  }
  throw new HttpsError("internal", err.message || "SMS send failed.");
}

exports.sendSmsAlert = onCall(
    functionOptions,
    async (request) => {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Authentication required.");
      }
      try {
        return await runSendSmsAlert(uid, request.data || {});
      } catch (err) {
        mapErrorToHttps(err);
      }
    },
);

/** HTTP fallback: verifies Bearer ID token (fixes v2 callable auth on some clients). */
exports.sendSmsAlertHttp = onRequest(
    {...functionOptions, cors: true},
    async (req, res) => {
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).json({error: "method-not-allowed"});
        return;
      }

      const authHeader = String(req.headers.authorization || "");
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      if (!match) {
        res.status(401).json({error: "unauthenticated", message: "Missing Bearer token."});
        return;
      }

      let uid;
      try {
        const decoded = await admin.auth().verifyIdToken(match[1]);
        uid = decoded.uid;
      } catch (e) {
        res.status(401).json({
          error: "unauthenticated",
          message: String(e?.message || e),
        });
        return;
      }

      try {
        const result = await runSendSmsAlert(uid, req.body || {});
        res.status(200).json(result);
      } catch (err) {
        const code = err.code || "internal";
        const status = code === "permission-denied" ? 403 :
          code === "invalid-argument" ? 400 :
            code === "resource-exhausted" ? 429 : 500;
        res.status(status).json({error: code, message: err.message});
      }
    },
);
