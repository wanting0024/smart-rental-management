# Subscription lifecycle — local implementation, staging/device checks pending

## Activation rules

`ConnectedRouteScope` supplies one observer per Navigator. The connected workspace,
booking chat and history sheet activate their feeds only when their route is
current and Flutter reports the app as resumed. A modal dialog/sheet covers the
route below for this purpose, even if part of that route remains visible.

| Current foreground view | Expected settled application Realtime channels |
| --- | --- |
| Connected Owner/Provider workspace | 1 booking-list channel |
| Booking chat | 2: messages and the single booking's status |
| History sheet, property form, provider setup, evidence or review | 0; reads are snapshots/explicit operations |
| Background/inactive app or signed-out login | 0 after teardown completes |

Channels are logical subscriptions, not necessarily separate WebSockets. Two
channels can share the client's one socket. Auth-state listeners are local event
listeners and are not counted as Postgres Realtime subscriptions. These counts
describe the current connected implementation, not the separate in-memory preview
or future modules added by other group members.

## Teardown and recovery

- Background/inactive events stop feeds immediately; they do not depend on a new
  frame being rendered. Activation waits until a safe frame boundary. Covered
  routes do not restart merely because the app resumes.
- Subscriptions are cancelled, not paused. Pausing a Dart listener would buffer
  events without releasing the backend channel. Generation guards reject late
  page/status/live-read responses after suspension, disposal or session changes.
- All application channels use `pagedRowChanges`. A per-client gate serializes
  channel creation and teardown. The installed SDK's `removeChannel` starts a
  last-socket disconnect without awaiting it; an immediate replacement can then
  encounter the closing socket. The helper instead awaits `channel.unsubscribe`
  (which removes the SDK registry entry), then awaits `realtime.disconnect` only
  when no channels remain. New managed channels wait for this operation. It does
  not remove unrelated channels indiscriminately.
- Server cleanup is not instantaneous: an unresponsive peer can require the SDK
  timeout. New subscription work waits for orderly teardown instead of opening
  duplicates. In-flight HTTP reads are not physically aborted, but their obsolete
  results are ignored. Cancelling a view cannot undo a write already committed by
  the server; RPC permission and transaction checks remain authoritative.
- Returning to a view reloads its bounded newest page. Previously loaded older
  pages can be loaded again. Chat keeps the unsent draft in memory while the route
  exists, but clears its status snapshot and does not enable sending until the
  fresh status permits it. This is not persistent/offline draft storage.
- Interrupted/closed live streams show a reconnect action. Reconnect replaces the
  failed subscription and refreshes records, rather than only making a one-time
  read against a dead channel. There is no new rapid polling/retry timer.
- Feeds are captured once when a route/sheet is opened, not recreated inside its
  builder on theme, keyboard or layout changes.

All newly added application channels should use this helper. Mixing custom raw
subscribe/disconnect operations on the same client outside the gate would need a
separate lifecycle review.

## Account boundary

The app listens to Supabase Auth changes with an error handler. A confirmed
sign-out or change from one authenticated user ID to another clears the in-memory
user session and replaces the Navigator, removing pushed private routes and back
navigation to the old account. The route observer itself belongs to this app
instance, not a global Navigator shared between app instances.

Each paged repository feed also captures the creating user ID, listens for auth
changes even while inactive, clears its records on identity change and becomes
permanently unusable. It checks the current identity after asynchronous reads as
well, before accepting their results. A late session-restoration/role lookup
cannot sign the previous account back into the UI. Sign-out clears the local
Provider ID/role/onboarding state.

A same-user token refresh does not reset the Navigator or duplicate channels.
A transient auth-stream network error is handled without inventing a sign-out or
changing the account role. This is client-side isolation, not a replacement for
server RLS or JWT validation, nor a new claim that session revocation has been
tested online.

## Local verification

- Feed tests: inactive startup makes no list read/channel; twenty leave/return
  cycles settle at one active listener and disposal at zero; rapid return awaits
  a deliberately delayed cancellation; stale reads, same-ID refresh, sign-out,
  account switch and explicit reconnect behavior are covered.
- Widget tests: pushed pages and modal sheets stop the route below; background
  teardown occurs without drawing another frame; resumption rechecks status;
  a draft survives and an old Accepted snapshot cannot enable sending while the
  fresh status is pending. Root-navigation fixtures verify private pushed routes
  disappear on identity change, back cannot reopen them, and late restoration
  cannot reopen a signed-out session.
- Installed-SDK integration: a loopback WebSocket protocol fixture performs twenty
  immediate joins/cancellations. The client's channel registry returns to zero on
  each cycle and peer sockets close. This reproduced the last-socket restart race
  before the gate was added and passes with the gate. A peer may observe socket
  closure before reading the final `phx_leave`; twenty received leave packets are
  not asserted. The fixture is **not** Supabase's hosted service or an RLS test.
- All 318 Flutter tests passed, including the existing UI/business-rule suite.
  The release Web build passed. `test/goldens/connected_chat_reconnect.png` is an
  inspected widget preview with synthetic records and a simulated connection
  interruption, not a live conversation.

No SQL migration was added or applied in this step. No hosted settings, data,
accounts, publication or credentials were changed.

## Manual staging and real-device checks still required

1. After manually deploying/configuring the existing migration chain in staging,
   use two distinct Owner/Provider accounts. Confirm live bookings/messages reach
   only authorized participants and the expected channel counts settle after
   navigation. Compare client diagnostics with Supabase Realtime monitoring.
2. Repeat workspace → chat → back and workspace → history → close at least twenty
   times. Also open/dismiss a confirmation dialog and change the theme. Check for
   duplicate updates, registry growth, stuck loading and uncaught errors.
3. On actual Android/iOS devices, background the app, lock the screen and switch
   apps/browser tabs. Change a booking from the other device during the gap.
   Foreground return must show the latest state before permitting a write. Verify
   the draft remains while the same route is alive.
4. Disconnect/reconnect Wi-Fi, test token-refresh failures, expire/revoke a session,
   sign out in another supported browser tab and switch accounts. Old private
   screens/data must disappear on a confirmed auth boundary. Check logs without
   recording access tokens, passwords or private messages.
5. Test forced process termination separately. Flutter does not guarantee every
   lifecycle notification before an abrupt kill; on next launch the app must
   restore/verify the session and read a fresh snapshot. Foreground channels do
   not constitute background push notifications or prove FCM delivery.

Relevant primary documentation:
[Flutter lifecycle states](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html),
[RouteObserver](https://api.flutter.dev/flutter/widgets/RouteObserver-class.html),
[Supabase auth events](https://supabase.com/docs/reference/dart/auth-onauthstatechange),
[Supabase channel removal](https://supabase.com/docs/reference/dart/removechannel).

Next separate protection task: bounded/authenticated caching, invalidation and
real image-compression verification. Loaded page state is not yet that cache.
