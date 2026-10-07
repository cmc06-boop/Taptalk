const {test, before, after, beforeEach} = require('node:test');
const fs = require('node:fs');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
let env;
const bucket = 'gs://demo-taptalk-security.appspot.com';
const path = 'phrase_images/learner/private.png';
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-taptalk-security',
    firestore: {host: '127.0.0.1', port: 8080, rules: fs.readFileSync('../firestore.rules', 'utf8')},
    storage: {host: '127.0.0.1', port: 9199, rules: fs.readFileSync('../storage.rules', 'utf8')},
  });
});
beforeEach(async () => {
  await env.clearFirestore(); await env.clearStorage();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await db.doc('user_profiles/learner').set({firebaseUid: 'learner', role: 'learner'});
    await db.doc('user_profiles/teacher').set({firebaseUid: 'teacher', role: 'teacher'});
    await db.doc('caregiver_security/parent').set({sessionId: 'current'});
    await db.doc('learner_caregivers/learner').set({parentUid: 'parent', active: true});
    await context.storage(bucket).ref(path).put(new Uint8Array([1, 2, 3]), {contentType: 'image/png', customMetadata: {audience: 'private'}});
  });
});
after(async () => { await env.cleanup(); });
const storage = (uid, session) => env.authenticatedContext(uid, session ? {trustedSession: session} : {}).storage(bucket);
test('private Storage media rejects strangers and password-only parent sessions', async () => {
  await assertFails(storage('stranger').ref(path).getMetadata());
  await assertFails(storage('parent').ref(path).getMetadata());
  await assertSucceeds(storage('learner').ref(path).getMetadata());
});
test('Storage caregiver authorization stays inside the two-document budget and rejects revocation', async () => {
  await assertSucceeds(storage('parent', 'current').ref(path).getMetadata());
  await env.withSecurityRulesDisabled(context => context.firestore().doc('caregiver_security/parent').update({sessionId: 'next'}));
  await assertFails(storage('parent', 'current').ref(path).getMetadata());
  await assertSucceeds(storage('parent', 'next').ref(path).getMetadata());
  await env.withSecurityRulesDisabled(context => context.firestore().doc('learner_caregivers/learner').update({active: false}));
  await assertFails(storage('parent', 'next').ref(path).getMetadata());
});
test('teacher private-media access requires a current server-owned enrollment grant', async () => {
  await assertFails(storage('teacher').ref(path).getMetadata());
  await env.withSecurityRulesDisabled(context => context.firestore().doc('teacher_learner_access/teacher_learner').set({classCodes: ['CLASS']}));
  await assertSucceeds(storage('teacher').ref(path).getMetadata());
  await env.withSecurityRulesDisabled(context => context.firestore().doc('teacher_learner_access/teacher_learner').delete());
  await assertFails(storage('teacher').ref(path).getMetadata());
});
test('shared lesson media validates the owner role; learners cannot mark private uploads as public lessons', async () => {
  const lesson = 'phrase_images/teacher/lesson.png';
  await assertSucceeds(storage('teacher').ref(lesson).put(new Uint8Array([4]), {contentType: 'image/png', customMetadata: {audience: 'lesson'}}));
  await assertSucceeds(storage('stranger').ref(lesson).getMetadata());
  await assertSucceeds(storage('parent', 'current').ref(lesson).getMetadata());
  await assertFails(storage('learner').ref('phrase_images/learner/spoof.png').put(new Uint8Array([5]), {contentType: 'image/png', customMetadata: {audience: 'lesson'}}));
  await assertFails(storage('stranger').ref(path).put(new Uint8Array([5]), {contentType: 'image/png'}));
});
