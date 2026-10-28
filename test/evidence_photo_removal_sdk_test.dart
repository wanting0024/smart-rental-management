import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/authenticated_memory_cache.dart';
import 'package:rental_app_demo/services/backend/supabase_evidence_repository.dart';

class _Auth extends GoTrueClient {
  _Auth() : super(autoRefreshToken: false);
  String? actor = 'provider';
  @override
  User? get currentUser => actor == null
      ? null
      : User(
          id: actor!,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01');
}

class _Client extends SupabaseClient {
  _Client(this.fixture, http.Client transport)
      : super('https://fixture.invalid', 'sb_publishable_fixture',
            httpClient: transport,
            authOptions: const AuthClientOptions(autoRefreshToken: false));
  final _Auth fixture;
  @override
  GoTrueClient get auth => fixture;
}

void main() {
  test(
      'removal uses scoped expected-path RPC, evicts cached bytes and leaves physical cleanup to Storage API',
      () async {
    final auth = _Auth();
    final cache = AuthenticatedMemoryCache(currentUserId: () => auth.actor);
    await cache.read<String>(
        key: 'photo:booking/before.jpg',
        ttl: const Duration(minutes: 2),
        sizeOf: (v) => v.length,
        load: () async => 'private bytes');
    final client = _Client(auth, MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/remove_evidence_photo');
      expect(jsonDecode(request.body), {
        'p_booking_id': 'booking',
        'p_kind': 'before',
        'p_expected_path': 'booking/before.jpg'
      });
      return http.Response(
          jsonEncode({'removed': true, 'path': 'booking/before.jpg'}), 200,
          headers: {'content-type': 'application/json'}, request: request);
    }));
    await SupabaseEvidenceRepository(client, cache: cache)
        .removePhoto('booking', EvidenceKind.before, 'booking/before.jpg');
    expect(cache.entryCount, 0);
    await client.dispose();
    auth.dispose();
  });
  test('stale-photo denial is typed and cannot delete or replace another file',
      () async {
    final auth = _Auth();
    final client = _Client(
        auth,
        MockClient((r) async => http.Response(
            '{"removed":false,"reason":"photo_changed"}', 200,
            headers: {'content-type': 'application/json'}, request: r)));
    await expectLater(
        SupabaseEvidenceRepository(client)
            .removePhoto('booking', EvidenceKind.after, 'booking/after.jpg'),
        throwsA(isA<EvidencePhotoRemovalRejected>()
            .having((e) => e.reason, 'reason', 'photo_changed')));
    await client.dispose();
    auth.dispose();
  });
  test(
      'session change while removing never confirms success to the next account',
      () async {
    final auth = _Auth();
    final client = _Client(auth, MockClient((r) async {
      auth.actor = 'another-account';
      return http.Response('{"removed":true,"path":"booking/before.jpg"}', 200,
          headers: {'content-type': 'application/json'}, request: r);
    }));
    await expectLater(
        SupabaseEvidenceRepository(client)
            .removePhoto('booking', EvidenceKind.before, 'booking/before.jpg'),
        throwsA(isA<CacheSessionChanged>()));
    await client.dispose();
    auth.dispose();
  });
}
