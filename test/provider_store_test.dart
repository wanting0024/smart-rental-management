// test/provider_store_test.dart
// Verifies ProviderStore (the source of truth for editable provider data)
// and DemoProvider.copyWith + computedScore (auto-recomputes MCDA).

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/provider_store.dart';

void main() {
  group('DemoProvider.copyWith', () {
    test('returns a copy with the requested fields replaced', () {
      final p = DemoProvider.ranked().first;
      final updated = p.copyWith(
        name: 'New Name',
        phone: '+60 99-999 9999',
        hourlyRate: 150.0,
      );
      expect(updated.name, 'New Name');
      expect(updated.phone, '+60 99-999 9999');
      expect(updated.hourlyRate, 150.0);
      // Untouched fields
      expect(updated.id, p.id);
      expect(updated.email, p.email);
      expect(updated.bio, p.bio);
    });
  });

  group('DemoProvider.computedScore (ADR-0001)', () {
    test('Full match + Low workload + nearby + high rating = high score', () {
      final p = DemoProvider(
        id: 'x', name: 'X', serviceTypes: const ['standard'],
        distanceKm: 1.0, rating: 5.0, workload: 'Low',
        score: 0.0, availability: 'Full match',
      );
      // avail=1.0*0.35=0.35 + dist=0.9*0.20=0.18 + rating=1.0*0.25=0.25 + work=1.0*0.20=0.20 = 0.98
      expect(p.computedScore, closeTo(0.98, 0.01));
    });

    test('No slot availability zeros the score', () {
      final p = DemoProvider(
        id: 'x', name: 'X', serviceTypes: const ['standard'],
        distanceKm: 1.0, rating: 5.0, workload: 'Low',
        score: 0.0, availability: 'No slot',
      );
      expect(p.computedScore, lessThan(0.7));
    });

    test('High workload + far + low rating = low score', () {
      final p = DemoProvider(
        id: 'x', name: 'X', serviceTypes: const ['standard'],
        distanceKm: 9.0, rating: 2.0, workload: 'High',
        score: 0.0, availability: 'Full match',
      );
      // avail=1.0*0.35=0.35 + dist=0.1*0.20=0.02 + rating=0.4*0.25=0.10 + work=0.2*0.20=0.04 = 0.51
      expect(p.computedScore, closeTo(0.51, 0.01));
    });
  });

  group('ProviderStore', () {
    test('starts with 3 seeded providers', () {
      final store = ProviderStore();
      expect(store.providers.length, 3);
    });

    test('byId returns the matching provider', () {
      final store = ProviderStore();
      final a = store.byId('p-a');
      expect(a, isNotNull);
      expect(a!.name, 'Provider A');
    });

    test('currentProvider defaults to the first when none set', () {
      final store = ProviderStore();
      expect(store.currentProvider, isNotNull);
      expect(store.currentProvider!.name, 'Provider A');
    });

    test('setCurrentProviderId updates the active provider', () {
      final store = ProviderStore();
      store.setCurrentProviderId('p-b');
      expect(store.currentProvider!.name, 'Provider B');
    });

    test('update() notifies listeners and recomputes score', () {
      final store = ProviderStore();
      var notified = 0;
      store.addListener(() => notified++);
      final p = store.byId('p-a')!;
      final newScore = p.computedScore;
      // Update with no change
      store.update(p.copyWith());
      expect(notified, 1);
      // Score should be re-derived and stored
      expect(store.byId('p-a')!.score, closeTo(newScore, 0.001));
    });

    test('update() re-sorts by score (highest first)', () {
      final store = ProviderStore();
      final sorted = store.providers;
      // Provider A (0.93) should be first
      expect(sorted.first.id, 'p-a');
      expect(sorted.first.score, greaterThanOrEqualTo(sorted[1].score));
      expect(sorted[1].score, greaterThanOrEqualTo(sorted[2].score));
    });

    test('update() with higher availability boosts rank', () {
      final store = ProviderStore();
      final c = store.byId('p-c')!;
      // Boost C to Full match + lower distance
      final updated = c.copyWith(
        availability: 'Full match',
        distanceKm: 0.5,
        workload: 'Low',
        rating: 4.9,
      );
      store.update(updated);
      // C's new score should be the highest now
      final newSorted = store.providers;
      expect(newSorted.first.id, 'p-c');
    });

    test('toggleAvailability() cycles through the 3 states', () {
      final store = ProviderStore();
      final p = store.byId('p-a')!;
      expect(p.availability, 'Full match');
      store.toggleAvailability('p-a');
      expect(store.byId('p-a')!.availability, 'Partial match');
      store.toggleAvailability('p-a');
      expect(store.byId('p-a')!.availability, 'No slot');
      store.toggleAvailability('p-a');
      expect(store.byId('p-a')!.availability, 'Full match');
    });
  });
}
