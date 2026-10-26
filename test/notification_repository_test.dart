import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/supabase_notification_repository.dart';
import 'package:rental_app_demo/services/backend/notification_snapshot.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'support/notification_fixture.dart';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

class _Auth extends GoTrueClient {
  _Auth()
      : super(url: 'https://fixture.invalid/auth/v1', autoRefreshToken: false);
  String? actor = notificationActor;
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
  late SupabaseNotificationRepository repo;
  final requests = <String>[];
  Map? payload;
  var wrong = false;
  setUp(() async {
    requests.clear();
    payload = null;
    wrong = false;
    auth = _Auth();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests.add(req.uri.path);
      payload = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
      req.response.headers.contentType = ContentType.json;
      if (req.uri.path.endsWith('read_my_notifications')) {
        req.response.write('1');
      } else {
        req.response.write(jsonEncode({
          ...notificationJson(
              filter: NotificationFilter.values
                  .byName(payload!['p_filter'] as String)),
          if (wrong) 'recipient_id': 'other'
        }));
      }
      await req.response.close();
    });
    client = _Client('http://127.0.0.1:${server.port}', auth);
    repo = SupabaseNotificationRepository(client);
  });
  tearDown(() async {
    await client.dispose();
    auth.dispose();
    await server.close(force: true);
  });
  test(
      'page uses own-only bounded RPC and precise cursor, never accepts a supplied recipient',
      () async {
    await repo.page(NotificationFilter.unread,
        before: const PageCursor(
            '2026-10-23T13:00:00.123456+00:00', notificationId),
        asOf: '2026-10-23T14:00:00+00:00');
    expect(requests, ['/rest/v1/rpc/page_my_notifications']);
    expect(payload!['p_limit'], 20);
    expect(payload!['p_before_at'], '2026-10-23T13:00:00.123456+00:00');
    expect(payload!.containsKey('recipient_id'), false);
    wrong = true;
    await expectLater(repo.page(NotificationFilter.all), throwsFormatException);
  });
  test(
      'read acknowledgement submits only IDs or server boundary; unauthenticated fails locally',
      () async {
    await repo.mark(ids: [notificationId]);
    expect(payload, {
      'p_ids': [notificationId],
      'p_through_at': null
    });
    await repo.mark(throughAt: '2026-10-23T14:00:00+00:00');
    expect(payload!['p_ids'], isNull);
    await expectLater(repo.mark(), throwsArgumentError);
    auth.actor = null;
    await expectLater(repo.page(NotificationFilter.all), throwsStateError);
    expect(requests.length, 2);
  });
}
