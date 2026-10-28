# Core booking backend

## Current checkpoint (28 October 2026)

There are **30** ordered migrations. The connected Owner/Provider App uses
independent Staging. The latest deployment applied only migration
`202610280030_evidence_photo_removal.sql`; the following dry-run reported no
pending migrations, seeds or role changes. Both disposable PostgreSQL privilege
profiles passed the complete 001–030 migration/test sequence. Latest Flutter
verification: 892 passing tests; paired-device acceptance remains pending.

Migration 030 lets only the assigned Provider remove the exact current
Before/After attachment while In Progress. It preserves the other photo/remarks
and retires the manifest for existing Storage API cleanup. Stale requests cannot
remove newer replacements. Device UAT of this latest feature remains pending.

See the [root README](../README.md) and
[development progress](../DEVELOPMENT_PROGRESS.md) for current features and
validation limits. The dated
[`STAGING_MIGRATION_PLAN.md`](STAGING_MIGRATION_PLAN.md) explains the original
permission/dependency review; it is not the latest deployment inventory.

`tool/build_staging_migration_bundle.ps1` generates the fresh 001–030 local
review bundle. The generator does not execute remote SQL.

The original project has an existing schema, not a reconciled migration history.
Never apply the fresh baseline/bundle to it. Do not rerun the fresh bundle on the
existing Staging schema either; reconcile its history and use reviewed incremental
migrations. Staging results are not Production deployment approval.

## Historical implementation notes

The following notes describe earlier milestones and retain their original
limitations. Statements below about undeployed migrations, mock-only screens or
missing features are historical, not the current implementation inventory.
Refer to the checkpoint above and dated progress records for later verification.

**Environment guard:** connected builds now require explicit environment/Project ID
settings and migration 013's administrator-owned marker. Existing local config is
not silently migrated. Follow `ENVIRONMENTS.md` before connecting; a missing or
mismatched marker blocks startup instead of opening a mock-data fallback.

**Photo lifecycle:** migration 014 requires registered immutable uploads and
locking attachment/remarks RPCs. Direct evidence writes are no longer allowed.
See `PHOTO_UPLOAD_LIFECYCLE.md` for safe replacement, cleanup and the default
read-only maintenance worker. No hosted deletion or scheduler has been run.

**Pagination:** migration 015 adds bounded participant-scoped cursor pages for
connected bookings, booking messages and status history, plus server-side Owner
summary counts independent of the loaded page. Read `PAGINATION.md` for ordering,
retry behavior and remaining hosted Realtime checks. No hosted migration was run.

**Subscription lifecycle:** connected routes now stop live channels when covered
or backgrounded, re-read on return, and clear the previous account's navigation
stack on an identity change. Channel removal and last-socket shutdown are awaited
under a client-wide gate. See `SUBSCRIPTION_LIFECYCLE.md` for local evidence and
manual staging/device checks. This does not deploy or configure Realtime online.

**Caching and image output:** the connected client now has a bounded, account-
isolated in-memory photo/reference cache, fresh private-photo authorization on
hits, and verified JPEG preparation before upload. See
`CACHING_AND_COMPRESSION.md` for limits, platform differences and outstanding
hosted/device checks. These changes neither make private buckets public nor
replace server-side content validation.

**Test-data management:** migration 016 adds staging-only, administrator-owned
test-run provenance, atomic/idempotent synthetic fixtures and read-only review.
`tool/test_data.mjs` defaults to dry run, requires explicitly provisioned fresh
Auth accounts and refuses production. See `TEST_DATA_MANAGEMENT.md`. No hosted
account/data was created; full business/account purge is not implemented.

**Credential storage:** connected Auth now uses an explicit native OS-backed
vault (session and PKCE), verified legacy migration and durable local logout
intent. Web uses per-tab sessionStorage rather than persistent localStorage,
without claiming an OS vault or XSS protection. Device/hosted verification is
still required. See `AUTH_CREDENTIAL_STORAGE.md` and the root security queue.

**Secret/log protection:** fixed allow-list diagnostics replace raw connected
exception logs/UI output, SDK console forwarding is disabled, and local source/
reachable-history/release-artifact checks are available through an opt-in build
gate. This is not CI enforcement, credential revocation or proof of no secrets.
See `SECRET_AND_LOG_PROTECTION.md` for commands, scope and the investigated
debug-Kernel string-boundary false positive.

The first migration (`migrations/202609270001_core_booking.sql`) implements a
report-aligned foundation for Owner/Provider accounts, properties, provider
capabilities and declared availability, bookings, and booking-status history.
It does **not** connect the Flutter demo to a Supabase project. No migration
has been applied to the hosted project. All migrations now run in a disposable
local PostgreSQL integration check, which does not replace hosted Supabase
Auth/Storage/Realtime and multi-session tests.

## Report rules represented

- Six `booking_status_enum` values: Pending, Accepted, In Progress, Completed,
  Declined, Cancelled. `previous_status` is nullable for the initial Pending
  history row.
- `Property.address` and `ProviderProfile.service_origin_address` are present
  for a later Route-Distance Service integration.
- Weekly slots and unavailable dates are inputs to dynamic alternative-window
  calculation. No permanent `AlternativeWindow` table exists.
- Pending does not block provider time. A database exclusion constraint stops
  overlapping Accepted/In Progress intervals using half-open `[start, end)`
  ranges.
- Authenticated participants can read their own booking and history. Account
  role, provider approval/statistics, booking status and interval cannot be
  changed by ordinary direct client updates.
- `accept_pending_booking` checks caller assignment, takes the provider lock
  before the booking lock, rereads Pending, rechecks the local Malaysian rental
  window, declared availability, service capability and blocking bookings, then
  updates status and inserts the history row in one transaction. A rejected
  acceptance leaves the request Pending without an Accepted history entry.
- Availability/window edits use the same provider lock and cannot invalidate a
  future confirmed booking. Notifications must be emitted only after commit by
  the application/service layer; they are not yet implemented here.

## Before connecting or deploying

1. Use a disposable Supabase project and review table/column names against the
   group's shared database contract. The current report's logical
   `ProviderAvailability` is represented by two physical tables: weekly slots
   and unavailable dates. Do not apply this create-only migration to an
   existing shared schema without reconciling it first.
2. Configure Supabase Auth email/password and at least eight-character
   passwords. Use only the publishable/anon client key in Flutter; never put a
   service-role key in the mobile app.
3. Exercise PostgreSQL integration tests with two distinct authenticated
   provider/owner users. In particular, race two Pending accept calls for
   overlapping slots and require exactly one success; test RLS, role spoofing,
   direct status updates, availability/window edits, terminal states, and
   half-open boundary cases.
4. Verify the existing transition/revision/evidence RPCs under distinct
   accounts, and add associated post-commit notifications before claiming
   full FR2.4/FR2.5 or NFR4.2 completion.
5. Validate the draft private chat and evidence tables with distinct accounts;
   reviews, payments and background notification policies remain future work.

The present Flutter demo still uses `BookingStore` in memory. Its local
history exists for preview/testing, not as proof of multi-user atomicity.

`migrations/202609270002_lifecycle_evidence_realtime.sql` adds protected
Declined/Cancelled/In Progress/Completed transitions, Pending interval
revision, participant-scoped completion evidence, a private 5 MB JPEG/PNG
bucket, and the booking Realtime publication. It is also a **draft**, not a
deployed or database-tested migration. A connected-mode Flutter screen and
repositories are available when build-time Supabase settings are supplied,
but the original demo screens remain separate. See
`../SPRINT1_IMPLEMENTATION_STATUS.md` for item-by-item status and required
integration inputs.

`migrations/202610220005_provider_data_visibility.sql` narrows direct
Provider-profile, capability and availability reads to the Provider who owns
the records. An authenticated directory RPC returns a whitelisted subset for
approved Providers, excluding the private service-origin address. It is a
local migration draft, not evidence that live RLS has been verified. Apply
after migrations 003 and 004 in staging, then test with distinct Owner,
Provider, other-Provider and unauthenticated sessions before production use.

`migrations/202610220006_secure_booking_creation.sql` removes direct
authenticated INSERT permission for Booking and adds the Owner-only
`create_pending_booking` RPC. It validates property ownership, provider
approval, service capability, the full requested interval, the rental
cleaning window, and conflicts with Accepted/In Progress bookings. Pending
requests do not reserve capacity; `accept_pending_booking` remains the final
atomic check. A caller-generated UUID is required once per request form and
must be reused for network retries. The unique Owner/token key prevents
duplicate Pending rows. This is not deployed or PostgreSQL-tested yet.

Staging verification must attempt direct Booking INSERT as Owner (denied),
RPC calls as Provider and another Owner (denied), an ineligible service/time
(rejected), and two overlapping Pending requests (both allowed before either
is accepted). Retry one token with identical data (same Booking ID), then
reuse it with changed data (rejected). Race two overlapping acceptances and
require exactly one success. Confirm the initial Pending history row is
written once with the created Booking.

`migrations/202610220007_property_window_lock_visibility.sql` restores the
provider-row lock in the Owner's property-window update trigger. Migration 005
made raw ProviderProfile rows own-only, which otherwise makes the original
invoker-rights trigger silently skip the lock. The revised trigger executes
with definer privileges but cannot be called directly by app roles. In staging,
race an Owner cleaning-window update against Provider acceptance and verify
that neither outcome leaves an Accepted booking outside the final window.

`migrations/202610220008_eligible_provider_search.sql` adds an Owner-only,
request-specific search. It checks approval, service capability, full weekly
availability, unavailable dates, rental-unit window, and Accepted/In Progress
overlap. Pending requests do not block search. The response contains only
safe presentation fields; it does not return raw schedules or private origin.
This is a hard-filter result, **not** the report's weighted provider ranking.
The booking-creation RPC must still revalidate at submission, and acceptance
must revalidate atomically. Exercise the search under another Owner, Provider,
and unauthenticated session before deploying it.

`migrations/202610220009_booking_quote_snapshot.sql` implements the agreed
pricing policy. A request shorter than 8 hours requires a positive hourly
rate and is priced by minutes/60, rounded to 2 decimals. At exactly 8 hours,
a positive daily rate takes precedence; an hourly-only Provider falls back to
8 times the hourly rate. Longer requests are rejected. The search RPC returns
the server quote; `create_pending_booking` independently recalculates it under
the Provider lock and rejects a changed price instead of silently changing
what the Owner agreed to. The resulting MYR basis/rate/duration/amount are
stored on Booking. Old unpriced Pending rows cannot newly become Accepted.
Pending interval revisions cannot change quoted duration; cancel and create a
new request for a different duration. Existing unpriced historical rows need
review before payment integration. This migration and its race behaviour
remain unverified until tested in PostgreSQL with multiple real accounts.

`migrations/202610220010_booking_messages.sql` adds booking-scoped persistent
text messages. Only the assigned Owner and Provider can read the conversation;
only a server RPC can send, and it accepts new messages only while the Booking
is Accepted or In Progress. Completed messages remain readable. A unique
per-sender client UUID makes network retries idempotent. The table is added
to the Supabase Realtime publication so active clients can receive updates.
This migration is **not deployed or tested in hosted Supabase**. The disposable
local PostgreSQL check below exercises representative SQL/RLS paths. In staging,
verify participant reads, a third account's denial, direct INSERT denial,
Closed/Pending send denial, retry de-duplication, and simultaneous completion
versus send before treating chat as production-ready. Background push alerts
are separate and not yet implemented.

## Disposable local migration check

With Docker Desktop running, execute `tool/verify_local_migrations.ps1` from
the repository root. It starts a network-isolated PostgreSQL 17 container
(16 is selectable),
loads the minimal Auth/Storage shim in `supabase/tests`, applies every migration
in filename order, runs booking-message and lifecycle/evidence RLS checks, and
stops/removes the container. The script does not use the Supabase URL/key.
The shim verifies SQL and selected policies, not hosted Supabase behaviour;
repeat cross-account Auth, Storage, Realtime and concurrency scenarios in a
backed-up staging project before deployment.

Run both `-PrivilegeProfile legacy` and `-PrivilegeProfile disabled` to test
with and without wide hosted defaults. A Docker-free synthetic PostgreSQL
runner is available as `tool/verify_native_migrations.ps1`; it verifies the
atomic generated bundle with a password-protected loopback-only test cluster
and shuts down the cluster afterward. See the migration plan for its bounds.
