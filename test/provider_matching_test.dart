import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/features/matching/domain/provider_matching.dart';
import 'package:rental_app_demo/models/demo_data.dart';

void main() {
  const service = ProviderMatchingService();

  ProviderMatchRequest request({
    String serviceType = 'standard',
    int startHour = 10,
    int endHour = 12,
    int rentalStartHour = 8,
    int rentalEndHour = 18,
  }) =>
      ProviderMatchRequest(
        serviceType: serviceType,
        requestedStart: DateTime(2026, 7, 15, startHour),
        requestedEnd: DateTime(2026, 7, 15, endHour),
        rentalWindowStart: DateTime(2026, 7, 15, rentalStartHour),
        rentalWindowEnd: DateTime(2026, 7, 15, rentalEndHour),
      );

  DemoProvider provider({
    required String id,
    required double distance,
    required double rating,
    required int workload,
    List<String> services = const ['standard'],
    String availability = 'Full match',
  }) =>
      DemoProvider(
        id: id,
        name: 'Provider $id',
        serviceTypes: services,
        distanceKm: distance,
        rating: rating,
        workload: workload <= 1
            ? 'Low'
            : workload <= 3
                ? 'Medium'
                : 'High',
        activeBookingCount: workload,
        score: 0,
        availability: availability,
      );

  DemoBooking booking({
    required String id,
    required String providerName,
    required BookingStatus status,
    int day = 15,
    int startHour = 10,
    int endHour = 12,
  }) =>
      DemoBooking(
        id: id,
        property: 'Unit T-01',
        serviceType: 'Standard cleaning',
        providerName: providerName,
        scheduledStart: DateTime(2026, 7, day, startHour),
        scheduledEnd: DateTime(2026, 7, day, endHour),
        status: status,
        specialInstructions: null,
      );

  List<DemoBooking> workloadBookings(String providerName, int count) =>
      List.generate(
        count,
        (index) => booking(
          id: '$providerName-workload-$index',
          providerName: providerName,
          status: BookingStatus.accepted,
          day: 15 + index,
          startHour: 13,
          endHour: 14,
        ),
      );

  group('mandatory eligibility filtering', () {
    test('excludes unsupported services before scoring', () {
      final result = service.match(
        providers: [
          provider(
            id: 'A',
            distance: 1,
            rating: 5,
            workload: 0,
            services: const ['deep'],
          ),
        ],
        request: request(),
        bookings: const [],
      );

      expect(result.rankedProviders, isEmpty);
      expect(
        result.excludedProviders.single.reasons,
        contains(ProviderExclusionReason.unsupportedService),
      );
    });

    test('partial availability is excluded rather than scored', () {
      final result = service.match(
        providers: [
          provider(
            id: 'A',
            distance: 1,
            rating: 5,
            workload: 0,
            availability: 'Partial match',
          ),
          provider(id: 'B', distance: 8, rating: 3, workload: 4),
        ],
        request: request(),
        bookings: const [],
      );

      expect(result.rankedProviders.single.id, 'B');
      expect(result.rankedProviders.single.score, 1);
      expect(result.excludedProviders.single.provider.id, 'A');
      expect(
        result.excludedProviders.single.reasons,
        contains(ProviderExclusionReason.requestedIntervalNotCovered),
      );
    });

    test('excludes every provider when request is outside rental window', () {
      final result = service.match(
        providers: [provider(id: 'A', distance: 1, rating: 5, workload: 0)],
        request: request(rentalStartHour: 11),
        bookings: const [],
      );

      expect(result.rankedProviders, isEmpty);
      expect(
        result.excludedProviders.single.reasons,
        contains(ProviderExclusionReason.rentalWindowIncompatible),
      );
    });

    test('Accepted and In Progress bookings create conflicts', () {
      for (final status in [BookingStatus.accepted, BookingStatus.inProgress]) {
        final candidate =
            provider(id: 'A', distance: 1, rating: 5, workload: 0);
        final result = service.match(
          providers: [candidate],
          request: request(),
          bookings: [
            booking(
                id: 'b-$status', providerName: candidate.name, status: status),
          ],
        );

        expect(result.rankedProviders, isEmpty);
        expect(
          result.excludedProviders.single.reasons,
          contains(ProviderExclusionReason.activeBookingConflict),
        );
      }
    });

    test('Pending does not block and back-to-back intervals do not overlap',
        () {
      final candidate = provider(id: 'A', distance: 1, rating: 5, workload: 0);
      final result = service.match(
        providers: [candidate],
        request: request(),
        bookings: [
          booking(
            id: 'pending',
            providerName: candidate.name,
            status: BookingStatus.pending,
          ),
          booking(
            id: 'accepted-before',
            providerName: candidate.name,
            status: BookingStatus.accepted,
            startHour: 8,
            endHour: 10,
          ),
        ],
      );

      expect(result.rankedProviders.single.id, 'A');
    });
  });

  group('equal-weight ranking', () {
    test('uses only normalized distance, rating, and workload', () {
      final result = service.match(
        providers: [
          provider(id: 'A', distance: 1, rating: 3, workload: 3),
          provider(id: 'B', distance: 2, rating: 4, workload: 2),
          provider(id: 'C', distance: 3, rating: 5, workload: 1),
        ],
        request: request(),
        bookings: [
          ...workloadBookings('Provider A', 3),
          ...workloadBookings('Provider B', 2),
          ...workloadBookings('Provider C', 1),
        ],
      );

      expect(
        result.rankedProviders.map((item) => item.id),
        ['C', 'B', 'A'],
      );
      expect(result.rankedProviders[0].score, closeTo(2 / 3, 0.0001));
      expect(result.rankedProviders[1].score, closeTo(1 / 2, 0.0001));
      expect(result.rankedProviders[2].score, closeTo(1 / 3, 0.0001));
    });

    test('uses neutral rating 3.0 when a provider has no rating', () {
      final result = service.match(
        providers: [
          provider(id: 'Unrated', distance: 2, rating: 0, workload: 1),
          provider(id: 'Rated', distance: 2, rating: 4, workload: 1),
        ],
        request: request(),
        bookings: [
          ...workloadBookings('Provider Unrated', 1),
          ...workloadBookings('Provider Rated', 1),
        ],
      );

      final unrated = result.rankedProviders.singleWhere(
        (item) => item.id == 'Unrated',
      );
      final rated = result.rankedProviders.singleWhere(
        (item) => item.id == 'Rated',
      );
      expect(rated.ratingSuitability, 1);
      expect(unrated.ratingSuitability, 0);
      expect(rated.score, greaterThan(unrated.score));
    });

    test('uses deterministic tie-breakers', () {
      final result = service.match(
        providers: [
          provider(id: 'Far', distance: 4, rating: 5, workload: 3),
          provider(id: 'Near', distance: 1, rating: 2, workload: 3),
        ],
        request: request(),
        bookings: [
          ...workloadBookings('Provider Far', 3),
          ...workloadBookings('Provider Near', 3),
        ],
      );

      expect(result.rankedProviders.first.id, 'Near');
      expect(
        result.rankedProviders.first.score,
        result.rankedProviders.last.score,
      );
    });

    test('counts only blocking bookings in the configured seven-day window',
        () {
      final candidate = provider(
        id: 'A',
        distance: 1,
        rating: 5,
        workload: 99,
      );
      final result = service.match(
        providers: [candidate],
        request: request(),
        bookings: [
          booking(
            id: 'accepted',
            providerName: candidate.name,
            status: BookingStatus.accepted,
            day: 16,
            startHour: 13,
            endHour: 14,
          ),
          booking(
            id: 'in-progress',
            providerName: candidate.name,
            status: BookingStatus.inProgress,
            day: 21,
            startHour: 13,
            endHour: 14,
          ),
          booking(
            id: 'pending',
            providerName: candidate.name,
            status: BookingStatus.pending,
            day: 17,
            startHour: 13,
            endHour: 14,
          ),
          booking(
            id: 'completed',
            providerName: candidate.name,
            status: BookingStatus.completed,
            day: 18,
            startHour: 13,
            endHour: 14,
          ),
          booking(
            id: 'outside-window',
            providerName: candidate.name,
            status: BookingStatus.accepted,
            day: 22,
            startHour: 13,
            endHour: 14,
          ),
        ],
      );

      expect(result.rankedProviders.single.activeBookingCount, 2);
      expect(result.rankedProviders.single.workload, 'Medium');
    });
  });
}
