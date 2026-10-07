#!/usr/bin/env node
'use strict';

// Existing cloud relationships are evidence for an operator-reviewed migration,
// never a reason for an unverified client to receive a trusted session.
const cleanUid = value => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const byId = records => new Map(records.map(record => [record.id, record]));
const uniqueSorted = values => [...new Set(values)].sort();

function buildMigrationPlan(source) {
  const links = source.links ?? [];
  const enrollments = source.enrollments ?? [];
  const profiles = byId(source.profiles ?? []);
  const accounts = byId(source.accounts ?? []);
  const owners = byId(source.owners ?? []);
  const securities = byId(source.securities ?? []);
  const classes = byId(source.classes ?? []);
  const grants = byId(source.grants ?? []);
  const conflicts = [];
  const caregivers = new Map();
  const learnerParents = new Map();
  const teacherPairs = new Map();
  const conflict = (code, id) => conflicts.push({code, id});

  for (const link of links) {
    const parentUid = link.parentFirebaseUid;
    const learnerUid = link.learnerFirebaseUid;
    if (!cleanUid(parentUid) || !cleanUid(learnerUid) || link.id !== `${parentUid}_${learnerUid}`) {
      conflict('invalid-parent-link', link.id);
      continue;
    }
    if (profiles.get(parentUid)?.role !== 'parent' || profiles.get(learnerUid)?.role !== 'learner') {
      conflict('parent-link-role-mismatch', link.id);
      continue;
    }
    const parents = learnerParents.get(learnerUid) ?? new Set();
    parents.add(parentUid);
    learnerParents.set(learnerUid, parents);
    const list = caregivers.get(parentUid) ?? [];
    list.push({learnerUid, linkId: link.id});
    caregivers.set(parentUid, list);
  }
  for (const [learnerUid, parents] of learnerParents) {
    if (parents.size !== 1) conflict('multiple-caregivers', learnerUid);
    const owner = owners.get(learnerUid);
    if (owner && (!parents.has(owner.parentUid) || owner.active !== true)) {
      conflict('caregiver-owner-mismatch', learnerUid);
    }
  }
  for (const owner of owners.values()) {
    if (owner.active === true && !learnerParents.get(owner.id)?.has(owner.parentUid)) {
      conflict('active-owner-without-link', owner.id);
    }
  }

  const caregiverOperations = [];
  for (const [parentUid, relationships] of caregivers) {
    const account = accounts.get(parentUid);
    const security = securities.get(parentUid);
    // An existing pinned recovery address survives subsequent Auth-email edits.
    const recoveryEmail = security ? security.recoveryEmail : account?.email;
    if (!security && (!account || account.disabled || account.emailVerified !== true ||
        typeof account.email !== 'string' || !account.email.trim())) {
      conflict('verified-parent-email-required', parentUid);
      continue;
    }
    if (typeof recoveryEmail !== 'string' || !recoveryEmail.trim() ||
        (security && (!Number.isInteger(security.generation) || security.generation < 0))) {
      conflict('invalid-existing-security', parentUid);
      continue;
    }
    caregiverOperations.push({kind: 'caregiver', parentUid,
      recoveryEmail: recoveryEmail.trim(), createSecurity: !security,
      relationships: relationships.sort((a, b) => a.learnerUid.localeCompare(b.learnerUid)),
      ownerUidsToCreate: relationships.filter(link => !owners.has(link.learnerUid)).map(link => link.learnerUid).sort()});
  }

  for (const enrollment of enrollments) {
    const teacherUid = enrollment.teacherFirebaseUid;
    const learnerUid = enrollment.learnerFirebaseUid;
    const classCode = enrollment.classCode;
    const classroom = classes.get(classCode);
    if (!cleanUid(teacherUid) || !cleanUid(learnerUid) || !cleanUid(classCode) ||
        enrollment.id !== `${classCode}_${learnerUid}` || !classroom ||
        classroom.classCode !== classCode || classroom.teacherFirebaseUid !== teacherUid ||
        profiles.get(teacherUid)?.role !== 'teacher' || profiles.get(learnerUid)?.role !== 'learner') {
      conflict('enrollment-class-owner-mismatch', enrollment.id);
      continue;
    }
    const key = `${teacherUid}_${learnerUid}`;
    const pair = teacherPairs.get(key) ?? {kind: 'teacher', id: key, teacherUid, learnerUid, classCodes: [], enrollmentIds: []};
    pair.classCodes.push(classCode);
    pair.enrollmentIds.push(enrollment.id);
    teacherPairs.set(key, pair);
  }
  for (const grant of grants.values()) {
    const pair = teacherPairs.get(grant.id);
    if (!pair || !Array.isArray(grant.classCodes) ||
        grant.classCodes.some(code => !pair.classCodes.includes(code))) {
      conflict('grant-without-owned-enrollment', grant.id);
    }
  }
  const teacherOperations = [...teacherPairs.values()].map(pair => ({...pair,
    classCodes: uniqueSorted(pair.classCodes), enrollmentIds: uniqueSorted(pair.enrollmentIds)}));
  return {conflicts, caregiverOperations, teacherOperations,
    counts: {parentAccounts: caregiverOperations.length,
      newSecurityRecords: caregiverOperations.filter(op => op.createSecurity).length,
      newLearnerOwners: caregiverOperations.reduce((n, op) => n + op.ownerUidsToCreate.length, 0),
      teacherGrants: teacherOperations.length}};
}

async function readSource(db, auth) {
  const names = ['parent_child_links', 'class_enrollments_cloud', 'user_profiles',
    'learner_caregivers', 'caregiver_security', 'teacher_classes_cloud', 'teacher_learner_access'];
  const collections = await Promise.all(names.map(name => db.collection(name).get()));
  const records = collections.map(snapshot => snapshot.docs.map(doc => ({...doc.data(), id: doc.id})));
  const [links, enrollments, profiles, owners, securities, classes, grants] = records;
  const parentUids = uniqueSorted(links.map(link => link.parentFirebaseUid).filter(cleanUid));
  const accounts = [];
  for (const uid of parentUids) {
    try {
      const account = await auth.getUser(uid);
      accounts.push({id: uid, email: account.email, emailVerified: account.emailVerified, disabled: account.disabled});
    } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
  }
  return {links, enrollments, profiles, owners, securities, classes, grants, accounts};
}

async function applyMigrationPlan(db, auth, plan) {
  if (plan.conflicts.length) throw new Error('Resolve every reported conflict before applying migration.');
  // Each authority write rechecks source evidence within its transaction. A
  // concurrent link revocation or ownership change aborts that operation.
  for (const operation of plan.caregiverOperations) {
    if (operation.createSecurity) {
      const account = await auth.getUser(operation.parentUid);
      if (account.disabled || account.emailVerified !== true || account.email?.trim() !== operation.recoveryEmail) {
        throw new Error(`Account verification changed: ${operation.parentUid}`);
      }
    }
    await db.runTransaction(async tx => {
      const secRef = db.doc(`caregiver_security/${operation.parentUid}`);
      const security = (await tx.get(secRef)).data();
      if (operation.createSecurity && security) throw new Error(`Security record changed: ${operation.parentUid}`);
      const ownerWrites = [];
      for (const relationship of operation.relationships) {
        const link = (await tx.get(db.doc(`parent_child_links/${relationship.linkId}`))).data();
        const allLinks = await tx.get(db.collection('parent_child_links')
          .where('learnerFirebaseUid', '==', relationship.learnerUid));
        const ownerRef = db.doc(`learner_caregivers/${relationship.learnerUid}`);
        const owner = (await tx.get(ownerRef)).data();
        if (link?.parentFirebaseUid !== operation.parentUid || link?.learnerFirebaseUid !== relationship.learnerUid ||
            allLinks.size !== 1 || (owner && (owner.parentUid !== operation.parentUid || owner.active !== true))) {
          throw new Error(`Caregiver ownership changed: ${relationship.learnerUid}`);
        }
        if (!owner) ownerWrites.push(ownerRef);
      }
      if (operation.createSecurity) tx.create(secRef, {recoveryEmail: operation.recoveryEmail,
        deviceHash: null, sessionId: null, generation: 0});
      for (const target of ownerWrites) tx.create(target, {parentUid: operation.parentUid, active: true});
    });
  }
  for (const operation of plan.teacherOperations) {
    await db.runTransaction(async tx => {
      const grantRef = db.doc(`teacher_learner_access/${operation.id}`);
      const grant = (await tx.get(grantRef)).data();
      if (grant && (!Array.isArray(grant.classCodes) || grant.classCodes.some(code => !operation.classCodes.includes(code)))) {
        throw new Error(`Teacher grant changed: ${operation.id}`);
      }
      for (const classCode of operation.classCodes) {
        const classroom = (await tx.get(db.doc(`teacher_classes_cloud/${classCode}`))).data();
        const enrollment = (await tx.get(db.doc(`class_enrollments_cloud/${classCode}_${operation.learnerUid}`))).data();
        if (classroom?.teacherFirebaseUid !== operation.teacherUid || classroom.classCode !== classCode ||
            enrollment?.teacherFirebaseUid !== operation.teacherUid || enrollment.learnerFirebaseUid !== operation.learnerUid ||
            enrollment.classCode !== classCode) throw new Error(`Class ownership changed: ${classCode}`);
      }
      tx.set(grantRef, {classCodes: operation.classCodes});
    });
  }
}

async function main() {
  const args = process.argv.slice(2);
  if (args.some(arg => arg !== '--apply' && !arg.startsWith('--project='))) {
    throw new Error('Usage: node migrate-security.js --project=PROJECT_ID [--apply]');
  }
  const projectId = args.find(arg => arg.startsWith('--project='))?.slice('--project='.length);
  if (!projectId) throw new Error('Pass --project=PROJECT_ID explicitly; dry run is the default.');
  const {initializeApp} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  const {getAuth} = require('firebase-admin/auth');
  initializeApp({projectId});
  const db = getFirestore();
  const auth = getAuth();
  try {
    const plan = buildMigrationPlan(await readSource(db, auth));
    console.log(JSON.stringify({projectId, mode: args.includes('--apply') ? 'apply' : 'dry-run',
      counts: plan.counts, conflicts: plan.conflicts}, null, 2));
    if (plan.conflicts.length) throw new Error('Migration refused: source ownership/verification conflicts require review.');
    if (args.includes('--apply')) {
      await applyMigrationPlan(db, auth, plan);
      console.log('Migration applied. No phone or active session was trusted; caregivers must complete email recovery.');
    } else {
      console.log('No writes performed. Review the source relationships before rerunning with --apply.');
    }
  } finally {
    await db.terminate();
  }
}

if (require.main === module) main().catch(error => { console.error(error.message); process.exitCode = 1; });
module.exports = {buildMigrationPlan, applyMigrationPlan};
