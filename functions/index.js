const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {hash, newId, trusted, deviceMatches, canConfirm} = require('./security-policy');
initializeApp();
const db = getFirestore();
const deny = () => { throw new HttpsError('permission-denied', 'Verification required or request unavailable.'); };
const emailOf = value => typeof value === 'string' ? value.trim().toLowerCase() : '';
const recentLogin = auth => Number.isFinite(auth.token.auth_time) && Date.now() / 1000 - auth.token.auth_time <= 300;
const signInProvider = auth => auth.token?.firebase?.sign_in_provider;
const ref = (collection, id) => db.collection(collection).doc(id);
const id = value => {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) deny();
  return value;
};
const securityRef = uid => ref('caregiver_security', uid);
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
  if (profile?.role !== 'parent') deny();
  const secret = data.deviceSecret;
  if (typeof secret !== 'string' || !/^[a-f0-9]{64}$/.test(secret)) deny();
  if (action === 'transfer') return transfer(request, secret);
  if (action === 'confirmLegacy') return confirmLegacy(request, secret);
  if (action === 'sendRecovery' || action === 'verifyRecovery') return recover(request, secret);
  if (action === 'status') {
    const account = caller;
    const accountEmail = emailOf(account.email);
    const result = await db.runTransaction(async tx => {
      const sec = (await tx.get(secRef)).data();
      if (!sec) {
        const legacy = await tx.get(db.collection('parent_child_links').where('parentFirebaseUid', '==', uid).limit(1));
        if (!legacy.empty) return {state: 'legacyConfirmation'};
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
      const owner = (await tx.get(ownerRef)).data();
      const legacy = await tx.get(db.collection('parent_child_links').where('learnerFirebaseUid', '==', learnerUid));
      // Deployment migration pins existing verified email ownership. An old
      // QR never bootstraps trust on an unverified replacement phone.
      if (!owner && !legacy.empty) deny();
      if (owner && (owner.parentUid !== uid || owner.active !== true)) deny();
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
  if (action === 'requestReplacement' || action === 'requestTransfer') {
    await rateLimit(uid, 'replacement', 10, 15 * 60000);
    const sec = (await secRef.get()).data();
    const account = await getAuth().getUser(uid);
    if (action === 'requestTransfer' && (!account.emailVerified || !account.email)) deny();
    const requestId = newId();
    await ref('device_replacements', requestId).set({uid, deviceHash: hash(secret),
      kind: action === 'requestTransfer' ? 'transfer' : 'replacement',
      recoveryEmail: sec?.recoveryEmail ?? (action === 'requestTransfer' ? account.email : null),
      generation: sec?.generation ?? 0, status: 'pending', expiresAt: Date.now() + 15 * 60000});
    return {requestId};
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
  // Unlink is a revocation tombstone; scanning the old QR cannot reopen it.
  if (action === 'unlink') {
    const learnerUid = id(data.learnerUid);
    await db.runTransaction(async tx => {
      const sec = (await tx.get(secRef)).data();
      const ownerRef = ref('learner_caregivers', learnerUid);
      const owner = (await tx.get(ownerRef)).data();
      if (!trusted(request.auth, sec) || !deviceMatches(secret, sec) || owner?.parentUid !== uid) deny();
      tx.update(ownerRef, {active: false});
      tx.delete(ref('parent_child_links', `${uid}_${learnerUid}`));
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
  if (!recentLogin(auth)) throw new HttpsError('unauthenticated', 'Sign in again before recovery.');
  const target = ref('device_replacements', id(data.requestId));
  const account = await getAuth().getUser(auth.uid);
  const accountEmail = emailOf(account.email);
  if (data.action === 'sendRecovery') {
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
  if (signInProvider(auth) !== 'emailLink') {
    throw new HttpsError('failed-precondition', 'Open the recovery link from your email on this phone.');
  }
  const tokenEmail = emailOf(auth.token.email || account.email);
  await db.runTransaction(async tx => {
    const pending = (await tx.get(target)).data();
    const sec = (await tx.get(securityRef(auth.uid))).data();
    const pinned = emailOf(sec?.recoveryEmail);
    if (!account.emailVerified || tokenEmail !== pinned || accountEmail !== pinned) deny();
    if (pending?.uid !== auth.uid || pending.kind !== 'replacement' || pending.deviceHash !== hash(secret) ||
        pending.status !== 'pending' || pending.generation !== sec?.generation ||
        !pending.emailRecoveryPending || pending.expiresAt <= Date.now()) deny();
    tx.update(target, {status: 'approved', emailRecoveryPending: FieldValue.delete()});
  });
  return {verified: true};
}

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

// Transfer requires the current trusted caregiver's explicit approval and a
// request created by the next caregiver, who has verified their own email.
async function transfer(request, secret) {
  const {data, auth} = request;
  const learnerUid = id(data.learnerUid);
  const target = ref('device_replacements', id(data.requestId));
  return db.runTransaction(async tx => {
    const currentRef = securityRef(auth.uid);
    const current = (await tx.get(currentRef)).data();
    const pending = (await tx.get(target)).data();
    const ownerRef = ref('learner_caregivers', learnerUid);
    const owner = (await tx.get(ownerRef)).data();
    if (!trusted(auth, current) || !deviceMatches(secret, current) || owner?.parentUid !== auth.uid ||
        owner.active !== true || pending?.kind !== 'transfer' || pending.uid === auth.uid ||
        pending.status !== 'pending' || pending.expiresAt <= Date.now() || !pending.recoveryEmail) deny();
    const nextRef = securityRef(pending.uid);
    const next = (await tx.get(nextRef)).data();
    const learner = (await tx.get(ref('learner_profiles', learnerUid))).data();
    if (!learner || pending.generation !== (next?.generation ?? 0)) deny();
    // Existing caregivers must use their already trusted phone for a transfer.
    if (next && next.deviceHash !== pending.deviceHash) deny();
    tx.set(currentRef, {...current, sessionId: null, deviceHash: null, generation: current.generation + 1});
    tx.set(nextRef, {deviceHash: pending.deviceHash, sessionId: newId(),
      generation: (next?.generation ?? 0) + 1, recoveryEmail: next?.recoveryEmail ?? pending.recoveryEmail});
    tx.set(ownerRef, {parentUid: pending.uid, active: true, deviceHash: pending.deviceHash});
    tx.update(ref('learner_profiles', learnerUid), {emergencyContacts: [], emergencyContactsNeedReview: true});
    tx.delete(ref('parent_child_links', `${auth.uid}_${learnerUid}`));
    tx.set(ref('parent_child_links', `${pending.uid}_${learnerUid}`), {
      parentFirebaseUid: pending.uid, learnerFirebaseUid: learnerUid, deviceHash: pending.deviceHash,
      learnerName: learner.learnerName ?? '', learnerProfileCode: learner.profileCode ?? '', linkedAt: FieldValue.serverTimestamp()});
    tx.update(target, {status: 'consumed'});
    tx.set(db.collection('security_audit').doc(), {action: 'transfer', actor: auth.uid,
      parentUid: pending.uid, learnerUid, at: FieldValue.serverTimestamp()});
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
