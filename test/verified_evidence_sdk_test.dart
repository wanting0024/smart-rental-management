import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/supabase_evidence_repository.dart';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _NetworkBinding();
  const booking = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  const upload = '11111111-1111-4111-8111-111111111111';
  const path = '$booking/before_$upload.jpg';
  final bytes = Uint8List.fromList(
      [255, 216, 255],); // Protocol fixture, not a real image.
  late HttpServer server;
  late SupabaseClient client;
  late List<String> calls;
  var mode = 'valid';
  setUp(() async {
    calls = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      calls.add(request.uri.path);
      final received =
          await request.fold<List<int>>([], (a, b) => a..addAll(b));
      dynamic body;
      if (request.uri.path.endsWith('begin_evidence_upload')) {
        body = {'state': 'pending', 'path': path, 'uploaded': false};
      } else if (request.uri.path.contains('/functions/')) {
        expect(received, bytes);
        expect(request.headers.value('x-upload-id'), upload);
        expect(request.headers.value('x-booking-id'), booking);
        expect(
            request.headers.contentType?.mimeType, 'application/octet-stream',);
        if (mode == 'lost') {
          (await request.response.detachSocket(writeHeaders: false)).destroy();
          return;
        }
        if (mode == 'reject') {
          request.response.statusCode = 422;
          body = {'code': 'PHOTO_REJECTED'};
        } else if (mode == 'busy') {
          request.response.statusCode = 503;
          body = {'code': 'VALIDATION_BUSY'};
        } else {
          body = {'verified': true, 'path': path};
        }
      } else if (request.uri.path.endsWith('attach_evidence_upload')) {
        body = mode == 'busy'
            ? {'attached': false, 'reason': 'upload_not_confirmed'}
            : {'attached': true, 'path': path};
      } else {
        fail('Unexpected direct Storage or alternate upload request');
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
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
  Future<String> send() => SupabaseEvidenceRepository(client).upload(
      bookingId: booking,
      kind: EvidenceKind.before,
      bytes: bytes,
      uploadId: upload,
      expectedPreviousPath: null,);
  test('installed SDK sends binary to validator, never directly to Storage',
      () async {
    mode = 'valid';
    expect(await send(), path);
    expect(calls.length, 3);
    expect(calls[1], '/functions/v1/evidence-validate');
  });
  test('definitive photo rejection does not attempt attachment', () async {
    mode = 'reject';
    await expectLater(
        send(),
        throwsA(isA<EvidenceUploadRejected>()
            .having((e) => e.reason, 'reason', 'photo_rejected'),),);
    expect(calls.length, 2);
  });
  test('busy validation cannot be mistaken for a saved photo', () async {
    mode = 'busy';
    await expectLater(
        send(),
        throwsA(isA<EvidenceUploadRejected>()
            .having((e) => e.reason, 'reason', 'upload_not_confirmed'),),);
    expect(calls.length, 3);
  });
  test('real lost HTTP response reconciles only through guarded attachment',
      () async {
    mode = 'lost';
    expect(await send(), path);
    expect(calls.length, 3);
  });
}
