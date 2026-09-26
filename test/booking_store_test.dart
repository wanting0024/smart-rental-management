// test/booking_store_test.dart
// Verifies the BookingStore (the real-time pub/sub) and the filter helpers.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/widgets/filter_sheet.dart';

void main() {
  group('BookingStore', () {
    test('starts with 5 seeded bookings (4 base + 1 recurring)', () {
      final store = BookingStore();
      expect(store.bookings.length, 5);
    });

    test('add() creates a requested booking and notifies listeners', () {
      final store = BookingStore();
      var notified = 0;
      store.addListener(() => notified++);
      final b = store.add(
        property: 'Unit X-99',
        serviceType: 'Standard',
        scheduledStart: DateTime(2026, 8, 1, 10),
        scheduledEnd: DateTime(2026, 8, 1, 12),
      );
      expect(b.status, DemoBookingStatus.requested);
      expect(b.providerName, isNull);
      expect(store.bookings.length, 6);
      expect(notified, 1);
      expect(store.lastUpdatedId, b.id);
    });

    test('updateStatus() with valid transition notifies and updates', () {
      final store = BookingStore();
      final b = store.bookings.firstWhere((x) => x.status == DemoBookingStatus.requested);
      var notified = 0;
      store.addListener(() => notified++);
      final ok = store.updateStatus(b.id, DemoBookingStatus.accepted);
      expect(ok, isTrue);
      expect(store.byId(b.id)!.status, DemoBookingStatus.accepted);
      expect(notified, 1);
    });

    test('updateStatus() with invalid transition returns false and does not change', () {
      final store = BookingStore();
      final b = store.bookings.firstWhere((x) => x.status == DemoBookingStatus.completed);
      var notified = 0;
      store.addListener(() => notified++);
      final ok = store.updateStatus(b.id, DemoBookingStatus.accepted);
      expect(ok, isFalse);
      expect(store.byId(b.id)!.status, DemoBookingStatus.completed);
      expect(notified, 0);
    });

    test('FSM matches ADR-0004 for all transitions', () {
      final store = BookingStore();
      // requested -> accepted
      expect(BookingStore.debugIsValidTransition(DemoBookingStatus.requested, DemoBookingStatus.accepted), isTrue);
      // accepted -> scheduled
      expect(BookingStore.debugIsValidTransition(DemoBookingStatus.accepted, DemoBookingStatus.scheduled), isTrue);
      // scheduled -> inProgress
      expect(BookingStore.debugIsValidTransition(DemoBookingStatus.scheduled, DemoBookingStatus.inProgress), isTrue);
      // inProgress -> completed
      expect(BookingStore.debugIsValidTransition(DemoBookingStatus.inProgress, DemoBookingStatus.completed), isTrue);
      // completed -> anything = false
      for (final s in DemoBookingStatus.values) {
        expect(BookingStore.debugIsValidTransition(DemoBookingStatus.completed, s), isFalse);
      }
    });

    test('forProvider filters by provider name', () {
      final store = BookingStore();
      final providerA = store.forProvider('Provider A');
      expect(providerA.every((b) => b.providerName == 'Provider A'), isTrue);
    });

    test('forProperty filters by property name', () {
      final store = BookingStore();
      final unitA12 = store.forProperty('Unit A-12, Menara Suria');
      expect(unitA12.every((b) => b.property == 'Unit A-12, Menara Suria'), isTrue);
    });
  });

  group('applyFilter', () {
    final source = DemoBooking.all();

    test('null status filter = no status filter applied', () {
      final result = applyFilter(source, FilterResult.empty);
      expect(result.length, source.length);
    });

    test('status filter narrows results', () {
      final result = applyFilter(source, const FilterResult(
        statusFilter: DemoBookingStatus.completed,
        sortMode: SortMode.newest,
        propertyFilter: null,
      ));
      expect(result.every((b) => b.status == DemoBookingStatus.completed), isTrue);
    });

    test('property filter narrows results', () {
      final result = applyFilter(source, const FilterResult(
        statusFilter: null,
        sortMode: SortMode.newest,
        propertyFilter: 'Unit A-12, Menara Suria',
      ));
      expect(result.every((b) => b.property == 'Unit A-12, Menara Suria'), isTrue);
    });

    test('sortMode.newest sorts by scheduledStart descending', () {
      final result = applyFilter(source, const FilterResult(
        statusFilter: null,
        sortMode: SortMode.newest,
        propertyFilter: null,
      ));
      for (int i = 0; i < result.length - 1; i++) {
        expect(result[i].scheduledStart.isAfter(result[i + 1].scheduledStart) ||
            result[i].scheduledStart.isAtSameMomentAs(result[i + 1].scheduledStart), isTrue);
      }
    });

    test('sortMode.byProperty sorts alphabetically', () {
      final result = applyFilter(source, const FilterResult(
        statusFilter: null,
        sortMode: SortMode.byProperty,
        propertyFilter: null,
      ));
      for (int i = 0; i < result.length - 1; i++) {
        expect(result[i].property.compareTo(result[i + 1].property) <= 0, isTrue);
      }
    });
  });
}
