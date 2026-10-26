import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/screens/booking_detail_screen.dart';
import 'package:rental_app_demo/screens/provider_schedule_screen.dart';
import 'package:rental_app_demo/screens/schedule_screen.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/schedule_binding.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/booking_card.dart';
import 'package:rental_app_demo/widgets/calendar_week_view.dart';

final _monday = DateTime.utc(2026, 10, 19);
const _next = PageCursor('2026-10-19T00:00:00Z', 'next');

Map<String, dynamic> _row(String id, String status,
        {String start = '2026-10-19T02:00:00Z',
        String end = '2026-10-19T05:00:00Z'}) =>
    {
      'booking_id': id,
      'current_status': status,
      'unit_name': 'Server $id',
      'building_name': 'Building',
      'service_name': 'Server cleaning',
      'requested_start_at': start,
      'requested_end_at': end,
    };

ScheduleBinding _binding({
  required Future<CursorPage<Map<String, dynamic>>> Function(PageCursor?) load,
  Stream<PageChange> Function()? changes,
  void Function(DateTime, DateTime)? onOpen,
}) =>
    ScheduleBinding(
      weekStart: _monday,
      openFeed: (start, end) {
        onOpen?.call(start, end);
        return CursorFeed<Map<String, dynamic>>(
          active: false,
          loadPage: load,
          idOf: (row) => row['booking_id'] as String,
          compare: (a, b) =>
              (a['booking_id'] as String).compareTo(b['booking_id'] as String),
          watchChanges: changes,
        );
      },
    );

Future<void> _pump(WidgetTester tester, ScheduleBinding binding,
    {bool provider = true,
    double width = 390,
    double height = 900,
    double textScale = 1,
    Future<void> Function(DemoBooking)? onBooking,
    Future<void> Function()? onManageAvailability}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Intentionally omit AppProviders: connected actions cannot use demo stores.
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: provider
        ? ProviderScheduleScreen(
            providerName: 'Must never match a server display name',
            bookings: const [],
            binding: binding,
            onBooking: onBooking,
            onManageAvailability: onManageAvailability,
          )
        : ScheduleScreen(
            bookings: const [],
            binding: binding,
            onBooking: onBooking,
          ),
  ));
  await tester.pump();
}

Future<void> _selectMonday(WidgetTester tester) async {
  await tester.tap(find.text('Mon'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
  });

  for (final provider in [false, true]) {
    for (final state in ['loading', 'partial', 'ready']) {
      testWidgets(
          '${provider ? 'provider' : 'owner'} short phone 200% text $state',
          (tester) async {
        final pending = Completer<CursorPage<Map<String, dynamic>>>();
        final binding = _binding(load: (_) async {
          if (state == 'loading') return pending.future;
          return CursorPage(
            items: [_row('one', 'Accepted')],
            next: state == 'partial' ? _next : null,
          );
        });
        addTearDown(binding.dispose);
        binding.setActive(true);
        await _pump(tester, binding,
            provider: provider, width: 320, height: 568, textScale: 2);
        if (state == 'loading') {
          await tester.pump(const Duration(milliseconds: 100));
        } else {
          await tester.pumpAndSettle();
        }
        expect(find.byTooltip('Next week').hitTestable(), findsOneWidget);
        expect(find.byType(CalendarWeekView),
            state == 'ready' ? findsOneWidget : findsNothing);
        if (state == 'partial') {
          expect(find.text('Load more').hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        if (state == 'loading') {
          pending.complete(const CursorPage(items: []));
          await tester.pump();
        }
      });
    }
  }

  for (final role in [UserRole.owner, UserRole.provider]) {
    testWidgets('main ${role.name} preview navigation opens original Schedule',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'coachmark_seen_owner_home_v1': true,
        'coachmark_seen_provider_inbox_v1': true,
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RentalAppDemo(localPreviewRole: role));
      await tester.pumpAndSettle();
      if (role == UserRole.owner) {
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Schedule'), 180,
            scrollable: find.byType(Scrollable).first);
      }
      await tester.tap(find.text('Schedule').last);
      await tester.pumpAndSettle();
      expect(
          role == UserRole.owner
              ? find.byType(ScheduleScreen)
              : find.byType(ProviderScheduleScreen),
          findsOneWidget);
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      final calendar =
          tester.widget<CalendarWeekView>(find.byType(CalendarWeekView));
      expect(calendar.selectedDay!.weekday, DateTime.monday);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('provider uses server scope, blocking statuses and callbacks',
      (tester) async {
    final binding = _binding(
        load: (_) async => CursorPage(items: [
              for (final status in [
                'Pending',
                'Accepted',
                'In Progress',
                'Completed',
                'Cancelled',
                'Declined',
              ])
                _row(status, status),
            ]));
    addTearDown(binding.dispose);
    binding.setActive(true);
    String? opened;
    var availability = 0;
    await _pump(tester, binding,
        width: 320,
        onBooking: (booking) async => opened = booking.id,
        onManageAvailability: () async => availability++);
    await tester.pumpAndSettle();
    await _selectMonday(tester);
    final calendar =
        tester.widget<CalendarWeekView>(find.byType(CalendarWeekView));
    expect(calendar.bookings.map((b) => b.id), ['Accepted', 'In Progress']);
    expect(find.text('Selected week'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('Upcoming'), findsNothing);
    await tester.tap(find.text('Server Accepted, Building').last);
    await tester.pumpAndSettle();
    expect(opened, 'Accepted');
    await tester.tap(find.byTooltip('Block out time'));
    await tester.pumpAndSettle();
    expect(availability, 1);
    expect(find.byType(BookingDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner keeps pending and completed, excludes cancelled/declined',
      (tester) async {
    final binding = _binding(
        load: (_) async => CursorPage(items: [
              for (final status in [
                'Pending',
                'Accepted',
                'In Progress',
                'Completed',
                'Cancelled',
                'Declined',
              ])
                _row(status, status),
            ]));
    addTearDown(binding.dispose);
    binding.setActive(true);
    String? opened;
    await _pump(tester, binding,
        provider: false, onBooking: (booking) async => opened = booking.id);
    await tester.pumpAndSettle();
    await _selectMonday(tester);
    final calendar =
        tester.widget<CalendarWeekView>(find.byType(CalendarWeekView));
    expect(calendar.bookings.map((b) => b.status).toSet(), {
      BookingStatus.pending,
      BookingStatus.accepted,
      BookingStatus.inProgress,
      BookingStatus.completed,
    });
    expect(find.text('Pending (not reserved)'), findsOneWidget);
    final cards = tester.widgetList<BookingCard>(find.byType(BookingCard));
    expect(cards.map((card) => card.booking.id), contains('Accepted'));
    calendar.onTapBooking(calendar.bookings.first);
    await tester.pumpAndSettle();
    expect(opened, calendar.bookings.first.id);
    expect(find.byType(BookingDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final provider in [false, true]) {
    testWidgets(
        '${provider ? 'provider' : 'owner'} hides partial week until all pages load',
        (tester) async {
      var pages = 0;
      final binding = _binding(load: (cursor) async {
        pages++;
        return cursor == null
            ? CursorPage(items: [_row('first', 'Accepted')], next: _next)
            : CursorPage(items: [_row('second', 'Accepted')]);
      });
      addTearDown(binding.dispose);
      binding.setActive(true);
      await _pump(tester, binding, provider: provider, width: 320);
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Selected week is incomplete'), findsOneWidget);
      expect(find.byType(CalendarWeekView), findsNothing);
      expect(find.textContaining('No jobs'), findsNothing);
      expect(find.textContaining('No bookings'), findsNothing);
      if (provider) expect(find.text('—'), findsNWidgets(3));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(pages, 2);
      expect(find.byType(CalendarWeekView), findsOneWidget);
      expect(binding.complete, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '${provider ? 'provider' : 'owner'} loading and failure retain week navigation',
        (tester) async {
      final pending = Completer<CursorPage<Map<String, dynamic>>>();
      var fail = true;
      final windows = <DateTime>[];
      var calls = 0;
      final binding = _binding(onOpen: (start, end) {
        windows.add(start);
        expect(end.difference(start), const Duration(days: 7));
      }, load: (_) async {
        calls++;
        if (calls == 1) return pending.future;
        if (fail) throw StateError('private failure');
        return const CursorPage(items: []);
      });
      addTearDown(binding.dispose);
      binding.setActive(true);
      await _pump(tester, binding, provider: provider, width: 320);
      expect(find.text('Loading selected week…'), findsOneWidget);
      expect(find.byType(CalendarWeekView), findsNothing);
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(binding.weekStart, _monday.add(const Duration(days: 7)));
      expect(windows.last, DateTime.utc(2026, 10, 25, 16));
      expect(
          find.textContaining('Could not load selected week'), findsOneWidget);
      expect(find.byType(CalendarWeekView), findsNothing);
      expect(find.textContaining('private failure'), findsNothing);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarWeekView), findsOneWidget);
      pending.complete(CursorPage(items: [_row('old-week', 'Accepted')]));
      await tester.pumpAndSettle();
      expect(binding.bookings, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '${provider ? 'provider' : 'owner'} selected day includes off-hour and cross-day work',
        (tester) async {
      final binding = _binding(
          load: (_) async => CursorPage(items: [
                _row('early', 'Accepted',
                    start: '2026-10-18T21:00:00Z', end: '2026-10-18T22:00:00Z'),
                _row('overnight', 'Accepted',
                    start: '2026-10-19T14:00:00Z', end: '2026-10-19T18:00:00Z'),
                _row('ends-at-midnight', 'Accepted',
                    start: '2026-10-18T14:00:00Z', end: '2026-10-18T16:00:00Z'),
              ]));
      addTearDown(binding.dispose);
      binding.setActive(true);
      await _pump(tester, binding, provider: provider);
      await tester.pumpAndSettle();
      await _selectMonday(tester);
      expect(find.text('Server early, Building'), findsWidgets);
      expect(find.text('Server overnight, Building'), findsWidgets);
      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();
      expect(find.text('Server overnight, Building'), findsWidgets);
      expect(find.text('Server early, Building'), findsNothing);
      expect(find.text('Server ends-at-midnight, Building'), findsNothing);
      await tester.tap(find.text('Mon'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      final calendar =
          tester.widget<CalendarWeekView>(find.byType(CalendarWeekView));
      expect(calendar.selectedDay!.weekday, DateTime.monday);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pagination failure retries without showing free slots',
      (tester) async {
    var failMore = true;
    final binding = _binding(load: (cursor) async {
      if (cursor == null)
        return CursorPage(items: [_row('one', 'Accepted')], next: _next);
      if (failMore) throw StateError('private pagination error');
      return const CursorPage(items: []);
    });
    addTearDown(binding.dispose);
    binding.setActive(true);
    await _pump(tester, binding);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selected week is incomplete'), findsOneWidget);
    expect(find.byType(CalendarWeekView), findsNothing);
    failMore = false;
    await tester.tap(find.text('Retry load more'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarWeekView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live failure hides stale calendar and uses retryLive',
      (tester) async {
    final streams = <StreamController<PageChange>>[];
    var loads = 0;
    final binding = _binding(load: (_) async {
      loads++;
      return CursorPage(items: [_row('one', 'Accepted')]);
    }, changes: () {
      final stream = StreamController<PageChange>();
      streams.add(stream);
      return stream.stream;
    });
    addTearDown(() async {
      binding.dispose();
      for (final stream in streams) {
        await stream.close();
      }
    });
    binding.setActive(true);
    await _pump(tester, binding);
    await tester.pumpAndSettle();
    streams.single.addError(StateError('private live failure'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Live updates interrupted'), findsOneWidget);
    expect(find.byType(CalendarWeekView), findsNothing);
    await tester.tap(find.text('Retry live updates'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.byType(CalendarWeekView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing callbacks never open preview routes or stores',
      (tester) async {
    final binding = _binding(
        load: (_) async => CursorPage(items: [_row('one', 'Accepted')]));
    addTearDown(binding.dispose);
    binding.setActive(true);
    await _pump(tester, binding);
    await tester.pumpAndSettle();
    final calendar =
        tester.widget<CalendarWeekView>(find.byType(CalendarWeekView));
    calendar.onTapBooking(calendar.bookings.single);
    await tester.pump();
    expect(find.byType(BookingDetailScreen), findsNothing);
    await tester.tap(find.byTooltip('Block out time'));
    await tester.pump();
    expect(find.byType(ProviderScheduleScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
