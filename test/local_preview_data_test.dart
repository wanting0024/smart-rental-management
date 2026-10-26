import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/models/local_preview_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';

void main() {
  final reference = DateTime(2026, 9, 28, 11);

  test('preview covers all six lifecycle states with coherent records', () {
    final bookings = LocalPreviewData.bookings(referenceTime: reference);
    final propertyNames = DemoProperty.all.map((p) => p.display).toSet();
    final providers = {for (final p in DemoProvider.seeded()) p.name: p};
    const serviceIds = {
      'Standard cleaning': 'standard',
      'Deep cleaning': 'deep',
      'Window cleaning': 'window',
    };

    expect(bookings.length, 15);
    expect(bookings.map((b) => b.id).toSet().length, bookings.length);
    expect(bookings.map((b) => b.status).toSet(), BookingStatus.values.toSet());
    for (final booking in bookings) {
      expect(propertyNames, contains(booking.property));
      expect(providers, contains(booking.providerName));
      expect(booking.scheduledEnd.isAfter(booking.scheduledStart), isTrue);
      expect(
        providers[booking.providerName]!.serviceTypes,
        contains(serviceIds[booking.serviceType]),
      );
    }

    final blocking =
        bookings.where((b) => b.status.blocksProviderSlot).toList();
    for (final first in blocking) {
      for (final second in blocking) {
        if (first.id == second.id ||
            first.providerName != second.providerName) {
          continue;
        }
        expect(
          first.scheduledStart.isBefore(second.scheduledEnd) &&
              second.scheduledStart.isBefore(first.scheduledEnd),
          isFalse,
        );
      }
    }
  });

  test('preview earnings and ordinary seed stay separate', () {
    final preview = LocalPreviewData.bookings(referenceTime: reference);
    final earnings = earningsFor('Provider A', preview);
    expect(earnings.jobsCompleted, 7);
    expect(earnings.totalNet, 1156);
    expect(earnings.records.map((r) => r.net).toSet().length, greaterThan(2));
    expect(
      earnings.records
          .where((r) =>
              !r.date.isBefore(reference.subtract(const Duration(days: 30))))
          .length,
      6,
    );
    expect(earningsFor('Provider A', LocalPreviewData.bookings()).weeklyNet,
        greaterThanOrEqualTo(136));
    expect(BookingStore().bookings.length, 5);
    expect(BookingStore(initialBookings: preview).bookings.length, 15);
  });
}
