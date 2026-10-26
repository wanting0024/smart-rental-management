import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/services/backend/backend_config.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            '${directory.path}/bin/cache/artifacts/material_fonts/$name',
          ).readAsBytes(),
        );
    await (FontLoader('Roboto')..addFont(font('roboto-regular.ttf'))).load();
    await (FontLoader('MaterialIcons')
          ..addFont(font('materialicons-regular.otf')))
        .load();
  });

  testWidgets(
      'staging login phone preview with injected backend, no live connection',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clientResult = await tester.runAsync(() async {
      return SupabaseClient(
        'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
    });
    final client = clientResult!;
    addTearDown(() => tester.runAsync(client.dispose));
    await tester.pumpWidget(
      RentalAppDemo(
        backend: SupabaseBackendProvider(
          client,
          config: const BackendConfig(
            url: 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
            publishableKey: 'sb_publishable_test',
            environmentName: 'staging',
            projectRef: 'aaaaaaaaaaaaaaaaaaaa',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('TEST ENVIRONMENT'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('welcome-log-in')));
    await tester.tap(find.byKey(const Key('welcome-log-in')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/staging_environment_login.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
