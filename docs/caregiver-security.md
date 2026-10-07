# Caregiver account, trusted phone and active session

The learner QR establishes the first caregiver relationship. The server records
one active caregiver per learner and one trusted phone per caregiver account.
Only a server-issued session claim matching that account's current security
record allows protected Firestore reads. Password login on another phone does
not grant learner access and does not revoke the previous phone.

The parent must verify an account email before the first QR link. TapTalk pins
that verified address for recovery; changing the Firebase Auth account email
does not silently change the recovery address. Lost-phone recovery through
Firebase email links requires the signed-in Auth email to still match that pin;
otherwise use the old trusted phone to approve the new device. These flows
require an email account. Mobile-number-only accounts need a verified email
before onboarding or legacy migration; SMS OTP recovery is not implemented.

## Phone replacement

After detecting an untrusted phone, the app creates an approval request automatically, valid for 15 minutes. The old phone
checks pending requests while TapTalk is open, every 15 seconds and when the app
returns to the foreground. The parent compares the request codes and approves
on the old phone. That server transaction trusts the new phone and invalidates
the old phone's protected session. Requests use in-app polling, not FCM or a
background push notification; open TapTalk on the old phone to approve.

If the old phone is unavailable, the parent signs in again and requests a
Firebase Auth sign-in link at the pinned recovery address, which must still
match the signed-in account email. They open that link on the new phone.
Recovery requires a recent login. Opening the email link does not revoke the
old phone until the parent explicitly confirms replacement. Recovery does not
require an administrator or a custom SMTP account.

Normal logout ends the protected session while keeping the phone credential.
Reinstallation or removal of app data requires device verification again.
Caregiver transfer requires the current trusted caregiver's explicit approval
of a request created by the next caregiver, whose email is verified. Transfer
revokes the former caregiver's protected session and learner relationship.

Protected parent screens are locked until an online server status check succeeds.
Offline monitoring from cached learner information is not available. Firestore
rules reject revoked session claims on subsequent server reads; an old phone's
UI locks when it next checks status or returns to the foreground. Data already
seen cannot be retroactively removed from a screenshot or another copy.

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

Mobile debug builds activate the App Check debug provider. Rebuild any APK made
before that activation fix, start it on the test phone, and find the generated
debug secret in Android Logcat (`DebugAppCheckProvider`). Register that phone's
token under Firebase Console → App Check → Android app → Manage debug tokens.
Restart the app after registration. Each test installation needs its own token;
keep the token private. Sideloaded release test APKs can pass
`--dart-define=TAPTALK_APP_CHECK_DEBUG_TOKEN=...` so Play Integrity is not
required. Windows debug builds require `APP_CHECK_DEBUG_TOKEN` in the process
environment. See the [Firebase debug-provider guide](https://firebase.google.com/docs/app-check/flutter/debug-provider).

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
