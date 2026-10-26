# Development progress

## Owner navigation and page responsibilities (26 October 2026)

- Retained five primary tabs and original UI. Home now has one Request cleaning
  CTA, status destinations, separate Pending / Upcoming lists; repeated Quick
  actions, More and primary drawer menu removed. Messages / notifications remain
  top utilities. Profile centralizes preferences, Schedule / Spending and Help.
- Providers now reads an approved-profile directory, with bounded search/pages
  and profile details / normal Back. It no longer opens the request form.
  Bookings searches all owned records at the server before paging, supports
  status / History and newest / oldest. Original booking cards remain.
- Additive read migration 029 passed local legacy/disabled ACL/RLS and paging
  verification and was deployed only to Staging. Fixed-account hosted read-only
  checks passed, no business records / users / credentials changed.
- 850 Flutter tests PASS; zero analyzer errors/warnings (style infos remain),
  source 159 / package 756 files pattern scan PASS. Android Profile 0.1.4+5 built,
  signer matches v0.1.3; distribution checksum verified. Device UAT pending.
  Details: docs/2026-10-26_OWNER_NAVIGATION.md; latest APK / checksum in output/uat.

## Owner UAT final combined batches (26 October 2026)

- All three requested Owner batches are included in 0.1.3+4. Batch two adds
  readable activity/cancel buttons and event timelines, removes detail Logout
  and duplicate Add, adds property examples and bedroom choices. Batch three
  adds pre-login Welcome, service scope / saved extra-task requests and user-facing
  Terms / Privacy drafts. The original connected UI and fixed accounts remain.
- Service descriptions use existing catalog data. Extra tasks remain outside the
  quote until separately agreed; both participants can read the saved notes.
  No migration, cloud business write or new user was needed for batches two/three.
- 837 complete Flutter tests PASS, including 28 batch-two and 12 batch-three
  additions. Retry notes/token behavior, both-role readback, 320px / 200% text,
  themes, recovery/session boundaries and intended visual baselines verified.
  Analyzer has zero errors/warnings (style infos remain). Source scan 157 files
  and final APK scan 754 files PASS. Hosted read-only fixed-account catalog,
  totals, filtered paging and denial checks PASS.
- Final Profile Staging APK built; versionCode 4, versionName 0.1.3, min API 23,
  universal ARM/x86, 96,547,677 bytes. Signature verified and matches v0.1.1.
  Distribution checksum matches the build; output/uat/SHA256-0.1.3.txt records it.
  Details and manual checklist: docs/2026-10-26_OWNER_UAT_FINAL.md.
- Device UAT / P2-4 remains pending. Legal drafts remain unpublished; production
  recovery configuration, real support/legal operations and payments are not
  accepted as complete. No production project changes or credential rotation.

## Owner UAT batch one (26 October 2026)

- Implemented requested items 2/3/4/6/7/13/16/17 in the existing UI: two-step
  role-specific registration and saved names; persistent safe sign-in errors;
  named greeting with neutral fallback; server-filtered status destinations;
  inline follow-up expansion; required, consistent 24-hour cleaning times;
  full-portfolio aggregates and plain-language pagination; personal/account
  sections in the Owner profile editor with immutable email/role.
- Follow-up list orders appointments at the server before paging. Status pages
  filter before paging; Ongoing includes Accepted and In Progress. Inline
  expansion stays on Home, retains state, and stops its channel off-route.
- Migration 028 applied only to Staging gqtetdavmrautoojaqrk after local SQL
  verification under both privilege profiles. Registration-name triggers add no
  direct client name-write grants; existing names/accounts are not overwritten.
- Read-only hosted checks with fixed accounts passed: marker, Owner totals vs
  profile, bounded status queries, Provider and anonymous denial. No new users,
  business records or credential rotation. Original project untouched.
- 797 Flutter regressions pass; updated intended form/pagination visual
  baselines reviewed. Local ACL/RLS, 25-property/26-booking aggregate fixtures,
  session isolation and concurrency checks passed. Static analysis has no errors
  or warnings (existing style infos); 153 lib files pattern scan PASS.
- Android package version 0.1.1+2. Packaging/verification evidence is tracked in
  docs/2026-10-26_OWNER_UAT_BATCH_ONE.md. Two-phone manual acceptance remains
  pending; this does not mark P2-4 or public-launch readiness complete.

## Owner persistent primary navigation (24 October 2026)

- Original My properties, Providers (connected request/search) and Owner Profile
  now retain the same bottom menu and selected destination, including loading /
  failure states. Existing inner AppBars keep their normal Back arrows; Owner
  Booking History and embedded preview categories explicitly return to Home.
- Primary tab switching replaces the current tab route rather than adding copies.
  Home / Bookings reuse the existing Owner root, with root selection carried
  across pushed routes and property details. Property details keep their own
  Schedule new cleaning CTA above the persistent menu. No duplicate visible menu.
- Rapid taps guarded; original local Properties / Providers / Profile paths also
  checked. Editors retain normal full-screen save/discard behavior, not a new UI.
- 22 new navigation regressions; 29 focused and 788 full Flutter tests passed.
  Actual connected composition uses offline mock transport, both-theme 320x568 /
  200% loading/error/ready, detail -> Profile -> Bookings/Home, normal Back and
  bounded stack tested. Staging Android debug built; no analyzer errors/warnings
  (style infos); 152 lib files secret-pattern scan PASS. No hosted API/user/data
  changes or credential rotation. Manual phone UAT remains pending P2-4.

## P2-3: cross-page UI/UX audit and repairs (24 October 2026)

- Preserved original UI/themes. Reproduced Owner dashboard 97/163px statistic
  overflow at 320px / 200% text; replaced fixed card heights with natural growth,
  responsive large-text stacking and readable quick-action content.
- Owner bar scales/wraps labels, full selected button semantics and actual semantic
  tap callback verified. Shared/Provider discard and Owner info dialogs scroll.
- Owner editor reuses original route, now publicly testable. Scrollable non-lazy
  form keeps all validators mounted; invalid earlier fields cannot disappear from
  validation when scrolling to Save. Pending disables repeat writes; uncertain
  saves retain entries and disable blind retry, unchanged backend protections.
- Cancellation buttons reflow; inline reason/Other-required errors replace hidden
  snackbars. Required Other field stays available even with optional comments off.
  Theme error/onError button colors and selected reason semantics added.
- 78 new regressions; 85 focused / 766 full Flutter tests passed; Staging Android
  debug built; source scan PASS 151 files; analysis no errors/warnings (style infos).
  Both-theme 320x568/200%, keyboard, state/retry, registration/recovery, draft/back,
  navigation semantics and touch-target tests. Existing connected UI/chart/range/
  paging/privacy suites pass. Rendered light/dark original layout inspected.
- No hosted API/login/signup, cloud records, keys/passwords, dependencies or SQL
  changed. No production work or PDF. Code-level P2-3 passed, not all-device / human
  usability certification. Manual native permissions, TalkBack and two-role UAT
  remain explicitly pending P2-4. Details: docs/2026-10-24_UI_UX_REVIEW.md.

## P2-2: supporting pages / non-final legal review drafts (24 October 2026)

- Kept original About & help UI; added readable sectioned Terms / Privacy drafts
  only for Staging / explicit local preview. Prominent non-publication/version
  label, copied full warning and unresolved checklist. No effective date, contract
  approval or recorded consent. Production/unknown environment gates checked in
  About and reader; local visibility is not backend authorization.
- Help now explains genuine own-message read logic / quiet polling, same-duration
  Pending revision, uncertain writes, cloud retention versus sign-out. Drafts
  describe actual participant property access, image preparation/private evidence,
  non-E2EE, session storage, memory-only support and missing deletion/export.
  Existing simulated support flow and actual configured-email copy preserved;
  no fake contact, real delivery, payment or scheduled-time guarantee introduced.
- 36 focused and 688 full Flutter tests passed (15 new); Android Staging debug
  built; lib scan PASS 151 files; analysis no errors/warnings, style infos remain.
  New coverage includes 320px/200% light/dark, copy warnings, back navigation,
  both documents, production/unknown/direct-entry/local preview gates.
- No backend/cloud/business data mutation or new dependency. Formal policies,
  real operator/contact, retention/backup/deletion procedure, time/dispute policy
  and qualified review remain separate launch decisions, not prototype completion.
- Next P2-3 cross-page UI/UX. Manual phone/emulator tests remain P2-4 as requested.
  Details: supabase/reviews/2026-10-24_SUPPORTING_PAGES.md.

## P2-1: genuine persisted message read/unread (24 October 2026)

- Additive Staging-only migration 027: private exact-message-ID own receipts;
  authenticated scoped read/count/unread-filter RPCs, no raw table grants/peer
  Seen disclosure. Own sent messages excluded, exact incoming batches <=50,
  atomic idempotent retry. Snapshot-aware paging leaves unseen/new arrivals unread.
- Reused original Messages layout, actual unread rows/header and server Unread
  filter, no pins/mock counts. Shared per-session badges on Owner quick action /
  drawer/header; one foreground 30-second quiet poll + local-write invalidation.
  Initial count unknown, failures retain last confirmed count, no optimistic zero.
- Thread marks only painted visible incoming bubbles while current/resumed, not
  prefetched cache items or outgoing messages. Debounced bounded acknowledgements,
  quiet retry, pop/background cancellation and late-account response guards.
  Fixed transient Auth-error handling in new host to preserve verified routes.
- Native full 001–027 / both grant profiles passed; only 027 deployed after pinned
  dry-run. Actual hosted dedicated four-message partial/new-arrival/own-ID/outsider
  checks passed; fresh sign-in/global/filter/closed-thread persistence and same-
  checkpoint resume passed. Existing account smoke 2 passed; original project and
  Provider A approval unchanged. No old conversation was acknowledged by tooling.
- 673 Flutter tests passed; Staging Android debug APK built; lib secret scan 149
  files PASS; analysis no errors/warnings, style infos remain. 15 new Flutter tests
  cover controller/viewport/repository/filter plus existing lifecycle/golden checks.
- Current test inventory 10 bookings, 28 status events, 7 messages, 1 review and
  4 private images, retained. No deletion/new real service or payment. Cross-device
  foreground badge propagation is polling, not push; manual phone UAT remains P2-4.
- P2-1 automated/hosted acceptance complete. Next P2-2 supporting pages. Hot Restart
  (not just Hot Reload) recreates existing thread state for the new read tracker.
  Details: supabase/reviews/2026-10-24_MESSAGE_READS.md.

## P1-4: negative-path and uncertain-network acceptance (24 October 2026)

- Seven bounded ordinary-account Staging test appointments verify permitted and
  denied cancellation/decline, same-duration Owner Pending revision, invalid actor/
  duration/window/state and post-start cancellation. Exact history counts prevent
  claiming duplicate terminal operations as success. Original P1-3 data retained.
- Actual concurrent acceptance of overlapping Pending requests gives one winner;
  other acceptance/revision/new conflicting creation denied. Cancelling the winner
  releases the slot. No privileged inserts, time changes, SQL status overrides.
- Tool-only fault transport pins HTTPS host and explicit POST paths. Real upstream
  writes with lost request/response exercise create/accept/revise/cancel/message/
  completion readback, stable idempotency IDs and Edge upload attach reconciliation.
  Timeout alone is never proof of commit. HTTP errors are not hidden by the injector.
- Real malformed bytes rejected by deployed validator; no completion without valid
  attached evidence. Owner upload, Provider self-review, early review, closed chat,
  original A outsiders and anonymous RPC/private-file access denied. Forged quote,
  elapsed start and >8h create requests leave no new booking.
- Added local approval-withdrawal/expiry/retry regression and wired native verifier;
  both 001–026 grant profiles and actual existing concurrency tests pass. Protected
  behavior already implemented, so no new migration/Edge deploy/cloud approval
  mutation or lib/UI edit was necessary. Existing http 1.6.0 explicit dev dependency
  only, no resolved-version upgrade.
- Hosted first run + checkpoint rerun pass; default gate skips. 19 new offline
  guards, 658 default Flutter tests, original hosted smoke 2, lib secret scan 146
  files PASS. Retained fixture: 9 bookings, 25 status events, 3 messages, 1 review,
  5 upload tickets (1 rejected), 4 private objects. No deletion; cleanup correctly
  blocked. No actual service, payment, physical offline/device UAT claim.
- P1-4 automated integration accepted. Next P2-1 message read/unread persistence.
  Scheduled early/late execution policy remains open; device UAT still P2-4.
  Details: supabase/reviews/2026-10-24_NEGATIVE_ACCEPTANCE.md.

## P1-3: real Staging business integration acceptance (24 October 2026)

- Ordinary dedicated Owner request -> assigned Provider accept -> start -> hosted
  verified private before/after upload -> complete -> Owner review -> reporting
  passed through actual App repositories. Missing evidence prevents completion.
  No administrator/state/time override, real-person data, service or payment claim.
- Both participant calendars, two genuine persisted synthetic message sends/global
  thread, request/completion notifications, own read receipt, four history entries,
  three MYT Earnings/Spending ranges and statistics verified. Both-role fresh
  password sign-in reads persisted booking/chat/review/evidence/receipt correctly.
- Explicit project-confirmed opt-in harness persists stable request/message/upload
  IDs before writes, resumes uncertain responses and refuses another run. Repeated
  hosted execution passed with same booking ID and no duplicate messages/photos.
  Cloud preview now correctly blocks cleanup of worked-on/history/file inventory;
  no deletion or business-history reset. Original project/accounts unchanged.
- New offline target/checkpoint/pixel guards: 25 passed. Default Flutter regression
  639 passed; existing two-account hosted smoke 2 passed; secret scan 146 lib files
  PASS. Tool analysis: no errors/warnings, 4 test-console infos. No App UI/source
  change, migration, function redeploy or new APK needed for this step.
- Existing execution-time policy is a genuine outstanding business decision:
  accepted Provider can start/complete before scheduled time if evidence satisfies
  rules. Test followed this existing rule with a future synthetic booking; did not
  fake the server clock. Confirm/test timing policy before public launch.
- P1-3 hosted integration passed, not native device UAT/real cleaning/payment.
  P1-4 negative paths next; P2-1 unread persistence and P2-4 device acceptance remain.
  Details: supabase/reviews/2026-10-24_BUSINESS_ACCEPTANCE.md.

## P1-2: isolated usable booking fixtures (24 October 2026)

- Dedicated reserved-domain synthetic Owner/approved Provider in pinned Staging;
  two [TEST] properties, seven weekly slots, two capabilities, one Pending booking.
  Original Owner A/Provider A unchanged; Provider A remains pending. No original-
  project mutation, completed job, chat, evidence, Storage upload or payment.
- Administrator-side lifecycle tool supports Plan / Setup / Verify / PreviewCleanup
  / explicitly confirmed Cleanup. Private ignored credentials, restricted local
  ACL, exact identity/metadata checks, no password reset/adoption, no client secret.
  Repeated setup retains identities and activity without creating duplicate rows.
- Migration 026 deployed only to Staging after dry-run. Cleanup requires matching
  registered run and fresh fingerprint; rejects mixed ownership, worked-on history,
  chat/evidence/upload/Storage and concurrent changes. Keeps Auth identities/shared
  catalog. Cloud preview only; deletion/reseed and actual lock-contention tests
  passed locally under both default-grant profiles, full 001–026 verification.
- New hosted App-repository readiness passes real role/property/profile/booking
  reads, hourly RM80/2h and daily RM280/8h quotes, isolation/admin RPC denial. Existing
  two-account smoke passes. Offline fixture guards 41 + original guards 19; Flutter
  regression 614 passed; lib secret-pattern scan PASS across 146 files. No lib/UI
  change or APK rebuild required for these administrator-side additions.
- P1-2 complete with cloud cleanup intentionally not executed. P1-3 is next: seeded
  Pending data does not prove normal Owner submission or end-to-end lifecycle.
  Operational notes: supabase/reviews/2026-10-24_ISOLATED_FIXTURE.md.

## P1-1: remaining connected workspace pages (24 October 2026)

- Reused original Owner Profile/settings, property list/cards/table/detail,
  Spending and Provider stats UI with genuine own-account data. Owner name/contact
  and property edits use fresh baselines, allowlists and revision-conflict checks;
  confirmed-window protection retained. Add/Manage distinct; per-property bounded
  booking history/requests use server UUIDs, never display-label matching.
- Removed connected fake NRIC verification, fixed property count/response/repeat
  metrics and placeholder export/share controls. Password/email/language actions
  disclose actual limitations. Spending is saved completed quote value, not proof
  of payment; server MYT periods, unknown pricing and page-vs-total scope explicit.
- Auth reads persisted Owner name on login/restore. Shared bounded own-account
  SWR bridge rejects stale-account replies, invalid projections and stale writes;
  original form now preloads edits and guards unsaved entries. Fixed narrow/200%
  spending-record/hero layouts and responsive real Provider metric cards.
- Migrations 024/025 deployed ONLY to Staging gqtetdavmrautoojaqrk after dry-run;
  original project untouched. Local SQL both grant profiles passed; 614 Flutter
  tests passed; hosted Owner/Provider reads passed; Android built; lib analysis
  style infos only, no errors/warnings; source secret scan PASS (146 files).
- This completes P1-1 code + automated acceptance, not the remaining seven tasks
  or manual device acceptance. Ordered definitions in PROTOTYPE_ACCEPTANCE.md.
  P1-2 isolated usable fixtures is next. No hosted business fixtures created yet;
  reusable Provider A remains pending; no payment/device push claimed.

## Functional Prototype: real global Messages entry (24 October 2026)

- Owner quick action / Provider drawer now open original ChatListScreen with
  protected Staging booking conversations, not preview MessageStore. Shared real
  booking-chat route is reused from both list and booking detail. Closed histories
  remain readable; existing status/participant/rate/idempotency guards unchanged.
- Additive authenticated-only RPC migration 023: explicit actor scope, safe
  name/unit/service/160-character preview projection, server-side literal search,
  20-row timestamp+UUID paging with as_of boundary. No new client table grants.
- Pull refresh, load-more retry, debounced search, quiet stale revalidation while
  visible, 30-second visible-only polling, lifecycle suspension and session/late
  response isolation. Preview-only fake pins/unread numbers are absent; persisted
  chat unread receipts and instantaneous global message notifications remain open.
- Local SQL verification passes both privilege-default profiles; Staging-only
  migration applied after dry-run. Both test-account hosted reads pass; no hosted
  booking/message fixtures created, no original-project change. Populated two-role
  exchange/emulator acceptance remains pending. See the conversation review.
- Verification: 608 Flutter tests passed, two-role hosted reads passed, both local
  SQL profiles passed, Android Staging debug APK built. Analysis style infos only
  (no errors/warnings); lib secret-pattern scan passed across 139 source files.

## Functional Prototype: simulated support flow (24 October 2026)

- Contact support in local preview / Staging now supports validated issue form,
  explicit simulation acknowledgement, session-local ticket history/detail,
  clearly simulated replies, close/reopen and confirmed reset. No real users,
  recipient email, mail provider or support staff is required for this flow.
- Composition-root memory store is bounded and tied to signed-in identity epochs.
  Logout/account change/restart removes tickets; stale forms cannot read/write a
  later account. Production has no simulation entry or enabled store. Existing
  configured-email support path remains unchanged outside prototype scope.
- Added unsaved-form protection, repeat-submit guard, 320px/200% light/dark checks,
  validation, ownership/capacity and real local-app wiring regressions. 597 Flutter
  tests passed, Staging Android debug build passed, analysis no errors/warnings
  (style infos remain), lib secret-pattern scan passed.
- No Supabase/schema/hosted business-data change. User Hot Restart / emulator
  acceptance pending. This completes the support Prototype step, not every app
  feature; outstanding scope is tracked in PROTOTYPE_COMPLETION.md.

## Real booking notifications and About & Help (24 October 2026)

- Connected Owner/Provider Notifications and About routes now open from drawer
  and bell instead of unavailable messages, reusing existing screen design.
- Notifications query genuine other-participant booking status-history events,
  with own-account persisted read receipts, server All/Unread/Needs action filters,
  20-event keyset pages, pull refresh and actual booking-detail navigation. Read
  acknowledgement is server-confirmed; failures reconcile before retry, including
  a read racing background refresh. Realtime stops on hidden/background routes.
- Additive migration 022 deployed only to Staging gqtetdavmrautoojaqrk after local
  PostgreSQL 001-022 tests passed under legacy and disabled default grants.
  Private receipt table has no API table grants; authenticated RPCs enforce actor
  scope. Original project untouched; no hosted fixture bookings/notifications.
- About Help articles now open and describe implemented rules, removing fake
  payouts/fees, recurring appointments and response-time promises. Contact title
  retained; real recipient email is still required. Terms/Privacy explicitly not
  published. Device push, chat/review/payment alerts are not implemented here.
- 20 new regressions; 584 Flutter tests passed, Staging Owner/Provider three-filter
  notification reads passed, Android debug APK built; analysis no errors/warnings
  (style infos remain), lib secret-pattern scan passed. User Hot Restart / populated
  notification and cross-device receipt acceptance remain manual checks.
- Details: supabase/reviews/2026-10-24_NOTIFICATIONS_HELP.md.

## Provider Inbox pull-to-refresh (23 October 2026)

- Removed the routine Refresh inbox button. One RefreshIndicator wraps the whole
  connected Inbox, covering overview-header drags and all four job tabs, including
  short/empty and failed lists. Horizontal swipes do not trigger reads. Existing
  failure-only Retry/live-reconnect controls and original UI remain unchanged.
- Added four gesture regressions; Inbox/SWR/navigation/layout/visual subset:
  34 tests passed (`output/inbox-pull-refresh-regression.log`). No backend changes.

## Session-scoped stale-while-revalidate (23 October 2026)

- Original Owner home / Provider Inbox, Schedule, Earnings, Profile view and
  Services & availability reuse same-account memory snapshots, then refresh in
  the background. First visits still load normally. Refresh failures retain
  clearly labeled saved data with Retry; authorization/decoding failures remove it.
  Follow-up: routine background refresh is now silent (no saved-data/updating
  text or progress banner); failure/incomplete-data warnings remain. Targeted
  silent-refresh / Schedule / availability UI suite: 35 passed.
- Stored snapshots expire for reuse after five minutes; LRU is bounded to 16
  entries / 2 MiB estimated payload. Nothing is persisted to disk. Identity,
  recovery and memory-pressure boundaries clear the cache. Booking/profile/
  availability/property/review writes invalidate before and after completion,
  including uncertain failures; pre-write reads cannot repopulate the cache.
- Schedule keys include role and exact week, Earnings keys include period/MYT
  day. Partial calendar pages never look like free slots. Edit Profile still
  loads a fresh revision; cached availability is read-only pending verification.
  Original UI and bottom navigation retained; saved-status banners fit narrow
  200% text layouts through page scrolling.
- 16 added regressions; full Flutter suite 560 passed, hosted Staging Owner and
  Provider read smoke passed, Android debug build passed. Analysis: style infos,
  no errors/warnings; source secret-pattern scan passed. No SQL/deployment or
  hosted business-data writes. User emulator Hot Restart / acceptance pending.
- Details: supabase/reviews/2026-10-23_STALE_WHILE_REVALIDATE.md.

## Provider persistent bottom navigation (23 October 2026)

- My Schedule retains original Inbox / Schedule / Earnings / Profile navigation,
  with Schedule selected. Earnings and Profile views share the same bar; editor
  keeps its Save bar. Primary tab switches replace routes rather than stacking
  duplicate pages; Inbox/back returns to existing home. Original UI retained.
- Added selected semantics, repeated-tap guard, responsive large-text labels and
  five regression tests. Full Flutter suite 544 passed; Staging Android debug APK
  compiled. No backend/schema changes; emulator visual acceptance pending.
- Details: supabase/reviews/2026-10-23_PROVIDER_PERSISTENT_NAVIGATION.md.

## Original Provider Profile + real backend (23 October 2026)

- Provider Profile / Edit profile reuse original UI with own-account server
  snapshots and atomic, allowlisted saves. Name, bio, service UUIDs, area/private
  origin, cents-preserving hourly/daily rates, contact, avatar color and sharing
  preference persist; approval/statistics/email remain system-managed/read-only.
- Migration 021 deployed only to Staging after isolated PostgreSQL tests. Added
  revision/contact conflict checks and active-booking-only opted-in phone lookup;
  no directory-wide contact exposure, profile fixture writes or original-project
  mutation. Profile Save never replaces weekly availability.
- 539 Flutter tests passed; PostgreSQL 001-021/security/concurrency suites passed
  under both privilege profiles; real Provider read and Owner denial passed.
  Staging Android debug APK compiled. Original light/dark captures inspected.
- Email change and avatar photo upload are explicitly not connected; user
  emulator save/reopen acceptance remains pending. Details:
  supabase/reviews/2026-10-23_PROFILE_BACKEND_BINDING.md.

## Original Earnings + real backend (23 October 2026)

- Provider Earnings now opens the original UI with real own-Provider reporting.
  Last 30 days / This month / All time use MYT completion-history timestamps,
  server whole-range totals/trend and 20-item keyset history pages. No preview
  stores or current-rate repricing enter connected earnings.
- Migration 020 deployed only to Staging after local PostgreSQL checks. Quotes
  are labeled Completed job value, not confirmed paid net income. Fees/payouts
  remain explicitly unavailable; no assumed 15% is adopted as a real fee policy.
- 515 Flutter tests passed; full synthetic PostgreSQL 001-020 suites passed under
  both privilege profiles; hosted Provider three-range reads and Owner denial
  passed. Staging debug APK compiled; phone/emulator visual acceptance pending.
- Full original Profile remains next. See
  supabase/reviews/2026-10-23_EARNINGS_BACKEND_BINDING.md for boundaries/evidence.

## Original Schedule + real backend (23 October 2026)

- Completed the first requested follow-up (Schedule); Earnings and full Profile
  remain next. Original Owner/Provider calendar layouts are reused, with real
  participant-scoped MYT-week overlap pages, safe card reads and protected actions.
- Incomplete/error/live-failed weeks are never drawn as free calendars. Added
  precise pagination, date selection, cross-midnight/off-hour/overlap handling,
  opt-in rescheduled-into-range Realtime reads, session/route lifecycle protection
  and refresh. No schema/grant changes or hosted business writes.
- Repaired short-screen/200% text and preview-card overflows. Full Flutter suite
  498 passed; both real Staging role read/login smoke cases passed. Staging Android
  debug APK compiled. Four light/dark widget captures inspected; phone/browser
  visual acceptance remains user hands-on. Scoped 16-file secret scan passed;
  analysis has style-only infos, no errors/warnings.
- Details: supabase/reviews/2026-10-23_SCHEDULE_BACKEND_BINDING.md.

## Original UI + real backend: Owner home / Provider Inbox (23 October 2026)

- Authenticated root now uses the original OwnerHomeScreen and ProviderInboxScreen
  with a lifecycle-owned server binding, retaining original visuals/navigation and
  local preview behavior. No alternate connected home and no fixture fallback.
- Owner full totals come from the summary RPC; booking cards use bounded server
  pages. Provider approval/statistics are real; page-only counts are qualified and
  unconnected earnings are not invented. Real request/add-unit/setup/single-booking
  operations are reused; unsupported original routes remain explicitly unavailable.
- Full Flutter suite: 462 passed. Actual Staging SDK read/login smoke: 2 passed.
  Staging Android debug APK compiled. Targeted analysis has style-only infos;
  scoped 15-file secret scan has no findings. Four light/dark widget renders inspected.
- Browser use was disabled in Work settings; no browser/phone visual acceptance
  claim. Server hot restarted; browser needs refresh, Android Studio needs rerun.
- No business fixtures, Provider approval, original-project mutation or migration.
  Detailed limits/evidence: supabase/reviews/2026-10-23_ORIGINAL_UI_BACKEND_BINDING.md.

## Reusable Staging Owner/Provider accounts (23 October 2026)

- With explicit user approval, created two marked synthetic Auth identities,
  owner.a@rental-test.invalid and provider.a@rental-test.invalid, in the pinned
  Staging project only. Strong different passwords are in an ignored local file
  with Windows-user/SYSTEM-only permissions, not App source or chat output.
- Both real password logins and authenticated role/profile reads passed; a second
  execution reused both accounts without duplicates or resets. Temporary test
  sessions were signed out. Normal signup email confirmation remains enabled.
- Provider stays pending; only its synthetic self-managed profile was created.
  No properties, bookings, availability or approval was seeded. Browser login,
  approval/setup and booking E2E remain next hands-on/acceptance checkpoints.
- Passed 19 offline provisioning guard cases and scoped two-script secret scan.
  Details: supabase/reviews/2026-10-23_STAGING_REUSABLE_ACCOUNTS.md.

## Staging connection and supervisor-preparation task 1 (23 October 2026)

- Verified the current Staging marker through the actual publishable-key Data API,
  configured the photo validator's exact local origin and created an ignored,
  pinned Staging-only client configuration. No original-project access or changes.
- Live checks passed: allowed origin preflight 200 with exact headers; two other
  origins denied 403; valid upload protocol with missing/invalid user JWT denied
  401. RLS/authentication were not disabled and no wildcard origin was introduced.
- Added repeatable read-only connection checks and a fixed-port Web launcher.
  Browser inspection confirmed the real Staging login page and test-environment
  banner at http://127.0.0.1:7391/. No real account login or business write yet.
- Passed 19 offline checker regressions, 21 targeted Flutter tests and 23 Node
  photo-service tests. Scoped four-file secret scan passed; whole-tree scanning
  remains blocked by reviewed OAuth examples in the portable pgAdmin runtime,
  not recorded as a whole-repository PASS. Full Flutter suite was not rerun here.
- Details and restart commands: supabase/reviews/2026-10-23_STAGING_CONNECTION_VERIFICATION.md.
  Environment setup is complete for this local origin; signed-in E2E/cross-account
  acceptance and original-project rollout remain separate pending milestones.

## Security/privacy task 4.2: trusted evidence validation (23 October 2026)

- Added migration 018 and a server-only Deno-compatible photo endpoint. Auth verifies the bearer before claiming the assigned Provider's registered ticket. The handler bounds binary input, checks source size/hash, actually decodes JPEG/PNG pixels, re-encodes without copying source metadata, and publishes only immutable canonical bytes. Both source and canonical manifests are distinct. Flutter sends binary through the installed Functions SDK, never directly to Storage, and does not fall back to a weaker upload path.
- Removed authenticated evidence INSERT, hid unverified pending objects, required private server attestation for attachment and a new Completed transition, and retained the existing quota/CAS/lifecycle/cleanup checks. Guarded leases, three-attempt budget, expiry/cleanup margin and hash-checked lost-write reconciliation protect retries. Definitive invalid photos prompt reselection; ambiguous failures retain the existing selection. Existing unverified records are not erased or blessed; participant reads are closed by 018 and any real legacy evidence requires a supervised rollout plan.
- All 441 Flutter tests passed, including four new loopback installed-SDK cases for binary routing, definitive rejection, busy response and an actually closed HTTP socket. The existing feedback test now expects the explicit upload-and-validation progress label. Four changed Dart files passed targeted analysis. All 23 server codec/handler/transport tests passed under both Node and Deno; Deno type-check passed. The production dependency advisory check reported zero known advisories at this check, not a guarantee of safety.
- All 18 migrations and expanded SQL role/bypass/lease-expiry/attempt/legacy-completion tests passed in disposable network-disabled PostgreSQL. Real concurrent sessions observed a blocked second validator claim; after the first commit only one processing lease/attempt existed and the competitor received busy. Existing quota concurrency and lifecycle/cleanup suites still passed. SQL uses explicit trusted-worker metadata fixtures, not a false claim of real file decoding or hosted integration.
- Final release Web and Android debug APK compilation succeeded; compilation is not hosted acceptance or production signing. No hosted schema/function/Storage/Auth operation, real credential, report or PDF was changed. Current limitations and later manual staging sequence are recorded in `supabase/VERIFIED_EVIDENCE.md`. Hosted JWT/Storage behavior, two-account bypass tests, legacy backfill/access decision and Edge CPU/memory performance still block launch approval. Task 4 is locally implemented, not signed off online; task 5 retention/account deletion requires agreed rules before destructive automation.

## Earnings sheet drag-handle cleanup (28 September 2026)

- Removed the duplicate hand-drawn grab bar from the earnings details sheet.
  The Material bottom sheet now explicitly supplies the single drag handle.
- The 320px details test covers the framework handle, amounts and closing;
  full Flutter suite: 157 passed.

## Expanded earnings preview and interactive chart (28 September 2026)

- Added six more completed Provider A bookings to the no-login preview, with
  different dates and durations, including one outside the last 30 days.
  The preview now contains 15 bookings; none is written to Supabase.
- The last-seven-days chart uses all completed records regardless of the
  selected history filter. Hovering with a pointer or tapping a day displays
  the full date, completed-job count and calculated net earnings.
- Verified the tooltip with mouse-hover and touch-tap widget interactions and
  checked the expanded fixture. Full Flutter suite: 157 passed. Focused
  analysis found only pre-existing style/trailing-comma notices.

## Provider earnings drill-down (28 September 2026)

- Earnings history rows now open a persistent, dismissible bottom sheet instead
  of a temporary snackbar. It shows the existing booking/service information
  and a gross, platform-fee, calculated-net breakdown.
- The history hint now reads "Tap a job for the earnings breakdown" and each
  row has a chevron, making the new interaction visible after a browser refresh.
- The sheet explicitly distinguishes calculated earnings from payment
  confirmation; no transfer or payout status was invented.
- A 320px widget test covers opening, amounts and closing. Full Flutter suite:
  156 passed. Focused analysis found style-only trailing-comma notices.

## Provider owner-note presentation (28 September 2026)

- Replaced the Provider job detail's amber warning-style note with a calm
  sender-labelled message bubble under Cleaning instructions. The message text
  and booking behaviour are unchanged; no sender name or timestamp was invented.
- Checked the actual 390px Provider preview and added a phone-layout test.
  Full Flutter test suite: 155 passed.

## Provider Earnings narrow-screen fix (28 September 2026)

- Removed a repeated period label from the totals line and allowed the
  remaining summary text to fit within the hero card on narrow phones.
- The selected period is still shown beneath "Total earned" and updates when
  the filter changes.
- Verified the live 390px preview and a 320px widget test covering period
  changes. Full Flutter test suite: 154 passed.

## Expanded local mock data (28 September 2026)

- The no-login Owner/Provider preview now uses nine date-relative sample bookings
  across Pending, Accepted, In Progress, Completed, Declined and Cancelled.
  These link to the existing five sample rental units and three providers.
- The Provider Inbox now shows and counts only bookings assigned to that
  provider; its weekly earnings summary is calculated from completed preview
  bookings rather than a fixed number.
- This preview-only data resets on refresh and is not written to Supabase.
  It must not be presented as real user activity or completion evidence.
- Full Flutter test suite: 153 passed. The visible Provider A preview was
  checked: New (1), Active (2), Done (1), and RM 136 this week.

## Local no-login design preview (28 September 2026)

- In a debug build without Supabase settings, `?preview=owner` and
  `?preview=provider` open the corresponding sample-data workspace directly.
  Connected Supabase builds and release builds never use this bypass.
- `web/design-preview.html` shows both modules in interactive phone frames.
  The preview does not create an Admin role, account, or real server records.
- A narrow-layout Provider Inbox statistic-card overflow was corrected.
- To reproduce: run `flutter run -d web-server --web-hostname=127.0.0.1
  --web-port=7371 --no-pub` without backend defines, then open
  `http://127.0.0.1:7371/design-preview.html`.
- The 150-test suite passes. The established demo pages remain separate from
  the connected workspace; wiring them to live repositories is still pending.

## Verified visual continuation: shared workspace styling (27 September 2026)

- Extended the approved EasyRenz-inspired visual direction beyond the dashboard. The app now uses a consistent navy/sky-blue brand palette, pale canvas, white outlined cards, Inter typography and shared button/navigation styling. EasyRenz branding/assets were not copied.
- Replaced the former Figma-export-based login presentation with an original role-selecting owner/provider screen. It remains a local demo and makes no authentication claim.
- Unified the Owner bottom navigation across Home, Properties, Providers and Bookings; Schedule and Spending remain accessible from the menu. Existing destinations and workflows are unchanged.
- The provider's Schedule tab previously appeared selected without navigating. It now opens the existing My schedule page and resets to Inbox on return.
- Kept success/warning/error status colors semantic rather than recoloring business states. Improved status-chip contrast on the booking-detail navy hero and stat contrast in Booking History.
- Browser inspection on a 390 x 844 viewport covered login, onboarding, owner dashboard, properties, provider browse, booking history, booking detail, cleaning-request form, provider inbox and provider schedule. A focused login-role widget test was added.
- Dark-mode inspection revealed low-contrast booking-list details and property stat labels; these now resolve colors against the active theme. The dashboard and owner navigation also follow dark mode instead of staying light.
- Full test suite: 129 passed. Release web build passed. Focused static analysis has informational style lints but no errors/warnings in the checked changed files.
- Final local preview: `http://127.0.0.1:7363/mobile-preview.html?v=unified-ui-final` while its local server is running.
- Remaining: detailed screens retain their established layouts; native-platform visual checks and real-backend integration have not been completed.

## Verified visual pilot: owner dashboard (27 September 2026)

- Inspected EasyRenz's public homepage and features page for visual reference: navy hierarchy, pale-blue accents, white cards and clear dashboard groupings. No EasyRenz branding, images or out-of-scope rental/tenant functions were copied.
- Replaced only the Owner Dashboard presentation with an original cleaning-focused workspace: greeting, request CTA, live booking counts, next open booking and working quick actions.
- Dashboard statistics still derive from BookingStore, while the rental-unit count derives from PropertyStore and updates when a unit is added. Navigation and booking actions retain their existing flows.
- Visual inspection at a 390 x 844 mobile viewport showed no card, text or bottom-navigation overflow. Properties shortcut opened the existing property screen.
- `flutter test`: 128 passed. Web release build passed. Focused analysis showed informational style lints, no errors or warnings.
- Preview: `http://127.0.0.1:7358/mobile-preview.html?v=owner-pilot-1` while its local server is running.
- This is an incremental style pilot. Login, provider pages and remaining owner screens retain their previous visual style; report screenshots should only be refreshed after a final design direction is chosen.

## Verified milestone: local status history and Supabase core design (27 September 2026)

- Compared report FR1.8, FR2.4–FR2.5, NFR4.2 and Algorithm 4.3 with the existing local lifecycle.
- New local bookings record an initial Pending event; successful state transitions record one event with actor/time/reason, while rejected transitions produce no history. Existing seeded bookings do not receive invented earlier events.
- Owner booking detail now displays the actual transition history. A narrow-phone widget test exposed a pre-existing hero overflow; the header spacing was corrected.
- The first Supabase migration drafts account/property/provider/booking/history tables, participant RLS, six-status enum, Pending-nonblocking overlap constraint, coordinated availability/window writes, and a protected acceptance RPC. PostgreSQL syntax parsing succeeded, but this migration has not been executed against a real database.
- `flutter test`: 128 tests passed, including three new status-history tests. `flutter build web --release`: passed. Focused static analysis reported style/info lints but no errors or warnings in the changed files.
- Browser smoke check: Owner demo → Booking History → Pending sample → Status history renders the honest missing-history message on a phone-sized view. The current preview is at `http://127.0.0.1:7358/mobile-preview.html?v=status-history-2` while its local server is running.
- The backend still needs a disposable-project RLS/concurrency test and connection to Flutter before any production claim.

## Verified milestone: Owner Property management and Pending revisions (27 September 2026)

- Compared implementation with the report's Owner requirements FR1.12–FR1.13 and the Property cleaning-window/booking rules before editing.
- Owner can add and edit local rental units with unit, building, address, bedrooms, size and permissible cleaning window. A booked unit cannot be renamed while bookings are linked by its display name in this demo.
- The new unit appears in the cleaning-request Property picker; the property portfolio and booking counts refresh in the same session.
- Pending request revisions recheck future time, current property window, current provider availability and overlap with Accepted/In Progress bookings. A failed revision leaves the booking unchanged; Pending remains nonblocking.
- Five focused Property/revision tests passed, including a narrow-phone add-property-to-booking-picker flow. Full suite: 125 tests passed. Web release build passed.
- Browser smoke check: Owner demo → My properties → Add property → saved unit appears; the phone layout and form were visually inspected at `http://127.0.0.1:7357/mobile-preview.html`.
- This is a local demo milestone, not secure multi-user completion: data reset on refresh, seeded units have no real address, and server-side validation/transaction safety remain outstanding.

## Verified milestone: editable provider availability (27 September 2026)

- Provider can edit multiple non-overlapping weekly working slots and mark/unmark unavailable dates from My schedule.
- Provider matching rejects intervals outside the edited slots or on an unavailable date. Dynamic alternative windows use those slots and still rerun all mandatory eligibility checks.
- Local provider acceptance rechecks current declared availability, rental-unit window and Accepted/In Progress overlap. A failed check leaves the request Pending.
- Changing default hours in the provider profile now updates each active weekday, with the effect explained on that screen.
- Report coverage, including incomplete requirements and nonfunctional evidence gaps, is tracked in `REPORT_REQUIREMENTS_TRACKER.md`.
- `flutter test`: 120 tests passed; `flutter build web --release`: passed.
- Browser smoke check: Provider demo → My schedule → My availability displays seven editable weekdays and unavailable dates. The preview is available at `http://127.0.0.1:7357/mobile-preview.html` while the local server is running.
- This milestone is local only. Availability resets after restart and acceptance is not yet a protected server transaction.

## Verified milestone: owner request flow (27 September 2026)

Implemented locally:
- Request form collects property, service, duration, future date/time and instructions.
- Eligibility filters precede equal-weight distance/rating/workload ranking.
- Unavailable intervals produce same-day feasible alternatives from the demo availability window; duration is preserved, alternatives are deduplicated and ordered by proximity (earlier first on ties).
- Selecting an alternative rechecks eligibility before showing provider rankings.
- The owner selects a provider, reviews the request and submits exactly one assigned Pending booking. Back/revise does not create a booking.
- Eligibility and future-time checks run again before local submission.
- Pending does not block capacity. Only Accepted and In Progress do.
- Existing six-state lifecycle and completion-evidence validation remain in place.

Verification:
- `flutter test`: 113 tests passed, including seven request-flow tests.
- `flutter build web --release`: passed.
- Browser smoke test: guest owner -> request -> eligible providers -> Provider A -> review -> Pending booking details, with the selected time and instructions displayed correctly.
- Mobile-size browser preview inspected. Static analysis still has informational lint findings; the repository is not lint-clean.

Preview: run a local static server for `build/web` and open `/mobile-preview.html` (currently served at http://127.0.0.1:7357/mobile-preview.html).

## Verified milestone: provider palette refinement (27 September 2026)

- Inbox, provider profile, and job detail now share the navy/sky-blue primary palette. Inbox hero stats have a consistent translucent treatment; Accept uses the same navy primary action as other screens, while Decline uses a restrained red accent.
- Online indicators use a quiet translucent pill and small mint dot. Job-detail headers use navy with high-contrast white title and state label; booking-state meaning and actions are unchanged.
- Browser visual check caught and corrected a low-contrast title/status label on the dark job-detail hero.
- `flutter test --no-pub`: 129 tests passed after the title-contrast adjustment. Release web preview rebuilt and Inbox/job-detail screens visually checked.
- Preview: `http://127.0.0.1:7364/mobile-preview.html?v=inbox-colors-1` while its local server is running.

## Verified milestone: Provider Inbox layout refinement (27 September 2026)

- The Inbox now matches the Owner workspace hierarchy: navy welcome card, separate white overview cards, search, section heading, and readable request cards.
- A request card gives the property name its own line and keeps the service type, status, appointment time, instructions, and Accept/Decline actions clear.
- The header and request list scroll together on shorter phones. At widths below 350px, the overview cards use two rows instead of squeezing their text.
- Added a 320x640 layout test after it detected a small stat-card overflow; the overflow is fixed. All 130 tests pass and the release Web build succeeds. Existing analyzer findings are informational style/context lints.
- Final phone preview: `http://127.0.0.1:7364/mobile-preview.html?v=inbox-layout-final` while the local server is running.

## Verified milestone: Owner property statistics (27 September 2026)

- My properties now shows a cleaning-booking statistics table between the portfolio summary and unit cards, grouped by building with an All properties total.
- The table and unit cards use the same booking-status counts. Open means Pending, Accepted or In Progress; Done means Completed; Total includes all booking statuses. The former per-card label Upcoming was changed to Open because its count is status-based, not date-based.
- Counts refresh from the current local booking store. A 320x640 test verifies the building and overall rows, updates after a new Pending booking, and no layout overflow.
- All 131 tests passed; the focused analyzer completed with informational trailing-comma lints only; the release Web build passed. The final phone preview was visually checked.
- Preview: `http://127.0.0.1:7365/owner-stats-preview.html?v=owner-stats-1` while the local server is running. As elsewhere in this demo, the statistics reset on refresh and are not yet backed by production data.

## Verified milestone: owner provider directory usability (27 September 2026)

- Replaced the fixed July example-match presentation in the general Browse providers tab with a clear provider directory. It shows service types, rating and hourly rate without implying that a provider is available for an owner-selected request.
- All service filters are visible as wrapping chips; rating, hourly-rate and name sorting are available. Provider cards use the established navy/blue palette and one clear profile action.
- Added a Find available providers action leading into the existing real request flow, where mandatory eligibility and equal-weight ranking still run on the chosen property and interval. No matching rule or booking lifecycle was changed.
- Added a 320x640 widget test for the directory, filter and action; all 132 tests pass. The web release build passed and the phone preview was visually checked, including navigation into the request form.
- Preview: `http://127.0.0.1:7365/provider-directory-preview.html?v=directory-1` while the local server is running. Provider profiles and rates remain demo data.

## Verified milestone: owner workspace palette consistency (27 September 2026)

- Properties, Providers and Bookings now use aligned 16dp page margins, navy text and actions, pale-blue informational surfaces and consistent white cards in light mode.
- Property Open/Done/Total summaries no longer use unrelated orange/green/blue fills; those colors are reserved for actual booking-state feedback. The provider intro uses the same pale-blue surface; active booking filters use the same accent.
- Dark-mode visual QA caught low-contrast headings/icons and primary buttons. The headings and icons now use the theme-aware light-blue foreground, and dark-mode primary, outlined and text buttons use high-contrast brand tokens. A contrast regression test was added.
- All 133 tests pass; web release build and light/dark browser previews pass. Status-chip meanings and booking/provider workflows are unchanged.
- Preview: `http://127.0.0.1:7365/owner-palette-preview.html?v=palette-1` while the local server is running.

## Verified milestone: owner page information hierarchy (27 September 2026)

- Booking History's four summary numbers are now a readable two-by-two grid rather than four narrow cells; the pending note wraps on small phones.
- Booking cards give the property name its own two-line space, then display status and recurring/multiday badges separately. Service type, time and provider stay visible below.
- Property Open/Done/Total tiles use distinct icons and a subtle outlined Total tile without introducing unrelated colors. Statistics table labels and explanatory note are larger.
- Provider card services are static labelled text rather than chip-like controls, making them visually distinct from the interactive service filters. The Bookings Browse link and provider service text were strengthened for readability.
- Matching, booking-status logic and displayed data are unchanged. A narrow-phone booking-card test was added; all 134 tests, web build and light/dark visual checks passed.
- Preview: `http://127.0.0.1:7365/owner-clarity-preview.html?v=clarity-1` while the local server is running.

## Limitations (not production-ready)

- Data and new bookings are in memory; refreshing resets the demo.
- Provider availability and unavailable dates can be edited locally but are not persisted or shared between users.
- Seeded rental cleaning windows are sample 08:00-18:00 values; newly added units can use another window. Alternatives currently cover the selected day only.
- Distances are demo values, not live route-distance results.
- Local acceptance checks are not a multi-user, transaction-safe backend reservation mechanism.
- Authentication, secure persistence/participant access, real notifications, messaging, evidence upload, payment integration and ratings still require implementation or verification. Existing screens may contain placeholders.
- General provider browsing still uses a fixed demo matching context; the new request-specific results screen uses the owner's entered interval.

## Next work

1. Add Supabase persistence, authenticated role ownership and access policies; implement transaction-safe provider acceptance with conflict rechecking and status history. Do not deploy or request secrets until the user's project configuration is available.
2. Connect live route distance, booking communication/notifications and completion evidence; then finish scoped payments/ratings and integration tests.

Continue in small verified milestones and show a preview after each completed part. Do not extend into other group members' modules.

## Verified locally: release baseline and connected property entry (17 October 2026)

- Android main manifest now declares Internet access; iOS declares camera and photo-library usage for completion evidence and profile photos.
- The transitive `app_links` package is pinned to 6.4.0 so this project's current Flutter toolchain can build an Android release APK. The APK builds successfully, but remains debug-signed until a private upload keystore is configured.
- A release build without Supabase settings no longer presents the local demo as if it were live. Creating a Play Store bundle is intentionally blocked when `android/key.properties` is absent.
- The connected Owner workspace now offers an Add unit form that saves through `SupabaseOwnerRepository.addProperty`, validates required/positive fields and the permissible cleaning window, and refreshes the property summary after a successful save.
- A phone-size visual preview is saved in `test/goldens/connected_property_form.png`. The shared AppBar and button typography now explicitly use Inter.
- `flutter test --no-pub`: 180 tests passed; `flutter build apk --release --no-pub` succeeded. The connected property save has not been end-to-end tested against Supabase because the configured project host was unreachable from this machine during this run.
- Still not launch-ready: Android app identity and target API, private signing key, live backend deployment/integration, real booking creation/matching, provider workflows, communication, evidence, payments, notifications, account deletion, store privacy disclosures, and on-device/iOS testing remain.

## Verified locally: connected provider setup (17 October 2026)

- The authenticated Provider workspace now opens a services-and-availability screen backed by that provider's own Supabase records. The provider can select cleaning service types, maintain weekly slots, and mark unavailable dates; the screen does not use local mock records.
- New or edited weekly slots must span at least two hours and may touch, but not overlap, another slot on the same day. Existing legacy slots shorter than two hours are shown for review and excluded from acceptance checks until corrected.
- Migration `202610170004_provider_setup.sql` seeds the five service names used by the app, adds the two-hour and overlap guards, saves service capabilities atomically, and requires provider approval before a Pending booking can be accepted. Existing Accepted/In Progress bookings remain protected when capabilities or availability change.
- The connected screen's layout snapshot is `test/goldens/connected_provider_setup.png`; the test now loads the Material icon font for a faithful layout preview.
- `flutter test --no-pub` passed 186 tests after the change. Targeted Dart analysis returned only info-level style findings. The migration has been reviewed against the repository schema but has **not** been applied or integration-tested against the live Supabase project because its host did not resolve from this machine. No production-readiness claim follows from these local tests.
- Next: deploy and validate migrations in a backed-up staging project, provide an authorised provider-approval workflow, then complete Owner booking creation and request-specific server-side eligibility/matching. Keep the existing local preview isolated from connected production flows.

## Verified locally: provider data visibility boundary (22 October 2026)

- Added `202610220005_provider_data_visibility.sql` to restrict direct reads of provider profiles, capabilities, weekly slots, and unavailable dates to the provider who owns those rows. Existing Owner/Provider booking participant policies are unchanged.
- Added `list_approved_provider_directory()` for authenticated users. It returns only approved providers and a whitelist of display fields; the private `service_origin_address` is not returned.
- The connected Owner repository now maps that RPC response into `ApprovedProviderDirectoryItem`, which has no private-origin field. This is a data-access foundation, not yet a connected Owner directory screen.
- Added a static regression test for the migration's safe select list and an owner-facing model test. The full Flutter suite passed 188 tests. These tests do not execute PostgreSQL RLS policies.
- The Supabase project host still did not resolve from this machine, so migration 005 was not applied and cross-account database tests were not performed. Before public use, apply migrations in a backed-up staging environment and verify Owner, Provider, other Provider, and unauthenticated access explicitly.

## Verified locally: secure Pending request creation (22 October 2026)

- Added `202610220006_secure_booking_creation.sql`: removes direct authenticated Booking INSERT permission and adds a restricted Owner-only RPC. The RPC checks the Owner's property, approved Provider, service capability, entire local-Malaysia interval, rental cleaning window and Accepted/In Progress conflicts before creating a Pending request.
- The request carries an Owner-scoped UUID idempotency key. Retries with the same key and details return the existing Booking; reuse with changed details fails. The key is protected from ordinary direct updates. The initial Pending history row still comes from the existing insert trigger in the same transaction.
- Updated the connected booking repository to use the RPC and return a typed creation result. The UI that will generate and retain one token per request form is not yet connected; this milestone is backend and repository groundwork, not a finished Owner booking screen.
- `flutter test --no-pub` passed 191 tests. Targeted Dart analysis reported info-level style lints only. The SQL and RLS still need real PostgreSQL tests with multiple identities; the Supabase project host did not resolve from this machine during this run, so migration 006 was not applied.
- Next: define quote snapshots and an authorised Provider approval path, then connect the Owner request and matching interface to the secure functions. Preserve the report's rule that Pending does not block time and acceptance rechecks atomically.

## Verified locally: property-window lock visibility (22 October 2026)

- After migration 005, an Owner cannot read another user's raw ProviderProfile row. The original property-window update trigger ran with the Owner's RLS context and could therefore miss the Provider row lock that serialises window changes with acceptance.
- Added migration `202610220007_property_window_lock_visibility.sql` to run that trigger with definer privileges while preserving Owner-only Property UPDATE RLS, stable Provider lock ordering, and the confirmed-booking window check. Direct function invocation remains revoked from app roles.
- A static regression test checks the function security context, lock, and confirmed-state filter. The full Flutter suite passed 192 tests. This is **not** a PostgreSQL concurrency test. The migration still requires staged deployment and a real two-session race test before live use.
- Quote calculation remains pending: the report permits hourly or daily rates but does not define how a short appointment should be charged under a daily rate. No monetary rule or Stripe amount is inferred from the report.

## Verified locally: connected Owner eligibility search (22 October 2026)

- Added `202610220008_eligible_provider_search.sql`. An Owner can query only their own rental unit; the result includes approved Providers who offer the selected service, cover the full requested interval, have no unavailable-date exception, and have no Accepted/In Progress overlap. Pending does not occupy capacity. The RPC returns only display-safe Provider fields.
- Connected an Owner search form to that RPC, with Malaysia-time conversion independent of device timezone. It shows rates and clearly labels results as eligible, not ranked. The current report's route-distance/rating/workload scoring is **not** connected.
- The form deliberately cannot submit a Booking yet because the report does not define the final amount for a short appointment with a daily-rate Provider. This prevents an unpriced request from being treated as a launch-ready customer flow. The secure creation RPC from migration 006 remains available for the next step once the pricing rule is settled.
- Visual preview: `test/goldens/connected_booking_search.png`. Widget, model, timezone and static migration checks were added. The full Flutter suite passed 197 tests; targeted analysis found info-level style lints only. Database/RLS integration remains unverified because the migration has not been applied to staging.

## Verified locally: MYR quote snapshot and priced Pending submission (22 October 2026)

- The selected pricing policy is now encoded in migration `202610220009_booking_quote_snapshot.sql`: under 8 hours uses the positive hourly rate, exactly 8 hours uses the daily rate when available (otherwise 8 hourly hours), and over 8 hours is rejected. The backend calculates to the nearest sen and stores currency, basis, rate, duration and total on the Booking. Search returns a server-calculated quote, while creation rechecks the current rate under a Provider lock and rejects `price_changed` rather than silently repricing. Provider rate edits do not change existing quotes.
- Legacy unpriced Pending requests cannot be newly Accepted. Pending revisions may change date/time while preserving duration and price; a duration change requires a new quoted request. Existing historical unpriced rows are not backfilled or treated as payment-ready.
- The connected Owner screen now lets the user select a time-eligible Provider, review the exact amount and instructions, and submit a priced Pending request. It retains the same idempotency token after a connection failure; business-rule rejections require a fresh search. The connected workspace shows the snapshot to both booking participants.
- Provider registration now accepts an hourly rate, an 8-hour daily rate, or both. A daily-only Provider is eligible only for an 8-hour request. The two-hour minimum **working slot** remains separate from any minimum **booking duration**, which has not been specified.
- Visual preview: `test/goldens/connected_booking_review.png`. Widget tests exercise Owner selection, quote display, submission parameters and safe retry. The full Flutter suite passed 202 tests and a release Web build completed. Targeted analysis showed info-level style lints only. SQL pricing checks are static only. Migrations 001–009 have **not** been deployed or verified against PostgreSQL; Stripe/payment processing, weighted matching, Provider approval, notifications and production hardening remain incomplete.

## Verified locally: connected completion evidence (22 October 2026)

- An authenticated Provider can now open an In Progress booking, choose camera/gallery images, upload one before and one after photo to the private `cleaning-evidence` bucket, enter completion remarks, and request the `Completed` transition. The backend RPC remains the authority for role, current state, uploaded-object presence and status-history consistency.
- Once Completed, either booking participant can open the evidence screen read-only; Owner access is provided directly from the connected booking card. Images are downloaded from private storage through participant policies rather than public URLs. The local preview's temporary image paths are not mixed into the connected flow.
- The screen checks both photos and nonempty remarks before submitting, handles failed uploads/transitions without declaring completion, and keeps payment separate. Widget tests cover required fields, successful Provider flow, and Owner read-only view. The 390px visual snapshot is `test/goldens/connected_booking_evidence.png`; the full Flutter suite passed 206 tests.
- This is a UI/repository milestone, **not** a live-cloud verification. Migrations 001–009, including evidence RLS and Storage policies, remain undeployed/unverified against PostgreSQL. A staging two-role test must validate uploads, private reads, concurrent status changes and the completion RPC before public use. Payment, communication, notifications, ratings and ranked matching are still open.

## Verified locally: booking-linked Owner–Provider messages (22 October 2026)

- Added migration `202610220010_booking_messages.sql`: participant-only message reads, no direct client writes, an authenticated server send RPC limited to Accepted/In Progress, per-sender idempotency tokens, and Realtime publication membership. Completed conversations remain read-only.
- The connected Owner and Provider booking cards now open one shared booking-specific chat. It displays only that booking's server messages, updates through Realtime, and keeps a failed-send draft and token for a safe retry. The client watches booking status so a completed conversation hides the composer; cancelled conversations also remain viewable. Message timestamps display in Malaysia time (MYT).
- The visual preview is `test/goldens/connected_booking_messages.png`. Local tests cover failed-send retry, live transition to completed read-only access, model/token handling and migration-policy text. The full Flutter suite passed 212 tests and a release Web build completed. This does **not** execute PostgreSQL or prove cross-account privacy.
- Migrations 001–010 remain undeployed/unverified against a real Supabase staging project. Before launch, test Owner/Provider/third-party access, direct INSERT denial, Realtime delivery, retry de-duplication and send-versus-completion concurrency. Background push notifications, payments, ratings and ranked matching remain incomplete.

## Verified in disposable local PostgreSQL (22 October 2026)

- Docker's isolated PostgreSQL 16 container executed all ten migrations in order with errors treated as failures. The runner is `tool/verify_local_migrations.ps1`; it creates a random-name, network-isolated container and removes it after the checks. It never connects to or changes the Supabase project.
- `supabase/tests/booking_messages_rls.sql` exercised two booking participants and an unrelated account: participant reads/sends, direct INSERT denial, outsider read/send denial, Completed read-only behaviour, retry de-duplication and changed-content token rejection.
- `supabase/tests/booking_lifecycle_evidence_rls.sql` exercised non-blocking overlapping Pending requests, one successful acceptance, conflict rejection of the other, In Progress transition, missing-evidence completion rejection, authorised evidence-object/row creation, successful completion with status history, Owner evidence read and outsider read denial.
- These checks establish executable SQL and representative RLS behaviour under a minimal local Supabase shim. They do **not** test hosted Supabase Auth/Storage/Realtime, image bytes, mobile devices, or two-session concurrency races. The real project hostname still did not resolve from this machine, so no migration was applied to the live project and no production-readiness claim is made.

## Verified locally: connected booking reviews (22 October 2026)

- Added migration `202610220011_booking_reviews.sql`: only the booking Owner can create or update one 1–5-star review with an optional 300-character comment after completion. Provider and Owner may read their shared booking's review; unrelated accounts cannot. Direct client writes are denied. The Provider's average is recomputed transactionally after each save.
- Connected Completed booking cards now open an Owner rating form or a Provider read-only review. This is backed by a repository and a protected RPC, not by preview fixtures.
- The isolated PostgreSQL runner passed all 11 migrations and cross-account review checks, including Pending/Provider/outsider write denial and direct INSERT denial. The complete Flutter suite passed 215 tests. Preview: `test/goldens/connected_owner_rating.png`.
- No migration was deployed to the hosted project. Supabase Dashboard currently requires the user to sign in, and its project hostname did not resolve from this machine. The user asked to skip manual Supabase steps for now; remind them to confirm project status before hosted integration. Until then, the connected rating flow is locally verified but not usable against the hosted database.

## UI/UX task 1: authenticated workspace design alignment (22 October 2026)

- The real connected Owner and Provider home routes now use shared navy/sky visual components instead of the technical "workspace/database" hero. Owner summary tiles, rental-unit cards and booking cards use the same spacing, surfaces and hierarchy. Booking cards show a readable MYT interval, service, rental-unit name/address, quote, current state and the next action.
- Migration `202610220012_booking_contexts.sql` supplies unit, address, service and instructions only for bookings in which the authenticated user is Owner or Provider. The Flutter booking stream enriches cards through one participant-scoped RPC per stream update; raw Property SELECT is not opened to Providers. Local PostgreSQL tests cover Owner/Provider visibility and unrelated-account denial.
- User-facing development wording in connected request, property, evidence and setup screens was replaced. Golden previews: `test/goldens/connected_owner_home.png` and `test/goldens/connected_provider_home.png`. A 320px Provider-card test checks context, MYT display and the Accept action.
- This completes task 1 in `UI_UX_TASKS.md` at the local code/test level, **not** online deployment or full app UX readiness. Tasks 2–7 remain. Migration 012 and earlier migrations are not installed on the hosted Supabase project.
- Final check: 12 migrations and participant-context privacy checks passed in disposable PostgreSQL, all 219 Flutter tests passed, and the release Web build completed. The screenshots use test records with the exact presentation components used by the connected route; they are not a live Supabase session.

## UI/UX task 2: connected data states (22 October 2026)

- Added a shared loading/empty/error card with a contextual next action. The real authenticated Owner/Provider home, request and provider search, service/availability setup, booking history, booking messages/status, completion evidence, and reviews now distinguish those states from loaded data. Retry creates a fresh Future or stream; a failed message reload preserves the unsent draft.
- Booking history opens immediately and loads inside its sheet; a failed read no longer exposes an exception string in a transient snackbar. Evidence editing is hidden until the initial private-record read succeeds, so a failed read cannot masquerade as an empty record.
- Added seven widget tests for failed reads/streams, retry, empty outcomes and draft preservation. Previews: `test/goldens/connected_empty_state.png` and `test/goldens/connected_error_state.png`. After the final history/search polish, all 228 Flutter tests and the release Web build passed. Targeted analysis found no errors or warnings, but the repository's existing info-level style lints remain.
- This is a local UI state milestone, not a claim that the hosted Supabase project works. Task 3 will address recoverable write errors and uncertain network outcomes. Hosted migration/deployment and real-account tests remain pending at the user's request.

## UI/UX task 3: recoverable write failures (22 October 2026)

- Owner request creation now checks the Owner-scoped booking record by its stable client request token after an uncertain response, before offering another submission. Provider acceptance and booking transitions re-read the current status. Booking rejection codes become plain-language actions rather than raw server reasons.
- Booking chat checks its stable message ID after a lost send response and refreshes the conversation if the message exists. Review saves re-read rating/comment, evidence uploads re-read the stored before/after path, and completion re-reads booking status. An already-applied change is reported as success instead of inviting a duplicate retry.
- Property creation lacks a server-side idempotency key, so an uncertain result disables another Save on that form and directs the Owner to refresh My properties first. Availability edits likewise pause until the Provider refreshes server data; unsaved service choices remain selected for comparison. Evidence refresh retains typed completion remarks. Technical exception text is kept out of these user-facing messages.
- Added simulated lost-response, readback, draft-preservation and safe-error-mapping tests. Phone preview: `test/goldens/connected_uncertain_property_save.png`. All 239 Flutter tests and the release Web build passed; targeted analysis found no errors or warnings but existing info-level style lints remain. No hosted Supabase deployment or real-network simulation was performed.

## UI/UX task 4: accessibility baseline (22 October 2026)

- Darkened light-theme hint/tertiary text; contrast tests now check primary, secondary and tertiary text against both normal light/dark surfaces at 4.5:1 or higher. Connected booking status and approved-provider text use brighter semantic colors in dark mode. The connected booking-card widget passes Flutter's tap-target and text-contrast guidelines in both themes.
- Standard filled, outlined and text buttons request at least 48dp minimum size. Booking History and Messages actions now announce their rental-unit context; summary tiles, request date/time choices and individual chat messages have more informative semantics. Evidence upload controls visibly distinguish before from after photos, and chat input has a persistent label.
- Inspected the four affected golden previews and refreshed their baselines. All 242 Flutter tests passed, release Web build completed, and targeted analysis had no errors/warnings (pre-existing info-level trailing-comma lints remain). This is a local baseline, not a complete accessibility certification: TalkBack/VoiceOver on real Android/iOS devices, large text, keyboard traversal and all remaining screens still need review. Hosted Supabase migration and two-account tests also remain pending.

## UI/UX task 5: small screens, large text and keyboard layout (22 October 2026)

- Added ten responsive regression scenarios in `test/connected_responsive_test.dart`, using real connected-route widgets with injected test records/callbacks. Cases cover 320×568, 320×640 and 390×844 portrait viewports, 150%/200% text, long unit/service/address/message values, and simulated 280/320dp keyboard insets. The Owner request, property form, booking card, Provider slot dialog, chat, history failure, evidence and review flows are included. Login actions are also checked for growth at 200% text.
- Fixed a reproduced horizontal overflow in rental-unit/service dropdowns with bounded labels and full-label tooltips. Shared loading/empty/error panels now scroll when height is constrained; the working-slot dialog is scrollable. Chat uses a compact composer when space is limited, hides its informational banner while composing in a short viewport, and bounds long send-error messages to a scrollable region.
- The property form's bottom Save action now moves above the keyboard; the test verifies its vertical position rather than merely checking that it exists. Login role tiles can stack and buttons grow with their labels. Shared form helper/error text wraps, the Owner properties section header can wrap, and booking title/status stack at larger text sizes.
- Inspected the new 150% Provider booking preview: `test/goldens/connected_provider_large_text.png`. All 253 Flutter tests passed, the release Web build completed, and targeted analysis returned no errors/warnings; info-level trailing-comma style findings remain. These simulations do not exercise a native keyboard, real notches/safe areas or device-specific text scaling. Hands-on device checks remain required. No hosted Supabase deployment was performed.

## UI/UX task 6: persistent action feedback (22 October 2026)

- Added `ConnectedActionFeedbackFrame` for visible working/success/error notices above the scrollable content. The frame keeps its content element stable as notices appear/disappear, preserving form state; the notice can scroll when keyboard space or large text limits its height. Success can be dismissed explicitly and is not timed away. No percentage progress is claimed for operations that do not supply byte/progress totals.
- Connected booking acceptance/start/decline/cancellation now show their specific operation and acknowledged result; uncertain writes display the verification phase, then the verified result or a refresh instruction. Workspace summaries are reloaded after booking writes. Returning from successful request/property creation or completion leaves persistent acknowledgement on Home. Refresh and sign-out are disabled during a booking write.
- Provider service/availability saves show progress and success; existing verification gates continue to require a fresh read after uncertain results. Photo picking/upload and completion expose their current step and lock competing writes. Review saves keep a visible disabled save control, lock editing while saving and display a persistent result. Editing a saved review or service selection clears stale success feedback.
- Fixed `RatingInput.didUpdateWidget` so a parent rebuild does not restore an existing review's old rating/comment over an edited draft. Four new tests cover delayed review/availability/photo writes, disabled repeat submission, failure/retry with retained review edits, notices remaining after 20 simulated seconds, and a recovery action above a keyboard at 200% text. The request submission test also observes the pending write before releasing its response.
- Inspected `test/goldens/connected_review_saved_feedback.png`; all 258 Flutter tests passed and the release Web build completed. Targeted analysis had no errors/warnings; informational style findings remain. Task 7 requires observed use by real first-time Owner/Provider users and has not been performed. Hosted Supabase deployment and real-device validation remain outstanding.

## UI/UX task 7: observation kit ready; real sessions pending (22 October 2026)

- Rechecked the supplied report's functional scope and NFR3.2 on PDF pages 93-98. Added a separate facilitator recorder under `tool/usability/`, with six Owner tasks, six Provider tasks, prerequisites/expected results, anonymous codes, wall-clock timing without silent pauses, guidance counts, task-ease notes, evidence references and CSV/JSON exports. The rental app's business UI was not changed in this step.
- `tool/usability/README.md` provides the paired Owner/Provider sequence, fixture setup, neutral facilitation script, issue log, interpretation rules and retest process. It identifies the hosted setup and incomplete connected ranking/alternatives/payment/notification/schedule/profile work that prevent a full evaluation. It also documents that the first-booking timer starts on authenticated Home with the test unit prepared beforehand, an evaluation condition that must be disclosed.
- The NFR3.2 calculation distinguishes observed sessions from facilitator dry runs, rejects local/unverified/repeated first-attempt claims, fails guided or over-300-second eligible attempts and marks missing server confirmation UNVERIFIED. No actual participant result is prefilled. Five Node tests exercise timing boundaries, exclusions, record consistency and CSV safety.
- Browser rehearsal on the separate `localhost` origin verified start/stop, identity locking, saved-record restoration and CSV/JSON downloads. Its one technical record is explicitly FACILITATOR_DRY_RUN / NOT_EVALUATED; exports were moved into `tmp/usability-qa/`. The delivered `127.0.0.1` recorder has zero saved attempts. Browser-observed layout was 631 CSS pixels wide; a requested 390px override did not take effect and is not claimed as verified. Existing Flutter responsive evidence is unchanged.
- User-facing preview: `output/usability/recorder-preview.jpg`. Task 7 is not complete: actual people have not been observed and no usability findings or human-task success rates are claimed. All changes in this step are evaluation tooling/documentation; the app's previous 258-test/Web-build result is not relabelled as a new run.

## Backend protection 1: explicit environment guard (22 October 2026)

- Added explicit local/staging/production build configuration, exact hosted Project ID/URL matching, development-to-production denial and intentional release-only production opt-in. Missing/partial/invalid configuration fails closed. Existing client secret/service-role rejection remains in place.
- Migration 013 creates an administrator-owned deployment marker, initially `unassigned`. An anonymous, non-persistent probe verifies both environment and Project ID before persistent Supabase Auth is initialized. App users can read only the non-secret marker through its RPC; they cannot update the marker table. Mismatches, absent migration, unassigned settings and network/timeout failures never open a sample-data fallback. Startup has progress and a safe connection retry.
- A persistent, theme-aware header outside the Navigator distinguishes local unsaved preview from staging records that really are saved. It remains visible on pushed routes/dialogs; production has no test badge. The 320px/200%-text case is covered. Preview `test/goldens/staging_environment_login.png` uses the real login/root widgets with an injected non-live backend, not an authenticated hosted session.
- All 271 Flutter tests passed. The isolated PostgreSQL runner passed 13 migrations, existing booking/message/evidence/review/context checks, and new anonymous/authenticated deployment-marker access checks. No hosted project, configuration file containing actual keys, data or migration was changed. Examples and ignored per-environment config filenames are supplied; `supabase/ENVIRONMENTS.md` explains the manual process.
- This is code-level prevention, not proof of deployed isolation. The existing project has not been assigned automatically. Distinct staging/production projects, administrator marker assignment, hosted cross-environment/session tests, test-data fixtures and scoped cleanup remain pending. The old connected config now intentionally needs explicit environment settings and a matching server marker. Photo lifecycle, pagination, deeper subscription tests and caching remain the next separate tasks in `BACKEND_PROTECTION_TASKS.md`.

## Backend protection 2: immutable photo upload and cleanup (22 October 2026)

- Added migration 014 and a testable upload coordinator. A selected photo retains immutable bytes, a stable UUID, a SHA-256 retry fingerprint and the previous photo path displayed to the Provider. The server denies stale-screen replacement before registration and uses compare-and-set on attachment to deny a second device's conflicting commit. Network retries reuse one immutable path with no upsert; uncertain Storage results are checked by the attachment RPC instead of generating another filename.
- Private evidence pointers and remarks can now be changed only through Provider-authorized RPCs using the same provider-then-booking locks as completion. Metadata existence/size/MIME are checked before attaching. Completed evidence cannot be edited, current photos cannot be deleted, Owner/outsider cleanup is denied, and cleanup tombstones cannot be reattached. The six booking states are unchanged; upload states are separate.
- Provider screens retain failed selections in memory, show an explicitly unsaved preview and direct retry action, verify the exact attempted path rather than any other device's changed path, preserve remarks and avoid post-disposal refresh. Preview decode failures have a safe placeholder. Existing ImagePicker resize/quality and 5 MB restrictions remain; cross-platform compression/decoded-image/EXIF validation is not newly claimed.
- Replaced files are retired only after a successful attachment. Registered pending uploads have a 24-hour server-time grace period. A bounded provider cleanup pass and service-role-only maintenance functions mark irreversible deletion tombstones; Storage API removes actual bytes, and an idempotent finish verifies disappearance. Unknown historical files are not swept. `tool/evidence_cleanup.mjs` defaults to read-only dry run, checks environment identity, validates paths and requires explicit production deletion opt-in. Its server credential is never placed in Flutter/config examples. No worker or scheduler was run against hosted data.
- All 282 Flutter tests passed; all 14 migrations and expanded lifecycle/photo/access checks passed in disposable PostgreSQL; all five mocked worker tests passed; the release Web build succeeded. Screenshot `test/goldens/evidence_photo_retry.png` is a simulated network-failure widget preview, not a live upload. Local Storage tests operate on a metadata shim, not actual files. Hosted Storage API semantics, real multi-session races, device image behavior and scheduled cleanup still require staging verification. Deployment instructions and limits are in `supabase/PHOTO_UPLOAD_LIFECYCLE.md`. Pagination is the next separate task.

## Backend protection 3: bounded cursor pagination (22 October 2026)

- Migration 015 adds participant-scoped booking, message and status-history pages. Each request defaults to 20 records and is capped at 50, with a raw database timestamp plus UUID cursor, deterministic ordering and bounded context enrichment. An independent Owner summary RPC counts all relevant records rather than only loaded bookings. Existing booking states, pricing and acceptance rules are unchanged.
- Connected booking lists, chat and history now offer explicit older-record loading. A failed page preserves loaded records, its retry cursor and chat drafts. Duplicate taps are serialized, IDs are deduplicated and generation/version guards reject stale responses. Live booking/chat changes trigger targeted reads instead of unbounded table reloads; observed deletions cannot be resurrected by an in-flight older page. Rejoining reloads the contiguous latest page. Status history remains a paged snapshot, not a new live subscription.
- Added ten feed tests, four interaction/responsive tests and two golden checks. All 298 Flutter tests passed; all 15 migrations and local access/lifecycle/pagination checks passed; the release Web build succeeded. SQL fixtures include timestamp ties with microseconds, more than two pages of data, an unrelated Owner, insertion after an initial cursor and summary totals exceeding page size. Inspected `test/goldens/paged_chat_older.png` and `test/goldens/paged_chat_retry.png`; these are widget previews with synthetic fixtures, not hosted sessions.
- No hosted migration, setting or data was changed. Real Supabase publication/RLS/channel rejoin behavior, administrative DELETE delivery and two-device tests still require staging verification. Explicitly loaded records remain in memory; other property/provider lists and capped/offline caching are not claimed as completed. `supabase/PAGINATION.md` records the contract and manual checks. Subscription lifecycle is the next separate task.

## Backend protection 4: route, app and account subscription lifecycle (22 October 2026)

- Added a per-Navigator route observer and a shared resumed/current-route activity binding. Workspace and chat channels stop when covered or backgrounded, without waiting for a background frame; history remains a paged snapshot. Resumption reads the latest bounded page. Booking/chat/history feeds are created once per route instead of inside rebuildable route builders.
- Cursor feeds now support ordered cancellation/restart, read-generation invalidation and permanent account-boundary invalidation. Sign-out/account changes clear rows and remove private pushed routes/back navigation. Late session restoration is guarded; local Provider identity is cleared. Same-user refresh and transient auth errors do not invent a logout or duplicate subscriptions. These client checks complement, not replace, RLS.
- Replaced the remaining implicit single-booking status table stream with a bounded status read plus an explicitly owned change channel. Lifecycle-aware status/message listeners await cancellation and discard stale snapshots; sending is unavailable until a fresh Accepted/In Progress status arrives. Drafts survive suspension while the route remains mounted. Closed/interrupted live feeds have a reconnect action that replaces the channel as well as refreshing data.
- A loopback test using the installed Supabase/Realtime SDK exposed a last-socket restart race: the SDK convenience removal returns before its asynchronous disconnect completes. Managed channel operations now use a per-client gate, await unsubscribe/registry removal and explicitly await last-socket disconnect before a replacement starts. Twenty real-SDK loopback cycles now return to an empty registry and closed peer sockets, without accessing a hosted project.
- Added 20 tests over the previous 298-test baseline: feed lifecycle/reconnect, route/background/draft behavior, root session-boundary fixtures, installed-SDK loopback cleanup and one reconnect golden. All 318 Flutter tests and the release Web build passed. Inspected `test/goldens/connected_chat_reconnect.png`; synthetic widget fixtures are not real hosted users/results. No SQL or hosted configuration/data was changed. Staging two-account, actual mobile OS, revocation and network-loss checks remain required, as described in `supabase/SUBSCRIPTION_LIFECYCLE.md`. Caching and compression verification is the next separate task.

## Backend protection 5: authenticated cache and verified photo output (22 October 2026)

- Added a per-backend session-bound, memory-only LRU cache with 12 MiB/24-entry limits, a four-load budget, same-key single-flight reads, TTL expiration and stale-work rejection across invalidation/account boundaries. Evidence photos expire after two minutes; service ID/name references after five. Booking/status/availability/eligibility/quote/payment decisions are not cached. Service references are immutable and support explicit force refresh.
- Private photo downloads freshly verify current booking participation/photo pointers even on cache hits. Denial, missing rows and replaced paths cannot serve old cached bytes; new metadata evicts obsolete image keys. Account changes, root disposal and memory pressure clear retained memory; connected Flutter decoded-image cache limits are 64 entries/20 MiB and evidence thumbnail decoding is bounded. These are cache limits, not a whole-process RAM/security-erasure guarantee.
- Added actual JPEG/PNG preparation: input byte/pixel limits, successful decode, aspect-ratio resize, orientation normalization, source metadata removal, white flattening and a bounded JPEG output up to 1600px/1 MiB. Native heavy work uses an isolate; Web uses native canvas/image codecs after a slow browser debug pixel-processing path was observed. Only one expensive job runs at a time. The existing immutable upload ticket/hash/ID and retained-byte retry behavior remain intact; Storage's existing 5 MiB backend limit is unchanged. New uploads request zero cache freshness. Source files are not modified.
- Added 28 tests to the prior 318-test baseline; all 346 native Flutter tests passed. All 12 Chrome HTML-renderer image tests passed, including Web orientation/metadata/size and asynchronous path checks. A synthetic 772,926-byte textured JPEG produced observed native/Web outputs of 180,795/175,134 bytes; no universal savings or real-device benchmark is claimed. SDK loopback tests cover fresh authorization on private cache hits, 403/empty-row denial, replacement/account isolation and reference invalidation. Root tests now also assert cache clearing/memory-pressure behavior. The release Web build passed; default CanvasKit browser-test bootstrap did not complete and is not counted as verified.
- Updated/inspected the synthetic `test/goldens/evidence_photo_retry.png` preview with prepared-image dimensions/size and retained upload retry. No SQL, hosted configuration, accounts or actual evidence was changed. Real-device peak RAM/quality/camera tests, hosted private Storage/RLS, server-side adversarial file inspection and existing cleanup/deployment checks remain pending. See `supabase/CACHING_AND_COMPRESSION.md`. Labelled test-data management is the next separate protection item; the five local protection tasks do not establish launch readiness.

## Backend protection 6: staging test-data provenance and review (22 October 2026)

- Added migration 016 with an administrator-only test-run registry, explicit reserved synthetic Auth email/ID checks, staging marker/project validation and read-only dependency inventory. Auth accounts must be manually provisioned first; no real account is silently relabelled. Client roles cannot access the registry or maintenance RPCs. The administrative environment probe now has an explicit service-role grant rather than relying on hosted default ACLs.
- Atomic fixtures create two labelled properties, an approved synthetic Provider with seven working slots/two capabilities, and one MYR 80 two-hour Pending request with its normal initial history. Same-run retries preserve subsequent activity and reject changed parameters. No completion, evidence, payment, real contact information or external-service success is invented. Synthetic addresses do not validate routing/geocoding.
- Added the server-only Node tool with offline plans, dry-run-by-default seed validation, explicit project-confirmed creation, strict arguments, secret-safe errors and uncertain-response retry guidance. Read-only inventory includes later related records, bounded samples, mixed-account warnings and a 14-day review reminder; it never deletes or extends retention on retry. No full business-data/Auth purge or scheduled retention deletion is implemented or approved.
- All 346 Flutter regression tests passed. All 17 Node tool tests passed (12 new test-data tests and five existing photo-cleanup tests). All 16 migrations and expanded access/inventory/fixture checks passed in a disposable network-isolated PostgreSQL container, including injected mid-seed rollback, production rejection, client denial, idempotency and totals exceeding the 20-ID sample. The offline CLI plan was exercised. No Flutter UI code changed, so no new UI preview or Web build is claimed for this task.
- No hosted migration, Auth provisioning, fixture creation, inspection, deletion or Storage operation was performed. See `supabase/TEST_DATA_MANAGEMENT.md` for the manual staging sequence. Hosted Auth/REST behavior, independent environments, two-account permissions and concurrency remain to be verified together with the user; local checks are not launch sign-off.

## Security/privacy task 1: protected Auth session and PKCE storage (23 October 2026)

- Added a serialized, environment/project-namespaced Supabase LocalStorage and PKCE adapter. Android uses the pinned secure-storage plugin's Keystore-backed RSA-OAEP/AES-GCM configuration with automatic destructive reset disabled; iOS uses unsynchronized, this-device/unlocked Keychain options. Existing environment verification still precedes opening/restoring any credentials. Web uses real per-tab sessionStorage, not persistent localStorage or a purported OS vault; normal tab closure may require login again, and browser session restoration/XSS remain distinct concerns.
- Legacy session migration validates bounded shape/project/subject, writes and reads back protected data and its marker before clearing exact legacy keys. Invalid sessions/global old PKCE are discarded; expired valid-shaped sessions remain refreshable. Completed migrations never resurrect stale plaintext. Missing installation metadata prevents automatic reuse of surviving Keychain entries on reinstall. Failures block access and use sanitized storage-specific retry guidance, without local-demo fallback.
- Added generation/current-SDK-token guards and a durable non-secret logout tombstone. Interrupted vault deletion cannot restore a surviving old token on next start; delayed signedOut/persist events cannot overwrite a newer active session. The actual SDK's async persistence behavior is covered: the repository confirms login persistence before success, still clears SDK memory on vault/network logout errors, and never equates local cleanup with immediate remote JWT revocation. Partial SDK initialization is disposed before retry.
- Added Android backup/device-transfer exclusions and iOS entitlement references; Android compile SDK is now 36 as required by the plugin, with minimum SDK unchanged at 23. Dependency resolution completed without changing global Developer Mode/Flutter settings; Windows desktop plugin execution remains unverified. The Android build installed SDK Platform 36 using existing SDK licensing. No Flutter/Dart/Gradle/AGP upgrade or custom application cryptography was introduced.
- All 380 native Flutter tests passed (34 new: 23 coordinator, seven installed-SDK loopback, four mocked-native/config/UI). All 26 Chrome HTML-renderer storage tests passed (23 coordinator plus three real-browser storage checks). Targeted analysis of all 13 touched Dart source/test files found no issues. Release Web and Android debug APK builds passed. Mocked vault tests and a debug APK do not prove actual device encryption, iOS signing, OEM backup behavior or hosted Auth security.
- No hosted Supabase configuration/data/account or real credential was changed. No routine business-page redesign or report rewrite was performed. Real Android/iOS vault/backup/reinstall checks, staged Auth refresh/revocation and signed iOS acceptance remain required. Manual checks and behavior changes are documented in `supabase/AUTH_CREDENTIAL_STORAGE.md`; the remaining six tasks are tracked in `SECURITY_AND_PRIVACY_TASKS.md`. Secret/log hardening is next, not silently included as complete here.

## Security/privacy task 2: allow-listed diagnostics and local release secret checks (23 October 2026)

- Replaced 18 raw connected exception logs with fixed operation/category/reference diagnostics; no raw error message, runtimeType, stack, URL, private ID, payload or arbitrary context is emitted. Production diagnostics are disabled by default. Explicitly disabled the SDK's default raw console forwarding. Framework/dispatcher/error-widget boundaries use sanitized logging and fixed on-screen guidance; native/plugin/browser logs still need device review.
- Login/registration now maps typed failures to fixed user-facing guidance instead of interpolating server exceptions. A typed role mismatch preserves actionable Owner/Provider selection advice. Existing booking, upload, payment and authorization rules were not changed, and no new telemetry service was added.
- Added a local standard-library Python scanner for covered private-key/token patterns, common raw Dart log/UI guards, readable worktree text/config, 307 objects reachable in current local Git refs, and bounded Web/ZIP/APK/AAB contents. It prints only redacted rule/location/counts, fails closed on incomplete scans and never probes credentials online. Added client-config schema checking, private-file artifact checks, ignore rules and an opt-in PowerShell release wrapper that withholds raw compiler output and gates both preflight and packaged output. Direct Flutter commands bypass that wrapper; no CI service or remote settings were configured.
- Thirteen Python tests passed using temporary synthetic repos/archives and a fake compiler for clean/config/compiler/artifact orchestration paths; 17 existing Node administrator-tool tests also passed. All 388 Flutter regression tests passed, including eight new diagnostics/UI/boundary tests. Seven portable tests also passed in Chrome HTML renderer. New diagnostics/helper/boundary/test files passed targeted analysis; no claim is made that legacy UI style warnings across the repo have all been fixed.
- Actual release Web, Android debug and Android release-mode APK builds succeeded. The source/reachable-history and actual release Web/APK content passed covered checks. A conservative raw debug-Kernel match was privately investigated using format-119 string-table offsets: the literal sb_secret_ was one complete 10-byte string and the 144-byte raw match crossed ten separate entries, not one complete key. No matched value was printed/allow-listed; the generic scanner remains conservative for that debug format. The AOT release artifact was checked independently.
- Android release-mode APK currently still uses the repository's existing signing fallback, so it is not approved for publication. Actual production-configured gate execution, AAB/signing, CI integration, independent secret scanning and device/staging log review remain required. No hosted Supabase setting/account/data, Git history or real credential was changed. Scope and reproducible release commands are in `supabase/SECRET_AND_LOG_PROTECTION.md`. Full recovery/callback/new-password handling is the next separate task.

## Security/privacy task 3: trusted password recovery and session isolation (23 October 2026)

- Final source compiled successfully as release Web, Android debug APK and Android release-mode APK. Source, 307 reachable local Git objects and the final Web/release-APK artifacts passed covered secret-pattern checks. Packaged manifests confirmed the custom recovery scheme is debug-only, Internet access is retained and release backup remains disabled. These are compilation/packaging checks without a real configured hosted backend, not production-connected acceptance or publish-ready signing.
- Added an explicit configured PKCE recovery destination and a dedicated controller. Exact callback scheme/host/port/path, a single bounded code and a protected recovery-labelled verifier precede the server code exchange. Disabled SDK broad URI auto-detection and implicit-token callback acceptance. Normal login/signup/email initiation is serialized against recovery exchange; unsolicited recovery links cannot force a normal logged-in user to log out. Signup confirmation remains verify-email-then-password-login rather than automatic callback login.
- A durable environment/project recovery marker precedes the exchange. Credential storage refuses to restore a marked session as normal Auth, interrupted recovery is discarded before startup restoration, and the root gates/unmounts private routes and clears private caches. Safe cleanup, weak/same-password correction, expired/used-link rejection, uncertain-update guidance and explicit fresh login replace automatic entry into the workspace. A locked vault preserves the gate and supports retry; remote logout failure is not claimed to revoke every old token immediately.
- Added light/dark new-password and confirmation forms, visibility/autofill support, repeat-submit prevention, terminal field clearing, fixed safe messages and 320px/large-text checks. Request-email UI disables an unconfigured destination and explains the Web tab constraint. Web callbacks are captured/scrubbed before asynchronous startup; a captured callback survives connection-setup retries only in memory. Other Auth URL fields are scrubbed without granting recovery, and the Web document adds no-referrer guidance.
- Added the public `AUTH_RECOVERY_REDIRECT_URL` client setting. Runtime release checks and the optional secure-build config gate require an HTTPS recovery destination; debug staging permits loopback Web and the debug-only Android custom scheme. No production domain, signing identity, release App Link host, iOS association entitlement or native desktop URL association was invented. The current root Web deployment and per-tab sessionStorage mean a Web reset link must be opened in the original requesting tab. Missing debug configuration disables recovery; a syntactically valid HTTPS URL is not evidence of hosted allow-list/domain verification.
- All 419 Flutter tests passed, including 20 installed-SDK/loopback recovery tests, four redirect/config tests and seven recovery UI/routing/golden tests. The lost-response case closes the real loopback HTTP socket after receiving the update; no app-level blind resubmission follows. Twelve portable/browser-storage/callback tests passed in Chrome HTML renderer; all 14 local scanner/build-wrapper tests passed. Twenty touched Dart files passed targeted analysis, with the final controller/test changes checked again. No hosted email, account, database, Storage, migration or Auth-setting operation was performed.
- Manual acceptance is still pending: separate staging setup, exact Auth redirect/mail/template/password-policy settings, real mail delivery and registered/unregistered email behavior, real signed Android/iOS links and secure storage, server revocation behavior, and production hosting/log review. Release-mode APK signing still uses the pre-existing fallback and is not approved for publication. See `supabase/PASSWORD_RECOVERY.md` and the updated security queue. The next separate task is photo/chat access and abuse prevention.

## Security/privacy task 4.1: booking communication and upload write limits (23 October 2026)

- Added migration 017 with administrator-only rolling-window policies and indexed per-actor budgets across bookings. Initial chat limits are 8 new messages/10 seconds, 40/minute and 300/hour; evidence reservation limits are 6/minute, 30/hour and 100/day. Existing records are the event ledger, with no duplicated message/photo/request history. Policy data and internal helpers are inaccessible to client roles. Limits use database time and are configurable operational safeguards, not charges, population findings or a guaranteed project-wide usage/billing cap.
- RPC entry points retain participant/provider checks, booking statuses, body/manifest validation and safe same-ID retries. Actor/action transaction advisory locks serialize competitors; the API explicitly requires Read Committed snapshots. New records use `clock_timestamp()`. Exact accepted-operation retries precede quota checks, changed-content tokens remain invalid, missing policies fail closed, and over-budget new operations return a fixed PT429 code/detail without saving a new row. No bucket/content-inspection or booking/payment rule was changed.
- Added typed, allow-listed 429 mapping and local UI pauses. Chat retains editable draft text and the retry ID; photos retain prepared bytes, upload ID and remarks. Pauses disable the relevant writes and completion, never auto-retry, cancel timers on disposal and cannot override current booking-state checks. Unknown network/gateway failures still use the prior lost-response verification path. Compact keyboard/large-text layouts are scrollable/bounded; three light/dark/chat/photo previews were visually inspected. Logs use a fixed `rateLimited` category, not server payloads.
- All 17 migrations and the existing SQL access/lifecycle/evidence/pagination/environment/test-data suites passed in disposable PostgreSQL 16 with no network. New SQL cases cover every quota window, cross-booking accounting, free identical retries, changed-token denial, policy-access denial, expiry, missing-policy failure and isolation rejection. Real parallel sessions observed a waiting advisory lock while another write remained uncommitted; the competing new message/upload was rejected and later retries left counts at 8/6. The helper verifies the parent-created container's name, label and network isolation before running synthetic fixtures. No hosted Auth/JWT/REST/Storage behavior is inferred from these role-shim tests.
- All 437 Flutter tests passed (18 added helper/installed-SDK/interaction/golden tests), as did 18 portable/browser tests in Chrome HTML renderer, 14 Python scanner/build-wrapper tests and 17 Node maintenance-tool tests. Eleven touched Dart files passed targeted analysis. Final release Web and Android debug APK builds succeeded. Source, 307 reachable local history objects and the release Web artifact passed covered secret-pattern scans. This is compilation/local verification, not a signed production release or launch approval.
- No hosted project/schema/account/email/Storage object or real credential was changed, and no original report/PDF was edited. Task 4 remains partial: next is 4.2 trusted server photo-content inspection/canonicalization plus enforced attachment validation; actual hosted cross-account/bypass tests and gateway/global abuse/capacity controls remain pending. See `supabase/BOOKING_COMMUNICATION_LIMITS.md` and the updated security queue for the defaults, limitations and later manual staging sequence.
