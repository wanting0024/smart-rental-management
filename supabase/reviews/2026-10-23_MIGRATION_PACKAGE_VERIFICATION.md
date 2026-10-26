# Step 2 local verification result — 2026-10-23

**Package preparation completed; hosted business deployment NOT performed.**
Target for the next step: smart-rental-staging / gqtetdavmrautoojaqrk.
Original project dvakrwalnqpcmgirmlct unchanged. No browser/remote SQL actions
were performed in this step, no hosted secrets read, no Auth accounts created.

## Changes

- Added migration 019: existing table/column grants reset, restricted editable
  columns, explicit SELECT/RLS paths, client/server RPC allow-lists, default
  postgres grants removed globally plus public/app_private overrides.
- Preserved existing 005–007 privacy/lock repairs, 009 quote/creation validation,
  lifecycle/overlap/cancellation rules and 017–018 quota/verified-photo rules.
- Added real SQL ACL/RLS/default-object/registration/profile/search/quote/retry
  checks, exercised with both wide legacy and disabled-Data-API defaults.
- Test fixtures now explicitly grant their local-only helper EXECUTE after
  deny-by-default function defaults. They are never deployment artifacts.
- Corrected a misleading old review assertion: Owner cannot read a private
  Provider profile; compare the returned RPC/directory aggregate with
  `IS DISTINCT FROM`, rather than letting SQL NULL silently skip a failure.
- Generated deterministic ordered fresh-Staging transaction bundle, source
  digests, pre/postflight queries and deployment/permission/learning plan.

## Executed results

Runtime: trusted EDB Windows PostgreSQL **17.11**, isolated synthetic cluster,
127.0.0.1 only, generated ephemeral password with SCRAM authentication. No
Windows service installed, firewall rule changed, Docker reset or hosted DB used.

| Check | legacy broad defaults | disabled exposure defaults |
| --- | --- | --- |
| Fresh generated atomic migrations 001–019 | PASS | PASS |
| Automatic-RLS bootstrap compatibility | PASS | PASS |
| Effective application table/column privileges and denied special privileges | PASS | PASS |
| Future table/sequence/function deny-by-default, including PUBLIC EXECUTE | PASS | PASS |
| Anonymous business reads/TRUNCATE/RPC denial; environment probe allowed | PASS | PASS |
| Normal account registration/contact edit/property/profile/availability operations | PASS | PASS |
| Identity/role/created_at/self-approval/quote/status/direct-booking write denials | PASS | PASS |
| Provider privacy and approved directory / eligible search | PASS | PASS |
| Price mismatch, out-of-window rejection, retry de-duplication/changed-content rejection | PASS | PASS |
| Two-hour availability/non-overlap guards, eight-hour daily quote/nonblocking Pending | PASS | PASS |
| Valid Provider acceptance; confirmed schedule remains protected | PASS | PASS |
| Existing messages/lifecycle/evidence/environment/upload/cursor/test-data/quota suites | PASS | PASS |
| Actual concurrent chat/upload quota and exclusive photo-validation lease/retry checks | PASS | PASS |
| Test clusters stopped; no postgres/initdb processes or temporary password files remained | PASS | PASS |

Final complete runs after the expanded quote/retry cases returned exit code 0
for both profiles. Earlier failures while preparing the fallback (incomplete
archive extraction and unsupported Windows stdin password input) were fixed;
they are not counted as successful runs. The corrected runner uses an ephemeral
test-password file removed immediately after initdb, then process environment;
it does not emit the password.

Docker execution was attempted but its engine startup failed; the Docker runner
and PostgreSQL 16 selection are **not claimed as revalidated**. The native runner
executes the actual generated transaction bundle, not substituted migration SQL.

## Reproduction

```powershell
pwsh -NoProfile -File tool/verify_native_migrations.ps1 -PostgresBin output/postgres-runtime/edb17/pgsql/bin -PrivilegeProfile legacy
pwsh -NoProfile -File tool/verify_native_migrations.ps1 -PostgresBin output/postgres-runtime/edb17/pgsql/bin -PrivilegeProfile disabled
```

Downloaded runtime source: official EDB
`https://get.enterprisedb.com/postgresql/postgresql-17.11-3-windows-x64-binaries.zip`.
Locally computed SHA-256 (not a separately verified vendor checksum):
`4b8db0930c38f6ef845db919551dedda3b6b845aeb0927b3d79a6e8e9e4537cf`.
Runtime and stopped synthetic data directories remain under ignored output
for local reuse/inspection, not application assets or hosted test records.

Tested source 019 SHA-256:
`5643f222d3599e05a9c7fdad77346b6accf466cb72860baf85d84c5c19b988b3`.
Tested generated bundle SHA-256:
`441be1aa5c823f9a4e212c82f15e62f622fef5105b83970422b58f55a7224247`.

## Important limits / next step

This is PostgreSQL role-shim verification, not hosted Auth/JWT delivery,
Data API reachability, Storage bytes/Realtime isolation, Edge CPU/resource
limits, device security or release readiness. Concurrent acceptance/property-
window scenarios still need the planned hosted acceptance matrix; this run's
concurrent tests cover quotas and image leases, not every business race.

Managed supabase_admin creation defaults remain outside the postgres creator
policy; the migration workflow/owner check must keep application objects under
postgres. Existing hosted business grants are NOT fixed until the reviewed
changes are deployed and verified in Step 3. Keep the user's reminder for
removing excess anon privileges as a real hosted checkpoint.

Fresh-Staging deployment must select a migration-history workflow. Prefer CLI
tracking; SQL Editor bundle use needs explicit reconciliation before future CLI
pushes. The package does not forge managed migration records or silently assign
an environment. Step 4 needs a separate original-schema/backup/legacy-evidence
plan and authorization.

Full contract and permission matrix: `../STAGING_MIGRATION_PLAN.md`.
