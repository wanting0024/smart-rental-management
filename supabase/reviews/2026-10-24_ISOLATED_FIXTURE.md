# P1-2 — isolated booking fixture acceptance

Date: 24 October 2026. Scope: synthetic data in Staging only, not production launch
or manual device acceptance. Original App/UI preserved; no separate Demo-ready build.

## Hosted result

Pinned project: `gqtetdavmrautoojaqrk` (`smart-rental-staging`). The original
`dvakrwalnqpcmgirmlct` project was not changed.

Run: `460574d3-d567-4082-8221-72b1f4fa8bec`. Separate reserved-domain Owner and
approved Provider; two [TEST] properties, seven daily 08:00–18:00 weekly slots,
Standard/Deep cleaning capabilities, hourly rate RM40 and daily rate RM280.
One Pending test booking on 25 October 2026, 10:00–12:00 MYT. Original reusable
Provider A remains pending. No real account was adopted or approved.

Actual App repositories verify own profiles, properties, bookings and eligibility.
The server returns hourly RM80 for two hours and daily RM280 for eight hours.
Original Owner A cannot read fixture properties/bookings; authenticated users
cannot invoke administrator cleanup. Repeat Setup keeps the same accounts,
passwords and run data without adding duplicate properties/bookings.

The Pending booking is administrator-seeded readiness data. It does **not** prove
the normal Owner create-request path, lifecycle, evidence validation, messages,
review, report updates or device experience. Those remain P1-3 / P2-4 acceptance.
No completion, payment, message or uploaded evidence was fabricated.

## Administrator operation

Run from the repository in PowerShell 7. Never import this tool into the App.

```powershell
& '.\tool\staging_fixture.ps1' -Mode Plan
& '.\tool\staging_fixture.ps1' -Mode Setup -ConfirmProject gqtetdavmrautoojaqrk
& '.\tool\staging_fixture.ps1' -Mode Verify
& '.\tool\staging_fixture.ps1' -Mode PreviewCleanup
```

Plan is read-only. Setup creates missing exact synthetic identities then seeds the
registered run; it does not reset existing activity or rotate passwords. Verify
uses both ordinary signed-in accounts and server quote/eligibility rules. Commands
pin the project/client/server environment and reject production opt-in/config.

Credentials are generated before cloud creation and retained only in ignored
`output/staging-private/booking-fixture.local.json`, protected by the private
directory ACL. Never commit, screenshot, paste or publish the password fields.
The existing administrator key is obtained in process memory, validated against
the Staging project and never stored/logged or embedded in the App. Tool-created
sessions use local sign-out only; the user's emulator session is not signed out.

After the fixture date passes, create a future booking through the normal App
flow. Setup never redates an existing registered run or overwrites user activity.
After an explicitly safe cleanup removes the registry, Setup can reuse the same
Auth identities/passwords and refresh an expired fixture date for a new seed.

## Guarded cleanup — not an automatic reset

Migration `202610240026_test_fixture_cleanup.sql` adds two service-role-only RPCs
with pinned environment checks and an empty function search path. Preview returns
counts, blockers and a full-scope data fingerprint, not private row payloads.

Cleanup requires an explicit matching project and a reviewed fresh fingerprint:
`-Mode Cleanup -ConfirmProject gqtetdavmrautoojaqrk -ConfirmFingerprint <preview>`.
Do not execute this just to refresh the App. Close the App before intentional
cleanup and review scope first. This review executed **cloud preview only**.

Refusal conditions include mismatched identities, mixed-account bookings, any
Accepted/InProgress/Completed current status or historical transition, chat,
reviews, evidence/upload tickets, Storage metadata and excessive inventory. Fresh
row locks and a fingerprint recheck reject edits/acceptance racing the preview.
Safe cleanup removes only registered run business data, retaining Auth identities,
passwords and shared service catalog; it never deletes Storage objects. A worked-on
run is retained for audit, not silently reset to make a demonstration look clean.

## Verification evidence

| Check | Result / scope |
|---|---|
| Fixture pure guards | 41 passed, offline |
| Existing account-tool guards | 19 passed, offline |
| Native PostgreSQL legacy / disabled defaults | Both passed, atomic 001–026; cleanup/reseed and genuine concurrent edit/acceptance refusals |
| Hosted migration | Dry-run showed only 026; deployed only to pinned Staging |
| Hosted Setup retry | Existing credentials/identities preserved, 2 properties / 7 slots / 2 capabilities / 1 Pending booking |
| Hosted cleanup | Preview eligible; no cloud deletion executed |
| New fixture App-repository smoke | Passed; both roles, quotes, ownership and admin-RPC denial |
| Original account hosted smoke | 2 passed; Provider A still pending |
| Default Flutter regression | 614 passed |
| App secret-pattern check | PASS across 146 lib files |
| Tool Dart analysis | Style infos only; no errors/warnings |

Logs are `output/p1-fixture-*.log`; local credentials are excluded from logs.
The opt-in `tool/staging_fixture_acceptance_test.dart` is an initial-readiness
check for the seeded date/windows; after actual booking acceptance or elapsed
dates its eligibility expectations may legitimately change. Do not weaken booking
guards or reset worked-on records to force that initial-readiness check to pass.

No `lib/` change was needed in this step. No new APK build or phone/emulator UAT
is claimed. Next: normal two-role P1-3 business acceptance, not production rollout.
