# Provider primary-page navigation — 23 October 2026

- User requested that My Schedule retain the bottom menu. Connected Schedule now
  shows the same Inbox / Schedule / Earnings / Profile bar, with Schedule selected.
  Earnings and the Profile view also retain this shared primary navigation in
  loading/error/success states. Profile editing keeps its original Save bar instead.
- No calendar, earnings, profile form design or backend/security contracts changed.
  Owner navigation and offline preview routing are not restructured by this task.
- Shared ProviderBottomNav replaces the duplicated Inbox tab definition. Selected
  states are available to accessibility services; labels wrap up to two lines and
  height accounts for larger text without covering content.
- Primary destination routes use named /provider-tab/* routes: a switch replaces
  the current primary tab instead of stacking duplicate Schedule/Earnings/Profile
  routes. Inbox returns to the existing authenticated home; tapping the active
  tab is a no-op. Back from a primary tab returns to Inbox. Detail/edit/availability
  routes keep their existing push/pop and unsaved-edit guards.
- In-flight duplicate taps are guarded. Existing ConnectedRouteLifecycle observers
  still pause covered routes and dispose replaced route bindings/subscriptions;
  no offstage IndexedStack or additional background feeds are introduced.
- Five new navigation tests cover selected state and actual Schedule integration,
  bounded route depth through repeated switches, Inbox/back, duplicate taps,
  failure-state navigation and all primary pages at 320x568 / 200% text in both
  themes. Tests load the app's real Inter font rather than substitute Ahem metrics.
- Full Flutter suite: 544 passed; Staging Android debug APK compiled. Targeted
  analysis has style infos only, no errors/warnings. Updated light/dark Schedule
  captures use synthetic offline fixtures, not an emulator or hosted-data claim.
- No hosted database changes. User emulator navigation acceptance remains pending.
