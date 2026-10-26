import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/earnings_history_screen.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/earnings_binding.dart';
import 'package:rental_app_demo/services/backend/earnings_snapshot.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'support/earnings_fixture.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      if (sdk.parent.path == sdk.path)
        throw StateError('Flutter fonts missing');
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
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'original Earnings connected ${dark ? 'dark' : 'light'} scale $scale no overflow',
          (tester) async {
        tester.view.physicalSize = Size(scale == 2 ? 320 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = StreamController<String?>.broadcast(),
            live = StreamController<PageChange>.broadcast();
        final binding = EarningsBinding(
            load: (p, {before, asOf}) async => earningsReport(period: p),
            userId: earningsActor,
            currentUserId: () => earningsActor,
            sessionChanges: session.stream,
            changes: () => live.stream);
        binding.setActive(true);
        await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: RepaintBoundary(
                key: const ValueKey('capture'),
                child: EarningsHistoryScreen(
                    providerName: '', bookings: const [], binding: binding))));
        await tester.pumpAndSettle();
        expect(find.text('Completed job value'), findsOneWidget);
        expect(find.text('RM 2400.24'), findsOneWidget);
        expect(find.byTooltip('Export statement'), findsNothing);
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('capture')));
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('output/earnings-ui').create(recursive: true);
            await File('output/earnings-ui/${dark ? 'dark' : 'light'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('earnings-trend-toggle')), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester
            .ensureVisible(find.byKey(const ValueKey('earnings-trend-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('earnings-trend-toggle')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Earnings trend'), 150,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('Earnings trend'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
            find.byKey(
                const ValueKey('earning-bbbbbbbb-bbbb-4bbb-8bbb-000000000000')),
            250,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.byKey(
            const ValueKey('earning-bbbbbbbb-bbbb-4bbb-8bbb-000000000000')));
        await tester.pumpAndSettle();
        expect(find.text('Not available'), findsOneWidget);
        expect(find.text('Net payout'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        binding.dispose();
        await session.close();
        await live.close();
      });
    }
  }
  testWidgets(
      'empty report keeps all three ranges and never falls back to fixtures',
      (tester) async {
    final session = StreamController<String?>.broadcast(),
        live = StreamController<PageChange>.broadcast();
    final binding = EarningsBinding(
        load: (p, {before, asOf}) async =>
            earningsReport(period: p, jobs: 0, count: 0, more: false),
        userId: earningsActor,
        currentUserId: () => earningsActor,
        sessionChanges: session.stream,
        changes: () => live.stream);
    binding.setActive(true);
    await tester.pumpWidget(MaterialApp(
        home: EarningsHistoryScreen(
            providerName: 'Provider C', bookings: const [], binding: binding)));
    await tester.pumpAndSettle();
    for (final p in EarningsPeriod.values) {
      await tester.tap(find.text(p.label));
      await tester.pumpAndSettle();
      expect(binding.period, p);
    }
    expect(find.text('RM 0.00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    binding.dispose();
    await session.close();
    await live.close();
  });
}
