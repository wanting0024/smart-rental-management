import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../tool/staging_business_acceptance_support.dart';
import '../tool/staging_negative_support.dart';

class _FakeUpstream extends http.BaseClient {
  int calls = 0;
  int status = 200;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    await request.finalize().drain<void>();
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"saved":true}')),
      status,
    );
  }
}

void main() {
  const path = '/rest/v1/rpc/create_pending_booking';
  Uri target([String p = path]) =>
      Uri.parse('https://$businessStagingRef.supabase.co$p');
  test('before-send loss never reaches upstream, then same operation can retry',
      () async {
    final upstream = _FakeUpstream();
    final client = StagingFaultClient(upstream);
    addTearDown(client.close);
    client.arm(path, TestNetworkFault.beforeSend);
    await expectLater(
      client.post(target()),
      throwsA(isA<InjectedTransportTimeout>()),
    );
    expect(upstream.calls, 0);
    expect(client.injected, 1);
    expect(client.armed, false);
    expect((await client.post(target())).statusCode, 200);
    expect(upstream.calls, 1);
  });
  test(
      'after-success fault waits for actual upstream success then loses response',
      () async {
    final upstream = _FakeUpstream();
    final client = StagingFaultClient(upstream);
    addTearDown(client.close);
    client.arm(path, TestNetworkFault.afterSuccess);
    await expectLater(
      client.post(target()),
      throwsA(isA<InjectedTransportTimeout>()),
    );
    expect(upstream.calls, 1);
    expect(client.injected, 1);
    expect(client.armed, false);
  });
  test('HTTP permission denial is not recast as a lost HTTP success response',
      () async {
    final upstream = _FakeUpstream()..status = 403;
    final client = StagingFaultClient(upstream);
    addTearDown(client.close);
    client.arm(path, TestNetworkFault.afterSuccess);
    expect((await client.post(target())).statusCode, 403);
    expect(client.injected, 0);
  });
  test('read never consumes a fault scoped to a POST write', () async {
    final upstream = _FakeUpstream();
    final client = StagingFaultClient(upstream);
    addTearDown(client.close);
    client.arm(path, TestNetworkFault.beforeSend);
    expect((await client.get(target())).statusCode, 200);
    expect(client.armed, true);
    await expectLater(
      client.post(target()),
      throwsA(isA<InjectedTransportTimeout>()),
    );
    expect(upstream.calls, 1);
  });
  test('cannot overwrite armed fault or inject an unreviewed endpoint', () {
    final client = StagingFaultClient(_FakeUpstream());
    addTearDown(client.close);
    expect(
      () => client.arm('/auth/v1/admin/users', TestNetworkFault.beforeSend),
      throwsStateError,
    );
    client.arm(path, TestNetworkFault.beforeSend);
    expect(
      () => client.arm(path, TestNetworkFault.afterSuccess),
      throwsStateError,
    );
  });
  for (final url in [
    'http://$businessStagingRef.supabase.co$path',
    'https://dvakrwalnqpcmgirmlct.supabase.co$path',
    'https://example.com$path',
    'https://$businessStagingRef.supabase.co:444$path',
    'https://user@$businessStagingRef.supabase.co$path',
  ]) {
    test('transport refuses non-pinned target $url', () async {
      final upstream = _FakeUpstream();
      final client = StagingFaultClient(upstream);
      addTearDown(client.close);
      await expectLater(client.post(Uri.parse(url)), throwsStateError);
      expect(upstream.calls, 0);
    });
  }
  Map<String, dynamic> state() {
    var n = 1;
    String uuid() =>
        '11111111-1111-4111-8111-${(n++).toString().padLeft(12, '0')}';
    return {
      'version': 1,
      'project_ref': businessStagingRef,
      'run_id': 'run',
      'property_id': uuid(),
      'service_type_id': uuid(),
      'cases': {
        for (final name in [
          'cancel_pending',
          'decline',
          'revise',
          'cancel_provider',
          'conflict_a',
          'conflict_b',
          'upload',
        ])
          name: {
            for (final field in [
              'request_id',
              'message_id',
              'bad_upload_id',
              'before_upload_id',
              'after_upload_id',
            ])
              field: uuid(),
            'start': '2026-10-30T02:00:00.000Z',
            'end': '2026-10-30T04:00:00.000Z',
          },
      },
    };
  }

  test('seven stable scoped cases accepted offline', () {
    expect(
      () => requireNegativeState(state(), {'run_id': 'run'}),
      returnsNormally,
    );
  });
  for (final field in [
    'version',
    'project_ref',
    'run_id',
    'property_id',
    'service_type_id',
  ]) {
    test('changed checkpoint $field denied', () {
      final s = state()..[field] = 'wrong';
      expect(
        () => requireNegativeState(s, {'run_id': 'run'}),
        throwsStateError,
      );
    });
  }
  test('no unbounded or missing cases', () {
    final s = state();
    (s['cases'] as Map).remove('decline');
    expect(() => requireNegativeState(s, {'run_id': 'run'}), throwsStateError);
    (s['cases'] as Map)['eighth'] = <String, String>{};
    expect(() => requireNegativeState(s, {'run_id': 'run'}), throwsStateError);
  });
  test('duplicate operation IDs rejected', () {
    final s = state();
    final c = (s['cases'] as Map)['upload'] as Map;
    c['before_upload_id'] = c['request_id'];
    expect(() => requireNegativeState(s, {'run_id': 'run'}), throwsStateError);
  });
  test('changed duration denied before remote operations', () {
    final s = state();
    ((s['cases'] as Map)['upload'] as Map)['end'] = '2026-10-30T05:00:00.000Z';
    expect(() => requireNegativeState(s, {'run_id': 'run'}), throwsStateError);
  });
}
