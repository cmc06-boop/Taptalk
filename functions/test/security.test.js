const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, getDocs, query, collection, where, setDoc, updateDoc, deleteDoc} = require('firebase/firestore');
const {hash, newId, trusted} = require('../security-policy');
process.env.GCLOUD_PROJECT = 'demo-taptalk-security';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
const {caregiverSecurity, caregiverRecovery} = require('../index');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const db = getFirestore();
const A = 'a'.repeat(64), B = 'b'.repeat(64), C = 'c'.repeat(64);
const account = uid => ({uid, email: `${uid}@example.test`, emailVerified: true});
getAuth().getUser = async uid => account(uid);
getAuth().createCustomToken = async (uid, claims) => JSON.stringify({uid, ...claims});
const emailCodes = new Map();
const realFetch = global.fetch;
global.fetch = async (url, init) => {
  if (!String(url).includes('accounts:signInWithEmailLink')) return realFetch(url, init);
  const {email, oobCode} = JSON.parse(init.body);
  const issued = emailCodes.get(oobCode);
  emailCodes.delete(oobCode);
  return issued && `${issued}@example.test` === email
    ? {ok: true, status: 200, json: async () => ({localId: issued})}
    : {ok: false, status: 400, json: async () => ({error: {message: 'INVALID_OOB_CODE'}})};
};
const emailCode = uid => { const code = `code_${newId()}`; emailCodes.set(code, uid); return code; };
let env;
const call = (uid, action, deviceSecret = A, data = {}, session, provider = 'password') => caregiverSecurity.run({
  auth: {uid, token: {auth_time: Math.floor(Date.now()/1000), email: `${uid}@example.test`,
    firebase: {sign_in_provider: provider}, ...(session ? {trustedSession: session} : {})}},
  data: {action, deviceSecret, ...data},
});
const approveInBrowser = async body => {
  let status;
  let payload;
  const response = {
    set() {},
    status(value) { status = value; return this; },
    json(value) { payload = value; },
  };
  await caregiverRecovery({method: 'POST', body}, response);
  return {status, payload};
};
const get = async path => (await db.doc(path).get()).data();
const parent = async (uid = 'parent') => db.doc(`user_profiles/${uid}`).set({firebaseUid: uid, role: 'parent'});
async function link() {
  const result = await call('parent', 'link', A, {profileCode: 'TT-12345678'});
  return JSON.parse(result.token).trustedSession;
}
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-taptalk-security', firestore: {
    host: '127.0.0.1', port: 8080, rules: fs.readFileSync('../firestore.rules', 'utf8'),
  }});
});
beforeEach(async () => {
  await env.clearFirestore();
  await parent();
  await db.doc('learner_profiles/learner').set({learnerFirebaseUid: 'learner', learnerName: 'Private learner', profileCode: 'TT-12345678', speakHistory: ['private']});
  await db.doc('user_profiles/learner').set({firebaseUid: 'learner', role: 'learner', fullName: 'Private learner'});
  await db.doc('learner_activity/tap').set({learnerFirebaseUid: 'learner', phraseText: 'private'});
});
after(async () => { await env.cleanup(); await db.terminate(); });

test('first QR creates one owner and trusted session; re-scan is idempotent', async () => {
  const session = await link();
  const again = await call('parent', 'link', A, {profileCode: 'TT-12345678'}, session);
  assert.equal(again.alreadyLinked, true);
  assert.equal((await db.collection('parent_child_links').get()).size, 1);
  assert.equal((await get('caregiver_security/parent')).recoveryEmail, 'parent@example.test');
});
test('stolen QR denies another caregiver with no learner data in error', async () => {
  await link(); await parent('other');
  await assert.rejects(call('other', 'link', B, {profileCode: 'TT-12345678'}), e =>
    e.code === 'already-exists' && !e.message.includes('Private learner'));
});
test('simultaneous first QR scans have exactly one winner', async () => {
  await parent('other');
  const results = await Promise.allSettled([
    call('parent', 'link', A, {profileCode: 'TT-12345678'}),
    call('other', 'link', B, {profileCode: 'TT-12345678'}),
  ]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal((await db.collection('parent_child_links').get()).size, 1);
});
test('password-only/new phone login cannot revoke old phone or read protected data', async () => {
  const session = await link();
  const prior = await get('caregiver_security/parent');
  assert.equal((await call('parent', 'status', B)).state, 'verificationRequired');
  await call('parent', 'requestReplacement', B);
  assert.deepEqual(await get('caregiver_security/parent'), prior);
  const stranger = env.authenticatedContext('parent').firestore();
  await assertFails(getDoc(doc(stranger, 'learner_profiles/learner')));
  await assertFails(getDoc(doc(stranger, 'learner_activity/tap')));
  await assertFails(getDoc(doc(stranger, 'user_profiles/learner')));
  await assertFails(getDocs(query(collection(stranger, 'parent_child_links'), where('parentFirebaseUid', '==', 'parent'))));
  const old = env.authenticatedContext('parent', {trustedSession: session}).firestore();
  await assertSucceeds(getDoc(doc(old, 'learner_profiles/learner')));
});
test('first verified sign-in registers exactly one trusted phone; a second phone is not trusted', async () => {
  const first = await call('parent', 'status', A);
  assert.equal(first.state, 'trusted');
  const session = JSON.parse(first.token).trustedSession;
  assert.equal((await get('caregiver_security/parent')).deviceHash, hash(A));
  assert.equal((await get('caregiver_security/parent')).recoveryEmail, 'parent@example.test');
  assert.equal((await call('parent', 'status', B)).state, 'verificationRequired');
  assert.equal((await call('parent', 'status', A, {}, session)).state, 'trusted');
  assert.equal((await get('caregiver_security/parent')).deviceHash, hash(A));
  await assert.rejects(call('parent', 'adoptDevice', B), {code: 'invalid-argument'});
  assert.equal((await get('caregiver_security/parent')).deviceHash, hash(A));
});
test('unverified email never registers a phone', async () => {
  getAuth().getUser = async uid => ({...account(uid), emailVerified: false});
  assert.equal((await call('parent', 'status', A)).state, 'setup');
  getAuth().getUser = async uid => account(uid);
  assert.equal(await get('caregiver_security/parent'), undefined);
});
test('old-phone approval atomically activates new phone and invalidates old tokens', async () => {
  const session = await link();
  const {requestId} = await call('parent', 'requestReplacement', B);
  const requests = await call('parent', 'status', A, {}, session);
  assert.equal(requests.requests[0].id, requestId);
  await assert.rejects(call('parent', 'approveReplacement', B, {requestId}), {code: 'permission-denied'});
  await call('parent', 'approveReplacement', A, {requestId}, session);
  const next = await call('parent', 'status', B);
  assert.equal(next.state, 'trusted');
  assert.equal((await call('parent', 'status', A)).state, 'verificationRequired');
  await assertFails(getDoc(doc(env.authenticatedContext('parent', {trustedSession: session}).firestore(), 'learner_activity/tap')));
  const nextSession = JSON.parse(next.token).trustedSession;
  assert.equal(next.links.length, 1);
  assert.equal((await get('learner_caregivers/learner')).deviceHash, hash(B));
  const nextDb = env.authenticatedContext('parent', {trustedSession: nextSession}).firestore();
  await assertSucceeds(getDoc(doc(nextDb, 'learner_activity/tap')));
  await assert.rejects(call('parent', 'approveReplacement', A, {requestId}, session));
});
test('a learner is visible only on the phone that scanned their QR', async () => {
  const session = await link();
  assert.equal((await get('learner_caregivers/learner')).deviceHash, hash(A));
  assert.equal((await get('parent_child_links/parent_learner')).deviceHash, hash(A));
  const parentDb = env.authenticatedContext('parent', {trustedSession: session}).firestore();
  await assertSucceeds(getDocs(query(collection(parentDb, 'parent_child_links'),
    where('parentFirebaseUid', '==', 'parent'), where('deviceHash', '==', hash(A)))));
  await assertFails(getDocs(query(collection(parentDb, 'parent_child_links'), where('parentFirebaseUid', '==', 'parent'))));
  // The same account on another phone never reads the learner or their QR code.
  await db.doc('caregiver_security/parent').update({deviceHash: hash(B)});
  await assertFails(getDoc(doc(parentDb, 'learner_activity/tap')));
  await assertFails(getDoc(doc(parentDb, 'learner_profiles/learner')));
  await assertFails(getDocs(query(collection(parentDb, 'parent_child_links'),
    where('parentFirebaseUid', '==', 'parent'), where('deviceHash', '==', hash(A)))));
  assert.equal((await call('parent', 'status', B, {}, session)).links.length, 0);
});
test('owners from before device binding are bound once to the trusted phone', async () => {
  const session = await link();
  await db.doc('learner_caregivers/learner').set({parentUid: 'parent', active: true});
  await db.doc('parent_child_links/parent_learner').update({deviceHash: FieldValue.delete()});
  assert.equal((await call('parent', 'status', A, {}, session)).links.length, 1);
  assert.equal((await get('learner_caregivers/learner')).deviceHash, hash(A));
  assert.equal((await get('parent_child_links/parent_learner')).deviceHash, hash(A));
});
test('recovery email link is pinned to the verified Auth email and requires explicit final confirmation', async () => {
  const session = await link();
  getAuth().getUser = async uid => ({...account(uid), email: 'attacker@example.test'});
  const {requestId} = await call('parent', 'requestReplacement', B);
  await assert.rejects(call('parent', 'sendRecovery', B, {requestId}), {code: 'failed-precondition'});
  getAuth().getUser = async uid => account(uid);
  const sent = await call('parent', 'sendRecovery', B, {requestId});
  assert.equal(sent.recoveryEmail, 'parent@example.test');
  await assert.rejects(call('parent', 'verifyRecovery', B, {requestId}), {code: 'permission-denied'});
  await assert.rejects(call('parent', 'verifyRecovery', B, {requestId, oobCode: 'code_not_from_email'}),
    {code: 'failed-precondition'});
  await assert.rejects(call('parent', 'verifyRecovery', C, {requestId, oobCode: emailCode('parent')}));
  const code = emailCode('parent');
  await call('parent', 'verifyRecovery', B, {requestId, oobCode: code});
  await assert.rejects(call('parent', 'verifyRecovery', B, {requestId, oobCode: code}));
  assert.equal((await get('caregiver_security/parent')).sessionId, session);
  const confirmed = await call('parent', 'confirmReplacement', B, {requestId});
  const recovered = await call('parent', 'status', B, {}, JSON.parse(confirmed.token).trustedSession);
  assert.equal(recovered.state, 'trusted');
  assert.equal(recovered.links.length, 1);
  assert.equal((await get('parent_child_links/parent_learner')).deviceHash, hash(B));
  await assertFails(getDoc(doc(env.authenticatedContext('parent', {trustedSession: session}).firestore(), 'learner_activity/tap')));
  assert.equal(trusted({token: {trustedSession: session}}, await get('caregiver_security/parent')), false);
  await assert.rejects(call('parent', 'confirmReplacement', B, {requestId}));
});
test('email opened in another browser approves only the requesting new phone', async () => {
  const oldSession = await link();
  const {requestId} = await call('parent', 'requestReplacement', B);
  await call('parent', 'sendRecovery', B, {requestId});
  const approval = await approveInBrowser({
    requestId,
    oobCode: emailCode('parent'),
  });
  assert.equal(approval.status, 200);
  assert.deepEqual(approval.payload, {ok: true});
  assert.deepEqual(
    await call('parent', 'replacementStatus', B, {requestId}),
    {status: 'approved'},
  );
  await assert.rejects(
    call('parent', 'replacementStatus', C, {requestId}),
    {code: 'permission-denied'},
  );
  const confirmed = await call('parent', 'confirmReplacement', B, {requestId});
  const nextSession = JSON.parse(confirmed.token).trustedSession;
  assert.equal((await call('parent', 'status', B, {}, nextSession)).state, 'trusted');
  assert.equal(
    trusted(
      {token: {trustedSession: oldSession}},
      await get('caregiver_security/parent'),
    ),
    false,
  );
});
test('stale password sessions and expired recovery requests are denied', async () => {
  await link();
  const {requestId} = await call('parent', 'requestReplacement', B);
  await call('parent', 'sendRecovery', B, {requestId});
  await db.doc(`device_replacements/${requestId}`).update({expiresAt: 0});
  await assert.rejects(call('parent', 'verifyRecovery', B, {requestId, oobCode: emailCode('parent')}));
  await assert.rejects(caregiverSecurity.run({auth: {uid: 'parent', token: {auth_time: 1, email: 'parent@example.test',
    firebase: {sign_in_provider: 'password'}}},
    data: {action: 'sendRecovery', deviceSecret: B, requestId}}), {code: 'unauthenticated'});
});
test('unambiguous leftover parent links can be confirmed onto this phone', async () => {
  await db.doc('parent_child_links/parent_learner').set({
    parentFirebaseUid: 'parent', learnerFirebaseUid: 'learner', learnerName: 'Private learner',
    learnerProfileCode: 'TT-12345678'});
  const status = await call('parent', 'status', B);
  assert.equal(status.state, 'legacyConfirmation');
  assert.equal(status.learners[0].ambiguous, false);
  await call('parent', 'confirmLegacy', B);
  assert.equal((await call('parent', 'status', B)).state, 'trusted');
  assert.equal((await get('learner_caregivers/learner')).parentUid, 'parent');
  assert.equal((await get('caregiver_security/parent')).recoveryEmail, 'parent@example.test');
});
test('conflicting leftover caregiver links require this learner QR and do not auto-pick', async () => {
  await parent('other');
  await db.doc('parent_child_links/parent_learner').set({
    parentFirebaseUid: 'parent', learnerFirebaseUid: 'learner', learnerName: 'Private learner',
    learnerProfileCode: 'TT-12345678'});
  await db.doc('parent_child_links/other_learner').set({
    parentFirebaseUid: 'other', learnerFirebaseUid: 'learner', learnerName: 'Private learner',
    learnerProfileCode: 'TT-12345678'});
  const status = await call('parent', 'status', B);
  assert.equal(status.learners[0].ambiguous, true);
  await assert.rejects(call('parent', 'confirmLegacy', B));
  await call('parent', 'confirmLegacy', B, {profileCodes: ['TT-12345678']});
  assert.equal((await get('learner_caregivers/learner')).parentUid, 'parent');
  assert.equal(await get('parent_child_links/other_learner'), undefined);
  await assert.rejects(call('other', 'confirmLegacy', C, {profileCodes: ['TT-12345678']}));
});
test('pending approvals from an older generation cannot replace the current phone', async () => {
  const session = await link();
  const b = await call('parent', 'requestReplacement', B);
  const c = await call('parent', 'requestReplacement', C);
  await call('parent', 'approveReplacement', A, {requestId: b.requestId}, session);
  const next = JSON.parse((await call('parent', 'status', B)).token).trustedSession;
  await assert.rejects(call('parent', 'approveReplacement', B, {requestId: c.requestId}, next));
});
test('normal logout invalidates session but preserves trust; reinstall secret requires verification', async () => {
  const session = await link();
  await call('parent', 'logout', A, {}, session);
  assert.equal((await get('caregiver_security/parent')).deviceHash, hash(A));
  assert.equal((await get('caregiver_security/parent')).sessionId, null);
  assert.equal((await call('parent', 'status', A)).state, 'trusted');
  assert.equal((await call('parent', 'status', newId())).state, 'verificationRequired');
});
test('transfer moves only that learner; the former caregiver keeps their phone and other learners', async () => {
  const session = await link(); await parent('next');
  await db.doc('learner_profiles/second').set({learnerFirebaseUid: 'second', learnerName: 'Second', profileCode: 'TT-87654321'});
  await call('parent', 'link', A, {profileCode: 'TT-87654321'}, session);
  const nextSession = JSON.parse((await call('next', 'status', B)).token).trustedSession;
  await assert.rejects(caregiverSecurity.run({auth: {uid: 'parent', token: {
    auth_time: 1, email: 'parent@example.test', trustedSession: session,
    firebase: {sign_in_provider: 'password'}}},
  data: {action: 'requestTransfer', deviceSecret: A, learnerUid: 'learner'}}),
  {code: 'unauthenticated'});
  // Fresh account proof plus the bound device secret works even though
  // reauthentication replaced the token and dropped its trusted claim.
  await assert.rejects(call('parent', 'requestTransfer', C, {learnerUid: 'learner'}));
  const {requestId} = await call('parent', 'requestTransfer', A, {learnerUid: 'learner'});
  assert.match(requestId, /^TR-[A-HJ-NP-Z2-9]{8}$/);
  await assert.rejects(call('next', 'transfer', C, {requestId}, nextSession));
  await call('next', 'transfer', B, {requestId}, nextSession);
  assert.equal((await get('learner_caregivers/learner')).parentUid, 'next');
  assert.equal(await get('parent_child_links/parent_learner'), undefined);
  const parentDb = env.authenticatedContext('parent', {trustedSession: session}).firestore();
  await assertFails(getDoc(doc(parentDb, 'learner_profiles/learner')));
  await assertSucceeds(getDoc(doc(parentDb, 'learner_profiles/second')));
  const former = await call('parent', 'status', A, {}, session);
  assert.equal(former.state, 'trusted');
  assert.deepEqual(former.links.map(link => link.learnerFirebaseUid), ['second']);
  assert.equal((await call('next', 'status', B, {}, nextSession)).state, 'trusted');
  await assert.rejects(call('parent', 'link', A, {profileCode: 'TT-12345678'}, session), {code: 'already-exists'});
});
test('unlink fully releases the learner so its QR can be linked again', async () => {
  const session = await link();
  await call('parent', 'unlink', A, {learnerUid: 'learner'}, session);
  assert.equal(await get('learner_caregivers/learner'), undefined);
  assert.equal(await get('parent_child_links/parent_learner'), undefined);
  await assertFails(getDoc(doc(env.authenticatedContext('parent', {trustedSession: session}).firestore(), 'learner_profiles/learner')));
  const again = await call('parent', 'link', A, {profileCode: 'TT-12345678'}, session);
  assert.equal(again.alreadyLinked, false);
  assert.equal((await get('learner_caregivers/learner')).parentUid, 'parent');
});
test('learners left inactive by the old unlink can be linked again', async () => {
  const session = await link();
  await db.doc('learner_caregivers/learner').update({active: false});
  await db.doc('parent_child_links/parent_learner').delete();
  await call('parent', 'link', A, {profileCode: 'TT-12345678'}, session);
  assert.equal((await get('learner_caregivers/learner')).active, true);
});
test('clients cannot forge owners, trusted sessions, links or teacher access', async () => {
  const attacker = env.authenticatedContext('attacker').firestore();
  for (const path of ['caregiver_security/attacker', 'user_security/attacker', 'learner_caregivers/learner',
    'device_replacements/forged', 'parent_child_links/attacker_learner', 'teacher_learner_access/attacker_learner']) {
    await assertFails(setDoc(doc(attacker, path), {parentUid: 'attacker', sessionId: 'forged', learnerFirebaseUid: 'learner', parentFirebaseUid: 'attacker'}));
  }
  await assertFails(setDoc(doc(attacker, 'class_enrollments_cloud/forged'), {teacherFirebaseUid: 'attacker', learnerFirebaseUid: 'learner'}));
  await assertFails(getDoc(doc(attacker, 'learner_profiles/learner')));
});
test('authorized teacher reads learner activity; forged enrollment is denied', async () => {
  await db.doc('teacher_classes_cloud/CLASS').set({teacherFirebaseUid: 'teacher', classCode: 'CLASS'});
  await assert.rejects(call('teacher', 'enroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'}));
  await db.doc('class_join_requests_cloud/CLASS_learner').set({learnerFirebaseUid: 'learner', teacherFirebaseUid: 'teacher', status: 'pending'});
  await call('teacher', 'enroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'});
  const teacher = env.authenticatedContext('teacher').firestore();
  await assertSucceeds(getDocs(query(collection(teacher, 'learner_activity'), where('learnerFirebaseUid', '==', 'learner'))));
  await call('teacher', 'unenroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'});
  await assertFails(getDoc(doc(teacher, 'learner_profiles/learner')));
});
test('trusted monitoring queries work; role changes and class ownership takeover are denied', async () => {
  const session = await link();
  const parentDb = env.authenticatedContext('parent', {trustedSession: session}).firestore();
  await assertSucceeds(getDocs(query(collection(parentDb, 'learner_activity'), where('learnerFirebaseUid', '==', 'learner'))));
  await assertSucceeds(getDocs(query(collection(parentDb, 'parent_child_links'),
    where('parentFirebaseUid', '==', 'parent'), where('deviceHash', '==', hash(A)))));
  await assertFails(updateDoc(doc(parentDb, 'user_profiles/parent'), {role: 'teacher'}));
  await db.doc('teacher_classes_cloud/CLASS').set({classCode: 'CLASS', teacherFirebaseUid: 'teacher'});
  await assertFails(updateDoc(doc(parentDb, 'teacher_classes_cloud/CLASS'), {teacherFirebaseUid: 'parent'}));
});

test('notifications require the current caregiver grant and a scoped learner query', async () => {
  const session = await link();
  await db.doc('parent_notifications/current').set({parentFirebaseUid: 'parent', learnerFirebaseUid: 'learner', teacherFirebaseUid: 'teacher'});
  await db.doc('parent_notifications/revoked').set({parentFirebaseUid: 'parent', learnerFirebaseUid: 'revoked', teacherFirebaseUid: 'teacher'});
  const parentDb = env.authenticatedContext('parent', {trustedSession: session}).firestore();
  await assertFails(getDocs(query(collection(parentDb, 'parent_notifications'), where('parentFirebaseUid', '==', 'parent'))));
  await assertSucceeds(getDocs(query(collection(parentDb, 'parent_notifications'), where('parentFirebaseUid', '==', 'parent'), where('learnerFirebaseUid', '==', 'learner'))));
  await assertFails(getDoc(doc(parentDb, 'parent_notifications/revoked')));
  await parent('next');
  const nextSession = JSON.parse((await call('next', 'status', B)).token).trustedSession;
  const {requestId} = await call('parent', 'requestTransfer', A, {learnerUid: 'learner'}, session);
  await call('next', 'transfer', B, {requestId}, nextSession);
  // The former parent stays trusted but never reads this learner's old
  // notifications after its authorization has moved.
  await assertFails(getDoc(doc(parentDb, 'parent_notifications/current')));
});
test('private phrase media denies strangers and stale sessions; teacher lesson media remains readable', async () => {
  const session = await link();
  await db.doc('phrase_media_cloud/private').set({teacherFirebaseUid: 'learner', data: 'private media'});
  await db.doc('user_profiles/teacher').set({firebaseUid: 'teacher', role: 'teacher'});
  await db.doc('phrase_media_cloud/lesson').set({teacherFirebaseUid: 'teacher', data: 'lesson media'});
  const stranger = env.authenticatedContext('stranger').firestore();
  await assertFails(getDoc(doc(stranger, 'phrase_media_cloud/private')));
  await assertSucceeds(getDoc(doc(stranger, 'phrase_media_cloud/lesson')));
  const parentDb = env.authenticatedContext('parent', {trustedSession: session}).firestore();
  await assertSucceeds(getDoc(doc(parentDb, 'phrase_media_cloud/private')));
  await db.doc('caregiver_security/parent').update({sessionId: 'replacement'});
  await assertFails(getDoc(doc(parentDb, 'phrase_media_cloud/private')));
});
test('class deletion revokes teacher grants while preserving other authorized classes', async () => {
  for (const classCode of ['CLASS1', 'CLASS2']) {
    await db.doc(`teacher_classes_cloud/${classCode}`).set({teacherFirebaseUid: 'teacher', classCode});
    await db.doc(`class_join_requests_cloud/${classCode}_learner`).set({learnerFirebaseUid: 'learner', teacherFirebaseUid: 'teacher', status: 'pending'});
    await call('teacher', 'enroll', A, {classCode, learnerFirebaseUid: 'learner'});
  }
  const teacherDb = env.authenticatedContext('teacher').firestore();
  await assertFails(deleteDoc(doc(teacherDb, 'teacher_classes_cloud/CLASS1')));
  await assert.rejects(call('stranger', 'deleteClass', A, {classCode: 'CLASS1'}));
  await call('teacher', 'deleteClass', A, {classCode: 'CLASS1'});
  assert.deepEqual((await get('teacher_learner_access/teacher_learner')).classCodes, ['CLASS2']);
  await assertSucceeds(getDoc(doc(teacherDb, 'learner_profiles/learner')));
  await call('teacher', 'deleteClass', A, {classCode: 'CLASS2'});
  await assertFails(getDoc(doc(teacherDb, 'learner_profiles/learner')));
});
test('rejected join requests and nonexistent existing enrollments never grant teacher access', async () => {
  await db.doc('teacher_classes_cloud/CLASS').set({teacherFirebaseUid: 'teacher', classCode: 'CLASS'});
  await db.doc('class_join_requests_cloud/CLASS_learner').set({learnerFirebaseUid: 'learner', teacherFirebaseUid: 'teacher', status: 'rejected'});
  await assert.rejects(call('teacher', 'enroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'}));
  await assert.rejects(call('learner', 'enroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'}));
});
test('removed enrollments cannot reuse accepted join requests to restore access', async () => {
  await db.doc('teacher_classes_cloud/CLASS').set({teacherFirebaseUid: 'teacher', classCode: 'CLASS'});
  const joinRef = db.doc('class_join_requests_cloud/CLASS_learner');
  await joinRef.set({learnerFirebaseUid: 'learner', teacherFirebaseUid: 'teacher', status: 'accepted'});
  await call('teacher', 'enroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'});
  await call('teacher', 'unenroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'});
  await assert.rejects(call('learner', 'enroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'}));
  assert.equal(await get('teacher_learner_access/teacher_learner'), undefined);
  await joinRef.set({learnerFirebaseUid: 'learner', teacherFirebaseUid: 'teacher', status: 'pending'});
  await assert.rejects(call('learner', 'enroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'}));
  await call('teacher', 'enroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'});
  await call('teacher', 'clearClassEnrollments', A, {classCode: 'CLASS'});
  await assert.rejects(call('learner', 'enroll', A, {classCode: 'CLASS', learnerFirebaseUid: 'learner'}));
});
test('deleted and disabled Auth accounts cannot mint replacement sessions', async () => {
  await link();
  getAuth().getUser = async uid => ({...account(uid), disabled: true});
  await assert.rejects(call('parent', 'status', A), {code: 'unauthenticated'});
  getAuth().getUser = async () => { throw Object.assign(new Error('Deleted'), {code: 'auth/user-not-found'}); };
  await assert.rejects(call('parent', 'status', A), {code: 'unauthenticated'});
  getAuth().getUser = async uid => account(uid);
});
test('caregiver transfer pauses SMS recipients until the learner explicitly reviews them', async () => {
  const session = await link(); await parent('next');
  await db.doc('learner_profiles/learner').update({emergencyContacts: ['09123456789']});
  const nextSession = JSON.parse((await call('next', 'status', B)).token).trustedSession;
  const {requestId} = await call('parent', 'requestTransfer', A, {learnerUid: 'learner'}, session);
  await call('next', 'transfer', B, {requestId}, nextSession);
  const profile = await get('learner_profiles/learner');
  assert.deepEqual(profile.emergencyContacts, []);
  assert.equal(profile.emergencyContactsNeedReview, true);
  const learnerDb = env.authenticatedContext('learner').firestore();
  // Background contact sync may preserve local numbers, but cannot lift the
  // review pause or restore automatic sending to the previous caregiver.
  await assertSucceeds(updateDoc(doc(learnerDb, 'learner_profiles/learner'), {emergencyContacts: ['09123456789']}));
  await assertFails(updateDoc(doc(learnerDb, 'learner_profiles/learner'), {emergencyContactsNeedReview: false}));
  await assert.rejects(call('parent', 'reviewEmergencyContacts', A, {contacts: ['09987654321']}));
  await call('learner', 'reviewEmergencyContacts', A, {contacts: ['09987654321']});
  assert.deepEqual((await get('learner_profiles/learner')).emergencyContacts, ['09987654321']);
  assert.equal((await get('learner_profiles/learner')).emergencyContactsNeedReview, false);
});
