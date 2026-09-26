// test/demo_data_test.dart
// Verifies the seed data is consistent and complete.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';

void main() {
  group('DemoProvider', () {
    test('seeded() returns 3 raw provider profiles', () {
      expect(DemoProvider.seeded().length, 3);
    });

    test('raw profiles do not store a request-independent score', () {
      for (final provider in DemoProvider.seeded()) {
        expect(provider.score, 0);
        expect(provider.hasRankingBreakdown, isFalse);
      }
    });

    test('Provider A has full declared availability', () {
      final a = DemoProvider.seeded().first;
      expect(a.name, 'Provider A');
      expect(a.availability, 'Full match');
      expect(a.activeBookingCount, 1);
    });

    test('Provider C is not fully available for the demo interval', () {
      final c = DemoProvider.seeded().last;
      expect(c.name, 'Provider C');
      expect(c.availability, 'Partial match');
    });

    test('all providers have non-empty id, name, workload, availability', () {
      for (final p in DemoProvider.seeded()) {
        expect(p.id, isNotEmpty);
        expect(p.name, isNotEmpty);
        expect(p.workload, isNotEmpty);
        expect(p.availability, isNotEmpty);
        expect(p.serviceTypes, isNotEmpty);
        expect(p.rating, inInclusiveRange(0, 5));
        expect(p.distanceKm, greaterThan(0));
        expect(p.activeBookingCount, greaterThanOrEqualTo(0));
      }
    });
  });

  group('DemoBooking', () {
    test('all() returns 5 sample bookings (4 base + 1 recurring)', () {
      expect(DemoBooking.all().length, 5);
    });

    test('every booking has a valid scheduled window', () {
      for (final b in DemoBooking.all()) {
        expect(b.scheduledEnd.isAfter(b.scheduledStart), isTrue,
            reason:
                '${b.id} end (${b.scheduledEnd}) must be after start (${b.scheduledStart})');
        expect(b.id, isNotEmpty);
        expect(b.property, isNotEmpty);
        expect(b.serviceType, isNotEmpty);
      }
    });

    test('bookings cover all major lifecycle stages', () {
      final statuses = DemoBooking.all().map((b) => b.status).toSet();
      expect(statuses.contains(BookingStatus.pending), isTrue);
      expect(statuses.contains(BookingStatus.accepted), isTrue);
      expect(statuses.contains(BookingStatus.inProgress), isTrue);
      expect(statuses.contains(BookingStatus.completed), isTrue);
    });

    test('Pending provider-directed requests have an assigned provider', () {
      for (final b in DemoBooking.all()) {
        if (b.status == BookingStatus.pending) {
          expect(
            b.providerName,
            isNotNull,
            reason: '${b.id} must identify the selected provider',
          );
        }
      }
    });
  });

  group('DemoProperty', () {
    test('5 properties seeded', () {
      expect(DemoProperty.all.length, 5);
    });

    test('every property has a display name', () {
      for (final p in DemoProperty.all) {
        expect(p.display, isNotEmpty);
        expect(p.display, contains('Unit'));
        expect(p.bedrooms, greaterThan(0));
        expect(p.sizeSqft, greaterThan(0));
      }
    });
  });

  group('ServiceTypeOption', () {
    test('5 service types seeded', () {
      expect(ServiceTypeOption.all.length, 5);
    });

    test('every service has a duration and price', () {
      for (final s in ServiceTypeOption.all) {
        expect(s.id, isNotEmpty);
        expect(s.label, isNotEmpty);
        expect(s.durationHours, greaterThan(0));
        expect(s.priceFrom, greaterThan(0));
      }
    });
  });
}
