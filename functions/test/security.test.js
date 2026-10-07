const {test, before, after, beforeEach} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, getDoc, getDocs, query, collection, where, setDoc, updateDoc, deleteDoc} = require('firebase/firestore');
const {hash, newId, trusted} = require('../security-policy');
process.env.GCLOUD_PROJECT = 'demo-taptalk-security';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.SMTP_PASSWORD = 'test';
process.env.SMTP_HOST = 'test';
process.env.SMTP_USER = 'test';
process.env.SMTP_FROM = 'test@example.test';
const {caregiverSecurity} = require('../index');
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const nodemailer = require('nodemailer');
const db = getFirestore();
const A = 'a'.repeat(64), B = 'b'.repeat(64), C = 'c'.repeat(64);
const account = uid => ({uid, email: `${uid}@example.test`, emailVerified: true});
getAuth().getUser = async uid => account(uid);
getAuth().createCustomToken = async (uid, claims) => JSON.stringify({uid, ...claims});
let mail;
nodemailer.createTransport = () => ({sendMail: async message => { mail = message; }});
let env;
const call = (uid, action, deviceSecret = A, data = {}, session) => caregiverSecurity.run({
  auth: {uid, token: {auth_time: Math.floor(Date.now()/1000), ...(session ? {trustedSession: session} : {})}},
  data: {action, deviceSecret, ...data},
});
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
  mail = null;
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
    e.code === 'permission-denied' && !e.message.includes('Private learner'));
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
  await assertSucceeds(getDoc(doc(env.authenticatedContext('parent', {trustedSession: nextSession}).firestore(), 'learner_activity/tap')));
  await assert.rejects(call('parent', 'approveReplacement', A, {requestId}, session));
});
test('recovery OTP is pinned to old verified email and requires explicit final confirmation', async () => {
  const session = await link();
  getAuth().getUser = async uid => ({...account(uid), email: 'attacker@example.test'});
  const {requestId} = await call('parent', 'requestReplacement', B);
  await call('parent', 'sendRecovery', B, {requestId});
  assert.equal(mail.to, 'parent@example.test');
  const otp = mail.text.match(/\d{8}/)[0];
  await assert.rejects(call('parent', 'verifyRecovery', C, {requestId, otp}));
  await call('parent', 'verifyRecovery', B, {requestId, otp});
  assert.equal((await get('caregiver_security/parent')).sessionId, session);
  await call('parent', 'confirmReplacement', B, {requestId});
  assert.equal((await call('parent', 'status', B)).state, 'trusted');
  assert.equal(trusted({token: {trustedSession: session}}, await get('caregiver_security/parent')), false);
  await assert.rejects(call('parent', 'confirmReplacement', B, {requestId}));
  getAuth().getUser = async uid => account(uid);
});
test('OTP wrong attempts, expired codes and stale password sessions are denied', async () => {
  await link();
  const {requestId} = await call('parent', 'requestReplacement', B);
  await call('parent', 'sendRecovery', B, {requestId});
  const otp = mail.text.match(/\d{8}/)[0];
  for (let i = 0; i < 5; i++) await assert.rejects(call('parent', 'verifyRecovery', B, {requestId, otp: '00000000'}));
  await assert.rejects(call('parent', 'verifyRecovery', B, {requestId, otp}));
  await db.doc(`device_replacements/${requestId}`).update({attempts: 0, otpExpiresAt: 0});
  await assert.rejects(call('parent', 'verifyRecovery', B, {requestId, otp}));
  await assert.rejects(caregiverSecurity.run({auth: {uid: 'parent', token: {auth_time: 1}},
    data: {action: 'sendRecovery', deviceSecret: B, requestId}}), {code: 'unauthenticated'});
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
test('trusted caregiver transfer revokes former caregiver, session and old QR', async () => {
  const session = await link(); await parent('next');
  const {requestId} = await call('next', 'requestTransfer', B);
  await assert.rejects(call('parent', 'transfer', C, {learnerUid: 'learner', requestId}));
  await call('parent', 'transfer', A, {learnerUid: 'learner', requestId}, session);
  assert.equal((await get('learner_caregivers/learner')).parentUid, 'next');
  assert.equal(await get('parent_child_links/parent_learner'), undefined);
  await assertFails(getDoc(doc(env.authenticatedContext('parent', {trustedSession: session}).firestore(), 'learner_profiles/learner')));
  assert.equal((await call('next', 'status', B)).state, 'trusted');
  await assert.rejects(call('parent', 'link', A, {profileCode: 'TT-12345678'}, session));
});
test('unlink tombstone prevents old QR from granting a different caregiver', async () => {
  const session = await link();
  await call('parent', 'unlink', A, {learnerUid: 'learner'}, session);
  await parent('other');
  await assert.rejects(call('other', 'link', B, {profileCode: 'TT-12345678'}));
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
  await assertSucceeds(getDocs(query(collection(parentDb, 'parent_child_links'), where('parentFirebaseUid', '==', 'parent'))));
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
  const {requestId} = await call('next', 'requestTransfer', B);
  await call('parent', 'transfer', A, {learnerUid: 'learner', requestId}, session);
  // A former parent may recover their own account but never this learner's
  // old notifications after its authorization has moved.
  await db.doc('caregiver_security/parent').update({sessionId: 'recovered'});
  await assertFails(getDoc(doc(env.authenticatedContext('parent', {trustedSession: 'recovered'}).firestore(), 'parent_notifications/current')));
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
  const {requestId} = await call('next', 'requestTransfer', B);
  await call('parent', 'transfer', A, {learnerUid: 'learner', requestId}, session);
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
