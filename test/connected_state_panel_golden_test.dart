import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/connected_state_panel.dart';

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

  for (final state in [ConnectedViewState.empty, ConnectedViewState.error]) {
    testWidgets('connected $state preview', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('My work')),
          body: ConnectedStatePanel(
            state: state,
            title: state == ConnectedViewState.empty
                ? 'No jobs assigned yet'
                : 'Could not load your information',
            message: state == ConnectedViewState.empty
                ? 'New requests will appear here when an Owner selects you.'
                : 'Check your connection and try again. Your saved information has not been removed.',
            actionLabel: state == ConnectedViewState.empty
                ? 'Manage availability'
                : 'Retry',
            onAction: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/connected_${state.name}_state.png'),
      );
    });
  }
}
