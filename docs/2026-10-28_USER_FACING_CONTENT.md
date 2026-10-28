# User-facing content and data presentation — 28 October 2026

The connected app uses its existing Supabase dataset and real save/send/status
operations. This batch changes presentation and removes development-only UI;
it does not turn simulated responses into live services.

- Removed the connected environment badge in About/help, integration-progress
  footer at login, and test-account wording in recovery information.
- Changed the Android launcher label to Smart Rental. Other platform display
  names and web metadata use the same name. Technical application identifiers
  and signing identity remain unchanged for in-place updates.
- Removed the simulated support route from About/help. With no real support
  address supplied, the Help center remains and no fictional ticket or reply
  can be created from the connected app. A configured real contact can still
  be displayed later. The user confirmed this Help-center-only choice.
- Rewrote help and user information to describe current service behaviour.
  Legal material retains its unpublished review status; no operator identity,
  legal approval, account-deletion process or payment service is invented.
- Removed Sprint/demo placeholder copy from UI fallbacks. Unavailable actions
  do not claim an email was sent, a report submitted or a link copied. Local
  drawer sign-out now performs the existing session sign-out action.
- Imported `[UAT]` labels and known synthetic notes are formatted at display
  boundaries for properties, booking cards, calendar, notifications, earnings,
  message previews, chat text and status reasons. Ordinary user text containing
  “test”, authentication emails, identifiers, amounts and status values remain
  unchanged. Original images and their content are retained.
- Existing property forms and Pending revisions preserve unchanged original
  field values when saving, so display cleanup cannot silently rename existing
  records or discard imported notes. New units reuse the existing building key,
  avoiding duplicate server groups caused by the display label.

No database migration, bulk rename, record deletion, account/password reset,
Production deployment or fabricated real-service evidence was performed.

880 Flutter regression tests passed, including six new content/data-preservation
checks. Lib/test analysis has no errors or warnings; informational style lints
remain. Updated login and both-theme About/help rendering were inspected.

The new Android package is version 0.1.8+9. Phone UAT remains a manual check;
successful automation does not claim all launch requirements are complete.
