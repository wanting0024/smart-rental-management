import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/time_slot_picker.dart';

import 'support/time_slot_steps.dart';

Widget harness({
  int first = 0,
  int last = 1439,
  int initial = 540,
  double scale = 1,
  bool dark = false,
  ValueChanged<int?>? selected,
}) =>
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
          builder: (context) => Scaffold(
                  body: Center(
                      child: FilledButton(
                onPressed: () async {
                  final value = await showMinuteTimeSlotPicker(
                    context: context,
                    title: 'Requested start time',
                    initialMinute: initial,
                    firstMinute: first,
                    lastMinute: last,
                  );
                  selected?.call(value);
                },
                child: const Text('Choose time'),
              )))),
    );

void main() {
  test('slots keep exact saved values and both range boundaries', () {
    final slots = timeSlotCandidates(
        firstMinute: 481, lastMinute: 1079, initialMinute: 557);
    expect(slots, containsAll([481, 510, 540, 557, 1079]));
    expect(slots.toSet().length, slots.length);
    expect(slots.every((minute) => minute >= 481 && minute <= 1079), isTrue);
    expect(timeSlotCandidates(firstMinute: 900, lastMinute: 800), isEmpty);
  });

  test('database time parser rejects invalid hours and keeps exact minutes',
      () {
    expect(parseTimeSlot('09:17:00'), 557);
    expect(parseTimeSlot('09:17:00.000'), 557);
    expect(parseTimeSlot('24:00'), isNull);
    expect(parseTimeSlot('10:60'), isNull);
    expect(parseTimeSlot(null), isNull);
  });

  testWidgets('one tap selects a requested time and closes the sheet',
      (tester) async {
    int? selected;
    await tester.pumpWidget(
        harness(first: 480, last: 1080, selected: (value) => selected = value));
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    await chooseTimeSlot(tester, 630);
    expect(selected, 630);
    expect(find.byType(TimeSlotPicker), findsNothing);
  });

  testWidgets('exact minutes remain selectable using time buttons',
      (tester) async {
    int? selected;
    await tester.pumpWidget(harness(selected: (value) => selected = value));
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    await chooseTimeSlot(tester, 557);
    expect(selected, 557);
  });

  testWidgets('selection never rounds an existing off-grid value',
      (tester) async {
    int? selected;
    await tester.pumpWidget(
        harness(initial: 557, selected: (value) => selected = value));
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    await chooseTimeSlot(tester, 557);
    expect(selected, 557);
  });

  testWidgets('range boundaries hide invalid earlier and later time choices',
      (tester) async {
    await tester.pumpWidget(harness(first: 600, last: 720, initial: 660));
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('time-slot-570')), findsNothing);
    expect(find.byKey(const ValueKey('time-slot-600')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('time-part-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('time-slot-720')), findsOneWidget);
    expect(find.byKey(const ValueKey('time-slot-750')), findsNothing);
  });

  testWidgets('empty range can be dismissed without changing a field',
      (tester) async {
    int? selected = -1;
    await tester.pumpWidget(
        harness(first: 900, last: 800, selected: (value) => selected = value));
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No times fit'), findsOneWidget);
    await tester.tap(find.byTooltip('Close time selection'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('local availability retains its supported 24:00 end boundary',
      (tester) async {
    int? selected;
    await tester.pumpWidget(harness(
        first: 1320,
        last: 1440,
        initial: 1440,
        selected: (value) => selected = value));
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    await chooseTimeSlot(tester, 1440);
    expect(selected, 1440);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'time buttons fit 320px / 200% text in ${dark ? 'dark' : 'light'}',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness(dark: dark, scale: 2));
      await tester.tap(find.text('Choose time'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await chooseTimeSlot(tester, 1110);
      expect(tester.takeException(), isNull);
    });
  }
}
