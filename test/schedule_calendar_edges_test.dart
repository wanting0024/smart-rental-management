import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/widgets/calendar_week_view.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

DemoBooking booking(String id, DateTime start, DateTime end) => DemoBooking(
    id: id,
    property: id,
    serviceType: 'Cleaning',
    providerName: null,
    scheduledStart: start,
    scheduledEnd: end,
    status: BookingStatus.accepted,
    specialInstructions: null);
void main() {
  test('range feeds recheck updates entering a previously empty week',
      () async {
    final changes = StreamController<PageChange>.broadcast();
    var reads = 0;
    final feed = CursorFeed<String>(
        active: true,
        recheckUnloadedUpdates: true,
        loadPage: (_) async => const CursorPage(items: []),
        idOf: (row) => row,
        compare: (_, __) => 0,
        changes: changes.stream,
        readOne: (id) async {
          reads++;
          return id == 'moved-in' ? id : null;
        });
    await feed.refresh();
    await Future<void>.delayed(Duration.zero);
    changes.add(const PageChange(PageChangeKind.update, 'moved-in'));
    await Future<void>.delayed(Duration.zero);
    expect(feed.items, ['moved-in']);
    expect(reads, 1);
    changes.add(const PageChange(PageChangeKind.update, 'outside'));
    await Future<void>.delayed(Duration.zero);
    expect(feed.items, ['moved-in']);
    expect(reads, 2);
    feed.dispose();
    await changes.close();
  });
  testWidgets(
      'cross-midnight and outside old grid hours remain visible and tappable',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final day = DateTime.utc(2030, 1, 7);
    String? tapped;
    final jobs = [
      booking('overnight', day.subtract(const Duration(hours: 1)),
          day.add(const Duration(hours: 1))),
      booking('short', day.add(const Duration(minutes: 30)),
          day.add(const Duration(minutes: 40))),
      booking('late', day.add(const Duration(hours: 23)),
          day.add(const Duration(days: 1)))
    ];
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: CalendarWeekView(
                    weekStart: day,
                    selectedDay: day,
                    bookings: jobs,
                    onTapBooking: (b) => tapped = b.id)))));
    await tester.pumpAndSettle();
    expect(find.text('12 AM'), findsOneWidget);
    expect(find.text('11 PM'), findsOneWidget);
    expect(find.text('overnight'), findsOneWidget);
    expect(find.text('short'), findsOneWidget);
    await tester.ensureVisible(find.text('short'));
    await tester.tap(find.text('short'));
    expect(tapped, 'short');
    expect(tester.takeException(), isNull);
  });
}
