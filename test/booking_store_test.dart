// test/booking_store_test.dart
// Verifies repository notifications, lifecycle enforcement, and filtering.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/widgets/filter_sheet.dart';

void main() {
  group('BookingStore', () {
    test('starts with five seeded bookings', () {
      expect(BookingStore().bookings.length, 5);
    });

    test('add creates a Pending request and notifies listeners', () {
      final store = BookingStore();
      var notifications = 0;
      store.addListener(() => notifications++);

      final booking = store.add(
        property: 'Unit X-99',
        serviceType: 'Standard cleaning',
        scheduledStart: DateTime(2030, 8, 1, 10),
        scheduledEnd: DateTime(2030, 8, 1, 12),
        providerName: 'Provider X',
      );

      expect(booking.status, BookingStatus.pending);
      expect(store.lastUpdatedId, booking.id);
      expect(notifications, 1);
    });

    test('valid transition updates the record and timestamp', () {
      final store = BookingStore();
      final booking = store.bookings
          .firstWhere((item) => item.status == BookingStatus.pending);

      expect(store.updateStatus(booking.id, BookingStatus.accepted), isTrue);
      expect(store.byId(booking.id)!.status, BookingStatus.accepted);
      expect(store.byId(booking.id)!.acceptedAt, isNotNull);
    });

    test('invalid transition is rejected without changing the record', () {
      final store = BookingStore();
      final booking = store.bookings
          .firstWhere((item) => item.status == BookingStatus.completed);

      expect(store.updateStatus(booking.id, BookingStatus.accepted), isFalse);
      expect(store.byId(booking.id)!.status, BookingStatus.completed);
    });

    test('provider and property filters return only matching records', () {
      final store = BookingStore();
      expect(
        store.forProvider('Provider A').every(
              (booking) => booking.providerName == 'Provider A',
            ),
        isTrue,
      );
      expect(
        store.forProperty('Unit A-12, Menara Suria').every(
              (booking) => booking.property == 'Unit A-12, Menara Suria',
            ),
        isTrue,
      );
    });
  });

  group('applyFilter', () {
    final source = DemoBooking.all();

    test('empty filter retains every record', () {
      expect(applyFilter(source, FilterResult.empty).length, source.length);
    });

    test('status and property filters narrow the result', () {
      final completed = applyFilter(
        source,
        const FilterResult(
          statusFilter: BookingStatus.completed,
          sortMode: SortMode.newest,
          propertyFilter: null,
        ),
      );
      expect(
        completed.every((booking) => booking.status == BookingStatus.completed),
        isTrue,
      );

      final unitA = applyFilter(
        source,
        const FilterResult(
          statusFilter: null,
          sortMode: SortMode.newest,
          propertyFilter: 'Unit A-12, Menara Suria',
        ),
      );
      expect(
        unitA.every(
          (booking) => booking.property == 'Unit A-12, Menara Suria',
        ),
        isTrue,
      );
    });

    test('newest sorting is descending by requested service time', () {
      final result = applyFilter(
        source,
        const FilterResult(
          statusFilter: null,
          sortMode: SortMode.newest,
          propertyFilter: null,
        ),
      );
      for (var i = 0; i < result.length - 1; i++) {
        expect(
          !result[i].scheduledStart.isBefore(result[i + 1].scheduledStart),
          isTrue,
        );
      }
    });
  });
}
