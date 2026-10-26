# Global booking conversations — 24 October 2026

Scope: connect existing Owner Messages quick action and Provider drawer to the
original ChatListScreen layout and the existing protected booking-chat screen.
This is real Staging data, not a simulated conversation store.

## Contract and security

- Migration 023 adds only `page_my_conversations`. Explicit authenticated EXECUTE;
  revoked PUBLIC/anon/service_role access; SECURITY DEFINER with empty search_path
  and auth.uid-derived actor checked against user_account. No new direct table
  permissions, receipt table or client-supplied recipient identity.
- One thread per booking. Accepted/In Progress bookings appear even before a
  message is sent. Pending/declined/cancelled/complete bookings without a message
  are not presented as existing chats; actual previous chats remain readable.
  Existing send RPC still independently enforces participant, live booking state,
  rate limits and idempotency. This change does not enable closed-thread sending.
- Projection: booking ID/status, participant-facing Provider display name (or
  explicit role fallback), unit/building/service, 160-character last-message
  preview and timestamp. No email/phone/private Provider origin/property address.
  Owner has no display-name field yet: show Property Owner, not an invented name.
- Twenty rows per App request, timestamp+booking UUID keyset with server as_of.
  Subsequent pages use the same boundary, so later messages cannot move an older
  thread across its page boundary. Metadata/status remains current, not a full
  historical database snapshot. Search is bounded, literal case-insensitive name/
  unit/building/service search across the server result, not only loaded rows.

## Client behavior

- Connected branch never reads preview MessageStore or filters by display name.
  Preview-only mock pins/unread counts/Unread filter are not shown. Persisted chat
  read/unread receipts, global unread badges and device message push are NOT
  implemented by this migration; do not claim new messages have been read.
- Pull-to-refresh, explicit load-more/retry, debounced search, initial/empty/error
  states. Routine same-query refresh retains existing results silently; failure
  warns, authorization/malformed response discards stale data. Account change
  clears results and rejects late requests.
- While visible, silently rechecks the first page every 30 seconds. Hidden or
  background lists stop polling; loading older pages also suspends polling so
  history is not collapsed while reading. Returning from a thread revalidates immediately.
  This is bounded polling, NOT instantaneous global Realtime delivery. Existing
  per-booking chat keeps its realtime subscription/lifecycle behavior.
- Thread entry reuses a single real booking-chat helper from both routes.
  Search input and preview limits account for Unicode; narrow light/dark 200%
  text tests preserve original list styling.

## Evidence and limits

- Local 001–023 migration bundle + all prior SQL regressions passed both legacy
  and disabled default-grant profiles. conversation_inbox.sql checks role scope,
  empty active chat, closed history, privacy, tied timestamps, cursor paging,
  literal search, validation, unauthenticated denial and later-message boundary.
- CLI dry-run listed only 202610240023_conversation_inbox.sql. Deployed only to
  linked smart-rental-staging gqtetdavmrautoojaqrk; original project untouched.
- Hosted Owner/Provider authenticated bounded reads passed. These fixed accounts
  do not yet have an approved/available populated booking scenario. An empty list
  is expected and is NOT evidence of a full two-device message exchange.
- Automated Flutter/UI/repository and Android evidence is recorded in
  output/conversations-*.log. User Hot Restart/populated emulator acceptance is
  still required. No hosted booking/message fixtures were created for this step.
- Verification: 608 Flutter tests passed; hosted read smoke 2 passed; Android
  Staging debug APK built; lib analysis has style infos, no errors/warnings;
  secret-pattern scan passed across 139 lib files. No manual emulator pass claimed.
