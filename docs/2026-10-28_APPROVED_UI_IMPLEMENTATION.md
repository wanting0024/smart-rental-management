# Approved UI batch 2–11 — 28 October 2026

Implemented in the existing connected Flutter screens. Existing Staging accounts
and cloud records are retained. No hosted database, permission, account or
Production deployment was changed by this UI batch.

| Item | Implemented behaviour |
| --- | --- |
| 2 Request cleaning | Four steps: unit/service, date/time, eligible Provider, review/send. Only final submission creates a request; the existing idempotency token and uncertain-response lookup remain. Changing search inputs invalidates the provider and quote. |
| 3 Providers | Service information cards with name, area, service tags, rates, rating and profile action. Availability is checked by the actual search, submit and accept operations. |
| 4 My properties | Units grouped by normalized Building name; distinct towers and unit records remain separate. Group counts explicitly describe units shown, while portfolio totals keep the server aggregate and cursor pagination. |
| 5 Bookings | All/Pending/Ongoing/History controls plus a permanently visible History dropdown. It is disabled outside History and resets to All history when changing tabs. Returning from details keeps the existing list state. |
| 6 Details | Owner Pending edit uses the existing revision RPC with fixed duration and quote. Active messaging is prominent, terminal conversations are read-only, and server-controlled actions remain authoritative. Owner details retain the original bottom destinations and Back. |
| 7 Status history | Actual events displayed as a vertical timeline with MYT timestamps and recorded reasons; Owner/Provider actor labels are shown when the booking participant IDs identify the event actor. Older-event pagination remains. |
| 8 Provider Earnings | Compact vertical bars on a shared scale, including genuine zero buckets. Tap changes the bar colour and shows period amount/jobs. No background selection stripe. Real connected amounts remain completed job quote value before fees, not settled net payouts. |
| 9 Rental-unit form | Shared Add/Edit form with an editable Building combobox: saved owner buildings, filtering while typing, new names permitted, optional address prefill only when empty. Bedroom options and existing time-slot controls remain. |
| 10 Feedback | Inline validation, short save-success feedback, and cancellation/discard confirmation with explicit consequences. Unknown writes keep drafts and require readback rather than silently submitting duplicates. |
| 11 Profile/settings | Grouped profile lists and separate Appearance, Notifications, Privacy/security and existing About/help pages. Appearance supports System/Light/Dark with device persistence. Provider services, rates, availability and phone privacy are retained. |

## Honest capability boundaries

- Messaging remains writable only for Accepted/In Progress, as required by the
  current backend. Pending explains when chatting opens instead of presenting
  a send action that will fail. Closed conversations retain read access.
- Notification preferences control unread highlights/badges on this device,
  scoped to the current account. They neither delete records nor mark them
  read. Device push delivery is not enabled and is labelled accordingly.
- Password recovery keeps the existing signed-out email flow. Synthetic test
  emails cannot receive recovery messages. Account deletion/export are clearly
  unavailable; no simulated successful deletion is presented.
- Support simulation and draft policies retain their explicit labels. No
  unapproved support contact, platform fee or payment settlement is invented.

## Validation

- 874 Flutter regression tests passed, including 14 new interaction/layout
  checks for combobox selection, account-separated preferences, History state,
  zero/selected chart bars, Pending revision safety, preservation of combined notes and settings.
- Narrow 320px layouts, 200% text, light/dark rendering and changed golden
  images were checked. Code analysis for lib/test has no errors or warnings;
  existing informational style lints remain.
- Installing on both phones and doing the paired Owner/Provider UAT is still
  a manual acceptance step; automated checks do not mark that UAT complete.

Package verification results are recorded with the final APK in output/uat.
