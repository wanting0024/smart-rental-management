import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/earnings_snapshot.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/supabase_earnings_repository.dart';
import 'support/earnings_fixture.dart';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _Auth extends GoTrueClient {
  _Auth()
      : super(url: 'https://fixture.invalid/auth/v1', autoRefreshToken: false);
  String? identity = earningsActor;
  @override
  User? get currentUser => identity == null
      ? null
      : User(
          id: identity!,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01');
}

class _Client extends SupabaseClient {
  _Client(String url, this.fixture)
      : super(url, 'sb_publishable_synthetic_fixture',
            authOptions: const AuthClientOptions(autoRefreshToken: false));
  final _Auth fixture;
  @override
  GoTrueClient get auth => fixture;
}

void main() {
  _NetworkBinding();
  late HttpServer server;
  late _Auth auth;
  late _Client client;
  late SupabaseEarningsRepository repository;
  var mode = 'normal';
  final calls = <Map>[];
  setUp(() async {
    calls.clear();
    mode = 'normal';
    auth = _Auth();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      calls.add(body);
      expect(request.uri.path, '/rest/v1/rpc/provider_earnings');
      request.response.headers.contentType = ContentType.json;
      final period =
          EarningsPeriod.values.singleWhere((p) => p.name == body['p_period']);
      final response = earningsFixture(period: period);
      if (mode == 'session') auth.identity = 'different';
      if (mode == 'wrong-provider') response['provider_id'] = 'different';
      if (mode == 'error') {
        request.response.statusCode = 403;
        request.response.write(
            jsonEncode({'code': '42501', 'message': 'Provider required'}));
      } else {
        request.response.write(jsonEncode(response));
      }
      await request.response.close();
    });
    client = _Client('http://127.0.0.1:${server.port}', auth);
    repository = SupabaseEarningsRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    auth.dispose();
    await server.close(force: true);
  });
  test(
      'all ranges use exactly one bounded RPC; provider identity is never caller supplied',
      () async {
    for (final period in EarningsPeriod.values) {
      final result = await repository.read(period);
      expect(result.period, period);
      expect(result.records.length, 20);
      expect(
          calls.last.keys,
          unorderedEquals(
              ['p_period', 'p_before_at', 'p_before_id', 'p_as_of']));
    }
    expect(calls.length, 3);
  });
  test('paging retains exact timestamp precision and fixed server as-of',
      () async {
    const cursor = PageCursor('2026-10-23T02:00:00.123456+00:00',
        'bbbbbbbb-bbbb-4bbb-8bbb-000000000019');
    await repository.read(EarningsPeriod.allTime,
        before: cursor, asOf: '2026-10-23T12:00:00.123456+00:00');
    expect(calls.single['p_before_at'], cursor.timestamp);
    expect(calls.single['p_before_id'], cursor.id);
    expect(calls.single['p_as_of'], contains('123456'));
  });
  test('unauthenticated and missing snapshot stop before network', () async {
    auth.identity = null;
    await expectLater(
        repository.read(EarningsPeriod.allTime), throwsStateError);
    auth.identity = earningsActor;
    await expectLater(
        repository.read(EarningsPeriod.allTime,
            before: const PageCursor('time', 'id')),
        throwsArgumentError);
    expect(calls, isEmpty);
  });
  test('changed session and wrong response identity are rejected', () async {
    mode = 'session';
    await expectLater(
        repository.read(EarningsPeriod.thisMonth), throwsStateError);
    auth.identity = earningsActor;
    mode = 'wrong-provider';
    await expectLater(
        repository.read(EarningsPeriod.thisMonth), throwsFormatException);
  });
  test('permission error is not converted to sample or zero earnings',
      () async {
    mode = 'error';
    await expectLater(repository.read(EarningsPeriod.thisMonth),
        throwsA(isA<PostgrestException>()));
  });
}
