# P1-4 — negative paths and uncertain-network acceptance

24 October 2026. PASS for the defined hosted repository + local regression scope.
Not a universal safety guarantee, real service/payment, production approval or
phone/emulator offline UI UAT. Original UI preserved; no PDF or separate build.

## Scope / safeguards

Only `gqtetdavmrautoojaqrk`, registered synthetic run
`460574d3-d567-4082-8221-72b1f4fa8bec`. Dedicated Owner / approved Provider from P1-2;
original Owner A / pending Provider A used only for denied-access/read verification.
No original project change, new administrator credentials, role/clock override,
approval change, cloud SQL, deletion, evidence attestation shortcut or fake payout.

Seven new bounded requests use distinct durable IDs and [TEST] instructions, with
separate future MYT dates; conflict_a/b share one interval intentionally. The old
seeded Pending and P1-3 Completed record/messages/review remain intact. The test
upload case completes via real hosted validated synthetic pixels, never actual
cleaning. Five cases end Cancelled, one Declined, one synthetic Completed.

## Observed checks

| Area | Expected and observed |
|---|---|
| Pending cancel | Owner allowed with reason; Provider cancel denied (may decline instead); blank reason rejected |
| Direct mutation | Owner direct status update denied; no forged completion |
| Decline | Assigned Provider allowed; Owner denied; declined request cannot be accepted |
| Accepted cancel | Both Owner and Provider cases allowed with reason before work; duplicate cancellation rejected, no history duplication |
| Post-start cancel | Both participants denied once In Progress; state preserved |
| Pending revise | Owner same-duration reschedule allowed; Provider and Accepted-state revision denied |
| Revision invariants | Changed duration rejected by quote constraint; outside window/conflict rejected; existing interval and RM80 quote unchanged |
| Concurrent acceptance | Two independent authenticated Provider clients race; exactly one accepts, other slot_conflict |
| Conflict / release | Conflicting create adds no booking; failed revise/accept preserves Pending; cancel winner frees slot for other Pending acceptance |
| Before-send failure | Injected creation never reaches server; request-token lookup remains empty |
| Lost create response | Actual server create committed; readback finds ID; same token reuses one row |
| Token mismatch | Changed request payload denied; changed message body with same token denied |
| Lost cancel/accept/revise/complete responses | Normal RPC executes upstream, response hidden; current state/interval readback proves commit; repeated terminal operation adds no history |
| Lost message response | wasSent confirms persisted row; retry same ID keeps one message readable by Provider |
| Malformed PNG | Actual deployed validator rejects bytes; rejected ticket does not attach; completion still refused |
| Lost Edge response | Actual valid canonical private object published; attachment reconciles response loss; retry keeps same path/object |
| Evidence / review actors | Owner upload denied; incomplete evidence cannot complete; early review / Provider self-review denied |
| Closed chat | New message after completion denied; prior persisted message still readable |
| Forged/invalid requests | Wrong price, past start and >8h interval denied without inserting a booking |
| Outsiders / anonymous | Original A accounts cannot read target booking/evidence/review/chat/private photo or cancel/accept it; other Owner cannot book fixture property; anonymous protected RPC denied |
| Approval / expiry (local SQL) | Withdrawn/rejected approval denies accepting an existing Pending, approved still works; expired Pending remains Pending without extra history |

Cancellation here is **status-based**, not a newly introduced clock cutoff. Start/
completion still do not restrict earliest scheduled execution; that policy remains
open. Expired Pending acceptance is already prohibited separately. Do not present
these tests as certification of an unspecified early/late start/cancel policy.

## Fault injection meaning / limits

`StagingFaultClient` is test tooling outside lib/. It forwards only pinned HTTPS,
disables redirects and arms one of six explicit POST endpoints. Before-send mode
throws without forwarding. After-success mode drains a REAL HTTP-2xx upstream
response then throws a timeout; it does not manufacture a successful response or
modify the database. HTTP errors pass through. A 2xx status alone does not prove
business success, so the harness always verifies actual state/token/evidence.

This tests uncertainty after genuine hosted operations, not merely a mocked
success. Existing local SDK/widget regressions also cover busy/rejected validator,
lost HTTP responses, retry/UI recovery and unsaved data behavior. Physical network
switching, OS lifecycle, camera permission and original-screen manual UAT remain
P2-4. Browser CORS/device push are not certified by non-browser repository calls.

## Repeatability and retained data

Explicit hosted writes only:

```powershell
flutter test --no-pub --dart-define=RUN_STAGING_NEGATIVE_ACCEPTANCE=true --dart-define=STAGING_WRITE_PROJECT=gqtetdavmrautoojaqrk tool/staging_negative_acceptance_test.dart --reporter expanded
```

Default invocation skips. Config/server marker/fixture Auth metadata are checked.
Private ignored `output/staging-private/negative-acceptance.local.json` stores
stable request/message/upload IDs before writes, not credentials. Same local lock
as P1-3 prevents those harnesses running concurrently. Use the same checkpoint,
never erase it to make new bookings or rewrite worked-on history. Completed cases
are read/checked on resume; fault/race proof flags must remain present. An actual
interruption before such evidence is recorded may require manual review, not
falsely marking the missing experiment passed or resetting the cloud run.

First hosted run passed; checkpoint rerun passed without extra rows/objects.
Inventory after tests: 9 bookings (1 Pending, 5 Cancelled, 1 Declined, 2 Completed),
25 status events, 3 messages, 1 review, 2 evidence rows, 5 tickets (one malformed
rejection), 4 private Storage objects. No cleanup executed; read-only preview
correctly blocks worked-on/chat/review/file inventory. Test identities/passwords
and original Provider A approval remain unchanged. Tool sign-out affects only its
own sessions, not global emulator sessions.

## Evidence / implementation impact

- `output/p1-negative-hosted.log`: real seven-case first run passed.
- `output/p1-negative-resume.log`: same checkpoint rerun + invalid-create checks passed.
- `output/p1-negative-sql-legacy.log`, `p1-negative-sql-disabled.log`: full native
  001–026 regression plus new approval/expiry case and actual rate/lease/cleanup
  concurrency tests passed; local servers stopped.
- `output/p1-negative-guards.log`: 19 offline transport/target/checkpoint guards passed.
- `output/p1-negative-regression.log`: 658 default Flutter tests passed.
- `output/p1-negative-existing-smoke.log`: original A account reads, 2 passed.
- `output/p1-negative-default-gate.log`: hosted writes skipped without opt-in.
- `output/p1-negative-inventory.log`: bounded retained inventory / cleanup denied.
- `output/p1-negative-security.log`: PASS across 146 lib files.
- `output/p1-negative-analysis.log`: static analysis of new tooling/tests.

Existing server rules passed; no production migration or App/UI behavior change was
required to force results. Added negative harness/support/guards and local SQL
regression, wired native verifier. Existing resolved http 1.6.0 is now explicitly
a dev dependency for fault injection; version did not change. No release build or
native device acceptance claimed. Next: P2-1 persisted chat read/unread and badges.
