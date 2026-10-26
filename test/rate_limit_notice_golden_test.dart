import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_evidence_screen.dart';
import 'package:rental_app_demo/services/backend/booking_rate_limit.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      final parent = sdk.parent;
      if (parent.path == sdk.path) throw StateError('Flutter fonts not found.');
      sdk = parent;
    }
    Future<ByteData> font(String name) async => ByteData.sublistView(
          await File('${sdk.path}/bin/cache/artifacts/material_fonts/$name')
              .readAsBytes(),
        );
    await (FontLoader('Roboto')..addFont(font('roboto-regular.ttf'))).load();
    await (FontLoader('MaterialIcons')
          ..addFont(font('materialicons-regular.otf')))
        .load();
  });
  Future<void> open(
    WidgetTester tester,
    Widget child, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('chat rate pause ${dark ? 'dark' : 'light'} preview',
        (tester) async {
      await open(
        tester,
        ConnectedBookingMessagesScreen(
          bookingId: 'synthetic-preview',
          currentUserId: 'owner',
          isProvider: false,
          bookingStatus: () => Stream.value('Accepted'),
          messages: () => Stream.value([
            BookingMessage(
              id: 'synthetic-message',
              bookingId: 'synthetic-preview',
              senderUserId: 'provider',
              body: 'Could you confirm the access instructions?',
              createdAt: DateTime.utc(2026, 10, 23, 2),
            ),
          ]),
          send: (_, __) async => throw const ServerActionLimit(
            BookingLimitedAction.message,
            10,
          ),
          wasSent: (_, __) async => false,
        ),
        dark: dark,
      );
      await tester.enterText(
        find.byType(TextField),
        'Please use the side gate. I will send the access details before the appointment.',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ConnectedBookingMessagesScreen),
        matchesGoldenFile(
          'goldens/chat_rate_pause_${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }
  testWidgets('photo rate pause preview retains the selected image',
      (tester) async {
    final png = Uint8List.fromList(
      img.encodePng(
        img.fill(
          img.Image(width: 32, height: 24),
          color: img.ColorRgb8(210, 222, 236),
        ),
      ),
    );
    await open(
      tester,
      ConnectedBookingEvidenceScreen(
        bookingId: 'synthetic-preview',
        isProvider: true,
        status: 'In Progress',
        load: (_) async => null,
        download: (_) async => png,
        pickPhoto: () async => png,
        upload: (_, __, ___, ____, _____) async =>
            throw const ServerActionLimit(
          BookingLimitedAction.evidence,
          60,
        ),
        saveRemarks: (_, __) async {},
        complete: (_) async {},
        checkStatus: (_) async => 'In Progress',
      ),
    );
    await tester.tap(find.text('Add before photo'));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ConnectedBookingEvidenceScreen),
      matchesGoldenFile('goldens/photo_rate_pause.png'),
    );
  });
}
