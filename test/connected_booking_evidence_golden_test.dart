import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rental_app_demo/screens/connected_booking_evidence_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_evidence_repository.dart';
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
            '${sdkDirectory.path}/bin/cache/artifacts/material_fonts/$name',
          ).readAsBytes(),
        );
    await (FontLoader('Roboto')..addFont(localFont('roboto-regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(localFont('materialicons-regular.otf')))
        .load();
  });

  testWidgets('connected completion form visual preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: ConnectedBookingEvidenceScreen(
          bookingId: 'booking-preview',
          isProvider: true,
          status: 'In Progress',
          load: (_) async => const BookingEvidenceRecord(
            bookingId: 'booking-preview',
            remarks: '',
          ),
          download: (_) async => Uint8List(0),
          upload: (_, __, ___, ____, _____) async => '',
          saveRemarks: (_, __) async {},
          complete: (_) async {},
          checkStatus: (_) async => 'In Progress',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ConnectedBookingEvidenceScreen),
      matchesGoldenFile('goldens/connected_booking_evidence.png'),
    );
  });

  testWidgets('retained photo retry phone preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Small, explicitly synthetic fixture: exercises real preparation/decoding
    // without pretending this is a participant's uploaded cleaning photograph.
    final fixture = img.Image(width: 240, height: 160, numChannels: 3);
    img.fill(fixture, color: img.ColorRgb8(235, 240, 245));
    img.fillRect(
      fixture,
      x1: 0,
      y1: 105,
      x2: 239,
      y2: 159,
      color: img.ColorRgb8(190, 177, 158),
    );
    img.fillRect(
      fixture,
      x1: 20,
      y1: 65,
      x2: 220,
      y2: 108,
      color: img.ColorRgb8(150, 170, 182),
    );
    img.fillRect(
      fixture,
      x1: 18,
      y1: 60,
      x2: 222,
      y2: 65,
      color: img.ColorRgb8(70, 85, 102),
    );
    img.drawString(
      fixture,
      'TEST IMAGE',
      font: img.arial14,
      x: 76,
      y: 80,
      color: img.ColorRgb8(30, 45, 65),
    );
    final png = img.encodePng(fixture);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: ConnectedBookingEvidenceScreen(
          bookingId: 'retry-preview',
          isProvider: true,
          status: 'In Progress',
          load: (_) async => const BookingEvidenceRecord(
            bookingId: 'retry-preview',
            remarks: '',
          ),
          download: (_) async => png,
          pickPhoto: () async => png,
          upload: (_, __, ___, ____, _____) async =>
              throw StateError('simulated offline'),
          saveRemarks: (_, __) async {},
          complete: (_) async {},
          checkStatus: (_) async => 'In Progress',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add before photo'));
    await tester.pumpAndSettle();
    expect(find.text('Retry before photo'), findsOneWidget);
    final photo = find.byType(Image);
    await tester.runAsync(
      () => precacheImage(
        tester.widget<Image>(photo).image,
        tester.element(photo),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ConnectedBookingEvidenceScreen),
      matchesGoldenFile('goldens/evidence_photo_retry.png'),
    );
  });
}
