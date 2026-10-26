import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/notification_binding.dart';
import 'package:rental_app_demo/services/backend/notification_snapshot.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'support/notification_fixture.dart';

void main() {
  test(
      'read during background refresh persists receipt and rejects older response',
      () async {
    final old = Completer<NotificationSnapshot>();
    var calls = 0;
    var read = false;
    final b = NotificationBinding(
        load: (filter, {before, asOf}) async {
          if (++calls == 2) return old.future;
          return notificationReport(read: read);
        },
        mark: ({ids, throughAt}) async {
          read = true;
        },
        userId: notificationActor,
        currentUserId: () => notificationActor,
        sessions: const Stream.empty(),
        changes: () => const Stream.empty());
    b.setActive(true);
    await Future<void>.delayed(Duration.zero);
    final refresh = b.refresh();
    expect(b.loading, true);
    expect(await b.read(id: notificationId), true);
    expect(b.snapshot!.unread, 0);
    old.complete(notificationReport());
    await refresh;
    expect(b.snapshot!.unread, 0);
    b.dispose();
  });
  test('notification identity, filter, status and date are validated', () {
    for (final patch in [
      {'recipient_id': 'other'},
      {'filter': 'wrong'},
      {'unread_count': -1},
      {
        'items': [
          {
            ...((notificationJson()['items'] as List).first
                as Map<String, dynamic>),
            'event_status': 'Payment'
          }
        ]
      },
      {
        'items': [
          {
            ...((notificationJson()['items'] as List).first
                as Map<String, dynamic>),
            'happened_at': '2026-10-23T13:00:00'
          }
        ]
      }
    ]) {
      expect(
          () => NotificationSnapshot.parse({...notificationJson(), ...patch},
              notificationActor, NotificationFilter.all),
          throwsFormatException);
    }
    expect(
        () => notificationReport(filter: NotificationFilter.unread, read: true),
        throwsFormatException);
  });
  test('filter races ignore previous responses and never mix pages', () async {
    final old = Completer<NotificationSnapshot>();
    final b = NotificationBinding(
        load: (filter, {before, asOf}) async => filter == NotificationFilter.all
            ? old.future
            : notificationReport(filter: filter),
        mark: ({ids, throughAt}) async {},
        userId: notificationActor,
        currentUserId: () => notificationActor,
        sessions: const Stream.empty(),
        changes: () => const Stream.empty());
    b.setActive(true);
    b.select(NotificationFilter.unread);
    await Future<void>.delayed(Duration.zero);
    expect(b.snapshot!.filter, NotificationFilter.unread);
    old.complete(notificationReport());
    await Future<void>.delayed(Duration.zero);
    expect(b.snapshot!.filter, NotificationFilter.unread);
    b.dispose();
  });
  test('session change clears private events and ignores late read', () async {
    final sessions = StreamController<String?>.broadcast();
    String? actor = notificationActor;
    final pending = Completer<NotificationSnapshot>();
    final b = NotificationBinding(
        load: (_, {before, asOf}) => pending.future,
        mark: ({ids, throughAt}) async {},
        userId: notificationActor,
        currentUserId: () => actor,
        sessions: sessions.stream,
        changes: () => const Stream.empty());
    b.setActive(true);
    actor = 'other';
    sessions.add(actor);
    await Future<void>.delayed(Duration.zero);
    pending.complete(notificationReport());
    await Future<void>.delayed(Duration.zero);
    expect(b.sessionEnded, true);
    expect(b.snapshot, isNull);
    b.dispose();
    await sessions.close();
  });
  test(
      'read receipt is not optimistic, and mark-all uses server as-of boundary',
      () async {
    var read = false;
    final pending = Completer<void>();
    List<String>? capturedIds;
    String? through;
    final b = NotificationBinding(
        load: (filter, {before, asOf}) async =>
            notificationReport(filter: filter, read: read),
        mark: ({ids, throughAt}) async {
          capturedIds = ids;
          through = throughAt;
          await pending.future;
          read = true;
        },
        userId: notificationActor,
        currentUserId: () => notificationActor,
        sessions: const Stream.empty(),
        changes: () => const Stream.empty());
    b.setActive(true);
    await Future<void>.delayed(Duration.zero);
    final write = b.read(all: true);
    expect(b.snapshot!.unread, 1);
    expect(b.busy, true);
    expect(capturedIds, isNull);
    expect(through, b.snapshot!.asOf);
    pending.complete();
    expect(await write, true);
    expect(b.snapshot!.unread, 0);
    b.dispose();
  });
  test('read timeout reconciles saved state, never reports confirmed success',
      () async {
    var read = false;
    final b = NotificationBinding(
        load: (filter, {before, asOf}) async =>
            notificationReport(filter: filter, read: read),
        mark: ({ids, throughAt}) async {
          read = true;
          throw TimeoutException('uncertain');
        },
        userId: notificationActor,
        currentUserId: () => notificationActor,
        sessions: const Stream.empty(),
        changes: () => const Stream.empty());
    b.setActive(true);
    await Future<void>.delayed(Duration.zero);
    expect(await b.read(id: notificationId), false);
    expect(b.snapshot!.items.single.read, true);
    b.dispose();
  });
  test('network refresh keeps events, authorization denial clears them',
      () async {
    Object? fail;
    final b = NotificationBinding(
        load: (filter, {before, asOf}) async {
          if (fail != null) throw fail;
          return notificationReport(filter: filter);
        },
        mark: ({ids, throughAt}) async {},
        userId: notificationActor,
        currentUserId: () => notificationActor,
        sessions: const Stream.empty(),
        changes: () => const Stream.empty());
    b.setActive(true);
    await Future<void>.delayed(Duration.zero);
    fail = StateError('offline');
    await b.refresh();
    expect(b.snapshot, isNotNull);
    expect(b.refreshError, isNotNull);
    fail = const PostgrestException(message: 'denied', code: '42501');
    await b.refresh();
    expect(b.snapshot, isNull);
    expect(b.error, isNotNull);
    b.dispose();
  });
  test('older events retain server snapshot boundary and bounded paging',
      () async {
    var pages = 0;
    final b = NotificationBinding(
        load: (filter, {before, asOf}) async {
          pages++;
          if (before != null) {
            expect(asOf, '2026-10-23T14:00:00+00:00');
            return notificationReport(
                id: '33333333-3333-4333-8333-333333333333');
          }
          return notificationReport(more: true);
        },
        mark: ({ids, throughAt}) async {},
        userId: notificationActor,
        currentUserId: () => notificationActor,
        sessions: const Stream.empty(),
        changes: () => const Stream.empty());
    b.setActive(true);
    await Future<void>.delayed(Duration.zero);
    await b.loadMore();
    expect(pages, 2);
    expect(b.snapshot!.items.length, 2);
    expect(b.snapshot!.next, isNull);
    b.dispose();
  });
  test('realtime work stops while covered or disposed', () async {
    final live = StreamController<PageChange>.broadcast();
    var reads = 0;
    final b = NotificationBinding(
        load: (filter, {before, asOf}) async {
          reads++;
          return notificationReport();
        },
        mark: ({ids, throughAt}) async {},
        userId: notificationActor,
        currentUserId: () => notificationActor,
        sessions: const Stream.empty(),
        changes: () => live.stream);
    b.setActive(true);
    await Future<void>.delayed(Duration.zero);
    b.setActive(false);
    await Future<void>.delayed(Duration.zero);
    live.add(const PageChange(PageChangeKind.reset));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(reads, 1);
    expect(live.hasListener, false);
    b.dispose();
    await live.close();
  });
}
