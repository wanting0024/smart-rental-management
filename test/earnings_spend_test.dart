// test/earnings_spend_test.dart
// Verifies the provider earnings and owner spend aggregations.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';

void main() {
  group('EarningsRecord', () {
    test('computeGross uses the supplied provider hourly rate', () {
      expect(
          EarningsRecord.computeGross(const Duration(hours: 2), hourlyRate: 80),
          closeTo(160, 0.01));
      expect(
          EarningsRecord.computeGross(const Duration(minutes: 90),
              hourlyRate: 120),
          closeTo(180, 0.01));
    });

    test('computeFee is 15% of gross', () {
      expect(EarningsRecord.computeFee(100), closeTo(15, 0.01));
      expect(EarningsRecord.computeFee(240), closeTo(36, 0.01));
    });
  });

  group('earningsFor()', () {
    test('uses provider rate for earnings and matching owner spend', () {
      final booking = DemoBooking(
        id: 'legacy-completed',
        property: DemoProperty.all.first.display,
        serviceType: 'Standard cleaning',
        providerName: 'Provider C',
        scheduledStart: DateTime(2030, 7, 17, 10),
        scheduledEnd: DateTime(2030, 7, 17, 12),
        status: BookingStatus.completed,
        specialInstructions: null,
      );
      final providers = DemoProvider.seeded()
          .map((p) => p.name == 'Provider C' ? p.copyWith(hourlyRate: 125) : p)
          .toList();
      final earnings =
          earningsFor('Provider C', [booking], providers: providers);
      final spend = spendFor([booking], providers: providers);
      expect(earnings.records.single.gross, 250);
      expect(spend.records.single.cost, 250);
    });

    test('booking rate snapshot survives a later provider rate edit', () {
      final providerStore = ProviderStore();
      final bookings = BookingStore(providerStore: providerStore);
      final request = bookings.add(
        property: DemoProperty.all.first.display,
        serviceType: 'Standard cleaning',
        scheduledStart: DateTime(2030, 7, 17, 10),
        scheduledEnd: DateTime(2030, 7, 17, 12),
        providerName: 'Provider A',
      );
      expect(request.hourlyRateAtBooking, 80);
      providerStore
          .update(providerStore.byId('p-a')!.copyWith(hourlyRate: 150));
      expect(bookings.byId(request.id)!.hourlyRateAtBooking, 80);
      final completed = request.copyWith(status: BookingStatus.completed);
      expect(
        earningsFor('Provider A', [completed],
                providers: providerStore.providers)
            .records
            .single
            .gross,
        160,
      );
    });

    test('returns zero summary for a provider with no completed jobs', () {
      final s = earningsFor('Unknown Provider', DemoBooking.all());
      expect(s.jobsCompleted, 0);
      expect(s.totalNet, 0);
      expect(s.weeklyNet, 0);
      expect(s.monthlyNet, 0);
      expect(s.records, isEmpty);
    });

    test('Provider A has 0 completed jobs in the seed (only inProgress)', () {
      final s = earningsFor('Provider A', DemoBooking.all());
      expect(s.jobsCompleted, 0);
      expect(s.totalNet, 0);
    });

    test('Provider C has 1 completed job (b-004) in the seed', () {
      final s = earningsFor('Provider C', DemoBooking.all());
      expect(s.jobsCompleted, 1);
      expect(s.records.first.bookingId, 'b-004');
      expect(s.records.first.hours, 2); // 13:00 - 15:00
      expect(s.records.first.gross, closeTo(160, 0.01));
      expect(s.records.first.platformFee, closeTo(24, 0.01));
      expect(s.records.first.net, closeTo(136, 0.01));
    });

    test('avgPerJob = totalNet / jobsCompleted when there are jobs', () {
      final s = earningsFor('Provider C', DemoBooking.all());
      expect(s.avgPerJob, closeTo(s.totalNet / s.jobsCompleted, 0.01));
    });
  });

  group('spendFor()', () {
    test('returns 1 completed record (b-004)', () {
      final s = spendFor(DemoBooking.all());
      expect(s.jobsFunded, 1);
    });

    test('totalSpent = sum of record costs', () {
      final s = spendFor(DemoBooking.all());
      final sum = s.records.fold<double>(0, (acc, r) => acc + r.cost);
      expect(s.totalSpent, closeTo(sum, 0.01));
    });

    test('byProvider is sorted descending', () {
      final s = spendFor(DemoBooking.all());
      for (int i = 0; i < s.byProvider.length - 1; i++) {
        expect(s.byProvider[i].value,
            greaterThanOrEqualTo(s.byProvider[i + 1].value));
      }
    });

    test('byProvider contains the correct provider for b-004', () {
      final s = spendFor(DemoBooking.all());
      expect(s.byProvider.first.key, 'Provider C');
    });
  });
}
