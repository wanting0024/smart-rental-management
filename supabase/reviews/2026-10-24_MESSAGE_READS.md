# P2-1 — persisted own-account message read/unread

24 October 2026. Code + hosted integration PASS, original UI preserved. Not device
push, peer Seen disclosure, production deployment or manual phone/emulator UAT.

## Model and authorization

Migration 027 adds `app_private.message_read_receipt`, keyed by recipient/message
ID with immutable first-read time. Private schema/table has no App/anon/service
API grants; RLS is enabled. Public read/count/filter functions are authenticated-
only, SECURITY DEFINER with empty search path and explicit actor/participant scope.
No caller-supplied recipient. Only incoming IDs in the selected booking may be
acknowledged (1–50 distinct non-null IDs); invalid mixed batches are atomic denials.
Duplicate acknowledgements do not create rows/change the first-read timestamp.

Own outgoing messages never count unread. An exact-ID receipt cannot clear an
older unseen message, a future new arrival or a different thread. No peer read
state is exposed. Closed history stays readable/acknowledgeable under participant
authorization; sending still requires Accepted/In Progress and original limits.

Original five-argument conversation RPC contract remains; private shared projection
adds per-thread unread/global total, plus separate `page_my_unread_conversations`
endpoint (avoids ambiguous defaulted overloads). Server filters before bounded
keyset pagination. Message and receipt timestamps respect the page's as_of boundary;
an already-loaded page is a snapshot, not a promise of live mutable read totals.
Global badges recheck current totals independently. Extra metadata contains no
contact email, address, origin or other user's read receipt.

## Original UI / lifecycle

Original conversation tiles/header use genuine server unread numbers. Original
Unread chip now works on connected data through the server filter, not just the
loaded first page. Fake preview pins/unread values remain outside connected paths.
Owner Messages quick-action icon, drawer Messages entry and list title share one
session-bound badge state; visual badges cap at 99+, accessible full count retained.

One global foreground-only poller checks a tiny unread-count RPC every 30 seconds.
Confirmed local sends/receipts invalidate/recheck it immediately; in-flight stale
replies are rejected. Unknown count hides a number rather than pretending zero;
failed refresh retains last confirmed data. Normal updates are silent, no save/
updating toast. Other-device changes may take about 30 seconds while foreground;
there is no device push/instant cross-device guarantee. Background timers stop.

Read tracking is opt-in on the actual connected chat route. Cache-built list
children are not considered seen: rendered geometry is checked against the actual
scroll viewport after painting. Only a current/resumed route may queue incoming
IDs that appeared on screen. Own bubbles are excluded; 200ms batched submissions
are capped at 50 and failed acknowledgements retry quietly after five seconds
while active. No optimistic decrement. Pop/background clears pending reads.
Account changes dispose shared state and reject late callbacks; transient token
refresh errors do not falsely sign out or recreate private routes.

## Verification

| Check | Result |
|---|---|
| Local SQL, both default-grant profiles | Full atomic 001–027 + receipt ACL/own-ID/mixed batch/idempotency/partial/new arrival/unread filter and existing concurrency tests passed |
| Staging rollout | Dry-run showed only 027; applied only to gqtetdavmrautoojaqrk |
| Hosted partial read | Two incoming -> read one -> one remains unread; repeating old acknowledgement does not clear new arrival |
| Role/isolation | Own sent ID and original Owner A outsider denied; each role retains only its own read state |
| Persistence/filter | Both fresh password sign-ins preserve zero unread for the test thread; global/list totals agree; target absent from Unread filter |
| Closed thread | Test appointment cancelled normally, four messages/read history remain; no sending-rule bypass |
| Resume | Same checkpoint rechecks existing records, no new appointment/messages; old chats not marked read |
| Flutter | 673 passed, including 15 additions for viewport/background/retry/session/race/filter/repository and existing 320px/200% light/dark checks |
| Android | Existing Staging debug APK compiled successfully |
| Source checks | Secret scan PASS across 149 lib files; analysis no errors/warnings (style infos remain) |

Logs: `output/p2-message-sql-legacy.log`, `p2-message-sql-disabled.log`,
`p2-message-dry-run.log`, `p2-message-push.log`, `p2-message-hosted.log`,
`p2-message-resume.log`, `p2-message-existing-smoke.log`,
`p2-message-regression.log`, `p2-message-android-build.log`,
`p2-message-analysis.log`, `p2-message-security.log`.

Hosted harness is separately opted in:

```powershell
flutter test --no-pub --dart-define=RUN_STAGING_MESSAGE_READS=true --dart-define=STAGING_WRITE_PROJECT=gqtetdavmrautoojaqrk tool/staging_message_reads_test.dart --reporter expanded
```

Uses only dedicated synthetic fixture accounts and ordinary App repositories.
Private ignored checkpoint `output/staging-private/message-reads-acceptance.local.json`
holds stable request/message IDs, not passwords. Same lock as prior acceptance
tools; do not delete checkpoint/history to force a new demonstration. An incomplete
experiment without its recorded evidence may require manual review, not a reset.
Tool sessions use local sign-out only. No administrator key or old chat receipt
write; test messages clearly labeled [TEST].

Retained fixture after this step: 10 bookings (1 Pending, 6 Cancelled, 1 Declined,
2 Completed), 28 status events, 7 messages, 1 review, 5 upload tickets / 4 private
images. This step adds one cancelled synthetic appointment/four messages, not a
new completed service/payment. Cleanup preview still blocks worked-on/file data;
no cloud deletion or original-project/account approval change.

## User follow-up / remaining scope

Hot Restart, not just Hot Reload, to instantiate the new read tracker in already-
open chat states. Use the dedicated fixture Owner/Provider to see populated original
Messages pages; old A accounts intentionally do not own these conversations.
Opening old test chats manually may change their own unread state normally.

P2-1 automation does not certify physical visibility to a human, screen-reader
device behavior, native offline switching or phone session storage; these remain
P2-4. Earliest scheduled execution policy is still a separate unresolved business
decision. Next P2-2: supporting pages and clearly non-final Terms/Privacy drafts.
