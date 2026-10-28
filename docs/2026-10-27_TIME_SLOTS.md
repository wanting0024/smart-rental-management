# Shared time-slot selection

All eight time-of-day entry paths now use the shared
`lib/widgets/time_slot_picker.dart` component: connected cleaning requests,
connected/local property windows, connected/local weekly availability, local
new requests, pending-request edits, and local Profile working hours.
The connected Profile continues to open its real weekly availability editor.

The original screens, bottom navigation, navy/sky theme and save callbacks are
retained. A time button selects and closes the sheet immediately. Day-part
filters keep the common half-hour buttons short. More times provides buttons
for every exact minute in a chosen hour; saved off-grid values are never rounded.
Times use 24-hour labels and Malaysia time. Cancel/Back leaves the value unchanged.
The sheet sizes to its content and scrolls when needed, including at 320px and
200% text scale. Its colors and fonts inherit the existing light/dark themes.

## Availability and business rules

- Time buttons are requested/declared times, not promises of an available
  provider. No server-confirmed availability badge or reservation is invented.
- The connected request picker reads the selected property's cleaning window,
  excludes elapsed start times on the selected Malaysian calendar day, and bounds
  the end by the existing maximum eight-hour duration.
- Provider search still calls the real eligibility service. Changing a time
  clears old providers, quote selections and request retry tokens. Creation and
  acceptance keep their existing backend rechecks and conflict protection.
- Property end times must follow the start. If a changed start invalidates an
  existing connected end, the end must be chosen again.
- Working slots retain the minimum two-hour duration and overlap checks. The
  local Profile's old one-hour automatic adjustment/message now uses the same
  existing two-hour rule. No server policy or rate calculation was changed.
- The local availability model retains its supported 24:00 end boundary.
  Connected PostgreSQL time fields remain within their existing 00:00–23:59
  contract. No migration, permission change or cloud data write is required.

## Validation

- All 860 Flutter tests pass, including ten new picker tests and the updated
  existing request/property/availability flows.
- Tests cover tap-to-select, dismissal, exact minute preservation, bounded and
  empty ranges, the local 24:00 boundary, and light/dark 320px / 200% layouts.
- Two property screenshot baselines were visually reviewed and updated for
  the clearer cleaning-window labels. Native connected-screen picker captures
  are in the ignored `output/time-slots-ui/` directory.
- Android Staging package version: 0.1.5+6. Runtime configuration/credentials
  and generated packages stay outside source control. Phone acceptance remains
  a separate UAT step.
- Analyzer: zero errors and warnings; existing style infos remain. Source and
  package pattern scans pass (160 source / 757 combined files). The scanner now
  preserves malformed binary separators rather than dropping them and joining
  unrelated AOT strings. Thirteen scanner tests include true-key detection on
  malformed UTF-8/UTF-16 boundaries and the false-positive regression.
- APK signer matches the previously distributed 0.1.4 build. The copied package
  is 96,007,094 bytes; SHA-256 is
  `CC1718FD2E472A8B5269A84300A027162A0D91D0683AAE152744A2EC6D503BB8`.
