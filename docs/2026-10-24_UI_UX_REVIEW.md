# P2-3 — cross-page UI/UX review

Follow-up after the audit: Owner My properties, Providers request/search and
Profile now retain the original bottom menu and Back, including loading/error.
Property details keep their CTA above the menu. Tab replacement and a carried
root-selection callback prevent duplicate roots / stacked primary pages and
preserve Home/Bookings after detail navigation. Normal Save/Discard editors are
not converted into primary tabs. Preview category Back/Profile paths checked.
22 added navigation cases; latest `output/owner-navigation-focused.log` 29 passed,
`owner-navigation-regression.log` 788 passed, `owner-navigation-android-build.log`
debug built, analysis no errors/warnings (style infos), scan 152 lib files PASS.
No cloud calls/accounts/data changed; P2-4 remains pending. The 766-test audit
evidence below is the earlier baseline, not an additional manual acceptance.

24 October 2026. Code / local automated / rendered-widget review passed.
Original connected Owner/Provider UI retained. Not a public-launch certificate,
all-device guarantee, full screen-reader audit or completed human/device UAT.

## Actual problems repaired

1. Owner dashboard statistics used fixed 92dp cards. At 320px / 200% font the
   narrow count/icon row wrapped digits, overflowing vertically by 97 / 163px.
   Cards now have minimum heights and natural content, with full-width reflow
   at enlarged text on narrow layouts. Quick-action content likewise grows,
   without one-line clipping. Normal-font original grid is preserved.
2. Owner navigation was fixed 64dp / single-line. It now grows with font scale,
   allows two lines and provides full selected button labels and semantic tap
   actions. Long labels may still wrap at extreme scale; they remain available
   in semantics, without reducing the user's requested font scale.
3. Shared unsaved confirmation overflowed by 16px with a 280dp simulated keyboard
   at 320x568 / 200%. Shared and Provider editor confirmations now scroll; Keep
   editing and Discard remain accessible. Owner info dialogs also scroll.
4. Owner editing used a lazy ListView for FormFields. Offscreen disposal could
   remove earlier validators from FormState when scrolling to Save. A scrollable
   non-lazy Column retains those fields. Invalid earlier entries block saving;
   busy / uncertain saves and session checks remain intact. The original editor
   is exposed for direct offline tests, not replaced with another design.
5. Cancellation buttons now stack at narrow widths/large text. Inline reason and
   Other-description errors remain discoverable; Other clearly says required,
   and still offers its required input if optional comments are disabled. Selected
   reasons expose semantics; destructive actions use theme error/onError colors.

No booking lifecycle, permission, pricing, cancellation entitlement or backend
rules changed. No extra remote login/signup, cloud fixture, password rotation,
database migration, deletion, dependency change or PDF.

## Connected surface coverage

This matrix combines new stress cases with the existing regression suite. It is
not a claim that every permutation of every historical preview screen was tested.
The current authenticated routes and shared original presentation components are
the acceptance scope; offline widget loaders are not fake production data paths.

| Surface | Evidence / checks |
|---|---|
| Sign-in / both-role registration | workspace_login / connected_registration / new P2 audit: 320px/200%, keyboard, invalid inputs do not authenticate, role/mode switch; client is a non-network test fixture. |
| Recovery / new-password destination | password_recovery / reset_password / new audit: neutral confirmation, sanitized failure/retry, field matching, narrow keyboard, ready/invalid/uncertain/cleanup/complete states. No real mail/password mutation. |
| Owner dashboard / Provider Inbox | owner_home_backend_binding / provider_inbox_backend_binding / new audit: real binding classes with offline rows, long populated names, loading/empty/error, both themes, 320x568/200%, lazy scroll content and state isolation. |
| Primary menus / drawers / returning | provider_persistent_navigation / connected_route_lifecycle / session_boundary / new audit: bounded route stack, retained Provider bar, busy-repeat guard, background handling; Owner full-label semantic tap and 48dp target checks. |
| Owner profile / edit | owner_workspace / new audit: actual connected presentation, invalid earlier field blocks Save after scroll, pending disables submit, uncertain saves keep draft and forbid blind retry, sign-in identity read-only. |
| Properties / detail / add-edit | owner_workspace / connected_property_form / connected_responsive / recovery/action tests: populated layouts, window locks, validation, preserved entries, keyboard Save and discard/back. |
| Provider matching / request / booking actions | connected_booking_search / submission / responsive / cancellation / new audit: service/interval options, quote context, loading/empty/error retry, reason selection and required comments. Connected Providers uses the supported request/search path, not an uncertified general directory. |
| Schedule (both roles) | schedule_backend_ui / calendar_edges / persistent_navigation: loading/partial/ready/error, 320x568/200%, selected-day/list behavior, week navigation and persistent Provider menu. |
| Earnings / Owner spending / Provider statistics | earnings_backend_ui / history_layout / owner_workspace / stats_layout: all three ranges, trend/history/details, priced vs missing data, small screen/large font, both themes and no fake payout. |
| Provider profile / editor / availability | profile_backend_ui / provider_setup / responsive / new audit: read-only fields, dirty/stale/uncertain state, keyboard and pending Save, scrollable discard, setup loading/empty/error retry and slot dialogs. |
| Messages / unread / thread / status history | conversation_inbox / message_unread / booking_messages / pagination / new audit: long content, viewport receipts, own badges, keyboard, disabled closed-state send, loading/empty/error retry, account isolation. |
| Evidence / completion / review | connected_evidence / review / photo_preparation / action_feedback / responsive / new audit: picker cancellation/failure and decoder guards, missing evidence blocks completion, keyboard remarks/rating, state retry and retained drafts. Native picker permissions are still manual UAT. |
| Notifications / Help / support / Terms / Privacy | notification_help / prototype_support / legal_drafts: loaded/empty/failure, filters/read action, support simulation/identity reset, explicitly unapproved documents; both themes and narrow/200% cases. |
| Shared loading/empty/error, SWR and action notices | connected_state_panel / snapshot / ui_states / action_feedback / stale_while_revalidate: retry actually reloads, ordinary refresh silent, failure does not pretend empty/saved, raw exception text not exposed. |

## Verification outputs

- 78 added cases: 76 new `test/p2_ui_ux_audit_test.dart` cases and two additional
  `test/reset_password_screen_test.dart` large-text/keyboard scenarios.
- `output/p2-ui-audit.log`: 85 focused tests passed, including existing reset tests.
- `output/p2-ui-regression.log`: 766 default Flutter tests passed.
- `output/p2-ui-android-build.log`: Staging Android debug APK built.
- `output/p2-ui-analysis.log`: no errors/warnings; style infos remain.
- `output/p2-ui-security.log`: secret-pattern PASS across 151 lib source files.
- Rendered-widget visual inspection: `output/p2-ui/owner-actions-light.png`,
  `owner-actions-dark.png`, and normal original Owner layout in
  `output/workspace-ui/owner-light.png`. These are actual offline widget captures,
  not native/emulator screenshots or screenshots of real account data.

First-pass logs retain failures found during audit; latest audit/regression logs
are authoritative for the repaired code. New audit treats missed-tap warnings as
fatal. Retries must invoke another read and remove the failure state; a simulated
tap on an offscreen label cannot count as passing. Fake keyboard insets verify
layout only, not a real Android input method.

## P2-4 — pending user device checklist

Hot Restart the current Staging App, using the SAME dedicated fixed Owner /
Provider fixture accounts. Do not register new identities just to repeat tests.
Store no passwords, email addresses or tokens in screenshots/reports.

- [ ] Record device/emulator, Android version, build and theme. No device pass
      recorded yet; do not populate the checklist from automation results.
- [ ] Owner: navigate dashboard/properties/profile/request and back; large text,
      scrolling, keyboard, invalid fields and unsaved Keep editing / Discard.
- [ ] Provider: Inbox -> Schedule -> Earnings -> Profile keeps navigation;
      select all three earnings ranges, review loaded data and back to Inbox.
- [ ] Both roles: open same supported active booking and exchange marked [TEST]
      messages; check unread list vs opening chat, fresh login persistence and
      foreground polling delay. Existing closed threads are intentionally read-only.
- [ ] Capture/select synthetic evidence, cancel picker, deny/regrant permission;
      photo/remarks completion and Owner review on a supported test appointment.
- [ ] Physically disconnect/reconnect network; confirm kept entries, honest errors,
      retry/readback and no duplicate operation after an uncertain response.
- [ ] Test light/dark and enlarged system text; check actual keyboard, bottom inset,
      notches/gesture navigation and orientation on the target device.
- [ ] Enable TalkBack: verify focus order, labels, selected tabs, actions and error
      announcements. Automated touch-target/label checks are not TalkBack testing.

Record actual observations/pass/fail; repair observed defects before accepting
P2-4. Actual email delivery, payments/payouts, push and recurring appointments are
not implemented and must not be demonstrated as real successes. Human usability
observation in UI_UX_TASKS.md remains separate from passing widget tests.
