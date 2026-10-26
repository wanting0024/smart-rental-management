# Original Provider Profile + real backend — 23 October 2026

## Scope and user entry points

- Provider Inbox bottom Profile and drawer View profile open WorkspaceProfile,
  which composes the original ProviderProfileScreen. Drawer Edit profile and
  the profile pencil open the original ProviderEditProfileScreen.
- Original navy hero, card structure, unified tinted category headers, sticky
  Save changes, themes and discard confirmation remain. Connected screens never
  read/write ProviderStore or invent seeded providers when a request fails.
- This change is the Provider's own profile/editor, not Owner profile/settings,
  a public Provider directory redesign or a new photo-upload implementation.

## Authoritative data and honest UI

- my_provider_profile reads only auth.uid() after a Provider-role check. It
  returns account phone, Auth email, saved bio/service area/private origin/rates,
  actual service UUIDs/weekly slots, approval and server-derived statistics.
- Completed-job count is derived from currently Completed bookings, review
  average/count from booking_review, and active workload from Accepted/In Progress
  intervals overlapping the next seven days. Nothing uses display-name identity.
- Connected UI removes fake Online, distance, request-match and on-time numbers.
  Missing rating/on-time performance display a dash, not a fabricated 4.8/96%.
  The old offline preview remains isolated and its existing behavior is retained.
- No provider display_name is invented/backfilled for existing accounts. The
  self-view uses an explicit Your provider profile placeholder until edited.
- Display name, avatar color and phone-sharing preference are new persisted
  self-profile fields; this does not claim the existing Owner directory/search
  UI already consumes the new display-name field. Public-directory exposure is
  unchanged and still excludes phone/email/private origin.

## Save and privacy contract

- Migration 021 adds display_name, avatar_color_index, show_phone_to_owners
  (default FALSE) and profile_revision; mutable field writes use the dedicated
  save_my_provider_profile RPC with an explicit allowlist and server validation.
- Name/bio, selected catalogue UUIDs, hourly/daily rates, area/private origin,
  phone, avatar color and sharing preference save in ONE transaction. It calls
  the existing capability guard; a confirmed-job service-removal conflict rolls
  back every related field. Rates retain cents; daily-only Providers are supported.
  Existing booking quote snapshots are untouched.
- The RPC cannot accept email, provider ID, role, approval, scores, statistics,
  arbitrary availability or a client-supplied revision value as an editable field.
  Its empty search_path, explicit auth.uid() filter and Provider-role check do not
  rely on client UI checks. Existing RLS/table grants remain restricted.
- Expected profile_revision and original phone implement optimistic concurrency.
  A profile update or capability change invalidates stale drafts; account phone
  changes are compared under row locks. No silent overwrite/retry occurs.
- Uncertain network failure blocks duplicate Save until the user checks/reloads
  the saved record. Drafts survive errors. Success is shown only after server
  acknowledgement. A session change clears the route; repository read/write
  results and binding generation checks reject stale-session data.
- Phone sharing is NOT directory-public. booking_provider_contact returns only
  the opted-in Provider phone to the booking Owner while Accepted/In Progress;
  strangers, completed/pending bookings and anonymous users cannot retrieve it.
  This introduces the protected lookup API, not a new Owner phone/dialer UI.
- Email stays read-only; it requires a separately verified Auth change flow.
  Avatar color persists, but photo picker/upload is explicitly unavailable in
  connected mode. No temporary local image is claimed to be saved.
- Working slots remain the separately protected real setup flow. Profile Save
  never replaces weekly hours. Returning from setup refreshes read-only slots;
  service/profile changes require checking the saved profile before draft reuse.

## Verification and deployment

- Full Flutter regression suite: 539 passed. New tests cover actual navigation,
  projection, exact decimals/daily-only/null values, own identity, session and
  route races, RPC allowlists/revision conflicts, save acknowledgement, uncertain
  writes, form validation, read-only email and light/dark 320px/200% text layouts.
- Synthetic PostgreSQL 17 full 001–021 chain and prior security/concurrency suites
  pass with BOTH legacy broad defaults and disabled defaults. New rollback-only
  fixtures test atomicity, stale revisions, guarded services, privileged/email
  field injection, unknown services, decimal and daily-only rates, private contact
  lookup, own-Provider isolation and Owner/anonymous denial.
- Linked project checked before CLI dry run: only 021 pending. Then 021 applied
  only to smart-rental-staging / gqtetdavmrautoojaqrk. Original project
  dvakrwalnqpcmgirmlct is not changed. No hosted approval/business fixture/profile
  edit was performed by this task.
- Hosted SDK smoke: reusable Provider reads the new own-profile RPC with real
  Auth identity/email and revision; Owner is denied 42501. Both role login/home/
  schedule checks and Provider three-period earnings reads still pass. Local test
  sign-out does not revoke the user's existing emulator session globally.
- Android Staging debug APK compiled. Four original-profile/editor light/dark
  widget captures inspected; screenshots contain SYNTHETIC offline fixtures, not
  a claimed real-device capture or hosted save acceptance.
- Targeted analysis: style infos remain, no errors/warnings. Scoped secret-pattern
  check is not a whole-repository security signoff.

## Remaining acceptance

- User emulator: Hot Restart, Provider Profile → Edit, save desired details, leave
  and reopen to check persistence; test real session-expiry/offline behavior.
- No populated hosted booking completion/payment flow, photo upload, verified
  email change, production rollout or production-ready certification is claimed.
