import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdkDirectory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdkDirectory.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      final parent = sdkDirectory.parent;
      if (parent.path == sdkDirectory.path) {
        throw StateError('Could not locate Flutter SDK fonts.');
      }
      sdkDirectory = parent;
    }
    Future<ByteData> localFont(String name) async => ByteData.sublistView(
          await File(
                  '${sdkDirectory.path}/bin/cache/artifacts/material_fonts/$name')
              .readAsBytes(),
        );
    await (FontLoader('Roboto')..addFont(localFont('roboto-regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(localFont('materialicons-regular.otf')))
        .load();
  });

  testWidgets('connected booking chat visual preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: ConnectedBookingMessagesScreen(
        bookingId: 'booking-preview',
        currentUserId: 'owner',
        isProvider: false,
        bookingStatus: () => Stream.value('Accepted'),
        messages: () => Stream.value([
          BookingMessage(
            id: '1',
            bookingId: 'booking-preview',
            senderUserId: 'owner',
            body: 'Please focus on the kitchen and bathrooms.',
            createdAt: DateTime.utc(2026, 10, 22, 2, 5),
          ),
          BookingMessage(
            id: '2',
            bookingId: 'booking-preview',
            senderUserId: 'provider',
            body: 'Understood. I will bring the required supplies.',
            createdAt: DateTime.utc(2026, 10, 22, 2, 8),
          ),
        ]),
        send: (_, __) async {},
        wasSent: (_, __) async => false,
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ConnectedBookingMessagesScreen),
      matchesGoldenFile('goldens/connected_booking_messages.png'),
    );
  });
}
