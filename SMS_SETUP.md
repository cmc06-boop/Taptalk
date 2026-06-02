# SMS Alert Setup (Firebase Functions + Twilio)

## 1) Install Firebase CLI and login

```bash
npm i -g firebase-tools
firebase login
firebase use <your-project-id>
```

## 2) Deploy function dependencies

```bash
cd functions
npm install
```

## 3) Configure Twilio secrets

```bash
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_FROM_NUMBER
```

`TWILIO_FROM_NUMBER` should be in E.164 format (example: `+15551234567`).

## 4) Deploy Cloud Function

```bash
cd ..
firebase deploy --only functions
```

Function deployed: `sendSmsAlert` (region `asia-southeast1`, `invoker: public` for callable auth).

If the app shows `SMS: UNAUTHENTICATED` after login, redeploy functions so Cloud Run allows callable requests:

```bash
firebase deploy --only functions
```

## 5) Publish Firestore Rules

Use the latest local `firestore.rules` in Firebase Console and click **Publish**.

## 6) Runtime behavior

- SMS trigger is manual via teacher alert flow.
- In-app notification still sends as primary.
- SMS recipient list comes from learner emergency contacts.
- Rate limit: one SMS burst per teacher-learner pair every 90 seconds.
- Audit logs written to `sms_alert_logs` with redacted numbers.
