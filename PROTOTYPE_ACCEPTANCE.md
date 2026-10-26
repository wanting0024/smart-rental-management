# Functional Prototype acceptance (no separate demo-ready build)

All work stays in the existing app/original UI and isolated Staging project.
Test identities are for verification, not a second demo/prototype implementation.
Only mark complete with evidence; local automation is not manual device UAT.

| ID | Work | Definition of done | Status |
|---|---|---|---|
| P1-1 | Remaining connected pages | Owner profile/settings, Spending, property list/detail/edit, Provider stats use actual own-account data, no preview stores/fake metrics/dead-end controls; automated permission/UI checks pass | Code + automated checks complete; populated device acceptance remains P2-4 |
| P1-2 | Usable isolated test fixtures | Dedicated synthetic Owner/approved Provider, property, valid services/slots/rates; repeatable setup/cleanup scoped by test run; no real users or original-project mutation | Complete: hosted setup/readiness + local cleanup/concurrency verified; cloud cleanup preview only |
| P1-3 | End-to-end business acceptance | Request -> accept -> start -> validated evidence -> complete -> review -> reporting; cross-check both accounts, schedule, notifications, messages and sign-in persistence using actual Staging operations | Hosted repository integration passed; populated device UAT remains P2-4 |
| P1-4 | Negative-path acceptance | Denied/allowed cancel and revise paths, conflicts, retries/idempotency, upload/network failures and account isolation tested; no duplicate/invalid transitions | Hosted negative integration + controlled response-loss checks passed; device offline UAT remains P2-4 |
| P2-1 | Message state | Persisted own-account unread/read logic and badges consistent across views/accounts; closed-thread rules retained; no fabricated unread counts | Code + hosted receipt/filter/re-login checks passed; manual device UAT remains P2-4 |
| P2-2 | Supporting pages | Help/support complete; readable Terms/Privacy drafts explicitly non-final, no fabricated recipient/delivery/verified identity; unfinished external integrations excluded or clearly labeled | Prototype code + automated checks complete; formal publication remains a launch requirement; device UAT P2-4 |
| P2-3 | UI/UX checks | Small screens, 200% text, light/dark, loading/empty/error, keyboard, forms/back navigation exercised and regressions repaired | Cross-page code / automated / rendered-widget review passed; physical device and screen-reader UAT remain P2-4 |
| P2-4 | Device UAT | User verifies agreed scenarios on phone/emulator, actual pass/fail recorded; no claim of hardware acceptance from automated tests | Requires user device acceptance |

Payments, actual payouts, device push, recurring bookings and real support delivery
are not silently added. No separate Demo-ready build, presentation package, fake
settlement or supervisor-only design is requested.

## P1-1 evidence — 24 October 2026

- Original Owner profile/settings layout now uses own name/contact/email and real
  property count. Name/contact revision-checked edits, persisted display name on
  sign-in, actual appearance toggle, notifications, property management/help and
  sign-out routes. Email/role read-only; no NRIC verification claim. Password and
  language actions explain implemented recovery/language limits, not fake success.
- Original Properties list/cards/table/detail reuse actual property IDs, server
  booking counts and bounded 20-row pages. Aggregates of loaded properties are
  explicitly scoped. Add and Manage are distinct routes; detail/edit preloads a
  fresh revision, checks changes, retains server window protections and preserves
  unsaved entries. Property-specific new requests preselect that property.
- Original Spending uses server completed quote value, MYT ranges, actual pricing
  availability, whole-range totals/top providers and bounded history. No payment
  confirmation/PDF export simulation. Statistics uses genuine history/reviews,
  completion-based weekly counts, documented denominators and missing values;
  removed fixed 12-minute/78% values and misleading Last 30 days hero label.
- Migrations 024/025 applied only to pinned Staging after dry-run. Local 001–025
  SQL regression profiles legacy/disabled passed. Own-role/other-account checks,
  stale revision denial, forged fields, paging, cents, unknown quotes, date ranges
  and anonymous denial covered. No hosted fixture business writes in this step.
- output/p1-workspace-full-test.log: 614 passed; hosted smoke: both accounts
  passed; Android debug build passed; analysis style infos, no errors/warnings;
  lib secret-pattern scan PASS across 146 files. Tests include 320px/200% light/
  dark original connected pages without preview stores and unsaved-form behavior.

## P1-2 evidence — 24 October 2026

- Dedicated reserved-domain synthetic Owner and approved Provider created only in
  Staging gqtetdavmrautoojaqrk. Two [TEST] properties, seven 08:00–18:00 weekly
  slots, two service capabilities and one Pending booking. Original Provider A
  remains pending; original project untouched. Credentials are private and ignored.
- Repeat Setup preserves identities/passwords and existing run data; no duplicate
  booking or property. Actual App repositories read both profiles/properties and
  bookings; server eligibility/quotes confirm 2h hourly RM80 and 8h daily RM280.
  Other-account reads and authenticated access to administrator cleanup are denied.
- Migration 026 adds administrator-only scoped cleanup with mandatory fresh
  inventory fingerprint. Mixed-account, worked-on, chat/evidence/upload/Storage
  runs are blocked. Local SQL cleanup/reseed and real concurrent edit/acceptance
  tests pass under both privilege-default profiles. Hosted cleanup was previewed
  only: no business data, Auth identity or Storage object deleted in the cloud.
- Evidence: output/p1-fixture-tool-guards.log (41), existing guards (19),
  p1-fixture-sql-legacy.log / p1-fixture-sql-disabled.log (001–026),
  p1-fixture-repository-smoke.log (new two-role fixture), existing smoke (2),
  p1-fixture-app-regression.log (614), client-security log (146 lib files).
- No App UI/source redesign or separate build. See
  supabase/reviews/2026-10-24_ISOLATED_FIXTURE.md for lifecycle and limitations.

The initial Pending booking above remains administrator-seeded test data. P1-3
below separately exercises ordinary signed-in Owner creation, not that seed path.

## P1-3 evidence — 24 October 2026

- Ordinary dedicated Owner created booking 4402d332-5baa-4b93-b4b2-8eb515bd0c4e
  through the App repository/create_pending_booking, with real eligibility and
  RM80 server quote. Same-token retry reused it. Both calendar projections read
  the actual booking; assigned Provider accepted through the protected RPC.
- Both accounts sent/read one clearly labeled synthetic message each; global
  conversations include the booking. Provider received its request notification.
  Provider started normally; completing without required evidence was refused.
- Two explicitly synthetic [TEST] PNGs were decoded/canonicalized by the hosted
  evidence-validate function, stored privately, attached, then downloaded/decoded
  by both participants. No SQL Storage metadata shim or attestation override.
  Remarks and normal transition completed the synthetic service record.
- Owner test review persisted and was readable by Provider. Last 30 days / This
  month / All time Earnings and Spending each include this completed RM80 quote;
  settlement remains unavailable. Provider statistics reflects completion/rating.
- Four exact lifecycle history entries; Owner completion notice/read receipt and
  both-role booking/messages/review/evidence survive fresh password sign-in.
  Durable checkpoint and stable IDs resume the same run. Hosted rerun passed;
  inventory stayed 2 total bookings (one seeded Pending, one actual Completed),
  2 messages, 1 review, 2 upload tickets and 2 Storage objects. Cleanup preview
  correctly blocks this worked-on run. Nothing was deleted or reset.
- 639 default Flutter tests passed (25 new offline guard/pixel tests); existing
  hosted account smoke 2 passed, secret-pattern scan PASS (146 lib files), tool
  analysis no errors/warnings (4 intentional test logging infos). Hosted write
  test is explicitly opted in, separately project-confirmed and default-skipped.
- Important existing business logic: start/completion require actor/status/evidence
  but not the scheduled wall-clock time. This test used a future appointment and
  exercised the existing rules without overriding time. Before public launch,
  decide and test the allowed early/late start/completion policy. No new policy
  or hidden Staging-only bypass was introduced.

Next: P1-4 negative paths. P1-3 proves hosted repository integration using
synthetic people/service/pixels, NOT actual cleaning, a payment, native camera,
device push, persisted chat unread badges or manual device UI acceptance.
Details: supabase/reviews/2026-10-24_BUSINESS_ACCEPTANCE.md.

## P1-4 evidence — 24 October 2026

- Seven bounded new [TEST] appointments through ordinary fixture accounts. Owner
  Pending cancellation / Provider Pending decline / either-participant Accepted
  cancellation succeed with correct actors/reasons. Wrong actors, missing reason,
  post-start cancellation and repeated terminal transitions are denied. History
  counts confirm no duplicate cancellations/acceptances/completions.
- Owner-only Pending revision succeeds at the same quoted duration; lost response
  is recovered by reading the new interval. Changed duration, outside rental window,
  accepted-state revisions and conflicting revisions leave original data intact.
- Two overlapping Pending requests race on independent signed-in Provider clients:
  one accepts, one returns slot_conflict. New conflicting creation also refuses
  without inserting; cancelling the winner releases the slot for the other request.
- Fault injection uses REAL pinned Staging upstream operations, dropping a request
  before send or hiding its HTTP-success response. Creation/cancel/revision/accept/
  message/completion readback verifies actual commit; stable IDs prevent duplicates.
  A lost successful Edge response reconciles through guarded attachment, without
  reuploading or trusting a timeout as proof of success.
- Real malformed PNG rejected; cannot attach or complete without valid evidence.
  Owner cannot upload, Provider cannot self-review, early review/new closed-thread
  message refused. Anonymous/unrelated original A accounts cannot read/mutate
  booking/chat/review/evidence/private Storage. Forged price/past/oversized request
  refusals create no booking. Original pending Provider A unchanged.
- Local regression verifies approval revoked after request creation prevents accept,
  approved acceptance still succeeds, repeat acceptance does not append history,
  expired Pending cannot be accepted. Both native 001–026 grant profiles and actual
  concurrent rate/lease/cleanup tests pass. Existing protection confirmed: no new
  migration, hosted approval mutation or production change was needed.
- Hosted first run and checkpoint rerun pass. Retained fixture inventory: 9 bookings
  (1 Pending, 5 Cancelled, 1 Declined, 2 Completed), 25 history entries, 3 messages,
  1 review, 5 upload tickets (one rejected), 4 private objects. Original P1-3 record
  and review/messages preserved; cleanup preview blocks worked-on/file data.
- 19 new offline transport/checkpoint guards; 658 default Flutter tests passed;
  original hosted accounts 2 passed; secret scan 146 lib files PASS. Explicit
  opt-in/project confirmation required; default invocation skips hosted writes.
  Fault transport is tool-only; existing http 1.6.0 made an explicit dev dependency,
  without changing its resolved version or original App UI.

Next: P2-1 persisted message read/unread and badges. Early execution timing policy
remains an explicit business decision, NOT certified by these state-based checks.
Physical Wi-Fi/airplane-mode/native UI acceptance still belongs to P2-4; controlled
response loss is not a claim of real-device offline UAT or universal launch safety.
Details: supabase/reviews/2026-10-24_NEGATIVE_ACCEPTANCE.md.

## P2-1 evidence — 24 October 2026

- Migration 027 deployed ONLY to pinned Staging after dry-run and native 001–027
  checks under both default-grant profiles. Private per-recipient/message-ID
  receipts, bounded authenticated-only read/count/unread-filter RPCs. No raw table
  grants or peer 'Seen' disclosure. Own outgoing messages never count as unread;
  only exact received IDs may be acknowledged; retries are idempotent/atomic.
- Original list shows genuine per-thread numbers and server Unread filter with
  bounded anchored paging. Shared session-scoped badge state drives list title,
  Owner Messages quick action and drawer entry. One quiet foreground 30-second
  count poll, immediate recheck after confirmed local receipt/send, no fake zero
  on initial/error states or optimistic decrement. Not push/instant cross-device.
- Painted viewport checks exclude cache-built offscreen bubbles and own messages.
  Only current/resumed thread records observed IDs; batches <=50 with bounded retry.
  Background/pop cancels queued reads; identity epochs reject late private results.
  Transient Auth errors retain verified routes/counts, not a false logout.
- Real hosted dedicated test: partial read leaves older incoming unread; new arrival
  remains unread after repeating old acknowledgement; own IDs/outsider denied.
  Both roles' fresh logins preserve receipts, global/list counts agree, read thread
  disappears from Unread filter while cancelled history remains readable. Checkpoint
  rerun preserves one added test appointment/four messages; old chats not marked.
- 673 Flutter tests passed; Android Staging debug built; existing hosted accounts
  2 passed; lib secret scan 149 files PASS; analysis no errors/warnings (style infos
  remain). Includes viewport, retry, large-text/small-screen unread filter, session
  boundaries, stale counts and genuine server read isolation tests.
- Retained fixture now: 10 appointments (1 Pending, 6 Cancelled, 1 Declined,
  2 Completed), 28 history events, 7 messages, 1 review, 4 private photo objects.
  No deletion, old chat acknowledgement, original-project/account mutation or payment.

Next P2-2: supporting pages / clearly non-final legal drafts. Hot Restart required
to recreate existing thread state; phone/emulator manual acceptance still P2-4.
Details: supabase/reviews/2026-10-24_MESSAGE_READS.md.

## P2-2 evidence — 24 October 2026

- Original About & help layout retained. Staging / explicitly enabled local
  preview opens sectioned Terms / Privacy review drafts. Notice and copied text
  carry DRAFT / NOT PUBLISHED, version and unresolved launch decisions. No
  effective date, legal approval, acceptance checkbox or consent write invented.
- Production and unknown environment labels fail closed to not-published
  explanations. Draft reader independently checks environment visibility; this
  is a labeling safeguard, not server authorization. Simulated support retains
  own-session memory-only flow; production / unknown cannot enter through About.
- Help matches actual same-duration Pending revision, message viewport receipts,
  quiet 30-second count refresh, interrupted-write readback, and sign-out versus
  cloud deletion. Privacy explains participant address access before acceptance,
  private evidence versus E2EE, native/browser session differences, real backend
  persistence, incomplete deletion/export and simulated support not being a
  real privacy-rights channel. Terms do not invent clock limits, money or refunds.
- 15 new tests; 36 focused help/support tests and 688 full Flutter tests passed.
  Android Staging debug build passed; analyzer no errors/warnings (existing and
  new style infos remain); lib secret scan 151 files PASS. Includes both drafts
  at 320px / 200% light/dark, complete copied warnings, back navigation and
  production/unknown/direct-entry gates. No manual device acceptance claimed.
- No cloud mutation, migration, recipient email, real support delivery, production
  deployment or PDF. Operator identity, real contacts, retention/deletion/backup
  handling, service timing/dispute policy and legal review remain launch work.

Next: P2-3 cross-page UI/UX checks; postponed phone/emulator UAT remains P2-4.
Details: supabase/reviews/2026-10-24_SUPPORTING_PAGES.md.

## P2-3 evidence — 24 October 2026

- Owner dashboard populated large-text audit reproduced 97 / 163px statistic
  overflows: fixed heights and narrow number/icon rows. Cards now grow naturally,
  reflow to full-width on narrow enlarged-text layouts; quick actions no longer
  clip their labels/subtitles to fixed heights. Normal layout/theme preserved.
- Owner navigation grows with text, wraps labels and exposes complete selected
  button labels plus actual semantic tap actions. Android minimum-target and
  labeled-target checks plus semantic action dispatch pass in both themes.
- Shared and Provider discard dialogs are scrollable with a short keyboard
  viewport. Keep editing preserves drafts; Discard returns normally. Owner
  information dialogs also allow scrolling.
- Owner editor is now directly testable using the SAME existing route component.
  Fields remain mounted in a scrollable Column rather than a lazy list: earlier
  invalid entries cannot drop out of FormState validation when Save is scrolled
  into view. Validation blocks writes, pending save disables duplicate submission,
  uncertain save retains input and requires reloading instead of fake success.
- Cancellation actions stack on narrow/large-text layouts; missing reason/comment
  is inline, Other correctly says required, and remains fillable even when optional
  comments are disabled. Reasons expose selected button semantics; destructive
  button uses theme error/onError pairing. Owner/Provider keyboard submissions pass.
- 78 new automated cases: 76 in p2_ui_ux_audit_test plus 2 reset-password cases.
  85 focused tests and 766 full Flutter tests pass. Both themes / 320x568 / 200%
  text, populated/empty/loading/error home states; request/availability/evidence/
  review/history/chat loading-empty-error and real retry invocation; registration,
  recovery/reset, profile, filter, cancel, keyboard, draft and navigation checks.
  Missed-tap warnings are fatal in the new audit; no offscreen taps accepted as passes.
- Existing suite rechecks Schedule/Earnings ranges and chart, Owner profile /
  spending / properties / Provider statistics, messages/unread/notifications,
  Help/support/legal drafts, snapshots/quiet SWR and session/back-stack isolation.
  Android Staging debug builds; analyzer no errors/warnings (style infos remain),
  secret-pattern scan 151 lib files PASS. Light/dark rendered output inspected.
- Entire step was offline code / widget automation / local APK build. No Staging
  login/signup, fixture creation, data reset, Supabase writes, schema/dependency
  changes, real email or push. Fixed testing credentials remain unchanged.

Next P2-4: actual phone/emulator keyboard/safe-area/camera/gallery/permissions,
TalkBack and both-role end-to-end acceptance. Still pending; screenshots and
automated accessibility checks are not hardware or human-usability certification.
Details: docs/2026-10-24_UI_UX_REVIEW.md.

## Owner menu / Back follow-up — 24 October 2026

My properties, connected Providers request/search and Owner Profile retain the
original bottom navigation in loading/error/ready. Property details retain both
menu and Schedule new cleaning CTA. Primary tab changes replace rather than pile
routes; Home/Bookings select the original root, including after detail navigation.
Preview category Back/Profile menus preserved too. 22 new cases, 29 focused and
788 full tests passed; Android Staging debug built; analyzer no errors/warnings
(style infos), source scan 152 lib files PASS. No backend data/account changes.
Manual phone/emulator acceptance still P2-4, not marked complete.
