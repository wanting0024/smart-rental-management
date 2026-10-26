import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/schedule_screen.dart';
import 'package:rental_app_demo/screens/provider_schedule_screen.dart';
import 'package:rental_app_demo/services/backend/schedule_binding.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/provider_workspace_navigation.dart';

// Rendered-widget QA with explicitly synthetic data, NOT hosted browser evidence.
void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      if (sdk.parent.path == sdk.path)
        throw StateError('Flutter fonts missing.');
      sdk = sdk.parent;
    }
    for (final font in [
      ('Roboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf')
    ]) {
      final bytes = await File(
              '${sdk.path}/bin/cache/artifacts/material_fonts/${font.$2}')
          .readAsBytes();
      await (FontLoader(font.$1)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });
  for (final provider in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
          'original ${provider ? 'provider' : 'owner'} Schedule ${dark ? 'dark' : 'light'} render',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = ScheduleBinding.malaysiaNow();
        final morning = DateTime.utc(now.year, now.month, now.day, 10);
        final start = morning.subtract(const Duration(hours: 8));
        final binding = ScheduleBinding(
            weekStart: now,
            openFeed: (a, b) => CursorFeed<Map<String, dynamic>>(
                active: false,
                loadPage: (_) async => CursorPage(items: [
                      {
                        'booking_id': 'synthetic-card',
                        'current_status': 'Accepted',
                        'unit_name': 'Unit A-12',
                        'building_name': 'Test Building',
                        'service_name': 'Standard cleaning',
                        'requested_start_at': start.toIso8601String(),
                        'requested_end_at': start
                            .add(const Duration(hours: 2))
                            .toIso8601String(),
                      }
                    ]),
                idOf: (row) => row['booking_id'] as String,
                compare: (_, __) => 0));
        binding.setActive(true);
        await binding.refresh();
        final boundary = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                home: provider
                    ? ProviderScheduleScreen(
                        bottomNavigationBar: ProviderBottomNav(
                            activeId: 'schedule', onChange: (id) async {}),
                        providerName: '',
                        bookings: const [],
                        binding: binding,
                        onBooking: (_) async {},
                        onManageAvailability: () async {})
                    : ScheduleScreen(
                        bookings: const [],
                        binding: binding,
                        onBooking: (_) async {}))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('output/schedule-ui').create(recursive: true);
          await File(
                  'output/schedule-ui/${provider ? 'provider' : 'owner'}-${dark ? 'dark' : 'light'}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
        binding.dispose();
      });
    }
  }
}
