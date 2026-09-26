// test/demo_data_test.dart
// Verifies the seed data is consistent and complete.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';

void main() {
  group('DemoProvider', () {
    test('ranked() returns 3 providers', () {
      expect(DemoProvider.ranked().length, 3);
    });

    test('providers are sorted by score descending (MCDA ADR-0001)', () {
      final list = DemoProvider.ranked();
      for (int i = 0; i < list.length - 1; i++) {
        expect(list[i].score, greaterThanOrEqualTo(list[i + 1].score),
            reason:
                'Provider ${list[i].name} (${list[i].score}) should rank above '
                '${list[i + 1].name} (${list[i + 1].score})');
      }
    });

    test('Provider A is the top match (matches tutor example R2)', () {
      final a = DemoProvider.ranked().first;
      expect(a.name, 'Provider A');
      expect(a.score, closeTo(0.93, 0.001));
      expect(a.availability, 'Full match');
    });

    test('Provider C is the lowest match (matches tutor example R4)', () {
      final c = DemoProvider.ranked().last;
      expect(c.name, 'Provider C');
      expect(c.score, closeTo(0.74, 0.001));
      expect(c.availability, 'Partial match');
    });

    test('all providers have non-empty id, name, workload, availability', () {
      for (final p in DemoProvider.ranked()) {
        expect(p.id, isNotEmpty);
        expect(p.name, isNotEmpty);
        expect(p.workload, isNotEmpty);
        expect(p.availability, isNotEmpty);
        expect(p.serviceTypes, isNotEmpty);
        expect(p.rating, inInclusiveRange(0, 5));
        expect(p.distanceKm, greaterThan(0));
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
