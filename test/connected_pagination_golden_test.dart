import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var directory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${directory.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Flutter fonts unavailable.');
      }
      directory = parent;
    }
    Future<ByteData> font(String name) async {
      final path = '${directory.path}/bin/cache/artifacts/material_fonts/$name';
      return ByteData.sublistView(await File(path).readAsBytes());
    }

    await (FontLoader('Roboto')..addFont(font('roboto-regular.ttf'))).load();
    await (FontLoader('MaterialIcons')
          ..addFont(font('materialicons-regular.otf')))
        .load();
  });

  testWidgets('chat live reconnect keeps the draft visible phone preview',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final changes = StreamController<PageChange>(onCancel: () async {});
    addTearDown(changes.close);
    final feed = CursorFeed<BookingMessage>(
      watchChanges: () => changes.stream,
      loadPage: (_) async => CursorPage(
        items: [
          BookingMessage(
            id: 'preview-message',
            bookingId: 'preview',
            senderUserId: 'provider',
            body: 'I have arrived and will start with the kitchen.',
            createdAt: DateTime.utc(2026, 10, 22, 2),
          ),
        ],
      ),
      idOf: (row) => row.id,
      compare: (_, __) => 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: ConnectedBookingMessagesScreen(
          bookingId: 'preview',
          currentUserId: 'owner',
          isProvider: false,
          pagedMessages: feed,
          bookingStatus: () => Stream.value('Accepted'),
          send: (_, __) async {},
          wasSent: (_, __) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Please use the side gate.');
    changes.addError(StateError('synthetic connection interruption'));
    await tester.pumpAndSettle();
    expect(find.text('Reconnect'), findsOneWidget);
    await expectLater(
      find.byType(ConnectedBookingMessagesScreen),
      matchesGoldenFile('goldens/connected_chat_reconnect.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final failed in [false, true]) {
    testWidgets(
        'paged chat ${failed ? 'retry' : 'older messages'} phone preview',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final feed = CursorFeed<BookingMessage>(
        loadPage: (before) async {
          if (before != null) throw StateError('simulated offline');
          return CursorPage(
            items: [
              BookingMessage(
                id: '12',
                bookingId: 'preview',
                senderUserId: 'owner',
                body: 'Thank you. Please upload the before and after photos.',
                createdAt: DateTime.utc(2026, 10, 22, 2, 2),
              ),
              BookingMessage(
                id: '11',
                bookingId: 'preview',
                senderUserId: 'provider',
                body: 'I have arrived and will start with the kitchen.',
                createdAt: DateTime.utc(2026, 10, 22, 2),
              ),
            ],
            next: const PageCursor('2026-10-22T02:00:00.000000Z', '11'),
          );
        },
        idOf: (row) => row.id,
        compare: (a, b) => b.createdAt.compareTo(a.createdAt),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          debugShowCheckedModeBanner: false,
          home: ConnectedBookingMessagesScreen(
            bookingId: 'preview',
            currentUserId: 'owner',
            isProvider: false,
            pagedMessages: feed,
            bookingStatus: () => Stream.value('Accepted'),
            send: (_, __) async {},
            wasSent: (_, __) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (failed) {
        await tester.enterText(
          find.byType(TextField),
          'Please keep this draft.',
        );
        await tester.tap(find.text('Load older messages'));
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(ConnectedBookingMessagesScreen),
        matchesGoldenFile(
          'goldens/paged_chat_${failed ? 'retry' : 'older'}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
