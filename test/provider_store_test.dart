import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/features/matching/domain/provider_matching.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/provider_store.dart';

void main() {
  group('DemoProvider.copyWith', () {
    test('returns a copy with requested fields replaced', () {
      final provider = DemoProvider.seeded().first;
      final updated = provider.copyWith(
        name: 'New Name',
        phone: '+60 99-999 9999',
        hourlyRate: 150,
      );

      expect(updated.name, 'New Name');
      expect(updated.phone, '+60 99-999 9999');
      expect(updated.hourlyRate, 150);
      expect(updated.id, provider.id);
      expect(updated.email, provider.email);
      expect(updated.bio, provider.bio);
    });
  });

  group('ProviderStore', () {
    test('starts with three unranked provider profiles', () {
      final store = ProviderStore();

      expect(store.providers.length, 3);
      expect(store.providers.every((provider) => provider.score == 0), isTrue);
    });

    test('byId returns the matching provider', () {
      final store = ProviderStore();

      expect(store.byId('p-a')?.name, 'Provider A');
    });

    test('currentProvider defaults to first profile when none is selected', () {
      final store = ProviderStore();

      expect(store.currentProvider?.name, 'Provider A');
    });

    test('setCurrentProviderId updates the active provider', () {
      final store = ProviderStore();

      store.setCurrentProviderId('p-b');

      expect(store.currentProvider?.name, 'Provider B');
    });

    test('update notifies listeners and clears stale request score', () {
      final store = ProviderStore();
      var notified = 0;
      store.addListener(() => notified++);
      final provider = store.byId('p-a')!;

      store.update(
        provider.copyWith(
          name: 'Updated Provider',
          score: 0.99,
          hasRankingBreakdown: true,
        ),
      );

      expect(notified, 1);
      expect(store.byId('p-a')?.name, 'Updated Provider');
      expect(store.byId('p-a')?.score, 0);
      expect(store.byId('p-a')?.hasRankingBreakdown, isFalse);
    });

    test('matchProviders applies request-specific eligibility and ranking', () {
      final store = ProviderStore();
      final result = store.matchProviders(
        request: ProviderMatchRequest(
          serviceType: 'standard',
          requestedStart: DateTime(2026, 7, 15, 10),
          requestedEnd: DateTime(2026, 7, 15, 12),
          rentalWindowStart: DateTime(2026, 7, 15, 8),
          rentalWindowEnd: DateTime(2026, 7, 15, 18),
        ),
        bookings: const [],
      );

      expect(
        result.rankedProviders.map((provider) => provider.id),
        ['p-a', 'p-b'],
      );
      expect(result.excludedProviders.single.provider.id, 'p-c');
      expect(result.rankedProviders.first.hasRankingBreakdown, isTrue);
    });

    test('toggleAvailability changes eligibility data, not a stored score', () {
      final store = ProviderStore();

      store.toggleAvailability('p-a');

      expect(store.byId('p-a')?.availability, 'Partial match');
      expect(store.byId('p-a')?.score, 0);
    });
  });
}
