# UI/UX and accessibility work

These tasks apply to the real authenticated Owner and Cleaning Service Provider flows, not only the local preview. Completing a visual component does not imply hosted Supabase or device verification.

## Latest acceptance — P2-3, 24 October 2026

Cross-page code / automated / rendered-widget audit passed: 85 focused and 766
full Flutter tests; Android Staging debug build; analysis no errors/warnings,
style infos remain; secret-pattern scan 151 lib files PASS. Original UI preserved.

Repairs: Owner large-text statistic/quick-action fixed-height overflow; navigation
scaling/selected/full-label semantic actions; short-keyboard discard dialogs;
Owner form validators staying mounted after scroll; inline cancellation reason /
required Other feedback, stacked buttons and theme error colors.

Evidence, route-to-test matrix and pending manual checklist:
`docs/2026-10-24_UI_UX_REVIEW.md`. No hosted/cloud calls or account creation in
this audit. Fixed Staging credentials were neither regenerated nor changed.

P2-4 manual phone/emulator and human usability remain pending. In particular,
physical keyboard/gestures, safe areas, camera/gallery permissions, TalkBack,
actual connectivity changes and populated two-role operation are not certified
by these widget tests. The dated milestones below are historical snapshots;
later hosted P1 acceptance is tracked in PROTOTYPE_ACCEPTANCE.md.

## Earlier local milestones — 22 October 2026

1. **Real-flow design alignment — completed locally (22 October 2026).** The authenticated Owner/Provider home now uses shared navy/sky components, booking context, Malaysia-time labels, readable status and next-step actions. This is a UI/code milestone; migration 012 still needs hosted deployment and real-account validation.
2. **UI state model — completed locally (22 October 2026).** Authenticated home, request/provider search, service/availability setup, booking history, messages, completion evidence and reviews now distinguish loading, empty, loaded, and failed states. Retry starts a fresh read or stream subscription; chat keeps unsent text. Widget tests simulate failed reads and successful retries, and phone-sized empty/error previews are stored in `test/goldens/`. Hosted Supabase and real-device validation remain outstanding.
3. **Recoverable errors — completed locally (22 October 2026).** Booking creation, booking transitions, chat, rating, evidence uploads and completion now read back the server's result after an uncertain response. Stable request/message IDs prevent duplicate retries. Property creation pauses further submission until the Owner checks My properties; availability writes require a fresh read before retry. Draft instructions, messages, ratings, remarks and service selections stay in the current screen. Technical exceptions are logged but not shown raw. Hosted two-account and real-network testing remain required.
4. **Accessibility baseline — completed locally (22 October 2026).** Shared light/dark body and hint text meet the 4.5:1 test threshold on their normal surfaces, standard buttons request at least 48dp, and Owner/Provider booking actions have contextual screen-reader labels. Booking date/time controls, chat messages, summary counts and before/after evidence controls also have clearer labels. Widget accessibility checks cover the connected booking card in both themes. Real-device TalkBack/VoiceOver, high-text-scale and end-to-end route audits remain outstanding.
5. **Responsive and keyboard matrix — completed locally (22 October 2026).** Added ten regression scenarios across 320×568, 320×640 and 390×844 portrait layouts, 150%/200% text and simulated 280/320dp keyboard insets. Fixed request-dropdown overflow, scrollable loading/error panels, compact chat input, property Save above the keyboard, scalable login controls and a large-text booking header. Evidence/review actions remain reachable with the keyboard open. Golden preview: `test/goldens/connected_provider_large_text.png`. Actual Android/iOS keyboards, safe-area behaviour and device-specific scaling still need hands-on verification.
6. **Action feedback — completed locally (22 October 2026).** Booking changes, request submission, photo uploads/completion, reviews and Provider availability use persistent progress/outcome feedback. A shared frame preserves form state and remains scrollable in a short keyboard viewport. Save controls are disabled during writes, uncertain outcomes still trigger the existing readback checks, and editing a review/service selection clears its previous success notice. Delayed-write, failure/retry, draft-preservation and persistent-success tests pass. Preview: `test/goldens/connected_review_saved_feedback.png`. Real hosted-account and device validation remains pending.
7. **Human usability validation — preparation ready; observations pending (22 October 2026).** `tool/usability/index.html` and its session guide provide six Owner and six Provider tasks, anonymous records, timers, guidance counts, actual/dry-run separation, CSV/JSON export and a guarded NFR3.2 evaluation. Five Node tests and an isolated browser rehearsal verify the recorder, not human usability. Hosted prerequisites and missing connected features are documented in `tool/usability/README.md`. This task remains incomplete until real users are observed, issues are reviewed and relevant fixes are retested.
