import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/workspace_binding.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';

Map<String, dynamic> card(String id, {String status = 'Pending'}) => {
      'booking_id': id,
      'unit_name': 'SERVER Unit $id',
      'building_name': 'SERVER Building',
      'service_name': 'Standard cleaning',
      'current_status': status,
      'requested_start_at': '2030-01-01T02:00:00Z',
      'requested_end_at': '2030-01-01T04:00:00Z',
      'instructions': 'Server instructions',
    };

const totals = OwnerDashboardSnapshot(
    propertyCount: 8, pendingCount: 37, activeCount: 11, completedCount: 82);

CursorFeed<Map<String, dynamic>> feed({
  required Future<CursorPage<Map<String, dynamic>>> Function(PageCursor?) load,
  Stream<String?>? sessions,
  String? Function()? current,
}) =>
    CursorFeed(
        active: false,
        loadPage: load,
        idOf: (row) => row['booking_id'] as String,
        compare: (_, __) => 0,
        ownerUserId: 'account-a',
        currentUserId: current,
        sessionChanges: sessions);

void main() {
  test(
      'server projection preserves UUID/status/MYT without fixture rates or proof',
      () {
    final row = WorkspaceBinding.projectBooking(
        card('server-uuid', status: 'In Progress'));
    expect(row.id, 'server-uuid');
    expect(row.property, 'SERVER Unit server-uuid, SERVER Building');
    expect(row.status.label, 'In Progress');
    expect(row.scheduledStart.hour, 10);
    expect(row.scheduledEnd.hour, 12);
    expect(row.providerName, isNull);
    expect(row.hourlyRateAtBooking, isNull);
    expect(row.hasProof, isFalse);
  });

  test('unknown status and offsetless or reversed times fail closed', () {
    for (final row in [
      card('a', status: 'Unknown'),
      {...card('b'), 'requested_start_at': '2030-01-01T02:00:00'},
      {...card('c'), 'requested_end_at': '2030-01-01T01:00:00Z'}
    ]) {
      expect(() => WorkspaceBinding.projectBooking(row), throwsFormatException);
    }
  });

  test(
      'bounded page and complete server counts remain distinct; next page de-duplicates',
      () async {
    final cursors = <PageCursor?>[];
    final binding = WorkspaceBinding(
        provider: false,
        loadOverview: () async => totals,
        feed: feed(load: (cursor) async {
          cursors.add(cursor);
          return cursor == null
              ? CursorPage(
                  items: [card('a')], next: const PageCursor('2030-01-01', 'a'))
              : CursorPage(items: [card('a'), card('b')]);
        }));
    addTearDown(binding.dispose);
    binding.setActive(true);
    await Future<void>.delayed(Duration.zero);
    expect(binding.loading, isFalse);
    expect(binding.bookings.length, 1);
    expect(binding.ownerSummary!.pendingCount, 37);
    expect(binding.hasMore, isTrue);
    await binding.loadMore();
    expect(binding.bookings.length, 2);
    expect(binding.hasMore, isFalse);
    expect(cursors.last!.id, 'a');
  });

  test('overview failure is visible and retry never introduces demo data',
      () async {
    var fail = true;
    final binding = WorkspaceBinding(
        provider: false,
        loadOverview: () async {
          if (fail) throw StateError('synthetic failure');
          return totals;
        },
        feed: feed(load: (_) async => const CursorPage(items: [])));
    addTearDown(binding.dispose);
    binding.setActive(true);
    await Future<void>.delayed(Duration.zero);
    expect(binding.error, isNotNull);
    expect(binding.ownerSummary, isNull);
    expect(binding.bookings, isEmpty);
    fail = false;
    await binding.refresh();
    expect(binding.error, isNull);
    expect(binding.ownerSummary!.propertyCount, 8);
  });

  test(
      'identity boundary clears rows/profile and ignores an in-flight overview',
      () async {
    final sessions = StreamController<String?>.broadcast();
    var current = 'account-a';
    final result = Completer<dynamic>();
    final binding = WorkspaceBinding(
        provider: true,
        loadOverview: () => result.future,
        feed: feed(
            load: (_) async => CursorPage(items: [card('private')]),
            sessions: sessions.stream,
            current: () => current));
    binding.setActive(true);
    await Future<void>.delayed(Duration.zero);
    expect(binding.bookings.length, 1);
    current = 'account-b';
    sessions.add(current);
    await Future<void>.delayed(Duration.zero);
    result.complete({'bio': 'account-a private profile'});
    await Future<void>.delayed(Duration.zero);
    expect(binding.bookings, isEmpty);
    expect(binding.providerProfile, isNull);
    expect(binding.error, isNotNull);
    binding.dispose();
    await sessions.close();
  });

  test('inactive or disposed binding ignores late overview results', () async {
    for (final dispose in [false, true]) {
      final result = Completer<dynamic>();
      final binding = WorkspaceBinding(
          provider: false,
          loadOverview: () => result.future,
          feed: feed(load: (_) async => const CursorPage(items: [])));
      binding.setActive(true);
      if (dispose) {
        binding.dispose();
      } else {
        binding.setActive(false);
      }
      result.complete(totals);
      await Future<void>.delayed(Duration.zero);
      expect(binding.ownerSummary, isNull);
      if (!dispose) binding.dispose();
    }
  });
}
