# Step 3 — 19 business migrations deployed; hosted acceptance pending

Target checked in the live Dashboard: smart-rental-staging /
gqtetdavmrautoojaqrk. Original dvakrwalnqpcmgirmlct remains excluded.

Read-only hosted SQL results:

| Check | Actual result |
| --- | --- |
| Database role | postgres |
| PostgreSQL | 17.11 |
| Non-extension public application relations | 0 |
| Non-extension public application functions | 0 |
| app_private schema exists | false |
| Automatic public-table RLS trigger enabled | true |
| Supabase migration history table exists | false |

Screenshot: `2026-10-23_staging_preflight_verified.png`.
No DDL, DML or permission-changing SQL was executed in this step. SQL Editor
currently holds only the read-only preflight. The dashboard still displays a
platform-issue banner; do not treat an execution timeout as proof of failure and
blindly rerun a migration later. Check real schema/history first.

## Local CLI preparation

Developer-only CLI pinned to **2.121.0** under `tool/backend-cli/package.json`
and its lockfile, with dependencies excluded by existing node_modules ignore.
Verified installed executable reports 2.121.0; login/init help checked.
No root Flutter package.json was created or required. No CLI login, init,
project linking, credential lookup, remote push or Edge deployment was run.

Current fresh-bundle SHA-256 was rechecked against the tested artifact:
`441be1aa5c823f9a4e212c82f15e62f622fef5105b83970422b58f55a7224247`.

## User hands-on action now

In an interactive PowerShell terminal, run:

```powershell
Set-Location 'C:\Users\yunli\Downloads\FPY\rental_app_demo'
& '.\tool\backend-cli\node_modules\.bin\supabase.cmd' login
```

User handles browser verification/access tokens and reports only success or a
redacted error. Never paste passwords, access tokens or verification codes into
chat or pass a token as a command-line argument. Stop if the CLI warns that it
will store a token in plaintext, and review the credential-storage choice first.

CLI login is developer Management API authentication, not App-user Auth. It does
not itself deploy business tables or change the environment marker. After login:
initialize only the missing local config, link ONLY the stated Staging reference,
inspect migration history and dry run, then let the user execute the reviewed
deployment checkpoint. Do not use db reset, force init over an existing config,
include seed/roles, or push a project config/auth policy without separate review.

Use the CLI's migration history rather than applying the manual SQL bundle and
then unknowingly replaying the same baseline. Matching validator deployment,
marker assignment, real test identities and hosted security acceptance remain
pending. Step 3 is not complete.

Official mechanics:
[Supabase CLI setup](https://supabase.com/docs/guides/local-development/cli/getting-started),
[login/link and migration push reference](https://supabase.com/docs/reference/cli/supabase-db-push).

## User login confirmation (later checkpoint)

User supplied a terminal screenshot showing `You are now logged in. Happy coding!`
at the actual app repository path. This confirms the CLI reports successful
developer login; it does not prove a linked project or successful deployment.
No credential/token was requested, read or copied by the assistant.

Local read-only check afterward: `supabase/config.toml` still absent; no local
`supabase/.temp/project-ref` file found. Next user hands-on actions are init,
then link with explicit `--project-ref gqtetdavmrautoojaqrk`. Neither init nor
link was executed by the assistant. No db push or hosted business changes.

## User init/link confirmation and assistant Dry Run

User's later screenshot confirms `Finished supabase init.` and
`Finished supabase link.`. Local file checks independently confirmed:

- `supabase/.temp/project-ref` is exactly `gqtetdavmrautoojaqrk`;
- config.toml exists, local project_id rental_app_demo, database major_version 17;
- all 19 source SHA-256 digests match the already tested manifest.

Assistant ran the following **preview only** with exit code 0:

```powershell
& '.\tool\backend-cli\node_modules\.bin\supabase.cmd' db push --linked --project-ref gqtetdavmrautoojaqrk --dry-run --skip-vault
```

CLI explicitly reported `DRY RUN: migrations will not be pushed`, dryRun=true,
upToDate=false, exactly the 19 reviewed files from 202609270001_core_booking.sql
through 202610230019_explicit_app_privileges.sql; seeds=[] and roles=[].
The CLI's final generic "Finished supabase db push" message is NOT proof that
deployment occurred when dryRun=true.

The current CLI help documents that db push can synchronize Vault entries from
config.toml before migrations; --skip-vault was deliberately set to exclude this
unrelated change. No --include-seed, --include-roles, --include-all or automatic
--yes confirmation was used. Its normal CLI authentication initialized its own
login role; no raw credential was retrieved or logged by the assistant.

A subsequent read-only linked db query returned query_role=postgres,
public_table_count=0, migration_history_exists=false. This query is an admin
context, not proof of App JWT isolation. No business migrations have run yet.

### Next hands-on action (NOT run by assistant)

```powershell
& '.\tool\backend-cli\node_modules\.bin\supabase.cmd' db push --linked --project-ref gqtetdavmrautoojaqrk --skip-vault
```

This is a REAL hosted write. User must check the explicit Staging reference and
the same 19-file list before confirming. Do not run against the original project.
If an error/timeout occurs, stop and inspect real migration history/schema;
do not reset, delete objects or blindly rerun the baseline. Migrations may have
committed individually before a failure. Do not claim a successful deployment
or Step 3 acceptance until history and effective privileges are re-read.

## Actual deployment independently verified

User subsequently reported real push completion. Assistant confirmed all 19
remote history versions exactly match the reviewed manifest and checked hosted
object/column/function privileges, RLS, Storage policy/bucket and publication
metadata. See `2026-10-23_STAGING_POST_DEPLOY_VERIFICATION.md` and JSON evidence.
No marker update, validator deployment, test account creation or real cross-user
acceptance occurred. Next user hands-on checkpoint is explicit Staging marker
assignment; current marker remains unassigned. Step 3 is not fully accepted yet.

## Marker assignment confirmed; validator deployment pending

User reported the exact expected marker result. Independent linked read returned
`{environment: staging, project_ref: gqtetdavmrautoojaqrk}`. Functions list returned
an empty array; no validator was deployed by the assistant. Local Node 23 tests
and Deno index.ts type check re-run successfully. Local config now explicitly
enables evidence-validate with verify_jwt=true and its existing index.ts entrypoint.

Next user action is single-function deployment to the explicit Staging using
--use-api (server-side bundling, without the unavailable local Docker engine).
Do not use --no-verify-jwt, --prune, deploy all functions, or paste server secrets.
Allowed Web origins remain unconfigured and Web calls fail closed until configured;
deployment alone will not demonstrate a usable photo flow. Exact-origin/CORS,
actual JWT/byte tests, server runtime bounds, client config and test accounts remain.

## Evidence validator deployed; browser-origin setup pending

User executed single-function deployment with --use-api to the explicit Staging.
Read-only metadata independently confirmed evidence-validate ACTIVE version 1,
verify_jwt=true, correct index.ts and deno.json paths. Deployment artifact digest:
ae377a33c230bc60033fa0f5f1050b7cc2ff6764c93f97af647a19a87086074d.

No key or secret value was fetched. Safe GET without Authorization returned 401;
OPTIONS from https://not-allowed.invalid returned 403 ORIGIN_NOT_ALLOWED with no
allow-origin header. This proves gateway denial and handler startup, not actual
JWT acceptance/photo decoding/Storage publication. No record or file was uploaded.

Plan a fixed local Web origin http://127.0.0.1:7391 (no listener was found when
checked). The next user hands-on command sets EVIDENCE_ALLOWED_ORIGINS to exactly
that non-secret origin in this Staging only. It is stored through the Secrets
configuration facility but is not an API key. The assistant has not set it.
Future Flutter Web startup must use --web-hostname 127.0.0.1 --web-port 7391;
localhost, a different port, and a hosted domain are different origins and are
not implicitly approved. CORS does not replace JWT/server ownership checks.

Client Staging config file is still absent. App connection, real test identities,
actual uploads/permissions/Realtime/concurrency and Edge resource bounds remain.
