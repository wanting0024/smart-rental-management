import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/paged_realtime.dart';

void main() {
  test(
      'installed SDK joins/leaves twenty times without growing its channel registry',
      () async {
    // Loopback protocol fixture, not Supabase Auth/RLS/Realtime certification.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    var joins = 0, leaves = 0;
    final serverTask = server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((raw) {
        final message = jsonDecode(raw as String) as List;
        final event = message[3] as String;
        if (event == 'phx_join') joins++;
        if (event == 'phx_leave') leaves++;
        if (socket.readyState == WebSocket.open &&
            (event == 'phx_join' ||
                event == 'phx_leave' ||
                event == 'heartbeat')) {
          socket.add(
            jsonEncode([
              message[0],
              message[1],
              message[2],
              'phx_reply',
              {'status': 'ok', 'response': <String, dynamic>{}},
            ]),
          );
        }
      });
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    try {
      for (var i = 0; i < 20; i++) {
        final joined = Completer<void>();
        final subscription = pagedRowChanges(
          client,
          table: 'booking',
          idColumn: 'booking_id',
          filterColumn: 'owner_id',
          filterValue: 'fixture-owner',
        ).listen(
          (event) {
            if (event.kind == PageChangeKind.reset && !joined.isCompleted) {
              joined.complete();
            }
          },
          onError: joined.completeError,
        );
        await joined.future.timeout(const Duration(seconds: 5));
        expect(client.getChannels(), hasLength(1));
        await subscription.cancel();
        expect(client.getChannels(), isEmpty);
      }
      expect(joins, 20);
      // The SDK may close the final socket before the peer reads phx_leave.
      // Registry removal plus completed socket closure is the invariant.
      expect(leaves, lessThanOrEqualTo(joins));
      await Future.wait(sockets.map((socket) => socket.done))
          .timeout(const Duration(seconds: 5));
    } finally {
      await client.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await serverTask.cancel();
      await server.close(force: true);
    }
  });
}
