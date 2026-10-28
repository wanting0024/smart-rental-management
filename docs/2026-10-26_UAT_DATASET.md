# Labelled Staging UAT dataset

This batch populates the existing isolated Owner/Provider pair in
`smart-rental-staging` (`gqtetdavmrautoojaqrk`). It creates no additional Auth
accounts, changes no passwords, and does not touch the original project.

## Contents

- Eight fictional properties across four fictional buildings, with varied
  bedrooms and floor areas. Names and addresses explicitly contain `[UAT]`.
- Twenty-four bookings: six Completed, one In Progress, five Accepted, eight
  Pending, two Cancelled and two Declined. Future active requests occupy
  different days and respect the existing provider slots, exceptions and busy
  intervals found during planning. An unfinished past task exercises late
  completion; it is not presented as an on-time service.
- Six conversations with twelve messages: two historical completed threads,
  three accepted threads and one unfinished thread. Replies on closed threads
  remain controlled by the existing server rules.
- Twelve generated, explicitly labelled test images. These are actual small
  PNG objects processed by the deployed `evidence-validate` service, attached
  through the existing upload RPCs. No invented Storage metadata, disabled
  triggers or fake validation attestations are used.
- Completion histories cover approximately three months. Prices use the
  provider's existing rates, with the existing eight-hour daily-rate rule.
  Earnings are still computed by `provider_earnings`; no income totals, fees,
  payouts or successful payment events are fabricated.

The new historical event dates are synthetic backfills for report testing.
They are not proof of an actual service, an old photograph capture date or
receipt of payment. Images and notes identify their test purpose.

## Running the administrator tool

From the repository root, with the existing Supabase CLI login and private
Staging configuration/fixture manifest:

```powershell
python tool/populate_uat_dataset.py plan
python tool/populate_uat_dataset.py apply --confirm-project gqtetdavmrautoojaqrk
python tool/populate_uat_dataset.py verify
```

The default mode is a read-only plan. Apply verifies the environment marker and
both existing synthetic Auth identity markers at the database. It creates no
persistent database objects or new public permissions. Runtime SQL, exact IDs,
batch state and verification results remain in the ignored private
`output/staging-private/` folder. Tokens are never persisted or printed.

The same batch uses deterministic IDs and request/message/upload retry keys.
Keep its manifest when resuming after interruption. A finished batch is verified
without creating more records. Do not delete the manifest to force reseeding.
The tool never deletes existing data or resets either account. Existing business
rows, account rows and the provider profile are fingerprinted before and after.
If a tester changes records during import, the verification must be reviewed.

Photo registration obeys the existing six-per-minute upload budget. Waiting is
expected and does not mean the upload guard should be disabled.

## Acceptance checks

- Original business-data fingerprints remain identical.
- Added properties, booking states, messages and verified attachments match
  the planned counts; all quotes have the correct duration and currency rules.
- Last 30 days, This month and All time use the same real reporting RPC and
  produce different coverage. Bucket totals reconcile with each range total.
- Owner search filters the new records before paging: 20 plus 4, without
  duplicate booking IDs.
- Both participants can read a selected conversation. The Owner can request
  a signed URL for a canonical image through normal participant permissions.
- New chat sends on Completed and Pending examples are rejected with the
  existing business-rule error. Eight offline checks cover environment pinning,
  date/quote correctness, safe retry IDs, empty RPC responses and test isolation.

No APK rebuild is needed for data-only changes. Refresh the connected Staging
app with the existing accounts. The device UAT checklist remains a separate
human acceptance task; a populated database does not mark it complete.

## Public datasets versus scenario data

Public reference data can be imported after mapping columns to the app schema.
For example, the Malaysian government catalogue contains a postcode dataset:
https://data.gov.my/data-catalogue

Supabase supports CSV imports and scripted imports:
https://supabase.com/docs/guides/database/import-data

For this UAT batch, a public listing dataset would not supply valid participant
Auth identities, related booking IDs, compatible lifecycle histories, verified
evidence or correct immutable quote snapshots. The scenario data is generated
specifically for those relationships. This tests the connected application;
it does not switch the UI to local hardcoded preview data.

Check the source licence, origin, field quality and personal-data content before
using any external dataset. A downloaded email/password CSV is not an Auth
account provisioning method. Do not disable RLS or triggers to force an import.

## Observation for a separate fix

Some provider discovery RPCs still read legacy stored `rating_average` and
`completed_job_count`, while the private Provider profile/report computes from
actual review/booking rows. This seeder deliberately does not overwrite those
profile fields to hide the discrepancy. Public discovery counts should be made
consistent with the authoritative records in a reviewed backend change.
