import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/evidence_upload_flow.dart';

void main() {
  final png =
      Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1]);
  EvidencePhotoUpload photo() => EvidencePhotoUpload(
        kind: EvidenceKind.before,
        bytes: png,
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );

  test('selection has stable immutable naming and content fingerprint', () {
    final selection = photo();
    expect(
      selection.pathFor('booking'),
      'booking/before_aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.png',
    );
    expect(selection.contentType, 'image/png');
    expect(selection.digest, hasLength(64));
    expect(selection.digest, photo().digest);
    final source = Uint8List.fromList(png);
    final snapshot =
        EvidencePhotoUpload(kind: EvidenceKind.after, bytes: source);
    source[8] = 99;
    expect(snapshot.bytes[8], 1);
    expect(() => snapshot.bytes[8] = 2, throwsUnsupportedError);
    expect(snapshot.id, matches(RegExp(r'^[a-f0-9-]{36}$')));
  });

  test('invalid or oversized image is rejected before network use', () async {
    var calls = 0;
    final flow = EvidenceUploadFlow(
      begin: (_) async {
        calls++;
        return {};
      },
      put: (_, __) async {},
      attach: (_) async => {},
    );
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
      Uint8List(EvidencePhotoUpload.maxBytes + 1),
    ]) {
      await expectLater(
        flow.run(
          'booking',
          EvidencePhotoUpload(kind: EvidenceKind.before, bytes: bytes),
        ),
        throwsArgumentError,
      );
    }
    expect(calls, 0);
  });

  test('lost upload response can still attach one existing object', () async {
    var uploads = 0;
    var attachments = 0;
    final selection = photo();
    final flow = EvidenceUploadFlow(
      begin: (_) async => {
        'state': 'pending',
        'path': selection.pathFor('booking'),
        'uploaded': false,
      },
      put: (_, __) async {
        uploads++;
        throw StateError('response lost');
      },
      attach: (_) async {
        attachments++;
        return {'attached': true, 'path': selection.pathFor('booking')};
      },
    );
    expect(await flow.run('booking', selection), selection.pathFor('booking'));
    expect(uploads, 1);
    expect(attachments, 1);
  });

  test('retry skips stored bytes and repeats attachment with the same ID',
      () async {
    var uploads = 0;
    var commits = 0;
    var stored = false;
    final selection = photo();
    final ids = <String>[];
    final flow = EvidenceUploadFlow(
      begin: (p) async {
        ids.add(p.id);
        return {
          'state': 'pending',
          'path': p.pathFor('booking'),
          'uploaded': stored,
        };
      },
      put: (_, __) async {
        uploads++;
        stored = true;
      },
      attach: (_) async {
        commits++;
        if (commits == 1) throw StateError('offline');
        return {'attached': true, 'path': selection.pathFor('booking')};
      },
    );
    await expectLater(flow.run('booking', selection), throwsStateError);
    expect(await flow.run('booking', selection), selection.pathFor('booking'));
    expect(uploads, 1);
    expect(ids, [selection.id, selection.id]);
  });

  test('already attached retry performs no upload or mutation', () async {
    final selection = photo();
    final flow = EvidenceUploadFlow(
      begin: (_) async =>
          {'state': 'attached', 'path': selection.pathFor('booking')},
      put: (_, __) async => fail('must not upload again'),
      attach: (_) async => throw StateError('must not mutate again'),
    );
    expect(await flow.run('booking', selection), selection.pathFor('booking'));
  });

  test('closed, retired or incorrectly scoped tickets never upload', () async {
    final selection = photo();
    for (final ticket in [
      {'state': 'closed'},
      {'state': 'deleting', 'path': selection.pathFor('booking')},
      {'state': 'pending', 'path': 'someone-else/photo.png'},
    ]) {
      final flow = EvidenceUploadFlow(
        begin: (_) async => ticket,
        put: (_, __) async => fail('unsafe ticket'),
        attach: (_) async => {},
      );
      await expectLater(
        flow.run('booking', selection),
        throwsA(isA<EvidenceUploadRejected>()),
      );
    }
  });

  test('competing replacement is not reported as a saved selection', () async {
    final selection = photo();
    final flow = EvidenceUploadFlow(
      begin: (_) async => {
        'state': 'pending',
        'path': selection.pathFor('booking'),
        'uploaded': true,
      },
      put: (_, __) async => fail('already stored'),
      attach: (_) async => {'attached': false, 'reason': 'photo_changed'},
    );
    await expectLater(
      flow.run('booking', selection),
      throwsA(
        isA<EvidenceUploadRejected>()
            .having((e) => e.reason, 'reason', 'photo_changed'),
      ),
    );
  });
}
