# Staging default protection setup — 2026-10-23

## Scope and target

Dashboard project: `smart-rental-staging`, reference `gqtetdavmrautoojaqrk`.
The original project `dvakrwalnqpcmgirmlct` was not modified.
No business migration, App configuration, account, bucket, or business record
was deployed/changed in this step. The dashboard's `main Production` label
identifies its main branch; it does not configure the App environment marker.

## Verified outcomes

| Check | Observed outcome |
| --- | --- |
| Automatically expose new tables | OFF persisted after reload despite the earlier Save timeout |
| Actual postgres/public default table CRUD grants | SELECT/INSERT/UPDATE/DELETE denied for anon and authenticated on all three probe tables |
| Automatic RLS before setup | No corresponding event trigger installed |
| Automatic RLS after setup | `app_enable_public_table_rls` enabled (`O`) |
| Plain CREATE TABLE | RLS true without an explicit ENABLE RLS statement |
| CREATE TABLE AS | RLS true without an explicit ENABLE RLS statement |
| SELECT INTO | RLS true without an explicit ENABLE RLS statement |
| Internal helper | SECURITY DEFINER with fixed `search_path=pg_catalog`; schema and function access revoked from PUBLIC/App roles in the creation transaction |
| Effective helper EXECUTE | false for anon, authenticated, service_role |
| Effective helper schema USAGE | false for anon and authenticated |
| Probe cleanup | Transaction ROLLBACK; separate subsequent query confirmed zero public ordinary/partitioned tables |

The Dashboard warned about RLS because the SQL includes CREATE TABLE text.
We ran the reviewed SQL unchanged rather than asking the editor to append RLS:
the test therefore measures the event trigger itself. No existing RLS protection
was disabled. All three empty probe tables existed only inside a rolled-back
transaction. The final editor content is a read-only verification query.

## Actual persistent change

Created only:

- internal schema `app_security_bootstrap` owned by postgres;
- helper `app_security_bootstrap.enable_public_table_rls()` with fixed search path;
- event trigger `app_enable_public_table_rls` for future public table creation.

The setup script deliberately fails on nonempty public tables or existing
same-named helpers instead of overwriting them. It is a one-time bootstrap,
not a numbered business migration. Dashboard target identity must be checked
in the URL; SQL cannot independently verify the project reference.

## Important remaining work — NOT a complete least-privilege sign-off

The OFF toggle only removes Data API default privileges. All three probes still
had `anon` TRUNCATE=true. Metadata also showed postgres/public defaults retaining
TRUNCATE, REFERENCES, TRIGGER, MAINTAIN, and sequence UPDATE; supabase_admin/public
defaults still contained broad grants. Global PUBLIC function EXECUTE defaults
also require deliberate review. Do not claim these are fixed by this toggle.

Prepare/test an explicit least-privilege migration, covering initial tables,
future grants, sequences, functions and required RPC allow-lists, before business
deployment to Staging. Preserve required Owner/Provider flows. Do not modify
Supabase-managed auth/storage/internal roles indiscriminately. No such broader
remediation was executed in this narrowly scoped setup.

Automatic RLS enables row filtering, but creates no business policies. Actual
Auth/JWT, cross-account API/Storage/Realtime behavior remains unverified. The
next user hands-on learning checkpoint is the reviewed Staging permission
migration and its before/after verification, followed by real role-isolation
tests. This step does not establish launch readiness.

## Reproducibility and evidence

- `2026-10-23_staging_auto_rls_setup.sql`: readable equivalent of executed setup.
- `2026-10-23_staging_auto_rls_probe.sql`: readable equivalent of executed probes.
- `2026-10-23_staging_auto_rls_probe_results.json`: complete Dashboard Copy as JSON output.
- `2026-10-23_staging_auto_rls_verified.png`: final Dashboard screenshot showing
  event enabled, no probe tables remaining, helper inaccessible to App roles.

Sources for mechanics (not evidence of this project's behavior):

- [Supabase event triggers](https://supabase.com/docs/guides/database/postgres/event-triggers)
- [Supabase grants, RLS and default privileges](https://supabase.com/docs/guides/api/securing-your-api)
