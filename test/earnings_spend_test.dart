// test/earnings_spend_test.dart
// Verifies the provider earnings and owner spend aggregations.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';

void main() {
  group('EarningsRecord', () {
    test('computeGross uses RM 80/h base rate', () {
      // 2 hours = RM 160
      expect(EarningsRecord.computeGross(const Duration(hours: 2)), closeTo(160, 0.01));
      // 3 hours = RM 240
      expect(EarningsRecord.computeGross(const Duration(hours: 3)), closeTo(240, 0.01));
    });

    test('computeFee is 15% of gross', () {
      expect(EarningsRecord.computeFee(100), closeTo(15, 0.01));
      expect(EarningsRecord.computeFee(240), closeTo(36, 0.01));
    });
  });

  group('earningsFor()', () {
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
        expect(s.byProvider[i].value, greaterThanOrEqualTo(s.byProvider[i + 1].value));
      }
    });

    test('byProvider contains the correct provider for b-004', () {
      final s = spendFor(DemoBooking.all());
      expect(s.byProvider.first.key, 'Provider C');
    });
  });
}
