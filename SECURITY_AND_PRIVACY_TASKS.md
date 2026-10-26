# Security and privacy work queue

Local checks are not hosted security approval or OWASP certification. Work on
one task at a time; preserve the report's Owner/Provider business rules.

| Task | Local status | Still needs validation/decisions |
| --- | --- | --- |
| 1. Credential storage | Implemented/tested; Android debug APK and release Web build checked | Physical Android Keystore/iOS Keychain, signed iOS build, real Auth refresh/revocation, backup/restore |
| 2. Secret/log protection | Local app logging/UI boundaries, source/history/release-artifact scanner and opt-in gated build script implemented/tested | Use gate on each release; real-device/native-plugin log review, independent secret scanning, CI integration and final production signing remain pending |
| 3. Account recovery/session lifecycle | Local trusted PKCE callback, durable recovery gate, light/dark password-change UI, safe failure/cleanup and fresh-login flow implemented/tested | Manual staging redirect/mail/password-policy setup, actual delivery, verified release mobile links/signing/device tests; Web currently requires the requesting tab |
| 4. Photo/chat access and abuse prevention | 4.1 local write budgets and safe retry UI; 4.2 trusted pixel decoder/canonicalizer, server-only publication, guarded attachment/completion implemented with local tests | Coordinated manual staging deployment, legacy-evidence rollout decision, hosted bypass/integration and Edge resource tests; gateway/IP/global traffic/capacity controls remain |
| 5. Retention and account deletion | Retired-photo cleanup/test-run review only | Product retention decisions, active-booking handling, trusted idempotent deletion/anonymous retention workflow |
| 6. Privacy notice/minimisation | Some field minimisation exists; notice links are placeholders | Actual readable policy matching implemented behavior, permissions and data lifecycle |
| 7. Release hardening | Partial signing/environment guards exist | Final signing/package identity, broader network/platform/backup checks, dependency audit, release checklist |

Task 1 details and manual checks: `supabase/AUTH_CREDENTIAL_STORAGE.md`.
Task 2 scope, gate usage and pattern-scan limitations: `supabase/SECRET_AND_LOG_PROTECTION.md`.
Task 3 configuration, Web tab limitation and acceptance: `supabase/PASSWORD_RECOVERY.md`.
Task 4.1 safeguards, defaults, manual rollout and limits: `supabase/BOOKING_COMMUNICATION_LIMITS.md`.
Task 4.2 trust boundary, legacy impact and coordinated rollout: `supabase/VERIFIED_EVIDENCE.md`.
The local implementation tasks above did not deploy hosted business changes.
The separate 2026-10-23 Staging default-protection setup is recorded below.
Retention/deletion rules must not be invented or executed without agreement.

Reference framework: [OWASP MASVS](https://mas.owasp.org/MASVS/).

## Manual Supabase setup follow-up — user-requested reminder

- [ ] Before the Staging permission migration, remind the user to remove
  unnecessary `anon` privileges on `public.booking`. The user's dashboard
  query showed SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER and TRUNCATE
  grants. This is an observed grant list, not evidence of API exploitability.
- [ ] Finish read-only grant/RLS/trigger inspection; review PUBLIC/inherited
  privileges and related tables/functions before preparing a coherent migration.
- [ ] Apply and test least-privilege changes in Staging first, including denial
  for logged-out access and valid Owner/Provider flows. Review authenticated
  direct writes against the RPC-based business rules too.
- [ ] Guide the user through a separately approved Production rollout and
  verify effective permissions afterward. Do not disable RLS or remove the
  `anon` role itself. No hosted permission change has been made for this reminder.

This is a checkpoint in the ongoing setup workflow, not a timed notification.

### 2026-10-23 hosted read-only review checkpoint

Live metadata inspection completed through the user's Dashboard: 19 categories,
10 RLS-enabled public tables, 58 columns, 29 policies, 40 constraints, 10 triggers,
11 application functions and 17 indexes. Full results, logic recommendations,
limitations and hands-on checkpoints are in
`supabase/reviews/2026-10-23_DATABASE_SECURITY_REVIEW.md`; the raw metadata CSV is
stored alongside it. No business records/secrets were queried, no business RPC
was invoked and no hosted structure/permission/data change was applied.

The broad anon/authenticated grants affect all ten tables, not just booking.
Default ACLs also require review. Least-privilege remediation is NOT completed;
the local shim does not reproduce all observed hosted defaults. Add an explicit
reviewed migration and corresponding tests before staged deployment. Existing
RPC allow-lists, account/provider guards, overlap constraint and private bucket
are useful protections to preserve, not evidence of complete launch readiness.

Current user hands-on checkpoint: run the read-only current_user/auth.uid query
to distinguish the Dashboard administrator from an App user. Cross-account,
actual API/Storage/Realtime, concurrency and Auth settings remain unverified.

### 2026-10-23 new Staging default protection checkpoint

- [x] User completed identity exercise: postgres / NULL (administrator, not App JWT).
- [x] New `smart-rental-staging` / `gqtetdavmrautoojaqrk` exists.
- [x] Automatically expose new tables OFF persisted after reload; actual postgres
  new-table CRUD defaults verified denied for anon/authenticated.
- [x] Installed private automatic-RLS event trigger on this NEW Staging only.
  Plain CREATE TABLE, CTAS and SELECT INTO all enabled RLS automatically.
  Rolled back probes; separately verified zero public tables remain.
- [ ] Least-privilege remediation still pending: residual default privileges,
  including TRUNCATE, remain; original project's broad grants are NOT fixed.
- [ ] Deploy/review business migrations, real Auth/API/Storage/Realtime tests,
  environment marker/configuration, and separate original-project rollout.

Evidence and exact scope: `supabase/reviews/2026-10-23_STAGING_DEFAULT_PROTECTIONS.md`.
No original-project setting, permission, or record was changed in this step.

### Step 2 — migration package preparation (2026-10-23)

- [x] Added 019 explicit object/column/default privilege closure and exact
  client/server function allow-lists; retain privacy and business-rule RPCs.
- [x] Added effective ACL/default-object and normal/forbidden SQL-path tests;
  test both broad legacy and disabled-exposure defaults with the same 001–019 chain.
- [x] Prepared ordered atomic fresh-Staging bundle, SHA-256 manifest, read-only
  preflight/postflight, permission matrix and staged rollout/learning checkpoints.
- [ ] Step 3: guided hosted deployment, actual JWT/Auth/Storage/Realtime and
  distinct-account/concurrency acceptance. No business migration deployed yet.
- [ ] Step 4: independent original-project schema/history/data/backup plan and
  explicit rollout. Never reuse the fresh-Staging bundle against the original.

Local execution details: `supabase/reviews/2026-10-23_MIGRATION_PACKAGE_VERIFICATION.md`.
Deployment contract: `supabase/STAGING_MIGRATION_PLAN.md`.
The earlier anon-revocation reminder is still a hosted action, not completed by
writing/testing 019 locally. Do not mark original/Staging grants remediated yet.

### Step 3 preflight / learning handoff

Hosted read-only preflight passed: postgres / 17.11, zero public application
relations/functions, no app_private schema or migration history, auto-RLS enabled.
Pinned developer CLI 2.121.0 installed locally and version verified. User hands-on
checkpoint is interactive developer CLI login; no login/link/init/push has run.
Details: `supabase/reviews/2026-10-23_STAGING_DEPLOYMENT_CHECKPOINT.md`.

User subsequently completed CLI login, init and Staging link. Linked project ID
and all 19 migration hashes independently verified. Assistant's dry run passed:
exactly 19 files, no seed/role scripts, Vault sync explicitly skipped. Follow-up
read-only query confirmed zero public business tables and no migration-history
table. Current hands-on checkpoint: user executes real Staging push; assistant
has NOT performed the real push. Hosted role/API/Storage/Realtime acceptance
and original-project rollout still pending.

### Hosted business deployment now confirmed (later checkpoint)

User performed the real Staging push. Independent postflight confirmed all 19
history versions, 17 RLS-enabled postgres-owned tables, explicit column/RPC
allow-lists and no excess application-table special privileges. The user's anon
revocation reminder is now satisfied **for this Staging application schema**;
it is still NOT completed on the original project. Raw policies/bucket/publication
metadata match the reviewed design; this is not actual App-role integration
acceptance. Environment marker remains unassigned; next hands-on assignment,
validator deployment, configuration and test identities are pending.
Evidence: `supabase/reviews/2026-10-23_STAGING_POST_DEPLOY_VERIFICATION.md`.

Marker follow-up: user assigned Staging identity, independently read back as
staging / gqtetdavmrautoojaqrk. Function list empty; local validator tests re-passed
(23 Node tests + Deno type check). Explicit local gateway verify_jwt=true added.
Next user checkpoint: deploy ONLY evidence-validate using API bundling. Actual
Edge deployment, exact Web origins and hosted photo/Auth acceptance still pending.

Later validator checkpoint: user deployed evidence-validate; independently verified
ACTIVE v1 / verify_jwt=true. Unauthenticated GET 401 and disallowed-origin OPTIONS
403 passed smoke checks. No keys read and no upload/fixture writes. Next user
action: configure exact non-secret EVIDENCE_ALLOWED_ORIGINS for the planned local
Web test origin http://127.0.0.1:7391; assistant has not changed that setting.
Actual signed-in upload/Storage/Edge resource acceptance remains pending.
