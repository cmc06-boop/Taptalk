'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {buildMigrationPlan, applyMigrationPlan} = require('../migrate-security');

function fixture() {
  return {
    links: [{id: 'parent_learner', parentFirebaseUid: 'parent', learnerFirebaseUid: 'learner'}],
    profiles: [{id: 'parent', role: 'parent'}, {id: 'teacher', role: 'teacher'}, {id: 'learner', role: 'learner'}],
    accounts: [{id: 'parent', email: 'parent@example.test', emailVerified: true, disabled: false}],
    owners: [], securities: [], grants: [],
    classes: [{id: 'CLASS', classCode: 'CLASS', teacherFirebaseUid: 'teacher'}],
    enrollments: [{id: 'CLASS_learner', classCode: 'CLASS', teacherFirebaseUid: 'teacher', learnerFirebaseUid: 'learner'}],
  };
}

test('legacy verified relationships seed no device trust or active session', async () => {
  const source = fixture();
  const plan = buildMigrationPlan(source);
  assert.deepEqual(plan.conflicts, []);
  assert.deepEqual(plan.counts, {parentAccounts: 1, newSecurityRecords: 1, newLearnerOwners: 1, teacherGrants: 1});
  const {db, docs, auth} = mockStore(source);
  await applyMigrationPlan(db, auth, plan);
  assert.deepEqual(docs.get('caregiver_security/parent'), {
    recoveryEmail: 'parent@example.test', deviceHash: null, sessionId: null, generation: 0,
  });
  assert.deepEqual(docs.get('learner_caregivers/learner'), {parentUid: 'parent', active: true});
  assert.deepEqual(docs.get('teacher_learner_access/teacher_learner'), {classCodes: ['CLASS']});
});

test('multiple caregivers never choose a winner and prevent apply', async () => {
  const source = fixture();
  source.links.push({id: 'other_learner', parentFirebaseUid: 'other', learnerFirebaseUid: 'learner'});
  source.profiles.push({id: 'other', role: 'parent'});
  source.accounts.push({id: 'other', email: 'other@example.test', emailVerified: true});
  const plan = buildMigrationPlan(source);
  assert.ok(plan.conflicts.some(c => c.code === 'multiple-caregivers'));
  const {db, docs, auth} = mockStore(source);
  await assert.rejects(applyMigrationPlan(db, auth, plan), /Resolve every/);
  assert.equal(docs.has('learner_caregivers/learner'), false);
});

test('disabled, missing and unverified account emails cannot seed recovery', () => {
  for (const account of [null, {emailVerified: false, email: 'p@example.test'},
    {emailVerified: true}, {emailVerified: true, email: 'p@example.test', disabled: true}]) {
    const source = fixture();
    source.accounts = account ? [{id: 'parent', ...account}] : [];
    assert.ok(buildMigrationPlan(source).conflicts.some(c => c.code === 'verified-parent-email-required'));
  }
});

test('malformed or conflicting parent relationships and revocation tombstones fail closed', () => {
  const cases = [
    source => source.links[0].id = 'noncanonical',
    source => source.profiles[0].role = 'teacher',
    source => source.owners.push({id: 'learner', parentUid: 'other', active: true}),
    source => source.owners.push({id: 'learner', parentUid: 'parent', active: false}),
    source => source.owners.push({id: 'otherLearner', parentUid: 'parent', active: true}),
  ];
  for (const modify of cases) {
    const source = fixture(); modify(source);
    assert.ok(buildMigrationPlan(source).conflicts.length > 0);
  }
});

test('repeated migration preserves existing recovery address, device, session and owners', async () => {
  const source = fixture();
  const security = {id: 'parent', recoveryEmail: 'pinned@example.test', deviceHash: 'a'.repeat(64), sessionId: 's'.repeat(64), generation: 4};
  source.securities.push(security);
  source.owners.push({id: 'learner', parentUid: 'parent', active: true});
  source.accounts[0].email = 'changed@example.test';
  source.grants.push({id: 'teacher_learner', classCodes: ['CLASS']});
  const plan = buildMigrationPlan(source);
  assert.equal(plan.counts.newSecurityRecords, 0);
  assert.equal(plan.counts.newLearnerOwners, 0);
  assert.equal(plan.caregiverOperations[0].recoveryEmail, 'pinned@example.test');
  const {db, docs, auth} = mockStore(source);
  await applyMigrationPlan(db, auth, plan);
  const {id, ...stored} = security;
  assert.deepEqual(docs.get('caregiver_security/parent'), stored);
});

test('invalid existing security cannot be silently repaired or replaced', () => {
  const source = fixture();
  source.securities.push({id: 'parent', generation: 0});
  assert.ok(buildMigrationPlan(source).conflicts.some(c => c.code === 'invalid-existing-security'));
});

test('only enrollments for the actual class owner can seed teacher access', () => {
  const cases = [
    source => source.classes[0].teacherFirebaseUid = 'other',
    source => source.classes = [],
    source => source.enrollments[0].id = 'forged',
    source => source.classes[0].classCode = 'OTHER',
    source => source.profiles[1].role = 'parent',
  ];
  for (const modify of cases) {
    const source = fixture(); modify(source);
    const plan = buildMigrationPlan(source);
    assert.ok(plan.conflicts.some(c => c.code === 'enrollment-class-owner-mismatch'));
    assert.equal(plan.teacherOperations.length, 0);
  }
});

test('multiple owned classes aggregate into one complete teacher grant', () => {
  const source = fixture();
  source.classes.push({id: 'SECOND', classCode: 'SECOND', teacherFirebaseUid: 'teacher'});
  source.enrollments.push({id: 'SECOND_learner', classCode: 'SECOND', teacherFirebaseUid: 'teacher', learnerFirebaseUid: 'learner'});
  source.grants.push({id: 'teacher_learner', classCodes: ['CLASS']});
  const plan = buildMigrationPlan(source);
  assert.deepEqual(plan.conflicts, []);
  assert.equal(plan.teacherOperations.length, 1);
  assert.deepEqual(plan.teacherOperations[0].classCodes, ['CLASS', 'SECOND']);
});

test('stale teacher grants cannot preserve access without an owned enrollment', () => {
  const source = fixture();
  source.grants.push({id: 'teacher_learner', classCodes: ['DELETED']});
  assert.ok(buildMigrationPlan(source).conflicts.some(c => c.code === 'grant-without-owned-enrollment'));
  source.grants = [{id: 'unknown_learner', classCodes: ['CLASS']}];
  assert.ok(buildMigrationPlan(source).conflicts.some(c => c.code === 'grant-without-owned-enrollment'));
});

test('apply rechecks account email verification before pinning recovery', async () => {
  const source = fixture();
  const plan = buildMigrationPlan(source);
  const {db, docs} = mockStore(source);
  await assert.rejects(applyMigrationPlan(db, {getUser: async () => ({emailVerified: true, email: 'changed@example.test'})}, plan), /verification changed/);
  assert.equal(docs.has('caregiver_security/parent'), false);
});

test('concurrent link revocation or added caregiver aborts trust migration', async () => {
  for (const change of [
    docs => docs.delete('parent_child_links/parent_learner'),
    docs => docs.set('parent_child_links/other_learner', {parentFirebaseUid: 'other', learnerFirebaseUid: 'learner'}),
  ]) {
    const source = fixture();
    const plan = buildMigrationPlan(source);
    const {db, docs, auth} = mockStore(source);
    change(docs);
    await assert.rejects(applyMigrationPlan(db, auth, plan), /ownership changed/);
    assert.equal(docs.has('caregiver_security/parent'), false);
    assert.equal(docs.has('learner_caregivers/learner'), false);
  }
});

test('concurrent class deletion or takeover aborts teacher grant migration', async () => {
  for (const change of [
    docs => docs.delete('teacher_classes_cloud/CLASS'),
    docs => docs.set('teacher_classes_cloud/CLASS', {classCode: 'CLASS', teacherFirebaseUid: 'other'}),
    docs => docs.delete('class_enrollments_cloud/CLASS_learner'),
  ]) {
    const source = fixture();
    const plan = buildMigrationPlan(source);
    const {db, docs, auth} = mockStore(source);
    change(docs);
    await assert.rejects(applyMigrationPlan(db, auth, plan), /ownership changed/);
    assert.equal(docs.has('teacher_learner_access/teacher_learner'), false);
  }
});

function mockStore(source) {
  const docs = new Map();
  const keys = {links: 'parent_child_links', enrollments: 'class_enrollments_cloud', profiles: 'user_profiles',
    owners: 'learner_caregivers', securities: 'caregiver_security', classes: 'teacher_classes_cloud', grants: 'teacher_learner_access'};
  for (const [key, name] of Object.entries(keys)) {
    for (const record of source[key]) {
      const {id, ...data} = record;
      docs.set(`${name}/${id}`, data);
    }
  }
  const db = {
    doc: path => ({path}),
    collection: name => ({where: (field, op, value) => ({query: {name, field, value}})}),
    runTransaction: async callback => {
      const writes = [];
      await callback({
        get: async target => {
          if (!target.query) return {data: () => docs.get(target.path)};
          const matches = [...docs].filter(([path, data]) => path.startsWith(`${target.query.name}/`) && data[target.query.field] === target.query.value);
          return {size: matches.length};
        },
        create: (target, data) => {
          if (docs.has(target.path)) throw new Error('already exists');
          writes.push([target.path, data]);
        },
        set: (target, data) => writes.push([target.path, data]),
      });
      for (const [path, data] of writes) docs.set(path, data);
    },
  };
  const auth = {getUser: async uid => source.accounts.find(account => account.id === uid)};
  return {db, docs, auth};
}
