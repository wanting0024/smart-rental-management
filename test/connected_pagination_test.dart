import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_history_sheet.dart';
import 'package:rental_app_demo/widgets/connected_paged_list.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

const cursor = PageCursor('2030-01-01T00:00:00.123456Z', '2');
BookingMessage msg(String id) => BookingMessage(
      id: id,
      bookingId: 'booking',
      senderUserId: 'provider',
      body: 'Message $id',
      createdAt: DateTime.utc(2030, 1, 1),
    );
CursorFeed<BookingMessage> messages(
  Future<CursorPage<BookingMessage>> Function(PageCursor?) load,
) =>
    CursorFeed(
      loadPage: load,
      idOf: (v) => v.id,
      compare: (a, b) => b.id.compareTo(a.id),
    );

void main() {
  testWidgets(
      'older message failure preserves the visible messages and composer draft',
      (tester) async {
    var olderCalls = 0;
    final feed = messages((before) async {
      if (before == null) return CursorPage(items: [msg('3')], next: cursor);
      if (olderCalls++ == 0) throw StateError('offline');
      return CursorPage(items: [msg('2'), msg('1')]);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ConnectedBookingMessagesScreen(
          bookingId: 'booking',
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
    await tester.enterText(find.byType(TextField), 'Keep my draft');
    await tester.tap(find.text('Load older messages'));
    await tester.pumpAndSettle();
    expect(find.text('Message 3'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Keep my draft',
    );
    await tester.tap(find.text('Retry loading older records'));
    await tester.pumpAndSettle();
    expect(feed.items.map((m) => m.id), ['3', '2', '1']);
    expect(find.text('You’re all caught up'), findsOneWidget);
  });

  testWidgets('load-more button stays disabled until its request completes',
      (tester) async {
    final pending = Completer<CursorPage<int>>();
    var requests = 0;
    final feed = CursorFeed<int>(
      loadPage: (before) async {
        requests++;
        return before == null
            ? const CursorPage(items: [3], next: cursor)
            : pending.future;
      },
      idOf: (v) => '$v',
      compare: (a, b) => b.compareTo(a),
    );
    addTearDown(feed.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ConnectedPagedList<int>(
            feed: feed,
            itemBuilder: (v) => Text('Booking $v'),
            emptyTitle: 'Empty',
            emptyMessage: 'No records',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load older records'));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Loading…'),
              matching:
                  find.byWidgetPredicate((widget) => widget is OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(requests, 2);
    pending.complete(const CursorPage(items: [2, 1]));
    await tester.pumpAndSettle();
    expect(find.text('3 shown · Newest first'), findsOneWidget);
  });

  testWidgets(
      'paged history loads older changes without replacing the latest change',
      (tester) async {
    Map<String, dynamic> event(String id) => {
          'status_history_id': id,
          'previous_status': 'Pending',
          'new_status': 'Accepted',
          'changed_at': '2030-01-01T00:00:00Z',
        };
    final feed = CursorFeed<Map<String, dynamic>>(
      loadPage: (before) async => before == null
          ? CursorPage(items: [event('3')], next: cursor)
          : CursorPage(items: [event('2'), event('1')]),
      idOf: (r) => r['status_history_id'] as String,
      compare: (a, b) => (b['status_history_id'] as String)
          .compareTo(a['status_history_id'] as String),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ConnectedBookingHistorySheet(
            bookingId: 'booking',
            pagedHistory: feed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load older changes'));
    await tester.pumpAndSettle();
    expect(feed.items, hasLength(3));
    expect(find.text('Request accepted'), findsWidgets);
    expect(find.text('Latest update'), findsOneWidget);
  });

  testWidgets('paged chat fits a narrow keyboard viewport with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final feed =
        messages((_) async => CursorPage(items: [msg('3')], next: cursor));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 280),
          ),
          child: child!,
        ),
        home: ConnectedBookingMessagesScreen(
          bookingId: 'booking',
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
    expect(find.byTooltip('Send message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
