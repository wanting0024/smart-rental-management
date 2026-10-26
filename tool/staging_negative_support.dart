// Administrator-free test transport. Never imported by lib/ or enabled in App.
import 'dart:async';
import 'package:http/http.dart' as http;
import 'staging_business_acceptance_support.dart';

enum TestNetworkFault { beforeSend, afterSuccess }

class StagingFaultClient extends http.BaseClient {
  StagingFaultClient(this.inner);
  final http.Client inner;
  static const permittedFaults = {
    '/rest/v1/rpc/create_pending_booking',
    '/rest/v1/rpc/accept_pending_booking',
    '/rest/v1/rpc/revise_pending_booking',
    '/rest/v1/rpc/transition_booking',
    '/rest/v1/rpc/send_booking_message',
    '/functions/v1/evidence-validate',
  };
  String? _path;
  TestNetworkFault? _fault;
  int injected = 0, forwarded = 0;
  void arm(String path, TestNetworkFault fault) {
    if (_path != null || !permittedFaults.contains(path)) {
      throw StateError('One explicitly scoped write fault only.');
    }
    _path = path;
    _fault = fault;
  }

  bool get armed => _path != null;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Refuse redirects/other projects even if a caller mutates its client config.
    if (request.url.scheme != 'https' ||
        request.url.host != '$businessStagingRef.supabase.co' ||
        request.url.port != 443 ||
        request.url.userInfo.isNotEmpty) {
      throw StateError('Fault transport only forwards pinned Staging HTTPS.');
    }
    request.followRedirects = false;
    final hit = request.method == 'POST' && request.url.path == _path;
    final fault = hit ? _fault : null;
    if (hit) {
      _path = null;
      _fault = null;
    }
    if (fault == TestNetworkFault.beforeSend) {
      injected++;
      throw InjectedTransportTimeout('before_send');
    }
    forwarded++;
    final response = await inner.send(request);
    if (fault == TestNetworkFault.afterSuccess) {
      // Drain the REAL HTTP-2xx response, then hide it from SDK. HTTP success
      // alone does NOT prove a business commit: the harness verifies readback.
      // HTTP errors surface unmodified; no positive result is fabricated.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await response.stream.drain<void>();
        injected++;
        throw InjectedTransportTimeout('success_response_lost');
      }
    }
    return response;
  }

  @override
  void close() => inner.close();
}

// Inherits TimeoutException so the real App failure guidance treats this as
// uncertain transport, never a database/business denial. No private URI/body.
class InjectedTransportTimeout extends TimeoutException {
  InjectedTransportTimeout(String phase) : super('Test transport: $phase');
}

void requireNegativeState(Map state, Map fixture) {
  if (state['version'] != 1 ||
      state['project_ref'] != businessStagingRef ||
      state['run_id'] != fixture['run_id'] ||
      !businessUuid.hasMatch('${state['property_id']}') ||
      !businessUuid.hasMatch('${state['service_type_id']}')) {
    throw StateError('Negative checkpoint target mismatch.');
  }
  final cases = state['cases'] as Map;
  if (cases.keys.toSet().difference({
        'cancel_pending',
        'decline',
        'revise',
        'cancel_provider',
        'conflict_a',
        'conflict_b',
        'upload',
      }).isNotEmpty ||
      cases.length != 7) {
    throw StateError('Exactly seven bounded test cases required.');
  }
  final ids = <String>{};
  for (final value in cases.values.cast<Map>()) {
    if (!businessUuid.hasMatch('${value['request_id']}') ||
        !ids.add(value['request_id'] as String)) {
      throw StateError('Stable distinct request IDs required.');
    }
    final start = DateTime.parse(value['start'] as String);
    final end = DateTime.parse(value['end'] as String);
    if (!start.isUtc ||
        !end.isUtc ||
        end.difference(start) != const Duration(hours: 2)) {
      throw StateError('Fixed quoted duration required.');
    }
    for (final field in [
      'message_id',
      'bad_upload_id',
      'before_upload_id',
      'after_upload_id',
    ]) {
      if (!businessUuid.hasMatch('${value[field]}') ||
          !ids.add(value[field] as String)) {
        throw StateError('Stable distinct operation IDs required.');
      }
    }
  }
}
