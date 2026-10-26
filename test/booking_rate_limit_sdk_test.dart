import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/booking_rate_limit.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_evidence_repository.dart';

class _LocalNetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LocalNetworkBinding();
  late HttpServer server;
  late SupabaseClient client;
  var requests = 0, storageRequests = 0;
  var errorMessage = 'CHAT_RATE_LIMITED';
  setUp(() async {
    requests = 0;
    storageRequests = 0;
    errorMessage = 'CHAT_RATE_LIMITED';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      requests++;
      if (request.uri.path.startsWith('/storage/')) storageRequests++;
      request.response.statusCode = 429;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'code': 'PT429',
        'message': errorMessage,
        'details': 'retry_after_seconds=12',
      }),);
      await request.response.close();
    });
    client = SupabaseClient('http://${server.address.host}:${server.port}',
        'sb_publishable_synthetic_fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('actual SDK maps message 429 without blindly retrying the POST',
      () async {
    await expectLater(
        SupabaseMessageRepository(client).send(
            bookingId: 'SYNTHETIC_BOOKING',
            clientMessageId: 'SYNTHETIC_ID',
            body: 'SYNTHETIC TEST MESSAGE',),
        throwsA(isA<ServerActionLimit>()
            .having((limit) => limit.retryAfterSeconds, 'wait', 12),),);
    expect(requests, 1);
    expect(storageRequests, 0);
  });
  test('limited upload ticket never sends bytes or tries to attach', () async {
    errorMessage = 'EVIDENCE_RATE_LIMITED';
    await expectLater(
        SupabaseEvidenceRepository(client).upload(
            bookingId: 'SYNTHETIC_BOOKING',
            kind: EvidenceKind.before,
            bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
            uploadId: 'SYNTHETIC_ID',
            expectedPreviousPath: null,),
        throwsA(isA<ServerActionLimit>().having(
            (limit) => limit.action, 'action', BookingLimitedAction.evidence,),),);
    expect(requests, 1);
    expect(storageRequests, 0);
  });
  test('unknown gateway 429 is not misreported as confirmed rejection',
      () async {
    errorMessage = 'SYNTHETIC_GATEWAY_ERROR';
    await expectLater(
        SupabaseMessageRepository(client).send(
            bookingId: 'SYNTHETIC_BOOKING',
            clientMessageId: 'SYNTHETIC_ID',
            body: 'SYNTHETIC TEST MESSAGE',),
        throwsA(isA<PostgrestException>()),);
    expect(requests, 1);
  });
}
