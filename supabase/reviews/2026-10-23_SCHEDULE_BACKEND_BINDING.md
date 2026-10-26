# Original Schedule + real backend — first of three remaining UI integrations

User requested original Schedule, Earnings, Profile connected one at a time.
This milestone completes Schedule only. Earnings and full original Profile
remain pending; no payment, payout or profile-completeness claim is made.

## Scope and data path

- Original Owner ScheduleScreen and ProviderScheduleScreen remain the visual
  components. Existing colors, date strip, calendar grid, summary cards and
  booking cards are reused. Original preview actions remain isolated.
- Owner More -> Schedule and Provider bottom navigation/drawer -> Schedule now
  open a lifecycle-owned authenticated WorkspaceSchedule composition wrapper.
- Calendar reads are interval-overlap queries for the selected MYT week, not
  the first page of recently-created dashboard requests. One request fetches
  at most 21 IDs (20 + cursor sentinel), then the existing participant-scoped
  booking_cards_by_ids RPC fetches at most 20 safe display cards. Empty pages
  skip the second request. No migration, new grants or RLS changes were needed.
- The existing creation-time/UUID keyset retains PostgreSQL timestamp precision.
  The query has no creation-date range restriction, so a booking created months
  ago can still appear in the selected future week. Week boundaries are MYT
  midnight converted to UTC, independent of the phone's local timezone.
- Calendar and definitive counts stay unavailable while a week is loading,
  incomplete, failed or its live connection is interrupted. Paging/retry and
  week navigation remain visible; an incomplete snapshot is never presented as
  free time. A calendar with no appointments is not provider availability.
- Provider only Accepted/In Progress bookings reserve displayed time. Owner may
  see Pending (explicitly not reserved), Accepted, In Progress and Completed;
  Cancelled/Declined are not displayed. No display-name ownership filtering.
- Selected-day cards follow the selected date/week rather than always listing
  today's jobs. Provider statistics refer to the selected week, clipped booked
  hours and remaining unfinished jobs in that week, not all-time totals.
- Existing protected single-booking actions and services/availability setup are
  reused. Schedule taps never invoke local preview status writes.

## Edge cases and lifecycle

- Route/background deactivation stops the week feed; resume rechecks it. Changing
  week disposes old pages and ignores late replies. Session changes clear data and
  cannot create a new-week feed under the old screen identity.
- CursorFeed now has an opt-in recheckUnloadedUpdates flag, enabled only for the
  range calendar: an update can move an unseen booking into the visible week.
  ReadOne rechecks the participant-scoped card and interval; movements out of
  the week or cancellation remove it. Other paged feeds keep their old default.
- The original 07:00–21:00 grid expands when real appointments require earlier
  or later hours. Cross-midnight intervals are sliced into each overlapping day;
  an appointment ending at midnight does not also occupy the next day.
  Overlapping blocks use separate lanes; short blocks avoid text overflow.
- Short screens / large text use a scrollable minimum-height version of the same
  layout, not a new design. Selected-day cards grow with text scaling. Fixed
  preview Owner-card overflow was also corrected.
- Both connected Schedule app bars expose Refresh schedule.

## Evidence

- Complete Flutter suite: 498 passed after the Schedule implementation and
  responsive fixes. This includes 19 Schedule UI cases, 7 installed-SDK loopback
  repository protocol cases, 4 binding cases, 2 range/calendar-edge cases, 4
  rendered light/dark checks, and existing preview/security/lifecycle regressions.
- The responsive tests initially caught 3 issues (short phone 200% text in each
  role, and preview Owner booking card). All were repaired before handoff; no
  assertions were removed or tests skipped to hide the failures.
- Real Staging installed-SDK smoke: both existing synthetic roles logged in,
  queried their own selected-week schedule and existing home data successfully.
  Temporary sessions signed out locally. The test accounts have no appointments:
  this is real Auth/API/RLS empty-week integration, NOT populated/cross-account
  booking E2E or evidence of a physical-device session.
- Android debug APK built with pinned ignored Staging settings. Compilation is
  not production signing or phone acceptance.
- Targeted analysis: no errors/warnings with non-fatal style infos; not lint-clean.
- Scoped scanner across 16 Schedule integration files: no secret-pattern findings.
- Light/dark 390x844 rendered-widget captures were inspected under
  output/schedule-ui/. Populated records in these pictures are explicit offline
  synthetic fixtures; they were not inserted into Staging.
- No hosted business data, approvals, Auth settings or original-project state
  was modified. No migrations were deployed in this milestone.

## Repeatable checks and next step

```powershell
flutter test
flutter test tool/staging_workspace_smoke_test.dart --dart-define=RUN_STAGING_READ_SMOKE=true
flutter build apk --debug --dart-define-from-file=supabase/backend_config.staging.local.json
```

Refresh the localhost page or stop/run Android Studio with the same Staging
define. User hands-on check: Owner More -> Schedule, then Provider -> Schedule.
Empty accounts should show a real empty week, not preview appointments.
Next implementation milestone: original Earnings UI with authoritative booked
amount/date-range aggregation; do not invent payment/payout confirmation.
