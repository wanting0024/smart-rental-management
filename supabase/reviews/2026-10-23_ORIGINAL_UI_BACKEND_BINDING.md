# Original Owner home / Provider Inbox bound to Staging

Scope approved by user: keep the existing UI, bind Owner home and Provider Inbox
to the real backend, do not create another visual design. Original hosted project
dvakrwalnqpcmgirmlct was not queried or changed. No migrations/privileges changed.

## Implementation

- The authenticated root now composes OwnerHomeScreen / ProviderInboxScreen,
  not the alternate ConnectedWorkspaceScreen home. Original hero, cards,
  theme/navigation components and local preview behavior remain in place.
- WorkspaceHome owns route/app lifecycle; WorkspaceBinding owns the bounded
  booking feed and overview. Background/covered routes pause subscriptions;
  resume rechecks data. Identity changes clear data and ignore late results.
- Server cards are projected into the existing display model only. The legacy
  DemoBooking class name is not a data source: no BookingStore writes, fixture
  rates/provider lookup, completion evidence or invented participant name.
  Unknown status, missing offset or reversed server interval fail closed.
  Malaysia wall-clock display remains consistent across device timezones.
- Owner account-wide counts use owner_dashboard_summary rather than the first
  20 loaded bookings. Loaded booking selection/search/paging are labelled as
  partial where appropriate; unknown/error values are not silently zero.
- Provider feed uses authenticated identity/RLS, not display-name filtering.
  Approval/rating/completed count come from its profile. Inbox subset counts
  are qualified as loaded; no calculated preview income/payout is substituted.
- Existing protected request/add-property/setup flows remain reachable.
  Booking cards route to a single-ID protected detail using the existing
  acceptance, cancellation, history, messages, photo and review operations.
  No local acceptance/decline or direct status UPDATE is used in connected mode.
- Connected drawer reflects the current account, removes preview role-switching
  and uses real sign-out. Preview keeps its existing behavior.

## Honest scope boundaries

- Owner Properties currently opens the existing add-unit form; the full original
  property-list screen has not been bound. Its quick-action copy says Add rental
  unit. Providers opens the existing real request-specific search.
- Provider Profile currently opens existing services/availability setup, not the
  full original profile editor. Approval remains administrator-controlled.
- Full original Schedule/Earnings/Profile/notifications/global messages screens
  are not certified connected. Unsupported routes explicitly report unavailable
  and never navigate to seeded pages. Per-booking messages/evidence still use
  existing protected routes. Downstream form/detail visual parity is future scope.
- The existing simplified ConnectedWorkspaceScreen remains as legacy functionality
  and a protected single-booking detail implementation, not the signed-in homepage.
- No complete booking E2E or native-device acceptance is claimed by this change.

## Verification actually executed

- Complete Flutter suite: **462 passed**, including preview regressions, new
  binding/projection/session-boundary cases, original Owner UI with server totals,
  navigation callbacks, errors/retry/pagination, Provider identity filtering,
  readable states, and narrow dark UI tests.
- Opt-in installed-SDK hosted smoke: **2 passed**, using existing private test
  credentials only in memory. Both actual password logins, App identity, bounded
  feeds, Owner full summary and Provider pending profile loaded successfully.
  Initial Realtime reset may start a newer overview; the smoke waits for it to
  settle instead of incorrectly treating that legitimate load as failure.
  Temporary verification sessions were signed out locally. No fixture/business
  records were seeded by this test. Do not commit credentials or JWTs.
- Android debug APK with ignored pinned Staging config: compiled successfully.
  This is not production signing and the phone has not been inspected remotely.
- Targeted analysis: no errors/warnings with --no-fatal-infos; style-only info
  diagnostics remain. It is not claimed lint-clean.
- Scoped secret-pattern scan of 15 integration source/test files: no findings.
  This is separate from the previously documented whole-tree scanner limitations.
- Rendered 390x844 empty-state widget captures, light/dark for both roles, saved
  under output/workspace-ui/. Inspected the images; these use offline fixtures
  through the same binding, not a logged-in browser or hosted-user screenshot.
  Material/Roboto/Inter fonts are loaded for meaningful visual QA.
- Local browser interaction was disabled by Work settings. No browser/phone visual
  acceptance is claimed. Existing localhost Flutter server was hot restarted;
  users must refresh the browser or stop/run their Android Studio session.

## Repeatable commands

```powershell
flutter test
flutter test tool/staging_workspace_smoke_test.dart --dart-define=RUN_STAGING_READ_SMOKE=true
flutter build apk --debug --dart-define-from-file=supabase/backend_config.staging.local.json
```

The hosted smoke is deliberately outside the default test/ tree and opt-in. It
requires the ignored local test/client files and never prints their contents.

Next hands-on check: restart the Staging build on Android, log in as Owner A and
Provider A, confirm the original layouts with real empty state/pending approval,
then continue the explicitly guided approval/setup and booking E2E milestones.
