import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/connected_booking_review_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_review_repository.dart';
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

  testWidgets('connected Owner review visual preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: ConnectedBookingReviewScreen(
        bookingId: 'booking-preview',
        isOwner: true,
        load: (_) async => null,
        save: (_, __, ___) async => const BookingReviewRecord(
          bookingId: 'booking-preview',
          rating: 5,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ConnectedBookingReviewScreen),
      matchesGoldenFile('goldens/connected_owner_rating.png'),
    );
  });

  testWidgets('saved review keeps an acknowledged result on screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: ConnectedBookingReviewScreen(
        bookingId: 'booking-preview',
        isOwner: true,
        load: (_) async => null,
        save: (id, rating, comment) async => BookingReviewRecord(
          bookingId: id,
          rating: rating,
          comment: comment,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_outline_rounded).last);
    await tester.pump();
    await tester.enterText(find.byType(TextField),
        'Followed my instructions and shared clear completion photos.');
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(find.text('Your review was saved.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Followed my instructions and shared clear completion photos.');
    await expectLater(find.byType(ConnectedBookingReviewScreen),
        matchesGoldenFile('goldens/connected_review_saved_feedback.png'));
  });
}
