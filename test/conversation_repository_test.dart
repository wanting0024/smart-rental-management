import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';

const actor = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _Auth extends GoTrueClient {
  _Auth()
      : super(url: 'https://fixture.invalid/auth/v1', autoRefreshToken: false);
  String? identity = actor;
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
  late SupabaseMessageRepository repo;
  Map? payload;
  String? route;
  var foreign = false;
  Completer<void>? delay;
  setUp(() async {
    foreign = false;
    delay = null;
    payload = null;
    route = null;
    auth = _Auth();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      route = request.uri.path;
      final raw = await utf8.decoder.bind(request).join();
      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      payload = decoded is Map ? decoded : {};
      await delay?.future;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(route!.endsWith('my_message_unread')
          ? {
              'recipient_id': foreign ? 'other' : actor,
              'messages': 3,
              'threads': 2
            }
          : route!.endsWith('read_booking_messages')
              ? {
                  'recipient_id': foreign ? 'other' : actor,
                  'booking_id': payload!['p_booking_id'],
                  'acknowledged': (payload!['p_ids'] as List).length
                }
              : {
                  'recipient_id': foreign ? 'other' : actor,
                  'as_of': payload!['p_as_of'] ?? '2026-10-24T01:00:00+00:00',
                  'search': payload!['p_search'],
                  'unread_only':
                      route!.endsWith('page_my_unread_conversations'),
                  'unread_total': 0,
                  'items': [],
                  'has_more': false,
                  'next_cursor': null
                }));
      await request.response.close();
    });
    client = _Client('http://127.0.0.1:${server.port}', auth);
    repo = SupabaseMessageRepository(client);
  });
  test(
      'read receipts use exact IDs, confirmed identity and no caller actor parameter',
      () async {
    await repo.markRead('booking', ['one', 'two']);
    expect(route, '/rest/v1/rpc/read_booking_messages');
    expect(payload, {
      'p_booking_id': 'booking',
      'p_ids': ['one', 'two']
    });
    expect(repo.changes.value, 1);
    foreign = true;
    await expectLater(repo.markRead('booking', ['one']), throwsFormatException);
    expect(repo.changes.value, 1);
  });
  test('global unread validates recipient, filter uses distinct bounded RPC',
      () async {
    expect(await repo.unread(), 3);
    foreign = true;
    await expectLater(repo.unread(), throwsFormatException);
    foreign = false;
    await repo.conversations('', unreadOnly: true);
    expect(route, '/rest/v1/rpc/page_my_unread_conversations');
  });
  test('empty or duplicate read batches denied before network', () async {
    await expectLater(repo.markRead('booking', []), throwsArgumentError);
    await expectLater(
        repo.markRead('booking', ['one', 'one']), throwsArgumentError);
    expect(route, isNull);
  });
  tearDown(() async {
    await client.dispose();
    auth.dispose();
    await server.close(force: true);
  });
  test(
      'bounded search RPC forwards exact cursor and server snapshot, no caller actor',
      () async {
    await repo.conversations('unit',
        before: const PageCursor('2026-10-23T01:00:00.123456+00:00', 'thread'),
        asOf: '2026-10-24T01:00:00+00:00');
    expect(route, '/rest/v1/rpc/page_my_conversations');
    expect(payload, {
      'p_limit': 20,
      'p_search': 'unit',
      'p_before_at': '2026-10-23T01:00:00.123456+00:00',
      'p_before_id': 'thread',
      'p_as_of': '2026-10-24T01:00:00+00:00'
    });
    foreign = true;
    await expectLater(repo.conversations(''), throwsFormatException);
  });
  test('unauthenticated reads rejected before network access', () async {
    auth.identity = null;
    await expectLater(repo.conversations(''), throwsStateError);
    expect(route, isNull);
  });
  test('in-flight previous identity response never reaches new account',
      () async {
    delay = Completer();
    final request = repo.conversations('');
    final rejected = expectLater(request, throwsStateError);
    while (payload == null) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    auth.identity = 'other';
    delay!.complete();
    await rejected;
  });
}
