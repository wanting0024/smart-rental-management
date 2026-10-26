# Labelled test data — staging only

## Implemented locally, not deployed

Migration 016 adds an administrator-only `test_data_run` registry. It does not
change existing user data, automatically assign an environment, create Auth
accounts, or run a seed when installed. No client can register/relabel itself
as a test run. RLS is enabled and ordinary app roles cannot read or write the
registry or execute maintenance RPCs.

`tool/test_data.mjs` supports three actions:

| Action | Effect |
| --- | --- |
| `plan` | Offline JSON blueprint with a Run ID and reserved test emails. No connection or secret needed. |
| `seed` | **Default dry run** checks staging identity, supplied Auth IDs, exact reserved emails, empty business identities, date and catalogue. Only `--execute --confirm-project <ref>` creates fixtures in one database transaction. |
| `inventory` | Read-only counts and at most 20 booking-ID samples for one registered run, including later activity associated with its actors. No delete action exists. |

The server independently checks and locks the staging marker for every fixture
or inventory call. The client also pins the exact HTTPS project URL/ID. Production,
unassigned environments, client keys, mismatched markers and reused business
accounts are rejected. This is protection against operator mistakes, not a
sandbox for someone who already possesses a project administrator secret.

## Fixture contents and provenance

One run binds **one new test Owner and one new test Provider** to a specific
project/date. The reserved addresses are:

```
owner.<run-uuid>@rental-test.invalid
provider.<run-uuid>@rental-test.invalid
```

The registry records `SYNTHETIC TEST DATA - NOT A REAL USER`, creation time and a
14-day **review reminder**. The date is server-generated for retention; passing
14 days does not delete anything. User roles remain Owner/Provider, not admin.

Seeding creates two explicitly `[TEST]`-labelled properties, one approved test
Provider with two catalogue capabilities, seven 08:00–18:00 working slots and
one two-hour Pending request at 10:00 Malaysian time on the specified date.
The snapshot is MYR 40/hour, MYR 80 total; the separate daily rate is MYR 280.
The existing initial-status trigger supplies its Pending history. No phone
numbers, real people, messages, ratings, evidence, completed services, payment
records or external-provider success results are fabricated.

Addresses are deliberately synthetic. This fixture does **not** validate route
geocoding/distance, real service delivery, email delivery, password recovery,
push notifications or payment integration. Configure an explicitly approved test
location and service sandbox separately when testing those integrations.

Repeating a seed with the **same Run ID, Auth IDs and date** returns
`already_seeded: true`; it does not reset later edits, recreate missing rows,
extend retention or produce another booking. Different parameters for that Run
ID are rejected. A failure anywhere in the SQL operation rolls the entire
business fixture back. Auth provisioning is a separate service operation and
is not part of that transaction. Lost replies are uncertain: inspect/retry the
same run rather than generate a new Run ID/accounts.

## Manual staging workflow — not executed automatically

1. Verify a **dedicated staging project**, distinct from real users' production
   project. Do not relabel production simply to pass this tool's guard. Follow
   `ENVIRONMENTS.md`; review/apply migrations to staging and explicitly assign
   its marker. Never apply files in `supabase/tests` remotely.
2. Generate an offline plan, choosing a date **1–90 Malaysian calendar days in
   the future**. Replace the date below; keep the returned Run ID and date:

   ```powershell
   node tool/test_data.mjs plan --date <YYYY-MM-DD>
   ```

3. As administrator, provision the two **new** Auth users with the exact emails
   from that plan, in staging only. Use the Dashboard's administrative user
   creation (not an email invitation) or a trusted server-side Auth Admin tool.
   Confirm them administratively for login testing; `.invalid` addresses cannot
   receive verification/recovery mail. Choose strong test passwords privately,
   record them in a password manager, and do not share them or secrets in chat.
   Copy their user UUIDs. **Do not log them into the app yet**: bootstrap may
   create business profiles, which this seed deliberately refuses to overwrite.
   If hosted custom triggers already created profiles, stop and review them.
4. In a developer-controlled terminal, configure `APP_ENV=staging`,
   `SUPABASE_PROJECT_REF=<staging-ref>` and
   `SUPABASE_URL=https://<staging-ref>.supabase.co`. Supply a server-only secret
   through process environment `SUPABASE_SERVICE_ROLE_KEY`. Both a current
   `sb_secret_...` key and a legacy service-role JWT are supported. No secret
   belongs in Flutter, a browser, a committed config, command-line arguments or
   a screenshot. For a private interactive PowerShell session:

   ```powershell
   $testAdminSecret = Read-Host 'Staging server secret (hidden)' -AsSecureString
   $env:SUPABASE_SERVICE_ROLE_KEY = [Net.NetworkCredential]::new('', $testAdminSecret).Password
   ```

   Environment variables are not encrypted storage; clear them when finished.
   Never distribute this administrator tool with an embedded secret. See
   [Supabase key guidance](https://supabase.com/docs/guides/getting-started/api-keys)
   and [Auth administrative creation](https://supabase.com/docs/reference/javascript/auth-admin-createuser).
5. Dry run first, reusing the exact plan/IDs/date (replace placeholders):

   ```powershell
   node tool/test_data.mjs seed --run <run-uuid> --date <YYYY-MM-DD> --owner <owner-uuid> --provider <provider-uuid>
   ```

6. Review the matching project and proposed counts. **This next command writes
   staging business data**; execute only after manually confirming the target:

   ```powershell
   node tool/test_data.mjs seed --run <run-uuid> --date <YYYY-MM-DD> --owner <owner-uuid> --provider <provider-uuid> --execute --confirm-project <staging-ref>
   ```

7. Inspect the run; then use the two test accounts in a verified staging build:

   ```powershell
   node tool/test_data.mjs inventory --run <run-uuid>
   ```

   Repeat inventory after tests to see persistent records. A staging build's
   existing permanent header warns that changes are saved to staging. Local
   preview data is separate and is not silently uploaded by this tool.
8. Clear the administrator secret from the process afterwards:

   ```powershell
   Remove-Item Env:SUPABASE_SERVICE_ROLE_KEY
   Remove-Variable testAdminSecret
   ```

## Review and cleanup boundaries

Inventory reports related accounts/properties/slots/capabilities/unavailable
dates, bookings, histories, messages, reviews, evidence pointers, upload tickets
and Storage **metadata** counts. Counts cover all related bookings; the ID sample
is limited to 20 and is not the entire set. The report is not a snapshot across
multiple future operations and not evidence that Storage bytes were deleted.

`mixed_account_bookings` flags requests involving another Owner/Provider or an
unexpected property owner. Such dependencies are **not** disposable just because
one actor belongs to a test run. All inventory replies set
`requires_manual_review=true` and `deletion_supported=false`. There is no
`DELETE`, table truncation, Auth removal, cascade purge, reset or scheduled
retention job in this tool. Counts are not a deletion allow-list. Administrator
reassignment or untracked historical data still requires separate review.

Unknown old `[TEST]` strings are not retroactively claimed. Do not identify
synthetic data only by display labels, dates or names. Do not use SQL DELETE
against `storage.objects` to remove file bytes. Existing retired-upload cleanup
in `PHOTO_UPLOAD_LIFECYCLE.md` has a different purpose: it does not delete
current evidence, completed histories, business records or Auth accounts.

Full business-data purge is deliberately **not implemented or approved** here.
Before adding one, define retention, backup/recovery, cross-account dependency
rules and per-record approval; coordinate Auth and Storage through their own
APIs. A manually disposable isolated environment is safer than broadly erasing
rows from a mixed staging/production project.

## Verification and remaining work

- Node tests cover deterministic plans, invalid dates/IDs, dry-run default,
  explicit creation confirmation, staging-only enforcement, marker mismatch,
  secret/header handling, no Auth/Storage operations, read-only inventory,
  malformed replies, retry guidance and secret-safe errors.
- Disposable PostgreSQL runs all 16 migrations and tests unassigned/production
  rejection, client denial, exact reserved-email checks, existing-profile
  refusal, dry-run non-mutation, injected mid-seed rollback, idempotent retry,
  fixed parameters, correct MYR/time/status fields, mixed-account warnings,
  retention reminders and sample limits with totals beyond one page.
- No hosted Auth provisioning, fixture creation, migration, inspection, account
  deletion or Storage operation has been performed. Real Auth/REST behavior,
  two-client activity, concurrent retries and environment reassignment races
  still require manually guided staging checks. These are not launch sign-off.
