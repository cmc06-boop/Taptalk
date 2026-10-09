const {randomBytes} = require('node:crypto');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {hash, newId, trusted, deviceMatches, canConfirm} = require('./security-policy');
initializeApp();
const db = getFirestore();
const deny = () => { throw new HttpsError('permission-denied', 'Verification required or request unavailable.'); };
const teacherDeviceActions = new Set([
  'status', 'requestReplacement', 'replacementStatus', 'approveReplacement',
  'confirmReplacement', 'sendRecovery', 'verifyRecovery', 'logout',
]);
const emailOf = value => typeof value === 'string' ? value.trim().toLowerCase() : '';
const recentLogin = auth => Number.isFinite(auth.token.auth_time) && Date.now() / 1000 - auth.token.auth_time <= 300;
const ref = (collection, id) => db.collection(collection).doc(id);
const id = value => {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) deny();
  return value;
};
const securityRef = uid => ref('caregiver_security', uid);
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const transferCode = () => `TR-${[...randomBytes(8)].map(byte => CODE_ALPHABET[byte & 31]).join('')}`;
async function activeAccount(uid) {
  try {
    const account = await getAuth().getUser(uid);
    if (account.disabled) deny();
    return account;
  } catch (_) {
    throw new HttpsError('unauthenticated', 'Sign in to an active account.');
  }
}
async function issue(uid, sessionId) {
  await activeAccount(uid);
  return {state: 'trusted', token: await getAuth().createCustomToken(uid, {trustedSession: sessionId})};
}
async function rateLimit(uid, action, max = 10, windowMs = 3600000) {
  const target = ref('security_rate_limits', `${uid}_${action}`);
  await db.runTransaction(async tx => {
    const old = (await tx.get(target)).data();
    const current = Date.now();
    const active = old?.until > current;
    const count = active ? old.count + 1 : 1;
    if (count > max) {
      throw new HttpsError('resource-exhausted', 'Please try again later.',
        {retryAfterSeconds: Math.ceil((old.until - current) / 1000)});
    }
    tx.set(target, {count, until: active ? old.until : current + windowMs});
  });
}

// All authority changes are server transactions. Clients cannot write owners,
// device credentials, grants, approvals, or session IDs through Firestore.
exports.caregiverSecurity = onCall(
  {
    enforceAppCheck: true,
    region: 'us-central1',
    invoker: 'public',
    minInstances: 1,
  },
  async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const uid = request.auth.uid;
  const caller = await activeAccount(uid);
  const data = request.data ?? {};
  const action = data.action;
  const secRef = securityRef(uid);
  if (action === 'reviewEmergencyContacts') {
    const profile = (await ref('user_profiles', uid).get()).data();
    if (profile?.role !== 'learner' || !Array.isArray(data.contacts) || data.contacts.length > 10 ||
        data.contacts.some(phone => typeof phone !== 'string' || !/^\+?[0-9]{7,15}$/.test(phone))) deny();
    await ref('learner_profiles', uid).update({emergencyContacts: [...new Set(data.contacts)], emergencyContactsNeedReview: false});
    return {ok: true};
  }
  if (action === 'deleteClass' || action === 'clearClassEnrollments') return clearClass(request);
  if (action === 'enroll' || action === 'unenroll') return enrollment(request);
  const profile = (await ref('user_profiles', uid).get()).data();
  const role = profile?.role;
  // Teachers use the same one-phone registration as parents. Learner linking
  // and caregiver transfer stay parent-only.
  if (role !== 'parent' && role !== 'teacher') deny();
  const secret = data.deviceSecret;
  if (typeof secret !== 'string' || !/^[a-f0-9]{64}$/.test(secret)) deny();
  if (role === 'teacher' && !teacherDeviceActions.has(action)) deny();
  if (action === 'transfer') return transfer(request, secret);
  if (action === 'confirmLegacy') return confirmLegacy(request, secret);
  if (action === 'sendRecovery' || action === 'verifyRecovery') return recover(request, secret);
  if (action === 'status') {
    const account = caller;
    const accountEmail = emailOf(account.email);
    const result = await db.runTransaction(async tx => {
      const sec = (await tx.get(secRef)).data();
      if (!sec) {
        if (role !== 'teacher') {
          const legacy = await tx.get(db.collection('parent_child_links').where('parentFirebaseUid', '==', uid).limit(1));
          if (!legacy.empty) return {state: 'legacyConfirmation'};
        }
        if (!account.emailVerified || !accountEmail) return {state: 'setup'};
        // The first phone a verified parent signs in on becomes the only
        // trusted phone. Any other phone must verify through the email link.
        const sessionId = newId();
        tx.set(secRef, {deviceHash: hash(secret), sessionId, generation: 1, recoveryEmail: accountEmail});
        tx.set(db.collection('security_audit').doc(), {action: 'registerFirstDevice', uid, at: FieldValue.serverTimestamp()});
        return {state: 'trusted', sessionId, needsToken: true};
      }
      if (!deviceMatches(secret, sec)) return {state: 'verificationRequired'};
      const sessionId = sec.sessionId || newId();
      if (!sec.sessionId) tx.update(secRef, {sessionId});
      return {state: 'trusted', sessionId, needsToken: request.auth.token.trustedSession !== sessionId};
    });
    if (result.state === 'legacyConfirmation') {
      const links = await db.collection('parent_child_links').where('parentFirebaseUid', '==', uid).get();
      const learners = [];
      for (const doc of links.docs) {
        const learnerUid = doc.data().learnerFirebaseUid;
        const all = await db.collection('parent_child_links').where('learnerFirebaseUid', '==', learnerUid).get();
        learners.push({
          learnerFirebaseUid: learnerUid,
          learnerName: doc.data().learnerName ?? '',
          learnerProfileCode: doc.data().learnerProfileCode ?? '',
          ambiguous: all.size > 1,
        });
      }
      return {state: 'legacyConfirmation', learners};
    }
    const trustedNow = result.state === 'trusted';
    const [pending, links, issued] = await Promise.all([
      trustedNow ? db.collection('device_replacements').where('uid', '==', uid).get() : null,
      trustedNow ? boundLinks(uid, hash(secret)) : [],
      result.needsToken
        ? getAuth().createCustomToken(uid, {trustedSession: result.sessionId}).then(token => ({state: 'trusted', token}))
        : {state: result.state},
    ]);
    return {...issued,
      links, requests: pending?.docs
      .filter(doc => doc.data().kind === 'replacement' && doc.data().status === 'pending' && doc.data().expiresAt > Date.now())
      .map(doc => ({id: doc.id})) ?? []};
  }
  if (action === 'link') {
    await rateLimit(uid, 'link');
    const code = String(data.profileCode ?? '').trim().toUpperCase();
    if (!/^TT-[A-Z0-9]{8}$/.test(code)) deny();
    const account = await getAuth().getUser(uid);
    if (!account.emailVerified || !account.email) throw new HttpsError('failed-precondition', 'Verify your email before linking.');
    const result = await db.runTransaction(async tx => {
      const sec = (await tx.get(secRef)).data();
      if (sec && (!deviceMatches(secret, sec) || !trusted(request.auth, sec))) deny();
      const profiles = await tx.get(db.collection('learner_profiles').where('profileCode', '==', code).limit(2));
      if (profiles.size !== 1) deny();
      const learner = profiles.docs[0];
      const learnerUid = learner.id;
      const ownerRef = ref('learner_caregivers', learnerUid);
      // An unlinked learner (including older inactive records) is free to link again.
      const stored = (await tx.get(ownerRef)).data();
      const owner = stored?.active === true ? stored : null;
      const legacy = await tx.get(db.collection('parent_child_links').where('learnerFirebaseUid', '==', learnerUid));
      // Deployment migration pins existing verified email ownership. An old
      // QR never bootstraps trust on an unverified replacement phone.
      if (!owner && !legacy.empty) deny();
      if (owner && owner.parentUid !== uid) {
        throw new HttpsError('already-exists', 'This learner already has a caregiver.');
      }
      const previousLinks = await tx.get(db.collection('parent_child_links').where('parentFirebaseUid', '==', uid).limit(1));
      if (!sec && !previousLinks.empty) deny();
      const sessionId = sec?.sessionId || newId();
      const deviceHash = hash(secret);
      if (!sec) tx.set(secRef, {deviceHash, sessionId, generation: 1, recoveryEmail: account.email});
      const linkRef = ref('parent_child_links', `${uid}_${learnerUid}`);
      const learnerData = learner.data();
      // The learner is bound to the phone that scanned this QR. The same
      // caregiver scanning again on a newly trusted phone moves that binding.
      const alreadyLinked = !!owner && owner.deviceHash === deviceHash;
      if (!alreadyLinked) {
        tx.set(ownerRef, {parentUid: uid, active: true, deviceHash});
        tx.set(linkRef, {parentFirebaseUid: uid, learnerFirebaseUid: learnerUid,
          learnerName: learnerData.learnerName ?? '', learnerProfileCode: code, deviceHash,
          linkedAt: FieldValue.serverTimestamp()}, {merge: true});
      }
      return {sessionId, alreadyLinked, learnerFirebaseUid: learnerUid,
        learnerName: learnerData.learnerName ?? '', profileCode: code};
    });
    return {...result, ...(await issue(uid, result.sessionId))};
  }
  if (action === 'requestTransfer') {
    await rateLimit(uid, 'replacement', 10, 15 * 60000);
    if (!recentLogin(request.auth)) {
      throw new HttpsError('unauthenticated', 'Confirm your account before transferring.');
    }
    const learnerUid = id(data.learnerUid);
    const requestId = transferCode();
    await db.runTransaction(async tx => {
      const sec = (await tx.get(secRef)).data();
      const owner = (await tx.get(ref('learner_caregivers', learnerUid))).data();
      // Reauthentication replaces the custom trusted-session token. For this
      // one action, recent account proof plus the bound device secret is the
      // equivalent (and avoids reissuing/signing in with another token first).
      if (!deviceMatches(secret, sec) || owner?.parentUid !== uid ||
          owner.active !== true) deny();
      tx.create(ref('device_replacements', requestId), {
        fromUid: uid, learnerUid, kind: 'transfer',
        giverGeneration: sec.generation, status: 'pending',
        expiresAt: Date.now() + 15 * 60000,
      });
      tx.set(db.collection('security_audit').doc(), {
        action: 'createTransfer', actor: uid, learnerUid,
        at: FieldValue.serverTimestamp(),
      });
    });
    return {requestId};
  }
  if (action === 'requestReplacement') {
    await rateLimit(uid, 'replacement', 10, 15 * 60000);
    const sec = (await secRef.get()).data();
    const requestId = newId();
    await ref('device_replacements', requestId).create({uid, deviceHash: hash(secret),
      kind: 'replacement', recoveryEmail: sec?.recoveryEmail ?? null,
      generation: sec?.generation ?? 0, status: 'pending', expiresAt: Date.now() + 15 * 60000});
    return {requestId};
  }
  if (action === 'replacementStatus') {
    const pending = (await ref('device_replacements', id(data.requestId)).get()).data();
    const sec = (await secRef.get()).data();
    if (pending?.uid !== uid || pending.kind !== 'replacement' ||
        pending.deviceHash !== hash(secret) ||
        pending.generation !== (sec?.generation ?? 0)) deny();
    if (pending.expiresAt <= Date.now()) return {status: 'expired'};
    return {status: pending.status === 'approved' ? 'approved' : 'pending'};
  }
  if (action === 'approveReplacement' || action === 'confirmReplacement') {
    const target = ref('device_replacements', id(data.requestId));
    const sessionId = await db.runTransaction(async tx => {
      const sec = (await tx.get(secRef)).data();
      const pending = (await tx.get(target)).data();
      const bindings = await linkedOwners(tx, uid);
      if (action === 'approveReplacement') {
        if (!trusted(request.auth, sec) || !deviceMatches(secret, sec) ||
            pending?.uid !== uid || pending.kind !== 'replacement' || pending.status !== 'pending' || pending.expiresAt <= Date.now() ||
            pending.generation !== sec.generation) deny();
        // The trusted phone's explicit approval confirms replacement. The new
        // phone receives its capability on its next status poll.
        const nextSession = newId();
        tx.set(secRef, {...sec, deviceHash: pending.deviceHash, sessionId: nextSession, generation: sec.generation + 1});
        moveLinkedLearners(tx, bindings, pending.deviceHash);
        tx.update(target, {status: 'consumed'});
        tx.set(db.collection('security_audit').doc(), {action, uid, at: FieldValue.serverTimestamp()});
        return null;
      }
      if (!canConfirm(pending, uid, secret, sec, Date.now())) deny();
      const nextSession = newId();
      tx.set(secRef, {...sec, deviceHash: hash(secret), sessionId: nextSession, generation: (sec?.generation ?? 0) + 1});
      moveLinkedLearners(tx, bindings, hash(secret));
      tx.update(target, {status: 'consumed'});
      tx.set(db.collection('security_audit').doc(), {action, uid, at: FieldValue.serverTimestamp()});
      return nextSession;
    });
    // Rules compare the session claim on every read, including already-issued
    // ID tokens. Password-only sessions never receive this capability.
    return sessionId ? issue(uid, sessionId) : {approved: true};
  }
  if (action === 'logout') {
    await db.runTransaction(async tx => {
      const sec = (await tx.get(secRef)).data();
      if (trusted(request.auth, sec) && deviceMatches(secret, sec)) tx.update(secRef, {sessionId: null});
    });
    return {ok: true};
  }
  // Unlink fully releases the learner: no caregiver record remains, so the
  // learner's QR can be linked again from a trusted phone.
  if (action === 'unlink') {
    const learnerUid = id(data.learnerUid);
    await db.runTransaction(async tx => {
      const sec = (await tx.get(secRef)).data();
      const ownerRef = ref('learner_caregivers', learnerUid);
      const owner = (await tx.get(ownerRef)).data();
      if (!trusted(request.auth, sec) || !deviceMatches(secret, sec) || owner?.parentUid !== uid) deny();
      tx.delete(ownerRef);
      tx.delete(ref('parent_child_links', `${uid}_${learnerUid}`));
      tx.set(db.collection('security_audit').doc(), {action: 'unlink', uid, learnerUid, at: FieldValue.serverTimestamp()});
    });
    return {ok: true};
  }
  throw new HttpsError('invalid-argument', 'Unknown action.');
});

// A verified phone replacement carries this caregiver's learners to the new
// phone. Reads happen here so the caller's transaction can write afterwards.
async function linkedOwners(tx, uid) {
  const links = await tx.get(db.collection('parent_child_links').where('parentFirebaseUid', '==', uid));
  const bindings = [];
  for (const linkDoc of links.docs) {
    const learnerUid = linkDoc.data().learnerFirebaseUid;
    if (typeof learnerUid !== 'string' || !learnerUid) continue;
    const ownerRef = ref('learner_caregivers', learnerUid);
    const owner = (await tx.get(ownerRef)).data();
    if (owner?.parentUid === uid && owner.active === true) bindings.push({ownerRef, linkRef: linkDoc.ref});
  }
  return bindings;
}
function moveLinkedLearners(tx, bindings, deviceHash) {
  for (const {ownerRef, linkRef} of bindings) {
    tx.update(ownerRef, {deviceHash});
    tx.update(linkRef, {deviceHash});
  }
}

// Learners bound to this trusted phone. Owners from before device binding are
// bound once to the phone that is trusted when they are first seen; links for
// learners scanned on another phone stay hidden until scanned here.
async function boundLinks(uid, deviceHash) {
  const links = await db.collection('parent_child_links').where('parentFirebaseUid', '==', uid).get();
  const valid = links.docs.filter(doc => typeof doc.data().learnerFirebaseUid === 'string' && doc.data().learnerFirebaseUid);
  const owners = valid.length
    ? await db.getAll(...valid.map(doc => ref('learner_caregivers', doc.data().learnerFirebaseUid)))
    : [];
  const visible = [];
  for (let i = 0; i < valid.length; i++) {
    const linkDoc = valid[i];
    const link = linkDoc.data();
    const learnerUid = link.learnerFirebaseUid;
    const owner = owners[i].data();
    if (owner?.parentUid !== uid || owner.active !== true) continue;
    let bound = owner.deviceHash === deviceHash;
    if (owner.deviceHash === undefined || link.deviceHash !== owner.deviceHash) {
      bound = await db.runTransaction(async tx => {
        const ownerRef = ref('learner_caregivers', learnerUid);
        const fresh = (await tx.get(ownerRef)).data();
        const current = (await tx.get(linkDoc.ref)).data();
        if (!current || fresh?.parentUid !== uid || fresh.active !== true) return false;
        const ownerHash = fresh.deviceHash ?? deviceHash;
        if (fresh.deviceHash === undefined) tx.update(ownerRef, {deviceHash});
        if (current.deviceHash !== ownerHash) tx.update(linkDoc.ref, {deviceHash: ownerHash});
        return ownerHash === deviceHash;
      });
    }
    if (bound) {
      visible.push({learnerFirebaseUid: learnerUid, learnerName: link.learnerName ?? '',
        learnerProfileCode: link.learnerProfileCode ?? ''});
    }
  }
  return visible;
}

async function recover(request, secret) {
  const {data, auth} = request;
  const target = ref('device_replacements', id(data.requestId));
  const account = await getAuth().getUser(auth.uid);
  const accountEmail = emailOf(account.email);
  if (data.action === 'sendRecovery') {
    if (!recentLogin(auth)) throw new HttpsError('unauthenticated', 'Sign in again before recovery.');
    const recoveryEmail = await db.runTransaction(async tx => {
      const sec = (await tx.get(securityRef(auth.uid))).data();
      const pending = (await tx.get(target)).data();
      if (!sec?.recoveryEmail || pending?.uid !== auth.uid || pending.kind !== 'replacement' ||
          pending.deviceHash !== hash(secret) || pending.status !== 'pending' || pending.expiresAt <= Date.now() ||
          pending.generation !== sec.generation) deny();
      const pinned = emailOf(sec.recoveryEmail);
      if (!account.emailVerified || !accountEmail || accountEmail !== pinned) {
        throw new HttpsError('failed-precondition',
          'The signed-in email must match the pinned recovery email.');
      }
      tx.update(target, {emailRecoveryPending: true});
      return pinned;
    });
    // Only links that will actually be emailed count: 5 per 15 minutes.
    await rateLimit(auth.uid, 'recovery', 5, 15 * 60000);
    return {sent: true, recoveryEmail};
  }
  const oobCode = data.oobCode;
  if (typeof oobCode !== 'string' || !/^[A-Za-z0-9_-]{10,512}$/.test(oobCode)) deny();
  const tokenEmail = emailOf(auth.token.email || account.email);
  const checkPending = async tx => {
    const pending = (await tx.get(target)).data();
    const sec = (await tx.get(securityRef(auth.uid))).data();
    const pinned = emailOf(sec?.recoveryEmail);
    if (!account.emailVerified || tokenEmail !== pinned || accountEmail !== pinned) deny();
    if (pending?.uid !== auth.uid || pending.kind !== 'replacement' || pending.deviceHash !== hash(secret) ||
        pending.status !== 'pending' || pending.generation !== sec?.generation ||
        !pending.emailRecoveryPending || pending.expiresAt <= Date.now()) deny();
    return pinned;
  };
  const pinned = await db.runTransaction(checkPending);
  // ID tokens report "password" for both password and email-link sign-ins, so
  // the one-time code from the email itself is the proof of email ownership.
  await redeemEmailLink(pinned, oobCode, auth.uid);
  await db.runTransaction(async tx => {
    await checkPending(tx);
    tx.update(target, {status: 'approved', emailRecoveryPending: FieldValue.delete()});
  });
  return {verified: true};
}

// Browser approval is intentionally independent of the phone where the email
// was opened. The one-time Firebase email code proves account ownership, while
// the pending request remains bound to the device hash chosen by the new phone.
async function approveRecoveryFromBrowser(requestId, oobCode) {
  const target = ref('device_replacements', id(requestId));
  if (typeof oobCode !== 'string' || !/^[A-Za-z0-9_-]{10,512}$/.test(oobCode)) deny();
  const pending = (await target.get()).data();
  if (pending?.kind !== 'replacement' || pending.status !== 'pending' ||
      !pending.emailRecoveryPending || pending.expiresAt <= Date.now()) deny();
  const sec = (await securityRef(pending.uid).get()).data();
  const pinned = emailOf(sec?.recoveryEmail);
  const account = await activeAccount(pending.uid);
  if (!pinned || !account.emailVerified || emailOf(account.email) !== pinned ||
      pending.generation !== sec?.generation) deny();
  await redeemEmailLink(pinned, oobCode, pending.uid);
  await db.runTransaction(async tx => {
    const fresh = (await tx.get(target)).data();
    const current = (await tx.get(securityRef(pending.uid))).data();
    if (fresh?.kind !== 'replacement' || fresh.uid !== pending.uid ||
        fresh.status !== 'pending' || !fresh.emailRecoveryPending ||
        fresh.expiresAt <= Date.now() ||
        fresh.generation !== current?.generation) deny();
    tx.update(target, {
      status: 'approved',
      emailRecoveryPending: FieldValue.delete(),
      approvedAt: FieldValue.serverTimestamp(),
    });
  });
}

exports.caregiverRecovery = onRequest(
  {region: 'us-central1', invoker: 'public'},
  async (request, response) => {
    response.set('Cache-Control', 'no-store');
    response.set('Content-Type', 'application/json; charset=utf-8');
    if (request.method !== 'POST') {
      response.status(405).json({ok: false});
      return;
    }
    try {
      const body = request.body ?? {};
      await approveRecoveryFromBrowser(body.requestId, body.oobCode);
      response.status(200).json({ok: true});
    } catch (error) {
      console.warn('Browser recovery approval rejected', error?.code ?? 'unknown');
      response.status(400).json({ok: false});
    }
  },
);

async function redeemEmailLink(email, oobCode, uid) {
  const response = await emailLinkSignIn(email, oobCode);
  if (response.localId === uid) return;
  if (response.error === 'INVALID_OOB_CODE' || response.error === 'EXPIRED_OOB_CODE') {
    throw new HttpsError('failed-precondition', 'This link expired or was already used.', {reason: 'linkUsed'});
  }
  deny();
}

// Same public key the app ships with; Identity Toolkit only accepts it for this project.
const AUTH_API_KEY = process.env.AUTH_API_KEY || 'AIzaSyC78hfq5hRC1f9i3jUpL3nHYCz5ONnRFx0';
const emailLinkSignIn = async (email, oobCode) => {
  const reply = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithEmailLink?key=${AUTH_API_KEY}`,
    {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email, oobCode})});
  const body = await reply.json().catch(() => ({}));
  if (reply.ok) return {localId: body.localId};
  const message = String(body?.error?.message ?? '');
  if (reply.status >= 500) throw new HttpsError('unavailable', 'Try again in a moment.');
  return {error: message.split(' ')[0]};
};

// Leftover client-written links stay blocked until this parent confirms.
// Conflicting learner records also require that learner's QR.
async function confirmLegacy(request, secret) {
  const {data, auth} = request;
  if (!recentLogin(auth)) throw new HttpsError('unauthenticated', 'Sign in again before recovery.');
  await rateLimit(auth.uid, 'legacy', 5);
  const account = await getAuth().getUser(auth.uid);
  const accountEmail = emailOf(account.email);
  if (!account.emailVerified || !accountEmail) {
    throw new HttpsError('failed-precondition', 'Verify your email before continuing.');
  }
  const codes = new Set((Array.isArray(data.profileCodes) ? data.profileCodes : [])
    .map(code => String(code).trim().toUpperCase()).filter(code => /^TT-[A-Z0-9]{8}$/.test(code)));
  const sessionId = await db.runTransaction(async tx => {
    const currentRef = securityRef(auth.uid);
    if ((await tx.get(currentRef)).data()) deny();
    const links = await tx.get(db.collection('parent_child_links').where('parentFirebaseUid', '==', auth.uid));
    if (links.empty) deny();
    const ownerWrites = [];
    const extraDeletes = [];
    for (const linkDoc of links.docs) {
      const learnerUid = id(linkDoc.data().learnerFirebaseUid);
      const allLinks = await tx.get(db.collection('parent_child_links').where('learnerFirebaseUid', '==', learnerUid));
      const ownerRef = ref('learner_caregivers', learnerUid);
      const owner = (await tx.get(ownerRef)).data();
      if (owner && (owner.parentUid !== auth.uid || owner.active !== true)) deny();
      if (allLinks.size > 1) {
        const profile = (await tx.get(ref('learner_profiles', learnerUid))).data();
        const code = String(profile?.profileCode ?? '').trim().toUpperCase();
        if (!codes.has(code)) deny();
        for (const other of allLinks.docs) {
          if (other.data().parentFirebaseUid !== auth.uid) extraDeletes.push(other.ref);
        }
      }
      ownerWrites.push(ownerRef);
    }
    const nextSession = newId();
    const deviceHash = hash(secret);
    tx.set(currentRef, {deviceHash, sessionId: nextSession, generation: 1,
      recoveryEmail: account.email.trim()});
    for (const ownerRef of ownerWrites) tx.set(ownerRef, {parentUid: auth.uid, active: true, deviceHash});
    for (const linkDoc of links.docs) tx.update(linkDoc.ref, {deviceHash});
    for (const other of extraDeletes) tx.delete(other);
    tx.set(db.collection('security_audit').doc(), {action: 'confirmLegacy', uid: auth.uid,
      at: FieldValue.serverTimestamp()});
    return nextSession;
  });
  return issue(auth.uid, sessionId);
}

// The current caregiver creates a child-specific offer only after recent
// reauthentication. The next caregiver accepts it on their own trusted phone.
async function transfer(request, secret) {
  const {data, auth} = request;
  const target = ref('device_replacements', id(data.requestId));
  const receiver = await getAuth().getUser(auth.uid);
  if (!receiver.emailVerified || !receiver.email) deny();
  return db.runTransaction(async tx => {
    const nextRef = securityRef(auth.uid);
    const next = (await tx.get(nextRef)).data();
    const pending = (await tx.get(target)).data();
    const learnerUid = id(pending?.learnerUid);
    const currentRef = securityRef(id(pending?.fromUid));
    const current = (await tx.get(currentRef)).data();
    const ownerRef = ref('learner_caregivers', learnerUid);
    const owner = (await tx.get(ownerRef)).data();
    if (!trusted(auth, next) || !deviceMatches(secret, next) ||
        pending?.kind !== 'transfer' || pending.fromUid === auth.uid ||
        pending.status !== 'pending' || pending.expiresAt <= Date.now() ||
        pending.giverGeneration !== current?.generation ||
        owner?.parentUid !== pending.fromUid || owner.active !== true) deny();
    const learner = (await tx.get(ref('learner_profiles', learnerUid))).data();
    if (!learner) deny();
    // Only this learner moves; the former caregiver keeps their trusted phone
    // and any other learners. Rules stop their reads of this learner at once.
    tx.set(ownerRef, {parentUid: auth.uid, active: true, deviceHash: next.deviceHash});
    tx.update(ref('learner_profiles', learnerUid), {emergencyContacts: [], emergencyContactsNeedReview: true});
    tx.delete(ref('parent_child_links', `${pending.fromUid}_${learnerUid}`));
    tx.set(ref('parent_child_links', `${auth.uid}_${learnerUid}`), {
      parentFirebaseUid: auth.uid, learnerFirebaseUid: learnerUid, deviceHash: next.deviceHash,
      learnerName: learner.learnerName ?? '', learnerProfileCode: learner.profileCode ?? '', linkedAt: FieldValue.serverTimestamp()});
    tx.update(target, {status: 'consumed'});
    tx.set(db.collection('security_audit').doc(), {action: 'transfer',
      actor: pending.fromUid, parentUid: auth.uid, learnerUid, at: FieldValue.serverTimestamp()});
    return {transferred: true};
  });
}

async function enrollment(request) {
  const {data, auth} = request;
  const classCode = id(data.classCode);
  const learnerUid = id(data.learnerFirebaseUid);
  return db.runTransaction(async tx => {
    const classroom = (await tx.get(ref('teacher_classes_cloud', classCode))).data();
    if (!classroom) deny();
    const teacherUid = classroom.teacherFirebaseUid;
    if (auth.uid !== teacherUid && auth.uid !== learnerUid) deny();
    const target = ref('class_enrollments_cloud', `${classCode}_${learnerUid}`);
    const existing = (await tx.get(target)).data();
    const join = (await tx.get(ref('class_join_requests_cloud', `${classCode}_${learnerUid}`))).data();
    const accessRef = ref('teacher_learner_access', `${teacherUid}_${learnerUid}`);
    const access = (await tx.get(accessRef)).data();
    const learner = (await tx.get(ref('user_profiles', learnerUid))).data();
    const classes = new Set(access?.classCodes ?? []);
    if (data.action === 'unenroll') {
      classes.delete(classCode);
      tx.delete(target);
      tx.delete(ref('class_join_requests_cloud', `${classCode}_${learnerUid}`));
    } else {
      if (existing && (existing.learnerFirebaseUid !== learnerUid || existing.teacherFirebaseUid !== teacherUid)) deny();
      if (!existing && (join?.learnerFirebaseUid !== learnerUid || join?.teacherFirebaseUid !== teacherUid ||
          !['pending', 'accepted'].includes(join?.status) ||
          (auth.uid !== teacherUid && join?.status !== 'accepted'))) deny();
      classes.add(classCode);
      tx.set(target, {classCode, classId: classroom.classId ?? 0, className: classroom.className ?? '',
        teacherFirebaseUid: teacherUid, teacherName: classroom.teacherName ?? '',
        learnerFirebaseUid: learnerUid, learnerUserId: 0, learnerName: learner?.fullName ?? '',
        enrolledAt: existing?.enrolledAt ?? FieldValue.serverTimestamp()});
    }
    if (classes.size) tx.set(accessRef, {classCodes: [...classes]});
    else tx.delete(accessRef);
    return {ok: true};
  });
}

async function clearClass(request) {
  const {data, auth} = request;
  const classCode = id(data.classCode);
  return db.runTransaction(async tx => {
    const classRef = ref('teacher_classes_cloud', classCode);
    const classroom = (await tx.get(classRef)).data();
    if (!classroom || classroom.teacherFirebaseUid !== auth.uid) deny();
    const enrollments = await tx.get(db.collection('class_enrollments_cloud').where('classCode', '==', classCode));
    const joins = await tx.get(db.collection('class_join_requests_cloud').where('classCode', '==', classCode));
    const grants = [];
    for (const enrollment of enrollments.docs) {
      const target = ref('teacher_learner_access', `${auth.uid}_${enrollment.data().learnerFirebaseUid}`);
      const access = (await tx.get(target)).data();
      grants.push({target, codes: (access?.classCodes ?? []).filter(code => code !== classCode)});
    }
    for (const {target, codes} of grants) {
      if (codes.length) tx.set(target, {classCodes: codes});
      else tx.delete(target);
    }
    for (const enrollment of enrollments.docs) tx.delete(enrollment.ref);
    for (const join of joins.docs) tx.delete(join.ref);
    if (data.action === 'deleteClass') {
      tx.delete(classRef);
    }
    return {ok: true};
  });
}
