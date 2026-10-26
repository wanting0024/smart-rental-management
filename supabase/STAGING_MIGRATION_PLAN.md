# Step 2 — reviewed Staging migration package

Target: **smart-rental-staging / gqtetdavmrautoojaqrk** only.
Original project **dvakrwalnqpcmgirmlct is excluded**. This document and the
bundle generator do not connect, deploy, configure Auth, create users or delete
anything remotely. Step 3 requires a separate guided execution/verification.

## Migration order and dependencies

Apply all 19 numbered SQL files in filename order; the generated manifest
contains exact filenames/order/SHA-256 digests. Never pick isolated fixes from
the middle, edit an already-applied migration, or rerun the create-only baseline.

| Order | Purpose / dependency |
| --- | --- |
| 001–002 | Core accounts/property/provider/availability/booking/history, transition/revision and initial private evidence; 002 adds property size fields |
| 003–004 | Accepted-before-start cancellation, service catalogue, two-hour availability slots, transactional capabilities replacement, approval checks |
| 005–007 | Provider private rows and safe directory; controlled booking creation; repair property-window lock visibility after private-row RLS |
| 008–009 | Eligible search, immutable MYR quote snapshot, minute-based hourly pricing / eight-hour daily rate; replace old unpriced RPC signature |
| 010–012 | Participant-only messages, completed-booking Owner reviews, scoped property/booking presentation |
| 013 | Administrator-owned environment marker, initially unassigned — does not silently enable Staging |
| 014–016 | Immutable registered uploads/cleanup, bounded cursor pages, Staging-only server-invoked synthetic fixture provenance |
| 017–018 | Actor-level communication limits; trusted image decoder/attestation, removal of direct client upload, verified completion |
| 019 | Explicit current and future privileges; column-level writes; exact client/server RPC lists; remove obsolete direct-booking INSERT policy |

Keep 005 and 007 together: privacy must not accidentally remove the provider
lock needed by an Owner property-window edit. Keep 009 with the matching client
quote contract. Deploy 018 with its matching `evidence-validate` function and
client; never enable an old unverified upload fallback. The matching Edge
function/CORS/JWT/secret configuration and runtime performance belong to Step 3.

## Explicit permission matrix after 019

All App users share PostgreSQL `authenticated`; account role, ownership,
assignment, status and business rules are checked by RLS/RPCs. Having a GRANT
does not mean every authenticated user can modify every row.

| Resource | App read scope | Direct App writes | Other writes |
| --- | --- | --- | --- |
| user_account | Own row | Register own ID/email/role/contact; update contact only | Identity/role/email/created_at are not editable |
| property | Owner's own rows | Insert normal fields; update name/address/size/window only | Ownership/IDs/audit fields immutable; confirmed-window guard preserved |
| provider_profile | Provider's own row | Insert profile fields; update bio/area/private origin/rates only | Approval/statistics are administrator/server-managed |
| service_type | Signed-in catalogue | None | Administrator only |
| provider_capability | Provider's own rows | None | `replace_provider_capabilities` RPC; preserve confirmed service requirements |
| provider_weekly_slot | Provider's own rows | Insert weekday/times; edit times/day; delete own slot | Two-hour minimum/non-overlap and confirmed-job guards preserved |
| provider_unavailable_date | Provider's own rows | Insert/delete own dates | Cannot invalidate a future confirmed booking |
| booking | Assigned Owner/Provider | Owner Pending instructions only | Creation/interval/status/quote via controlled RPCs; no direct INSERT/DELETE |
| booking_status_history | Booking participants | None | Lifecycle transaction only |
| booking_message | Booking participants | None | Participant RPC; Accepted/In Progress only; quotas/idempotency |
| booking_review | Booking participants | None | Owning Owner RPC; Completed only; aggregate in same transaction |
| booking_evidence | Booking participants | None | Guarded attachment/remarks RPCs |
| evidence_upload | Uploading Provider | None | Registered manifest, trusted attestation and controlled lifecycle RPCs |
| app_deployment_environment | No direct table read | None | Admin assignment; non-secret `get_app_environment` before login |
| test_data_run | No direct App/server-role table access | None | Staging-only server fixture/inspection RPCs |
| app_private | No client/server-role schema access | None | Internal definer helpers, never public client endpoints |
| cleaning-evidence bucket | Current verified attached paths, scoped participants; own tombstoned cleanup paths | No client upload/overwrite; guarded obsolete DELETE only | Trusted server validates pixels before immutable publication |

Logged-out `anon`: no business-table/column/sequence grants. Only
`get_app_environment()` is explicitly callable in the application public schema.
`service_role`: only listed worker/maintenance/fixture RPCs plus the environment
probe; not broad direct access to business tables. Its hosted Storage privileges
are not changed. It is a privileged server credential, never an App setting.

App roles have no TRUNCATE/REFERENCES/TRIGGER/MAINTAIN grants on application
tables, and no CREATE in public. New postgres-created objects default to no
App-role grants; future endpoints must add explicit grants and tests. Existing
column grants are reset as well as table grants.

## Creator-role caveat and scope

`ALTER DEFAULT PRIVILEGES` only affects future objects created by the named
creator. 019 controls **postgres**, globally and public/app_private overrides.
The global function revoke is necessary because schema-only revocation cannot
remove implicit PUBLIC EXECUTE. This global future-default change is deliberate;
future postgres-created functions in other schemas also need explicit grants.

The managed `supabase_admin` defaults are inspected, not impersonated/rewritten.
That role cannot authenticate through the Data API and its defaults are not
inherited into postgres-created objects. The supported migration workflow must
create application objects as postgres. Preflight/postflight must flag different
owners; do not create app objects as a different role and assume this default
policy covers them. Managed auth/storage/extensions grants are not blanket-revoked.

019 refuses unknown non-extension public relations/sequences or unexpected
application owners. It does not enable FORCE RLS (which would interfere with the
deliberately privileged RPC architecture). It is not an admin-key sandbox.

## What to do in Step 3 — not executed in Step 2

1. Check exact Dashboard project reference and fresh-schema preflight. No real
   user data may be copied into this initial Staging test. Export existing
   settings/metadata if any; stop on unexpected business objects.
2. Prefer the normal Supabase CLI migration workflow so migration history is
   recorded. Linking/deployment requires the developer's deliberate login/target
   check. Do not use `db reset`, delete/recreate a project or guess credentials.
3. `tool/build_staging_migration_bundle.ps1` generates a reviewable **single
   transaction** fresh-schema SQL artifact and SHA-256 manifest. It is an
   alternative guided manual artifact, not an automatic deployment. If using
   SQL Editor instead of the CLI, plan migration-history reconciliation before
   future CLI pushes; the bundle deliberately does not forge Supabase's managed
   migration registry. Never apply the bundle then blindly push 001 again.
4. Re-read postflight grants/column grants/function access/RLS/publication.
   Compare to the matrix. Assign the Staging marker manually only after verifying
   target identity; it intentionally remains unassigned after migrations.
5. Deploy the matching validator function with exact origins/JWT checks and
   server-only secrets. Configure ignored Staging client settings using only the
   publishable/anon key. No production configuration or credentials are changed.
6. Provision separate Owner A/B and Provider A/B test Auth identities. Test real
   bearer-token allows/denials, retry tokens, cancellation, concurrency, private
   photos, pagination and Realtime. SQL role shims are not real Auth delivery,
   API reachability, Storage bytes, Edge resource or Realtime authorization tests.
7. Record outcomes with account role/action/expected/actual and synthetic IDs;
   redact tokens and credentials. Step 4 requires a separate backed-up original-
   schema reconciliation/rollout, not the fresh-Staging package.

### Hands-on learning checkpoints

- Before execution: identify Project Reference, current_user and migration order.
- Review GRANT versus RLS versus column privileges; one normal edit and one
  forbidden approval/quote edit. A denied UPDATE may affect zero rows rather than
  raise an exception: verify the stored record did not change.
- Personally run one reviewed Staging migration step, inspect effective grants,
  then test Owner A versus Owner B with real App identities.

### Business-rule clarification (preserved, not changed here)

The declared **availability slot** minimum is two hours. The current **booking
duration** rule in 009 is 1–480 whole minutes; a sub-eight-hour booking uses the
hourly rate pro rata. These are different concepts. This permission migration
does not invent a two-hour minimum charge or change the agreed daily pricing.
If the product requires a minimum booking duration/charge, decide that explicitly
and update search/create/revision/UI/tests together before launch.

## Local verification

Docker runner: `pwsh -NoProfile -File tool/verify_local_migrations.ps1
-PrivilegeProfile legacy -PostgresVersion 17`, then repeat with `disabled`.
Version 16 can also be selected. Legacy defaults include all App-role grants;
disabled defaults retain the observed non-CRUD privileges. Tests must pass both.

Docker-free fallback: `tool/verify_native_migrations.ps1 -PostgresBin <trusted
PostgreSQL bin directory> -PrivilegeProfile legacy` (repeat disabled). This
creates a unique synthetic cluster with a generated ephemeral password, only
127.0.0.1 listening, no Windows service, stops it afterward and retains synthetic
files under ignored output. It exercises the generated atomic bundle and the
existing concurrency suite. It does not change Docker settings or hosted data.

See `reviews/2026-10-23_MIGRATION_PACKAGE_VERIFICATION.md` for actual execution
results; availability of tests is not itself a passing result.

Semantics: [Supabase grants/RLS/defaults](https://supabase.com/docs/guides/api/securing-your-api),
[PostgreSQL default privileges](https://www.postgresql.org/docs/17/sql-alterdefaultprivileges.html).
