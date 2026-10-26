# Session-scoped stale-while-revalidate — 23 October 2026

## Scope and visible behavior

Original UI and navigation remain in use. Connected Owner home / Provider Inbox,
Schedule, Earnings, Profile view and Services & availability can reuse an eligible
same-account snapshot while independently refreshing from the authenticated
backend. This changes perceived loading, not backend authorization or write rules.
It does not eliminate network requests or turn the app into an offline writer.

- Cold / expired / invalidated entry: normal first-load panel; no invented data.
- Eligible saved snapshot: show content immediately and refresh silently, without
  an updating banner or progress text on each navigation (user-requested follow-up).
- Successful refresh: replace with server result, including a genuinely empty one.
- Transport/server failure: retain saved content with an explicit stale notice and
  retry. A first-read failure still shows an error, not an empty success state.
- Authorization, identity or decoding failure: discard private cached content.
- Profile editor bypasses cached baselines and still uses revision/contact conflict
  checks. Availability is disabled for pointer, keyboard and action handlers until
  fresh data is confirmed. Uncertain writes still require read-after-write checks.

## Cache boundaries

`SessionSnapshotCache` belongs to one backend provider (one project/client), uses
only memory, and is scoped to the authenticated identity and generation. Reuse TTL
is five minutes; at most 16 entries / 2 MiB estimated serialized payload. This is
not an exact Dart heap measurement. Reading an entry does not renew its age.
An already visible failed-refresh view may remain on screen, clearly stale, until
retry/leave; TTL controls reuse on entry rather than silently blanking that view.

Main identity changes, recovery transitions, memory pressure and disposal clear
snapshots. Mutation wrappers invalidate both before and after writes, even on an
uncertain outcome. Concurrent writes block cache publication, and generation leases
reject old in-flight reads. Reads spanning an invalidation are not labeled fresh.
Backend queries still use the existing RLS/RPC; eligibility, quotes, status checks,
contact access and saves never use cache entries as authorization or write inputs.

Schedule key = role + exact UTC boundaries of the MYT week. Only the first bounded
page is stored, preserving its next cursor. A partial page never draws an apparently
  free calendar. Complete saved calendars refresh silently; failures remain explicitly
stale. Earnings key = period + MYT calendar day; server whole-range aggregates,
as-of history cursor and money semantics remain intact. No fees/payouts are invented.
Profile view and edit have separate cache-use policies. Overview uses an explicit
wrapper so a successfully loaded null Provider profile is not confused with a miss.

Realtime remains route/lifecycle-scoped; no hidden-page live channels are added.
Generic CursorFeed behavior is opt-in, leaving unrelated history/chat feeds intact.
Current UI is not rebuilt as a second design. Narrow Schedule status banners reserve
scrollable height rather than compressing the calendar at enlarged text sizes.

## Verification

- `output/swr-full-test.log`: 560 passed (544 baseline + 16 added).
- `output/swr-targeted-test.log`: 28 SWR/repository tests passed.
- `output/swr-staging-read-smoke.log`: Owner and Provider login/read cases passed,
  including Schedule, three Earnings ranges, own Profile and Owner denial. Uses
  local sign-out, not global revocation of the user's emulator session.
- `output/swr-android-build.log`: Staging Android debug APK compiled.
- `output/swr-analysis.log`: no errors/warnings; existing/new style infos remain.
- `output/swr-source-security-scan.log`: secret-pattern scan of lib passed; not a
  complete security audit or proof of credential revocation.

Added tests cover TTL/LRU/budget, logout epochs, write races/unknown outcomes,
known-empty cache entries, initial/refresh/authorization failures, exact week and
role isolation through the real repository adapter, partial-calendar safety, editor
fresh baselines, Earnings period races, null overviews, visible cached states,
read-only availability and Schedule at 320x568 / 200% text in both themes.
Existing golden tests pass without updating their approved baselines.

No schema migration, cloud settings change or hosted business-data mutation was
performed. Emulator visual acceptance is not claimed. After Hot Restart, visit a
main page once, switch away/back, then check saved-data updating behavior. Profile
editing must still wait for its fresh baseline. Test airplane mode only after a
successful read: saved content should remain labeled stale, with retry; restore
network and retry to verify replacement. Do not deliberately submit writes offline.
