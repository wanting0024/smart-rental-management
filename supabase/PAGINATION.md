# Cursor pagination — local implementation, hosted verification pending

## Scope and contract

Migration `202610220015_cursor_pagination.sql` must follow migrations 001–014.
It has been exercised only against disposable local PostgreSQL, not the hosted
project. Review and apply it manually in staging before using this connected UI.
Do not deploy it separately from the preceding migrations or bypass the
environment marker required by migration 013.

| Connected view | RPC | Descending order |
| --- | --- | --- |
| Owner/Provider bookings | `page_my_bookings` | `created_at`, `booking_id` |
| Booking chat | `page_booking_messages` | `created_at`, `message_id` |
| Booking status history | `page_booking_history` | `changed_at`, `status_history_id` |

Each read returns `items`, `has_more`, and `next_cursor`. The client requests 20
records; the server accepts 1–50 and reads at most one extra row to determine
whether an older page exists. Pass the returned timestamp string and UUID back
unchanged: parsing and reserializing a timestamp in a browser can lose database
precision. Both cursor fields must be present or both absent. Equal timestamps
are ordered by UUID, not by an assumption that timestamps are unique.

Bookings are newest-created first, **not** a chronological appointment calendar.
Chat reverses the visual list so newest messages appear at the bottom and the
older-message button is at the top. Status history is newest first. Explicit
loaded counts are not presented as total counts. `owner_dashboard_summary`
calculates complete Owner property/Pending/active/Completed counts on the server,
not from the first 20 bookings. `booking_cards_by_ids` is restricted to 1–50
participant-owned IDs and enriches only those cards with unit/service context.

All page RPCs require authentication and check booking participation explicitly.
The Owner summary also checks the Owner role. The internal page-packing helper
is not exposed to application roles. These checks are important because the RPCs
use `security definer` with an empty search path.

## Loading, retries and concurrent changes

- One load-more operation is allowed at a time; repeated taps do not multiply
  requests. A failed older-page read keeps the current cursor and loaded records.
  Retry requests that same page. Chat drafts are not cleared by page failures.
- Records are merged by ID. A late page from an earlier refresh/session is ignored;
  it cannot overwrite current state. Observed delete events leave tombstones so
  an in-flight older page cannot resurrect that row.
- Booking/chat channels use change notifications rather than an initial unbounded
  table stream. A changed loaded record or new record is fetched by ID. Updates to
  unloaded records do not cause a full historical download. The installed SDK
  still receives the normal change payload; this is **not** ID-only Realtime
  bandwidth or a new server-side selected-columns feature.
- On subscription/reconnection the latest bounded page is reloaded to recover
  missed events. Previously loaded older pages are reset and can be loaded again.
  A verified chat send also refreshes the latest page. Initial-load changes are
  queued and replayed after the page resolves.
- Explicitly loaded pages remain in memory until the feed is disposed/refreshed.
  This is not a disk cache, offline mode or a capped-memory cache. Cache policy is
  a separate task. Opening status history loads a fresh paged snapshot; it does
  not create a separate live status-history subscription.
- Pages are not a cross-request database snapshot. Keyset boundaries avoid offset
  shifts from newer inserts; they do not freeze every record against concurrent
  updates. Publication, RLS and reconnect behavior still need real hosted tests.
- Filtered administrative DELETE delivery must not be assumed: replica identity
  and Supabase Realtime behavior require staging checks. Normal app users cannot
  directly delete bookings/messages/history. A refresh/rejoin removes records
  no longer returned; no broad unfiltered delete channel was added.

The feed cancels its channel on disposal. Route visibility, app backgrounding
and logout lifecycle coordination are now implemented locally; see
`SUBSCRIPTION_LIFECYCLE.md` for the separate tests and remaining device checks.
Properties, provider directories and any other large lists are not claimed as
paginated by this change.

## Verification and manual staging checks

Local tests cover 61 same-timestamp Owner bookings, an unrelated Owner booking,
67 messages, and 58 history rows (including the automatic initial history row).
They verify complete traversal, unique IDs, page limits, microsecond boundaries,
new-insert stability, context visibility, full summary counts, and outsider/anon
denial. Fixtures are synthetic and run only in a disposable database.

Flutter tests cover serialized taps, exact-cursor retry, draft retention, stale
responses, changes during initial loading, realtime merge ordering, deletion
tombstones, disposal, history append, and 320px/200%-text keyboard layout. Golden
previews use injected test records, not a live authenticated Supabase session.

After manually applying the full migration chain in staging:

1. Sign in as distinct Owner/Provider/outsider users. Create enough labelled test
   records to cross two page boundaries. Verify each role sees only permitted data.
2. Verify the network panel returns no more than 20 list rows per client request;
   Owner summary totals must remain correct before older pages are loaded.
3. Disconnect before loading older messages. Verify the current messages/draft
   remain, reconnect and retry without gaps or duplicated IDs.
4. Send a message/change a booking from the other device during paging and during
   a connection gap. Verify targeted refresh and the bounded reconnect reset.
5. Check same-time records, terminal history and long text on actual devices.
   Record query timings and channel counts; do not infer production capacity
   from small local fixtures.

No hosted data, environment marker, project key, migration or publication was
changed by these local implementation/test runs.
