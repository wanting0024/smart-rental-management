import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/local_preview_data.dart';
import 'package:rental_app_demo/screens/provider_schedule_screen.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1200, 900),
  ]) {
    testWidgets('today job card fits schedule at ${size.width}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: ProviderScheduleScreen(
          providerName: 'Provider A',
          bookings: LocalPreviewData.bookings(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining("Today's jobs"), findsOneWidget);
      expect(find.text('Unit D-03, Menara Suria'), findsWidgets);
      expect(find.text('Deep cleaning'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'mobile date strip changes the focused day and keeps it on week navigation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ProviderScheduleScreen(
        providerName: 'Provider A',
        bookings: LocalPreviewData.bookings(),
      ),
    ));
    await tester.pumpAndSettle();

    final selected = find.byKey(const ValueKey('schedule-selected-day-label'));
    expect(selected, findsOneWidget);
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    final mondayLabel = tester.widget<Text>(selected).data!;
    expect(mondayLabel, startsWith('Mon '));

    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    final nextMondayLabel = tester.widget<Text>(selected).data!;
    expect(nextMondayLabel, startsWith('Mon '));
    expect(nextMondayLabel, isNot(mondayLabel));
    expect(tester.takeException(), isNull);
  });
}
