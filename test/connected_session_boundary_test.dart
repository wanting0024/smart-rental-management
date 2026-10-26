import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/supabase_auth_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/backend/supabase_booking_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';

// Fixture-only identities and repositories. No hosted account/network is used.
class FixtureAuth extends GoTrueClient {
  FixtureAuth()
      : super(url: 'https://fixture.invalid/auth/v1', autoRefreshToken: false);
  final events = StreamController<AuthState>.broadcast();
  String? userId = 'owner-a';
  @override
  User? get currentUser => userId == null
      ? null
      : User(
          id: userId!,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2030-01-01',
          email: '$userId@fixture.invalid',
        );
  @override
  Stream<AuthState> get onAuthStateChange => events.stream;
  void emit(String? id, {AuthChangeEvent? event}) {
    userId = id;
    events.add(
      AuthState(
        event ??
            (id == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn),
        id == null
            ? null
            : Session(
                accessToken: 'fixture-only-not-a-token',
                tokenType: 'bearer',
                user: currentUser!,
              ),
      ),
    );
  }
}

class FixtureClient extends SupabaseClient {
  FixtureClient(this.fixture)
      : super(
          'https://fixture.invalid',
          'fixture-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
  final FixtureAuth fixture;
  @override
  GoTrueClient get auth => fixture;
}

class FixtureIdentity extends SupabaseAuthRepository {
  FixtureIdentity(super.client);
  Completer<AuthIdentity?>? delayed;
  @override
  Future<AuthIdentity?> currentIdentity() async =>
      delayed?.future ??
      AuthIdentity(
        userId: client.auth.currentUser!.id,
        email: 'owner-a@fixture.invalid',
        role: UserRole.owner,
      );
}

class FixtureOwner extends SupabaseOwnerRepository {
  FixtureOwner(super.client);
  @override
  Future<List<Map<String, dynamic>>> properties() async => [];
  @override
  Future<OwnerDashboardSnapshot> dashboard() async =>
      const OwnerDashboardSnapshot(
        propertyCount: 0,
        pendingCount: 0,
        activeCount: 0,
        completedCount: 0,
      );
}

class FixtureBookings extends SupabaseBookingRepository {
  FixtureBookings(super.client);
  final feeds = <CursorFeed<Map<String, dynamic>>>[];
  @override
  CursorFeed<Map<String, dynamic>> openFeed({
    required bool provider,
    bool active = true,
    void Function()? onServerChange,
  }) {
    final feed = CursorFeed<Map<String, dynamic>>(
      active: active,
      loadPage: (_) async => const CursorPage(items: []),
      idOf: (row) => row['booking_id'] as String,
      compare: (_, __) => 0,
    );
    feeds.add(feed);
    return feed;
  }
}

class FixtureBackend extends SupabaseBackendProvider {
  FixtureBackend(super.client);
  late final identityFixture = FixtureIdentity(client);
  late final ownerFixture = FixtureOwner(client);
  late final bookingFixture = FixtureBookings(client);
  @override
  SupabaseAuthRepository get auth => identityFixture;
  @override
  SupabaseOwnerRepository get owner => ownerFixture;
  @override
  SupabaseBookingRepository get bookings => bookingFixture;
}

void main() {
  for (final next in <String?>[null, 'owner-b']) {
    testWidgets('identity changes to $next remove all pushed private routes',
        (tester) async {
      final auth = FixtureAuth();
      final client = (await tester.runAsync(() async => FixtureClient(auth)))!;
      final backend = FixtureBackend(client);
      addTearDown(() async {
        await client.dispose();
        await auth.events.close();
        auth.dispose();
      });
      await tester.pumpWidget(RentalAppDemo(backend: backend));
      await tester.pumpAndSettle();
      expect(find.text('Owner Dashboard'), findsOneWidget);
      await backend.cache.read(
        key: 'photo:fixture',
        ttl: const Duration(minutes: 1),
        sizeOf: (String value) => value.length,
        load: () async => 'private fixture',
      );
      expect(backend.cache.entryCount, 1);
      final context = tester.element(find.text('Owner Dashboard'));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private booking details')),
        ),
      );
      await tester.pumpAndSettle();
      auth.emit(next);
      await tester.pumpAndSettle();
      expect(find.text('Private booking details'), findsNothing);
      expect(find.text('Welcome to Smart Rental'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
      expect(backend.cache.entryCount, 0);
      expect(
        backend.bookingFixture.feeds
            .every((feed) => !feed.active && feed.items.isEmpty),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'same identity refresh and transient auth errors keep the current route',
      (tester) async {
    final auth = FixtureAuth();
    final client = (await tester.runAsync(() async => FixtureClient(auth)))!;
    final backend = FixtureBackend(client);
    addTearDown(() async {
      await client.dispose();
      await auth.events.close();
      auth.dispose();
    });
    await tester.pumpWidget(RentalAppDemo(backend: backend));
    await tester.pumpAndSettle();
    await backend.cache.read(
      key: 'reference:fixture',
      ttl: const Duration(minutes: 1),
      sizeOf: (String value) => value.length,
      load: () async => 'same account',
    );
    final context = tester.element(find.text('Owner Dashboard'));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Private booking details')),
      ),
    );
    await tester.pumpAndSettle();
    auth.emit('owner-a', event: AuthChangeEvent.tokenRefreshed);
    auth.events.addError(StateError('offline refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Private booking details'), findsOneWidget);
    expect(backend.cache.entryCount, 1);
    tester.binding.handleMemoryPressure();
    expect(backend.cache.entryCount, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'late session restoration cannot reopen an account after sign-out',
      (tester) async {
    final auth = FixtureAuth();
    final client = (await tester.runAsync(() async => FixtureClient(auth)))!;
    final backend = FixtureBackend(client);
    addTearDown(() async {
      await client.dispose();
      await auth.events.close();
      auth.dispose();
    });
    final delayed = Completer<AuthIdentity?>();
    backend.identityFixture.delayed = delayed;
    await tester.pumpWidget(RentalAppDemo(backend: backend));
    auth.emit(null);
    await tester.pumpAndSettle();
    delayed.complete(
      const AuthIdentity(
        userId: 'owner-a',
        email: 'owner-a@fixture.invalid',
        role: UserRole.owner,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Smart Rental'), findsOneWidget);
    expect(find.text('Owner Dashboard'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
