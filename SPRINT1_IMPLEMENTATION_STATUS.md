# Sprint 1 implementation status (27 September 2026)

The older `SPRINT_PLAN.md` is a proposed backlog, not evidence of completion.
The six-state report lifecycle is authoritative: Pending, Accepted, In Progress,
Completed, Declined and Cancelled. There is no Scheduled, Delayed or
Rescheduled status. The local demo and the connected workspace are deliberately
separate; connected mode never displays seeded bookings as real records.

| Backlog item | Current state | Evidence / next verification |
| --- | --- | --- |
| S1-01 Supabase project/config | Configured; integration unverified | Personal Free project `dvakrwalnqpcmgirmlct` is healthy. Its URL and publishable key are stored in a git-ignored local file; a connected Web build and login-page preview succeed. Auth/database integration still needs deployed schema and real-account tests. |
| S1-02 Database schema | Draft | Two migrations cover the core schema, RLS, protected acceptance/revision/transitions, evidence and Realtime publication. Neither has been applied or integration-tested. Review against the team's shared schema first. |
| S1-03 Seed data | Not done | Do not seed fake auth accounts or mix demo records into real data. Service types and test accounts need agreed identifiers and a disposable project. |
| S1-04 Backend abstraction | Partial | `SupabaseBackendProvider` groups connected repositories; existing local stores still have different interfaces. |
| S1-05 Auth | Partial | Connected login, registration fields, role verification and persisted-session restore are coded; live email confirmation and RLS remain untested. Magic link is not implemented. |
| S1-06 Owner dashboard | Partial | Server property/booking counts and property reads exist in connected mode. Full owner property/booking UI wiring remains. |
| S1-07 Provider matching | Partial | Connected Owner search now calls a request-specific server hard-filter RPC and displays eligible Providers with a server-calculated quote. Google route distance and the final weighted ranking are not connected; never substitute straight-line or fabricated distance. |
| S1-08 Booking CRUD | Partial | Connected Owner screen now submits a priced Pending request through the protected RPC with a retry token. Read/revision and atomic acceptance clients exist. SQL deployment, multi-account concurrency and full booking-detail screens remain. |
| S1-09 Tracking FSM | Partial | Draft RPC protects Declined/Cancelled/In Progress/Completed and status history. Connected provider inbox exposes Pending accept/decline/start only. Completion evidence flow and database tests remain. |
| S1-10 Wire screens to repositories | Partial | A separate honest connected workspace shows real records; most established demo screens still use local stores. |
| S1-11 Storage | Partial | Private bucket/RLS draft and JPEG/PNG ≤5 MB upload/download repository exist; no live upload test or final screen wiring. |
| S1-12 Realtime | Partial | Booking streams and publication draft exist; no multi-device verification, background push or notification implementation. |
| S1-13 Chapter 4 diagrams | External | User's report diagrams need direct reconciliation with the final deployed schema; no diagrams changed in this coding iteration. |
| S1-14 FSM repository tests | Partial | Local FSM tests and config/login widget tests pass. Real RLS/transaction/concurrency tests require a disposable PostgreSQL/Supabase project. |
| S1-15 Tutor demo | External | Requires the user's tutor and a working deployed project; not performed. |

## Reproduce the two modes

Without settings, the current Flutter app runs its original local demo.
For connected mode, copy `supabase/backend_config.example.json` to a private
file named `supabase/backend_config.local.json`, fill in only the project URL
and **publishable/anon** key, and run Flutter with
`--dart-define-from-file=supabase/backend_config.local.json`. Never place a
secret/service-role key in the app. The private file is git-ignored.

The connected app needs migrations 001 and 002 applied in that order, Auth
email/password enabled, and valid Owner/Provider accounts. Do **not** apply
the create-only migrations to an existing group database until the schema and
RLS contracts have been reconciled.

## Verification completed locally

- All Flutter tests pass in local/demo mode and widget tests exercise the
  connected registration fields without submitting to a remote project.
- Release Web build succeeds.
- The backend Dart files compile. The repository-wide analyzer still emits
  pre-existing style/info lints; there are no compiler errors in this work.

## Blocking inputs for full Sprint 1 acceptance

1. Supabase Project URL and publishable/anon key, **not** a service-role key.
2. Confirmation whether to use a disposable individual project or the shared
   group project, plus the team's existing schema if one exists.
3. Google Routes API/server-side key and agreed route-distance interface for
   provider matching, if that service is already available.
4. A test Owner and Provider account (or permission to create them) in the
   disposable project for RLS, evidence and concurrent-acceptance testing.
