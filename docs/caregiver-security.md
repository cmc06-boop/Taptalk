# Caregiver account, trusted phone and active session

The parent verifies an account email once, then uses TapTalk normally. Home,
Favorites, Settings, and Profile do not require a learner QR. My Child is the
only place that asks for a learner.

The first caregiver link is automatic: a verified account scans the learner QR,
the server creates the caregiver link, trusts that phone, and opens monitoring.
There is no administrator, teacher, or manual Firebase registration in that
path. A different account cannot take a learner that already has a caregiver
just by scanning the QR. That move needs an explicit transfer from the current
caregiver.

Each learner is bound to the account **and** the phone that scanned their QR
(`learner_caregivers/{learner}.deviceHash`, mirrored on `parent_child_links`).
Firestore and Storage rules only allow a parent to read a learner, their
activity, notifications, media, or link record when that device hash equals the
parent's current trusted phone. A verified phone replacement (email link or
old-phone approval) moves every linked learner to the new phone in the same
transaction, so no rescan is needed. The email link opens TapTalk directly via
the App Link on `/__/auth/links` (`hosting/.well-known/assetlinks.json`); if a
browser opens it instead, `hosting/caregiver-recovery` hands it to the app.

A parent account has exactly one trusted phone. The first phone where a
verified parent signs in becomes that phone automatically (`status` registers
it). Reopening the app on the trusted phone checks in the background and does
not show a security page.

## Another phone, phone replacement and recovery

On any other phone, `status` returns `verificationRequired` and TapTalk shows a
full-screen "Verify this device" step. The parent account cannot be used there
until the step finishes. A password alone never moves the trusted phone.

1. `requestReplacement` creates a 15-minute request bound to this phone.
2. `sendRecovery` requires a sign-in from the last 5 minutes (otherwise the
   screen asks for the password or Google again) and an Auth email that matches
   the pinned recovery address. TapTalk then sends an email sign-in link there.
3. The parent opens the link on this phone (or pastes it). The link
   reauthenticates with the `emailLink` provider, `verifyRecovery` approves the
   request, and `confirmReplacement` makes this phone the trusted phone.
4. The previous phone's session and device credential stop working at once. If
   it opens TapTalk again, it is shown the same verification step.

This is also the lost-phone recovery path: the old phone is not needed. A
forgotten password is reset with Forgot password on the login screen first.
The old trusted phone can still approve a pending replacement directly
(`approveReplacement`).

Requires Firebase Console → Authentication → Sign-in method → Email/Password →
"Email link (passwordless sign-in)" enabled, and `taptalk-2d809.firebaseapp.com`
in Authorized domains.

Normal logout ends the protected session while keeping the phone credential.
Reinstallation or removal of app data makes the phone untrusted, so it needs the
same email-link verification. For caregiver transfer, the current caregiver
reauthenticates and creates a child-specific, single-use code on their trusted
phone. The next caregiver accepts it on their own trusted phone within 15
minutes. Only that learner relationship moves; the former caregiver keeps their
trusted phone and any other learners.

Protected learner reads still require a server-issued session. Firestore rules
reject revoked session claims. Data already seen cannot be retroactively
removed from a screenshot or another copy.

## Backend setup and deployment

Installing the updated Flutter app alone does not activate the server rules.
Use the project's Firebase CLI and a Node 22 runtime for `functions/`. Install
its pinned dependencies with `pnpm install --frozen-lockfile` before testing or
deploying. Cloud Functions deployment requires a Firebase project with the
necessary billing enabled.

Lost-phone recovery uses Firebase Authentication email sign-in links, not a
custom SMTP server. Enable Email/Password, email verification, and Email link
sign-in in the Firebase Auth console. Add
`taptalk-2d809.firebaseapp.com` as an authorized domain if it is not already
present.

The `caregiverSecurity` callable uses `us-central1` and enforces Firebase App
Check. Register production App Check providers for every target app in the
Firebase console. Debug providers require registered debug tokens in development;
an unregistered token causes all caregiver and enrollment callables to fail.
Enable Firebase email/password sign-in and email verification, and verify that
the app is configured for the same project as the deployed backend.

Mobile debug builds use one fixed token from the gitignored file
`app_check_debug_token.local` at the repo root. Register that token once under
Firebase Console → App Check → Android app → Manage debug tokens. Reinstalling
a debug build keeps the same token, so it does not need to be registered again.
Release builds use Play Integrity and ignore that file. Sideloaded release test
APKs can still pass `--dart-define=TAPTALK_APP_CHECK_DEBUG_TOKEN=...`. Windows
debug builds require `APP_CHECK_DEBUG_TOKEN` in the process environment. See the
[Firebase debug-provider guide](https://firebase.google.com/docs/app-check/flutter/debug-provider).

The runtime also needs permission to sign the custom tokens used for trusted
sessions. Enable the IAM Service Account Credentials API, then grant Service
Account Token Creator on the actual function service account to that same
account. Inspect the deployed service account rather than guessing its name.
With the Google Cloud CLI available, run after function deployment:

```powershell
gcloud services enable iamcredentials.googleapis.com --project=taptalk-2d809
$tapRuntimeSa = gcloud functions describe caregiverSecurity --gen2 --region=us-central1 --project=taptalk-2d809 --format='value(serviceConfig.serviceAccountEmail)'
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tapRuntimeSa)) { throw 'Could not identify the deployed service account.' }
gcloud iam service-accounts add-iam-policy-binding $tapRuntimeSa --member="serviceAccount:$tapRuntimeSa" --role="roles/iam.serviceAccountTokenCreator" --project=taptalk-2d809
```

This grants signing permission on that service account. See [Firebase custom
token setup](https://firebase.google.com/docs/auth/admin/create-custom-tokens)
and the [IAM signing API](https://docs.cloud.google.com/iam/docs/reference/credentials/rest/v1/projects.serviceAccounts/signBlob).

The same runtime account also needs Firestore document read/write permissions
and Firebase Auth user-read permissions. If those are not already granted by
the project's existing policy, grant `roles/datastore.user` and
`roles/firebaseauth.viewer` to that runtime account in this project. See [Firestore IAM](https://firebase.google.com/docs/firestore/security/iam)
and [Firebase Auth permissions](https://docs.cloud.google.com/iam/docs/roles-permissions/firebaseauth).

Review and test the migration below before releasing the new app. Deploy the
function, Firestore and Storage rules together with:

```sh
firebase deploy --only functions:caregiverSecurity,firestore:rules,storage --project PROJECT_ID
```

Coordinate deployment and migration so legacy clients cannot continue writing
relationships during migration. Verify rules and flows against a Firebase
emulator or staging project before production. Production deployment and
migration are separate operational actions; a source-code commit performs
neither.

## One-time migration of existing cloud relationships

The old app allowed clients to write caregiver and enrollment relationships.
Those historical records cannot be accepted as unquestionable proof of consent.
Before migration, review them with the account owners using the project's
existing records and support process. Do not select the first row when different
caregivers claim the same learner.

Use Application Default Credentials for a trusted operator account with Auth
read access and Firestore migration permissions. From `functions/`, run:

```sh
node migrate-security.js --project=PROJECT_ID
```

This is a **dry run**: it reads existing data, prints counts and conflicts, and
writes nothing. An explicit project argument is required. The script refuses
application while any ownership or verification conflict remains. It checks
canonical relationship IDs, learner/parent/teacher roles, active owner records,
verified parent emails and teacher ownership of every enrolled class. Missing,
disabled or unverified legacy parent accounts require resolution before applying.
Resolve inconsistent records only after establishing legitimate ownership and
consent; the script never chooses a caregiver winner or removes a revocation
tombstone to reopen an old QR.

After the source records have been reviewed and the dry run is conflict-free:

```sh
node migrate-security.js --project=PROJECT_ID --apply
```

For each unambiguous legacy caregiver relationship, this seeds the learner owner
and pins the account's verified recovery email. A newly seeded security record
has `deviceHash: null`, `sessionId: null` and `generation: 0`: no phone is
automatically trusted. The parent signs in and confirms leftover links, or
uses unavailable-old-phone recovery with the Firebase email link and then
explicitly confirms replacement. This is account recovery, not product
administrator approval. Conflicting multi-caregiver records stay blocked until
the confirming parent scans that learner QR.

The migration also builds each teacher's learner-access record from enrollments
where that teacher owns the referenced class. It refuses orphaned enrollments,
mismatched owners and stale grants. Existing trusted credentials, recovery email
pins and revocation records are preserved. The apply step rechecks relationship
and class ownership inside each server transaction to detect concurrent changes.
If an operation fails, preceding independent operations may already be committed;
resolve the reported issue and rerun the dry run before retrying. Repeated runs
preserve established trust rather than issuing new sessions.

## Verification

Run the pure migration checks without a Firebase project:

```sh
node --test test/migration.test.js
```

The security tests in `test/security.test.js` additionally use the Firestore
emulator on port 8080. Validate first QR link, repeated QR, another caregiver's
QR attempt, password-only new-phone login, old-phone approval, Firebase email
link recovery with final confirmation, expiry, leftover-link confirmation,
old-session rejection, logout/reinstall, caregiver transfer, and enrollment
access revocation. Verify a real recovery email and the two-phone flow in
staging before releasing.

## Private media and platform configuration

New Firebase media references use authenticated `gs://` SDK downloads rather
than publishing bearer download URLs. Legacy Firebase URLs are converted to the
same authenticated route in the app. Private learner images and videos require
the current caregiver session or a server-owned teacher enrollment. Shared
teacher lesson media remains accessible to signed-in users. Storage rules use
at most two Firestore authority documents for caregiver private-media reads.
Enable the Storage service agent's Firestore lookup permission when the Firebase
console/CLI requests it during deployment.

Previously issued Firebase download tokens can still authorize existing leaked
URLs outside the updated app. Revoke those old tokens during the coordinated
media rollout before claiming protection for historical URLs. Historical copies
already downloaded to old devices cannot be retroactively withdrawn.

iOS recovery links are routed back into TapTalk through the Associated Domains
entitlement. Keep `applinks:taptalk-2d809.firebaseapp.com` enabled for the iOS
app identifier in Apple Developer and verify the domain association on a signed
device build; unsigned simulator builds cannot validate universal-link routing.

The Android app disables backup. Apple credentials use device-only Keychain
accessibility with synchronization disabled, and the runner entitlements include
Keychain access. Apple code signing/provisioning must support those entitlements.
Linux secure storage requires libsecret, and Windows builds require the plugin's
ATL support. Android is the primary device flow; test other targets on their own
hardware and configure supported Firebase App Check providers before release.

Start both local demo emulators from the repository root for backend tests:

```sh
firebase emulators:start --only firestore,storage --project demo-taptalk-security
```

In a second terminal, from `functions/`, run `pnpm test`. Recovery email sending
is not invoked in these tests; no email or SMS is sent. Flutter security
gate/media/notification tests also mock native dependencies. A source commit
does not verify real email receipt, Google reauthentication on a phone, or
production App Check setup.

Caregiver transfer pauses teacher SMS and clears the cloud emergency recipients.
This pause survives background sync from an old learner contact cache. Save the
reviewed contacts explicitly in the learner Profile while online to resume
teacher SMS. Teacher SMS uses fresh, authorized server contacts and never merges
removed cloud contacts back from the teacher phone's old cache. The learner's
local contact edit can still be saved offline, but the app reports that an online
review is required before teacher SMS resumes.
