import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/connected_property_form_screen.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'support/owner_uat_steps.dart';

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
        throw StateError('Flutter fonts not found.');
      }
      directory = parent;
    }
    Future<ByteData> font(String name) async => ByteData.sublistView(
          await File(
                  '${directory.path}/bin/cache/artifacts/material_fonts/$name')
              .readAsBytes(),
        );
    await (FontLoader('Roboto')..addFont(font('roboto-regular.ttf'))).load();
    await (FontLoader('MaterialIcons')
          ..addFont(font('materialicons-regular.otf')))
        .load();
  });

  testWidgets('uncertain property save phone preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: ConnectedPropertyFormScreen(
        onSave: (_) async => throw StateError('response lost'),
      ),
    ));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Unit A-12');
    await tester.enterText(fields.at(1), 'Menara Suria');
    await tester.enterText(fields.at(2), 'Jalan Ampang, Kuala Lumpur');
    await chooseBedrooms(tester, 3);
    await tester.ensureVisible(fields.last);
    await tester.enterText(fields.last, '980');
    await selectPropertyWindow(tester);
    await tester.ensureVisible(find.text('Add property'));
    await tester.tap(find.text('Add property'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Your entries are kept'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ConnectedPropertyFormScreen),
      matchesGoldenFile('goldens/connected_uncertain_property_save.png'),
    );
  });
}
