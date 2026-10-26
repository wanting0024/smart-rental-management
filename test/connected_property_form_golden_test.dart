import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/connected_property_form_screen.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await loader.load();
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

  testWidgets('connected Owner property form visual preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: ConnectedPropertyFormScreen(onSave: (_) async {}),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ConnectedPropertyFormScreen),
      matchesGoldenFile('goldens/connected_property_form.png'),
    );
  });
}
