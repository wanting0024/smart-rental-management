import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_evidence_screen.dart';
import 'package:rental_app_demo/services/backend/booking_rate_limit.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_evidence_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  Widget chat(
          {required Future<void> Function(String, String) send,
          required Future<bool> Function(String, String) verify,
          Stream<String?> Function()? status,}) =>
      ConnectedBookingMessagesScreen(
          bookingId: 'synthetic-booking',
          currentUserId: 'synthetic-owner',
          isProvider: false,
          messages: () => Stream.value(const <BookingMessage>[]),
          bookingStatus: status ?? () => Stream.value('Accepted'),
          send: send,
          wasSent: verify,);

  Future<void> open(WidgetTester tester, Widget child,
      {bool dark = false,
      double width = 390,
      double height = 844,
      double scale = 1,}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,),
        home: child,),);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'limited chat keeps draft/token, pauses Send and never auto-retries',
      (tester) async {
    final tokens = <String>[];
    var lookups = 0;
    await open(
        tester,
        chat(send: (id, text) async {
          tokens.add(id);
          if (tokens.length == 1) {
            throw const ServerActionLimit(BookingLimitedAction.message, 10);
          }
        }, verify: (_, __) async {
          lookups++;
          return false;
        },),);
    await tester.enterText(
        find.byType(TextField), 'SYNTHETIC BOOKING INSTRUCTION',);
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Sending paused'), findsOneWidget);
    expect(find.textContaining('Your draft is kept'), findsOneWidget);
    expect(lookups, 0); // This is not a lost/uncertain write response.
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Send message',),)
            .onPressed,
        isNull,);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'SYNTHETIC BOOKING INSTRUCTION',);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(tokens, hasLength(1));
    expect(find.text('Sending paused'), findsNothing);
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(tokens, hasLength(2));
    expect(tokens[0], tokens[1]);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,);
  });
  testWidgets(
      'editing a limited draft creates a fresh token only on later manual send',
      (tester) async {
    final tokens = <String>[];
    final bodies = <String>[];
    await open(
        tester,
        chat(
            send: (id, body) async {
              tokens.add(id);
              bodies.add(body);
              if (tokens.length == 1) {
                throw const ServerActionLimit(BookingLimitedAction.message, 10);
              }
            },
            verify: (_, __) async => false,),);
    await tester.enterText(find.byType(TextField), 'SYNTHETIC FIRST DRAFT');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SYNTHETIC REVISED DRAFT');
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(tokens, hasLength(1));
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(tokens[0], isNot(tokens[1]));
    expect(bodies, ['SYNTHETIC FIRST DRAFT', 'SYNTHETIC REVISED DRAFT']);
  });
  testWidgets('booking closure still prevents sending when the pause expires',
      (tester) async {
    final statuses = StreamController<String?>.broadcast();
    var sends = 0;
    await open(
        tester,
        chat(
            send: (_, __) async {
              sends++;
              throw const ServerActionLimit(BookingLimitedAction.message, 10);
            },
            verify: (_, __) async => false,
            status: () => statuses.stream,),);
    statuses.add('Accepted');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SYNTHETIC DRAFT');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    statuses.add('Completed');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Conversation is read-only for this booking'),
        findsOneWidget,);
    expect(sends, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await statuses.close();
  });
  testWidgets(
      'limited photo keeps selected bytes, upload ID and unsaved remarks',
      (tester) async {
    final png =
        Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));
    var picks = 0, reads = 0;
    String? before;
    final tokens = <String>[];
    final payloads = <Uint8List>[];
    await open(
        tester,
        ConnectedBookingEvidenceScreen(
            bookingId: 'synthetic-booking',
            isProvider: true,
            status: 'In Progress',
            load: (_) async {
              reads++;
              return BookingEvidenceRecord(
                  bookingId: 'synthetic-booking',
                  beforePath: before,
                  remarks: '',);
            },
            download: (_) async => png,
            pickPhoto: () async {
              picks++;
              return png;
            },
            upload: (booking, kind, bytes, id, previous) async {
              tokens.add(id);
              payloads.add(bytes);
              if (tokens.length == 1) {
                throw const ServerActionLimit(
                    BookingLimitedAction.evidence, 10,);
              }
              before = '$booking/before_$id.jpg';
              return before!;
            },
            saveRemarks: (_, __) async {},
            complete: (_) async {},
            checkStatus: (_) async => 'In Progress',),);
    await tester.enterText(find.byType(TextField), 'SYNTHETIC UNSAVED REMARKS');
    await tester.ensureVisible(find.text('Add before photo'));
    await tester.tap(find.text('Add before photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photo uploads paused'), findsOneWidget);
    expect(find.text('Selected photo · waiting to upload'), findsOneWidget);
    expect(reads, 1);
    expect(picks, 1);
    final retryButton = find.ancestor(
        of: find.text('Retry before photo'),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),);
    expect(tester.widget<OutlinedButton>(retryButton).onPressed, isNull);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(tokens, hasLength(1));
    await tester.ensureVisible(find.text('Retry before photo'));
    await tester.tap(find.text('Retry before photo'));
    await tester.pumpAndSettle();
    expect(tokens, hasLength(2));
    expect(tokens[0], tokens[1]);
    expect(payloads[0], orderedEquals(payloads[1]));
    expect(picks, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'SYNTHETIC UNSAVED REMARKS',);
  });
  testWidgets('leaving a paused conversation cancels its pending UI timer',
      (tester) async {
    await open(
        tester,
        chat(
            send: (_, __) async =>
                throw const ServerActionLimit(BookingLimitedAction.message, 60),
            verify: (_, __) async => false,),);
    await tester.enterText(find.byType(TextField), 'SYNTHETIC DRAFT');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 61));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'paused chat remains usable with a narrow screen, keyboard and large text',
      (tester) async {
    await open(
        tester,
        chat(
            send: (_, __) async =>
                throw const ServerActionLimit(BookingLimitedAction.message, 60),
            verify: (_, __) async => false,),
        dark: true,
        width: 320,
        height: 540,
        scale: 1.5,);
    await tester.enterText(find.byType(TextField), 'SYNTHETIC DRAFT');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 230);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send message'), findsOneWidget);
  });
}
