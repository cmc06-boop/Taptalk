# Phrase usage warnings

Monitoring identifies matching English/Filipino phrases with a shared key. It
preserves the original history text. Known translation pairs use one total,
including uses in different personal-board categories. Selecting a category
locates phrases used there, while the displayed count is the phrase's total.
Unrecognized custom translations remain separate until added to the vocabulary.

- Frequently used: at least 5 recorded uses in the selected period.
- Negative-phrase warning: at least 10 recorded uses of that phrase today.
- Consecutive qualifying days: Needs Attention, Persistent Pattern, Needs Review.
- Every new tap has its own event ID, including rapid taps within one second.
  Cloud retries reuse that ID rather than adding another use. Lessons remain
  excluded from this personal-board warning feature.

## Automatic teacher SMS

The teacher's Android phone sends warnings to the learner's saved emergency
contact numbers. Parents' numbers must be saved in the learner's **Profile →
Emergency contacts**. This uses the same contact source as manual teacher alerts.
The teacher must have an active SIM/SMS plan and grant the Android SMS permission.
The teacher app must be running and have the learner's activity available locally
or through monitoring sync. The parent app does not need to be open for SMS.

The app stores a separate SMS submission record for each teacher, learner,
phrase, local calendar day and normalized phone number. Refreshing or restarting
the same installation does not resend successful submissions. Explicitly failed
numbers can retry on a subsequent evaluation after five minutes; successful
recipients are skipped. An interrupted/uncertain submission is not automatically
resent. Different teachers/devices have separate records.

The notification history includes the SMS submission status. Submission to the
native SMS sender is not a carrier delivery receipt. Automatic warnings never
open a Messages composer or report that as a successful automatic send.

## Device verification

Use test accounts and a consenting test recipient. With a teacher signed in on
Android, save the recipient in the learner's emergency contacts and sync it.
Record 10 rapid combined uses of a negative phrase such as Help/Tulong across personal
categories. Open the
learner's monitoring page and confirm the total, warning, SMS status, and receipt
on the test phone. Refresh and restart the teacher app: it should not send again
for that phrase/day/number. Verify a denied SMS permission reports failure.

Automated tests mock all native SMS calls; they do not send real messages.

Update both learner and monitoring devices to this version for rapid-tap
counting. Old versions can still discard nearby events. Previously discarded
taps cannot be reconstructed if they no longer exist locally or in the cloud.
