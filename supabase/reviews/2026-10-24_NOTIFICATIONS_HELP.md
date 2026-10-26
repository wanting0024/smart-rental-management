# Booking notifications and truthful Help — 24 October 2026

## Implemented

Owner and Provider connected bell/drawer links open the original Notifications and
About & help screens through WorkspaceActions. Connected Notifications never runs
the preview seed or displays pretend payments, reviews or named fixture people.
The booking detail callback uses the authenticated role and existing protected route.

Migration 022 adds only app_private.notification_read and three functions. Events
are derived from real booking_status_history for current participants, excluding
their own actions. Existing legitimate history is immediately queryable; there is
no fan-out/backfill copying private booking data into another public table.

- Recipients are auth.uid(), never a user ID supplied by the app. Current booking
  participation is rechecked on every read and write. No addresses, phone numbers,
  email addresses or chat previews are included in notification payloads.
- The receipt table has RLS and no anon/authenticated/service_role direct grants.
  The private event helper cannot be executed by API roles. Public RPCs have
  explicit authenticated-only EXECUTE and empty search_path; no broad new grants.
- All/Unread/Needs action filtering, full counts and bounded 20-event pages execute
  server-side. Ordering retains PostgreSQL timestamp precision and UUID tie-breaks.
  Needs action means a currently Pending Provider request or an Owner completion
  awaiting a review. An old Pending event is not actionable after cancellation.
- Individual receipts validate every requested event against the actor's eligible
  events, and writes are idempotent. Mark all uses the server report's as-of cutoff,
  not device time, excluding events with later timestamps. This is an event-time
  cutoff, not a claim of persistent transaction-snapshot isolation across RPCs.
- UI read markers are never changed optimistically. A timeout triggers rereading
  to reconcile a possibly committed receipt; it does not show fake success. A tap
  during revalidation cancels the older read, persists the receipt and refreshes.
- Route/app lifecycle stops Realtime while hidden; session changes clear private
  view state. Initial failures stay failures. Refresh failures retain labeled old
  content; normal revalidation is silent. Tabs fit 320px/200% text in both themes.

About help links open readable articles and correct unsupported claims. There is
no fixed 15% payment fee, weekly payout, recurring appointment, 24h/48h support
promise, unsupported reliability score or distance ranking presented as live.
Support can copy an actual operator-provided SUPPORT_EMAIL to the clipboard; this
does not send a ticket/email. No email was provided in this task (the user's answer
was the label "contact support"), so it explicitly remains unconfigured. Approved
Terms/Privacy content is also missing and is labeled not published, not invented.
These operator decisions remain launch blockers, not completed integrations.

## Verification / deployment

- output/notifications-native-legacy-3.log and notifications-native-disabled.log:
  isolated PostgreSQL full 001-022 chain, ACL/RLS, lifecycle/evidence/pagination/
  profile/earnings/notification and concurrency suites passed with both defaults.
  New SQL fixture verifies 25 same-time events paginate without overlap, own and
  unrelated actor isolation, no raw private-table access, individual idempotence,
  as-of mark-all, invalid requests and anonymous denial. Local fixture transaction
  rolls back; no hosted synthetic notification or booking was created.
- output/notifications-staging-deploy.log: CLI dry-run identified only migration
  022; linked project explicitly checked as gqtetdavmrautoojaqrk before deployment.
  Original dvakrwalnqpcmgirmlct was not changed.
- output/notifications-staging-smoke.log: real Owner and Provider login/read cases
  passed, including all three notification filters and existing workspace checks.
  This is read-only acceptance of fixed accounts, not proof of populated hosted
  events or hosted receipt writes. Local sign-out does not revoke emulator logins.
- output/notifications-full-test.log: 584 passed (20 new notification/help tests).
  Added parser/controller, HTTP RPC adapter, gesture/filter/read/link, navigation,
  support-copy/no-send, missing policy and small-screen/theme tests. Existing
  approved golden baselines unchanged. App drawer status badge now wraps safely.
- output/notifications-android-build.log: Staging Android debug build passed.
- output/notifications-analysis.log: no errors/warnings; style infos remain.
- output/notifications-source-security.log: lib secret-pattern scan PASS (134 files),
  not a comprehensive security audit or proof of credential revocation.

The local migration verifier now generates a 22-migration fresh-Staging bundle.
Its native PostgreSQL startup uses a hidden process and bounded parent wait, avoiding
PowerShell waiting on the long-lived test server's inherited pipeline handles.
All completed test clusters were stopped; no Windows database service was installed.

## Explicit remaining acceptance / product decisions

Hot Restart in Android Studio. Open Notifications on each role; an empty real
account should show no invented events. During normal Staging testing create a
real request with the Owner, view it in Provider notifications, mark/read it and
reopen; use real allowed transitions to verify counterpart notifications. Verify
cross-device read persistence and offline retry. No emulator acceptance is claimed.

Not included: device/lock-screen push (FCM/APNs), payment/review/chat notifications,
background notification delivery, automatic reminders, a global live unread bell
badge, admin support ticket processing or published legal documents. The in-app
screen explicitly distinguishes booking updates from device push notifications.
