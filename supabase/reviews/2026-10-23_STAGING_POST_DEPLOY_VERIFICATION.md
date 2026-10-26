# Staging business migrations — deployment confirmed, acceptance still pending

Later same-day update: this document's unassigned-marker/function-pending notes
below are the original deployment snapshot, not the current state. The marker is
now pinned to Staging, the validator is deployed and local-origin connection
checks passed. See 2026-10-23_STAGING_CONNECTION_VERIFICATION.md. Real signed-in
acceptance and original-project rollout are still pending.

User reported `Finished supabase db push.` after the guided real command.
Assistant independently inspected the hosted target through the authenticated
CLI, not by assuming that message proves completion.

Target: smart-rental-staging / gqtetdavmrautoojaqrk. Original project
dvakrwalnqpcmgirmlct was not queried or changed in this verification.

## Confirmed hosted results

- CLI migration list: exactly all 19 reviewed local versions also present remotely.
  Metadata history was independently compared against the package manifest.
- 15 public + 2 app_private tables, all postgres-owned and RLS enabled.
- 51 effective table-role combinations checked: no App-role TRUNCATE,
  REFERENCES, TRIGGER or MAINTAIN on application tables. anon/service_role
  have no direct SELECT/INSERT/UPDATE/DELETE or INSERT/UPDATE column grants.
- Authenticated table read/write matrix and all 41 explicit non-SELECT column
  grants match the reviewed allow-list. No broad authenticated INSERT/UPDATE.
  Direct DELETE only applies to own availability/date rows under RLS.
- 50 non-extension public/private functions inspected: exact 23 authenticated
  and 10 server RPC allow-lists match. anon can execute only the non-sensitive
  get_app_environment endpoint in this scope. All 50 have fixed search paths.
- 27 policies inspected across application schemas and Storage. Obsolete
  direct-booking INSERT policy absent. Evidence Storage has participant SELECT
  and tombstoned DELETE policies, no authenticated INSERT policy in this project.
- cleaning-evidence bucket remains private, 5 MiB, JPEG/PNG only.
- Realtime publication contains booking, booking_message, booking_status_history.
- postgres creation defaults for public tables/sequences and global/public
  functions contain owner-only grants. Managed supabase_admin defaults are not
  rewritten; migration workflow must continue to create as postgres.
- anon/authenticated are not superusers/BYPASSRLS, cannot CREATE in public and
  cannot USAGE app_private. service_role is deliberately BYPASSRLS, not an App key.
- Environment marker is still `{environment: unassigned, project_ref: null}`,
  the expected fail-closed initial state, NOT a deployment failure.

Assistant ran only read-only post-deployment metadata/probe calls; no fixture
rows or test accounts were created, and no marker assignment was performed.
The CLI's own login-role handling is part of its authorized authentication path.

## Evidence

- `2026-10-23_staging_post_deploy_readonly.sql`: exact metadata query.
- `2026-10-23_staging_post_deploy_metadata.json`: complete parsed result rows.
- `2026-10-23_staging_post_deploy_checks.json`: 13 metadata checks, all true.
- Additional in-session comparisons verified all 41 column grants, authenticated
  table matrix and exact 19 history versions against local reviewed manifests.

## What this does NOT establish

Admin metadata inspection is not real Auth/JWT isolation, HTTP API, Storage
upload/download bytes, Realtime, Edge runtime or device testing. No complete
launch-readiness or full Step 3 claim. Local isolated tests remain separate evidence.
Original-project permissions/backup/schema rollout are still pending independently.

## Next user hands-on checkpoint

After confirming the Staging Dashboard URL, explicitly assign the administrator-
owned environment marker to staging / gqtetdavmrautoojaqrk. Explain why an App
role cannot modify it and why local/hosted identity must match. Do not label the
original project as Staging or grant client marker-write permission.

Then deploy matching evidence-validate with exact CORS/JWT/server-only secrets,
set ignored Staging App configuration, provision synthetic distinct test Auth
accounts and execute actual allow/deny/concurrency scenarios. No secrets should
be pasted into chat or committed. These steps have NOT happened yet.
