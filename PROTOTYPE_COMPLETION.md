# Functional Prototype completion — working scope

Updated 26 October 2026. Target: demonstrate all intended Owner/Provider flows with
test identities, not public-launch approval. Existing original UI and protected
Staging implementation stay in place; mock behavior must be explicitly labeled
and isolated from actual booking/payment/security rules.

## Current implemented foundations (not a claim of complete user acceptance)

- Owner navigation refinement in Staging 0.1.4+5: five tabs retained; Home
  focuses on pending/upcoming appointments with one primary request CTA; Providers
  browses approved profiles; Bookings supports complete server search / History;
  Profile centralizes utilities / settings / Help. Read-only migration 029 and
  hosted fixed-account checks pass. 850 Flutter tests and APK verification pass;
  manual acceptance remains pending. See docs/2026-10-26_OWNER_NAVIGATION.md.

- Owner UAT batches two/three complete in the original connected UI: activity /
  cancellation controls and real-event timeline, property examples / bedroom
  choices / single Add, Welcome, service scope / saved extra-task notes and user
  Terms / Privacy drafts. All three batches combined in Staging APK 0.1.3+4;
  837 Flutter tests PASS, source/package scan PASS, signing continuity and
  distribution checksum verified. Fixed accounts and original project unchanged.
  Manual paired-phone acceptance remains pending. Legal texts are not published.
  See docs/2026-10-26_OWNER_UAT_FINAL.md and output/uat/README-UAT.md.

- Owner UAT batch one (items 2/3/4/6/7/13/16/17): two-step named registration,
  persistent safe errors, status destinations with database filters, inline
  appointment paging, explicit required cleaning times, full-portfolio totals,
  and personal/account profile sections. Migration 028 deployed to Staging;
  797 Flutter regressions, local SQL and hosted read-only checks passed. Manual
  two-phone acceptance is still pending. See docs/2026-10-26_OWNER_UAT_BATCH_ONE.md.

- Original connected Owner home / Provider Inbox, Schedule, Earnings and Provider
  Profile; persistent Provider primary navigation; quiet SWR and Inbox pull refresh.
- Owner My properties / Providers request-search / Profile now retain bottom
  navigation and Back, including loading/error. Primary switches stay bounded,
  reuse the existing Home/Bookings root, and property details retain their CTA.
  Follow-up: 788 full tests and Android Staging debug build passed; device UAT pending.
- Real in-app booking notifications, own read receipts, filters and booking links.
- Global Messages now reads real participant-scoped booking threads for both
  roles, preserving original list UI and using existing protected chat. Includes
  server search, 20-row keyset paging, pull refresh, silent visible 30-second
  revalidation and session isolation. P2-1 now adds own persisted read receipts,
  real per-thread unread, server Unread filter and shared entry badges. Quiet
  foreground 30-second polling, not device push; no peer Seen disclosure/fake pins.
- About Help articles open and describe actual implemented behavior, including
  message read status/polling, Pending revision and uncertain saves. P2-2 adds
  readable Terms/Privacy review drafts in Staging/local preview, clearly marked
  DRAFT / NOT PUBLISHED. Production/unknown keeps non-publication explanations.
- Simulated Contact support flow now works without a real support email: create,
  history/detail, simulate reply, close/reopen, reset. Available to signed-in local
  preview / Staging only. Memory-only, no mail or cloud tickets, no attachment or
  real agent. Thirty tickets / ten replies per ticket; logout, identity changes
  and restart clear them. Do not enter real private information.
- Core backend request, acceptance, protected lifecycle/evidence, review and
  reporting now also pass a real two-role Staging repository walkthrough (P1-3),
  with real Edge validation/private Storage, messages, notifications and repeat
  sign-in. Service/photos are explicitly synthetic; populated emulator UI UAT
  remains P2-4, not inferred from hosted automation.

## Remaining Prototype work / acceptance

- Four P1 -> four P2 acceptance sequence is tracked in PROTOTYPE_ACCEPTANCE.md.
  No separate Demo-ready build or presentation package is requested.
- Owner Profile & settings / Spending, property management/detail/edit and
  Provider statistics now use real connected own-account data with the original
  layouts. P1-1 code/automated acceptance passed; populated device UAT remains.
- P1-2 isolated test scenario is ready in Staging: a new synthetic Owner/approved
  Provider, two properties, seven weekly slots, two capabilities and one Pending
  booking. Server quotes verified hourly RM80/2h and daily RM280/8h; App repository
  reads and account isolation pass. Original Provider A stays pending. Repeatable
  setup and guarded cleanup are implemented; cloud cleanup only previewed, local
  cleanup/concurrency verified. No real-provider approval bypass or cloud deletion.
- The initial Pending booking remains seed data. P1-3 separately created and
  completed one new request through normal authenticated App/backend operations.
  Checkpoint rerun keeps the same booking/messages/photos; worked-on fixture cleanup
  is correctly blocked. After seven additional P1-4 cases, current retained test
  inventory after P2-1 is 1 Pending / 6 Cancelled / 1 Declined / 2 Completed,
  7 synthetic messages, 1 test review and 4 small private synthetic photos. No real payment.
- P1-4 hosted cancellation/revision/conflict/upload/permission and controlled
  network-loss acceptance passed, including real concurrent acceptance and stable
  checkpoint retry. Both SQL profiles pass; 658 default Flutter tests pass. No
  App redesign, migration or new approval bypass needed; original accounts intact.
- P2-1 code/hosted receipt acceptance passed: visible inbound IDs only, no whole-
  thread reset; partial/new-arrival/own-message/outsider and fresh login checked.
  Shared badge state rejects old-account replies, stops background polling and
  retains last confirmed counts on failure. 673 tests and Android debug build pass.
- P2-2 supporting pages / non-final legal drafts passed 36 focused / 688 full
  Flutter tests and Android Staging debug build. No fake recipient, consent,
  approved policy or cloud changes. Existing start/
  completion logic still checks actor/state/evidence, not scheduled wall-clock
  time; decide an explicit early/late execution policy before launch rather than
  silently adding a test bypass. P1-4 tests the existing state-based policy only.
- Rehearse the populated original UI on the user's phone/emulator in P2-4. P1-3
  hosted acceptance does not prove camera picker, native permission or device
  session-storage behavior or push delivery. Read-state UI/physical device UAT
  still remains even though the hosted receipt persistence has passed.
- Terms/Privacy prototype previews are now readable, sectioned and copyable with
  version/non-publication warnings and unresolved launch decisions. This does not
  complete legal review/publication, operator identity/contact, retention/deletion
  implementation or account rights requests. No acceptance is recorded.
- Decide presentation scope of payments, device push, reminders and recurring
  bookings. If simulated, isolate and label them; do not show a fabricated real
  transfer, SMS, push delivery or recurring appointment as confirmed.
- P2-3 cross-page UI/UX code / automated / rendered-widget checks passed. Owner
  dashboard large-text cards/navigation, keyboard discard dialogs, Owner form
  validator lifecycle and cancellation feedback repaired without redesign. 78 new
  regressions; 766 full tests and Android Staging debug build passed. Actual phone
  safe-area/keyboard/permissions/TalkBack and both-role walkthrough remain P2-4.
  Automated rendering and fault injection are not manual emulator/offline UAT.

## Support demonstration now

Hot Restart the Staging app; sign in using an existing test account. Open About &
help -> Contact support -> New test request. Enter synthetic subject/description,
confirm simulation, save, open history/detail, simulate reply, close/reopen. Leaving
an edited form asks before discarding. Reset asks for confirmation and affects only
local test tickets. Real Staging bookings, notification receipts and money fields
are not changed by the support simulation.

Latest evidence: output/p2-support-regression.log (688 passed),
output/p2-support-focused.log (36 passed), output/p2-support-android-build.log
(debug APK built), output/p2-support-analysis.log (style infos, no errors/warnings),
output/p2-support-security.log (151 lib files PASS). Includes existing support
session/production/form regressions and 15 new draft/help regression tests.
Review: supabase/reviews/2026-10-24_SUPPORTING_PAGES.md.

Formal launch remains separate: approved policies, real support contact/process,
production readiness, delivery integrations, operational monitoring and final
security/privacy acceptance are not requirements to *show a labeled prototype*,
but must not be silently treated as completed production work.
