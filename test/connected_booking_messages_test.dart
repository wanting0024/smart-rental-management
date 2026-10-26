import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

BookingMessage _message(String id, String sender, String body) =>
    BookingMessage(
      id: id,
      bookingId: 'booking-1',
      senderUserId: sender,
      body: body,
      createdAt: DateTime.utc(2026, 10, 22, 9),
    );

void main() {
  testWidgets('accepted booking sends and keeps one token for retry',
      (tester) async {
    final tokens = <String>[];
    final texts = <String>[];
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ConnectedBookingMessagesScreen(
        bookingId: 'booking-1',
        currentUserId: 'owner-1',
        isProvider: false,
        messages: () => Stream.value(const <BookingMessage>[]),
        bookingStatus: () => Stream.value('Accepted'),
        send: (token, body) async {
          tokens.add(token);
          texts.add(body);
          attempts++;
          if (attempts == 1) throw const SocketException('offline');
        },
        wasSent: (_, __) async => false,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField), '  Please use the side gate  ');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your draft is kept'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '  Please use the side gate  ');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(tokens, hasLength(2));
    expect(tokens[0], tokens[1]);
    expect(texts, ['Please use the side gate', 'Please use the side gate']);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });

  testWidgets('completed booking keeps messages readable but hides composer',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ConnectedBookingMessagesScreen(
        bookingId: 'booking-1',
        currentUserId: 'owner-1',
        isProvider: false,
        messages: () => Stream.value([
          _message('1', 'provider-1', 'I have finished the kitchen.'),
          _message('2', 'owner-1', 'Thank you.'),
        ]),
        bookingStatus: () => Stream.value('Completed'),
        send: (_, __) async => throw StateError('read-only'),
        wasSent: (_, __) async => false,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('I have finished the kitchen.'), findsOneWidget);
    expect(find.text('Thank you.'), findsOneWidget);
    expect(find.text('Conversation is read-only for this booking'),
        findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('lost send response is verified before retrying', (tester) async {
    var sends = 0;
    var checks = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ConnectedBookingMessagesScreen(
        bookingId: 'booking-1',
        currentUserId: 'owner-1',
        isProvider: false,
        messages: () => Stream.value(const <BookingMessage>[]),
        bookingStatus: () => Stream.value('Accepted'),
        send: (_, __) async {
          sends++;
          throw const SocketException('response lost');
        },
        wasSent: (_, __) async {
          checks++;
          return true;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Use the side gate');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(sends, 1);
    expect(checks, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(find.textContaining('Your draft is kept'), findsNothing);
  });

  testWidgets('live completion closes the message composer', (tester) async {
    final statuses = StreamController<String?>();
    addTearDown(statuses.close);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ConnectedBookingMessagesScreen(
        bookingId: 'booking-1',
        currentUserId: 'owner-1',
        isProvider: false,
        messages: () => Stream.value(const <BookingMessage>[]),
        bookingStatus: () => statuses.stream,
        send: (_, __) async {},
        wasSent: (_, __) async => false,
      ),
    ));
    statuses.add('Accepted');
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    statuses.add('Completed');
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Conversation is read-only for this booking'),
        findsOneWidget);
  });

  test('message model and token have expected fields', () {
    final message = BookingMessage.fromMap({
      'message_id': 'm1',
      'booking_id': 'b1',
      'sender_user_id': 'u1',
      'body': 'Hello',
      'created_at': '2026-10-22T09:00:00Z',
    });
    expect(message.body, 'Hello');
    expect(message.createdAt.isUtc, isTrue);
    expect(
        ClientMessageToken.newV4(),
        matches(RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
  });
}
