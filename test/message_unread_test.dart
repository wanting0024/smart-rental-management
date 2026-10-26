import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/message_unread_binding.dart';
import 'package:rental_app_demo/widgets/message_unread_scope.dart';
import 'package:rental_app_demo/widgets/visible_message_receipt.dart';
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';

void main() {
  testWidgets('unknown is not zero, foreground poll stops in background',
      (tester) async {
    var calls = 0;
    final binding = MessageUnreadBinding(
        load: () async {
          calls++;
          return 3;
        },
        userId: 'owner',
        currentUserId: () => 'owner',
        sessions: const Stream.empty());
    expect(binding.count, isNull);
    binding.setActive(true);
    await tester.pump();
    expect(binding.count, 3);
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 2);
    binding.setActive(false);
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 2);
    binding.dispose();
  });
  testWidgets(
      'failed refresh keeps confirmed count, never clears unread optimistically',
      (tester) async {
    var bad = false;
    final binding = MessageUnreadBinding(
        load: () async {
          if (bad) throw StateError('offline');
          return 4;
        },
        userId: 'owner',
        currentUserId: () => 'owner',
        sessions: const Stream.empty());
    binding.setActive(true);
    await tester.pump();
    bad = true;
    await binding.refresh();
    expect(binding.count, 4);
    expect(binding.failed, true);
    binding.dispose();
  });
  testWidgets('session switch clears counts and rejects late reply',
      (tester) async {
    final response = Completer<int>();
    final sessions = StreamController<String?>.broadcast(sync: true);
    var user = 'owner';
    final binding = MessageUnreadBinding(
        load: () => response.future,
        userId: user,
        currentUserId: () => user,
        sessions: sessions.stream);
    binding.setActive(true);
    user = 'provider';
    sessions.add(user);
    response.complete(99);
    await tester.pump();
    expect(binding.count, isNull);
    expect(binding.active, false);
    binding.dispose();
    await sessions.close();
  });
  testWidgets(
      'receipt during in-flight badge refresh invalidates stale count and rechecks',
      (tester) async {
    final old = Completer<int>();
    final changed = ValueNotifier(0);
    var calls = 0;
    final binding = MessageUnreadBinding(
        load: () {
          calls++;
          return calls == 1 ? old.future : Future.value(0);
        },
        userId: 'owner',
        currentUserId: () => 'owner',
        sessions: const Stream.empty(),
        changes: changed);
    binding.setActive(true);
    changed.value++;
    old.complete(8);
    await tester.pump();
    expect(binding.count, 0);
    expect(calls, 2);
    binding.dispose();
    changed.dispose();
  });
  testWidgets(
      'only observed IDs acknowledged, deduped and background pending cancelled',
      (tester) async {
    final batches = <List<String>>[];
    final reads = VisibleMessageReads((ids) async {
      batches.add(ids);
    });
    reads.seen('hidden');
    reads.setActive(true);
    reads.seen('shown');
    reads.seen('shown');
    await tester.pump(const Duration(milliseconds: 210));
    expect(batches, [
      ['shown']
    ]);
    reads.seen('shown');
    reads.seen('background');
    reads.setActive(false);
    await tester.pump(const Duration(seconds: 6));
    expect(batches.length, 1);
    reads.dispose();
  });
  testWidgets(
      'failed read is not confirmed, bounded retry succeeds with same IDs',
      (tester) async {
    var calls = 0;
    final batches = <List<String>>[];
    final reads = VisibleMessageReads((ids) async {
      batches.add(ids);
      if (calls++ == 0) throw StateError('offline');
    });
    reads.setActive(true);
    reads.seen('incoming');
    await tester.pump(const Duration(milliseconds: 210));
    reads.seen('incoming');
    await tester.pump(const Duration(seconds: 4));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    expect(batches, [
      ['incoming'],
      ['incoming']
    ]);
    reads.seen('incoming');
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    reads.dispose();
  });
  testWidgets('visible acknowledgement batches never exceed 50',
      (tester) async {
    final batches = <List<String>>[];
    final reads = VisibleMessageReads((ids) async {
      batches.add(ids);
    });
    reads.setActive(true);
    for (var i = 0; i < 120; i++) reads.seen('$i');
    for (var i = 0; i < 3; i++)
      await tester.pump(const Duration(milliseconds: 210));
    expect(batches.map((b) => b.length), [50, 50, 20]);
    reads.dispose();
  });
  testWidgets(
      'cache-built offscreen bubbles are not read, scrolling exposes only painted items',
      (tester) async {
    final seen = <int>{};
    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    height: 300,
                    child: ListView.builder(
                        controller: scroll,
                        itemExtent: 100,
                        itemCount: 30,
                        itemBuilder: (_, i) => VisibleMessageReceipt(
                            onVisible: () => seen.add(i),
                            child: Text('Message $i'))))))));
    await tester.pump();
    expect(seen, containsAll([0, 1, 2]));
    expect(seen.contains(5), false);
    scroll.jumpTo(600);
    await tester.pump();
    await tester.pump();
    expect(seen, containsAll([6, 7, 8]));
    expect(seen.contains(15), false);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
  testWidgets('shared badge caps visual count but preserves accessible count',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final binding = MessageUnreadBinding(
        load: () async => 123,
        userId: 'owner',
        currentUserId: () => 'owner',
        sessions: const Stream.empty());
    binding.setActive(true);
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
        home: MessageUnreadScope(
            binding: binding,
            child: const Scaffold(
                body: MessageUnreadBadge(child: Icon(Icons.chat))))));
    expect(find.text('99+'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('123 unread messages')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
    binding.dispose();
  });
  testWidgets(
      'original conversation acknowledges visible inbound only, never own message',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final seen = <String>[];
    final rows = List.generate(
        25,
        (i) => BookingMessage(
            id: 'm$i',
            bookingId: 'booking',
            senderUserId: i == 24 ? 'owner' : 'provider',
            body: List.filled(8, 'Synthetic message $i').join(' '),
            createdAt: DateTime.utc(2026, 10, 24, 0, i)));
    await tester.pumpWidget(MaterialApp(
        home: ConnectedBookingMessagesScreen(
            bookingId: 'booking',
            currentUserId: 'owner',
            isProvider: false,
            messages: () => Stream.value(rows),
            bookingStatus: () => Stream.value('Completed'),
            send: (_, __) async {},
            wasSent: (_, __) async => false,
            markRead: (ids) async {
              seen.addAll(ids);
            })));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(seen, isNotEmpty);
    expect(seen.contains('m24'), false);
    expect(seen.contains('m0'), false);
    await tester.pumpWidget(const SizedBox());
  });
}
