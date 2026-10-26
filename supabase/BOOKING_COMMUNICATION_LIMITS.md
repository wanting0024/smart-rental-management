# Security task 4.1: new-message and photo-upload limits

Updated 23 October 2026. Implemented and tested **locally**, not deployed to the
hosted Supabase project. Task 4 remains partial: trusted server-side photo
content inspection and hosted cross-account/Storage tests are still pending.

## What the controls mean

- **Authorization / RLS** decides which booking participants may read or act.
  This already exists and remains unchanged; being logged in is not enough.
- **Rate limiting** restricts the rate of new writes by an otherwise authorized
  account. Limits apply across all its bookings, not just one screen or device.
- **Idempotency** means retrying the same accepted message/upload ID and content
  reuses that operation. It does not create another record or consume quota twice.
- **Sliding window** means the last 10/60/3600/86400 seconds according to the
  database clock, not a phone's clock or a calendar-minute reset.

## Initial configurable safety defaults

| Operation | Rolling window | Maximum new records |
| --- | --- | --- |
| Booking message | 10 seconds | 8 |
| Booking message | 60 seconds | 40 |
| Booking message | 1 hour | 300 |
| Evidence upload reservation | 60 seconds | 6 |
| Evidence upload reservation | 1 hour | 30 |
| Evidence upload reservation | 24 hours | 100 |

These are technical safety defaults, not academic findings, paid-plan allowances,
booking prices or a universal industry standard. They permit normal short bursts
and before/after photos while bounding new-write flooding. An administrator can
tune the six rows in `app_private.activity_limit` after observing real usage;
the app's authenticated/anonymous users cannot read or change that configuration.
No extra copy of chat text, photos or per-request activity log is stored.

Every applicable window must have room. Failed quota checks create no message
or upload ticket. Existing upload reservations still expire under the prior
24-hour ticket policy; this step does not change photo retention/deletion rules.

## Server implementation

Migration `202610230017_booking_communication_limits.sql` replaces the existing
`send_booking_message` and `begin_evidence_upload` function bodies, keeping their
names, parameters and successful response contracts. Existing participant checks,
booking-state rules, content/manifest bounds and compare-and-set checks remain.

The server derives the actor from `auth.uid()`. An actor/action-scoped
transaction advisory lock serializes concurrent requests before the budget
query; the query uses indexes on actor and creation time and bounded window
lookups. Supported API transactions use **Read Committed** isolation so a request
waiting for the lock sees the previous committed write. Other isolation modes
are explicitly rejected rather than silently using a stale snapshot.

An identical existing-operation retry is resolved before the quota check.
Changed content under an old ID remains an error, not a free new operation.
Participant/state validation precedes rate feedback; unrelated users are denied
access, not given another account's quota information. New records use server
`clock_timestamp()` rather than a client timestamp or an old transaction start.

The private helper fails closed if all policy rows for an action are missing.
On a valid but over-budget new operation, PostgreSQL raises `PT429` with only
`CHAT_RATE_LIMITED` or `EVIDENCE_RATE_LIMITED`, plus a bounded
`retry_after_seconds` detail. PostgREST's documented custom error mapping turns
that into HTTP 429. Real hosted HTTP/error-verbosity behavior remains to be checked.

No booking lifecycle, payment/price rule, module scope, bucket policy, service-role
key handling or historical conversation-read permission was changed.

## App behavior

- Only the expected fixed RPC code/message is treated as a definite rejection.
  Unknown transport/gateway failures retain the existing lost-response
  verification and safe idempotent retry path.
- Chat displays **Sending paused**, retains editable text and the retry ID, and
  temporarily disables Send. A later manual send of edited text gets a new ID.
- Photos display **Photo uploads paused**, retain the prepared bytes/upload ID
  and remarks, and disable uploads/completion while waiting. The limited begin
  call does not proceed to Storage transfer or attach.
- A timer re-enables the control; **nothing is sent automatically**. The displayed
  wait is approximate. Navigating away cancels the UI timer; returning/restarting
  cannot reset the server's budget. These UI timers are convenience, not security.
- Short screens/large text/keyboard layouts use a compact, scrollable wait notice
  and bounded composer. Light and dark themes use existing application colors.
- Diagnostic logs record the fixed `rateLimited` category without payloads or
  identifiers; raw RPC messages/details do not become on-screen text or logs.

## Important limits of this step

These are **new-write budgets**, not a firewall or an account-wide financial cap.
They do not throttle every read, invalid attempt, repeated Storage-body transfer,
new-account creation, IP address or total project traffic/storage. Gateway-level
request/body/concurrency controls, global capacity monitoring and Auth abuse
protection still need separate review. Six 5 MB upload reservations per minute
does not mean the project's overall Storage/egress allowance is safe for an
unlimited number of providers.

The existing client prepares/re-encodes images, but client checks can be bypassed.
Storage MIME metadata/signatures/manifests alone do **not** prove actual decoded
content, dimensions, metadata stripping or claimed digest. Task **4.2** must add
trusted server-side inspection/canonicalization and enforce it at attachment.
This migration does not claim to solve that gap or certify OWASP compliance.

## Manual hosted rollout — do later together

1. Verify the account, project identity and administrator-owned **staging** marker;
   inspect applied migration history and take the appropriate backup. A Free plan
   or a project's display name does not establish that it is staging.
2. Review this migration and the configurable defaults. Apply only unapplied
   migrations in order (001–016 must already exist before 017), using the migration
   runner's transaction. For SQL-editor execution, review a single BEGIN/COMMIT
   transaction rather than pasting individual statements after partial errors.
3. Ship the updated client together with the server change. The client remains
   compatible with the older RPC contract, but it cannot provide server-side
   protection until migration 017 is actually deployed.
4. Use deliberately provisioned staging identities: assigned Owner/Provider and
   unrelated accounts. Check participant-only reads, provider-only evidence,
   closed-booking rejection, all rolling windows, actual 429 details and retries.
5. Run two actual authenticated clients against different bookings for the same
   account at the quota boundary. Check one new operation succeeds, the other is
   limited, and both historical records and same-ID retries remain correct.
6. Verify actual Supabase Auth, Storage, Realtime, RLS and device/network behavior.
   Keep task 4 partial until content inspection and bypass tests also pass.

## Reproducible local evidence

`pwsh -NoProfile -File tool/verify_local_migrations.ps1` creates a disposable,
labelled PostgreSQL 16 container with `--network none`. It checks all 17 migrations
and the existing access/lifecycle/upload/pagination/environment/test-data suites,
plus quota windows, cross-booking accounting, private-policy denial, expiry,
identical/changed-ID retries, missing-policy failure and isolation rejection.

The added Python concurrency harness refuses other container names/labels/network
modes. It uses real parallel SQL sessions, observes an actual waiting advisory
lock while the first transaction is uncommitted, verifies the second request is
limited, and checks same-ID retries leave counts at 8 messages/6 upload tickets.
Only synthetic local fixtures are used; the disposable database is removed by
the parent test script and can be recreated from source. No hosted operation occurs.

Flutter tests separately exercise the installed SDK against loopback HTTP 429s,
UI/timer/draft/photo preservation, narrow keyboard layouts and light/dark previews.
These layers do not replace real hosted JWT/Storage/Realtime integration tests.

Sources: [PostgREST custom HTTP errors](https://docs.postgrest.org/en/stable/references/errors.html#raise-errors-with-http-status-codes),
[PostgreSQL transaction advisory locks](https://www.postgresql.org/docs/16/functions-admin.html#FUNCTIONS-ADVISORY-LOCKS),
[OWASP file-upload guidance](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html).
