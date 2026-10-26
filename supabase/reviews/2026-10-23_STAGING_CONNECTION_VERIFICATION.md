# Staging connection milestone — verified 23 October 2026

Scope: the first supervisor-preparation task, environment connectivity only.
This is not complete Step 3 acceptance and is not release approval.

## Changes made

- Independently re-read the hosted environment marker: staging /
  gqtetdavmrautoojaqrk. The original project dvakrwalnqpcmgirmlct was not queried
  or changed during this task.
- Set only EVIDENCE_ALLOWED_ORIGINS on the Staging project to the exact origin
  http://127.0.0.1:7391. No wildcard, JWT disablement, database grant, RLS change,
  schema migration or Edge code redeployment was used.
- Created ignored supabase/backend_config.staging.local.json using only the
  existing publishable client key. No server/admin key is in that file or in
  Flutter command-line defines. Production opt-in remains false.
- Added a pinned read-only connection checker and fixed-origin Web launcher.
  The launcher refuses an occupied port and never stops an existing process.

## Actual verification results

| Check | Actual result |
| --- | --- |
| Environment RPC using the App publishable key, not postgres | Correct Staging marker |
| Photo service OPTIONS from http://127.0.0.1:7391 | HTTP 200, PREFLIGHT, exact Allow-Origin and required headers/method |
| OPTIONS from http://127.0.0.1:7392 | HTTP 403, ORIGIN_NOT_ALLOWED, no Allow-Origin |
| OPTIONS from https://unapproved.invalid | HTTP 403, ORIGIN_NOT_ALLOWED, no Allow-Origin |
| Valid binary-upload protocol without a user bearer | HTTP 401 |
| Same protocol with an invalid user bearer | HTTP 401 |
| Git ignore check for local Staging configuration | Ignored |
| Actual Flutter Web debug startup on fixed origin | Running at http://127.0.0.1:7391/ |
| Browser visual check | Real login form; TEST ENVIRONMENT / Changes are saved to staging banner; no setup-error or preview workspace |

The browser reaches login only after the App's existing public-client server
marker check succeeds. No user was logged in and no Auth identities, bookings,
photos or chat messages were created in this task. HTTP preflight verification
does not establish successful signed-in browser photo upload.

Regression checks run in this task:

- 19 offline PowerShell checker cases passed: valid path, invalid local config,
  wrong server marker, incorrect CORS headers, extra origins and missing/invalid
  authentication. All HTTP/config reads are mocked; no real key is read.
- 21 targeted Flutter tests passed across backend_config, backend_environment_ui,
  local_preview_entry and workspace_login. These are not a full-suite rerun or
  real hosted login acceptance.
- 23 existing Node photo codec/handler/backend tests passed.
- Scoped secret-pattern scan of the three new scripts and ignored local client
  configuration: four files, zero findings. Keys were not printed.
- Whole-tree scanner was BLOCKED by four REFRESH_TOKEN examples in the ignored
  portable PostgreSQL pgAdmin Python dependencies. The four matching locations
  were inspected and are OAuth documentation examples, not App session records.
  A fifth initial match in our synthetic negative-test literal was removed by
  constructing that fake value at runtime; its rejection test still passes.
  No global scanner rules/exclusions were weakened. Whole-tree scanning is not
  recorded as a PASS; generated-runtime scoping remains a separate tooling issue.

## Repeatable developer commands

From the app repository in PowerShell 7:

```powershell
# Read-only hosted checks; no real login or business writes.
pwsh -NoProfile -File .\tool\verify_staging_connection.ps1

# Starts a debug App only after the checks pass, with pinned Staging defines.
pwsh -NoProfile -File .\tool\run_staging_web.ps1

# Offline regression checks; mocks all HTTP calls and configuration reads.
pwsh -NoProfile -File .\tool\verify_staging_connection_test.ps1
```

Use exactly http://127.0.0.1:7391/, not localhost, a different port or a preview
query parameter. An origin is scheme + host + port; changing any component
requires a deliberate allow-list review. Do not solve a future CORS failure by
turning off authentication or allowing every origin.

The ignored config is development-only and has no configured recovery redirect.
Password-recovery redirect/email delivery and a release build remain separate
acceptance tasks; this milestone does not assert that they work.

## Next milestone

Provision/verify distinct synthetic Owner and Provider identities, then run the
real signed-in booking/photo workflow and cross-account allow/deny cases. A
successful login screen and anonymous denials do not prove signed-in permissions,
private Storage bytes, Realtime, cancellation races or complete E2E behavior.
Do not proceed to the original-project rollout on this evidence alone.
