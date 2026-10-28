import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/notifications_screen.dart';
import 'package:rental_app_demo/screens/about_screen.dart';
import 'package:rental_app_demo/services/backend/notification_binding.dart';
import 'package:rental_app_demo/services/backend/notification_snapshot.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'support/notification_fixture.dart';

NotificationBinding make(NotificationLoader load, {NotificationMarker? mark}) =>
    NotificationBinding(
        load: load,
        mark: mark ?? ({ids, throughAt}) async {},
        userId: notificationActor,
        currentUserId: () => notificationActor,
        sessions: const Stream.empty(),
        changes: () => const Stream.empty());
void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
  });
  for (final dark in [false, true]) {
    testWidgets('real notification read, filters and booking link, dark=$dark',
        (tester) async {
      var read = false;
      String? opened;
      final filters = <NotificationFilter>[];
      final b = make((filter, {before, asOf}) async {
        filters.add(filter);
        if (read && filter == NotificationFilter.unread) {
          return NotificationSnapshot.parse(
              {...notificationJson(filter: filter, read: true), 'items': []},
              notificationActor,
              filter);
        }
        return notificationReport(filter: filter, read: read);
      }, mark: ({ids, throughAt}) async {
        expect(ids, [notificationId]);
        read = true;
      });
      b.setActive(true);
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: NotificationsScreen(
              role: 'Provider',
              binding: b,
              onOpenBooking: (id) async => opened = id)));
      await tester.pumpAndSettle();
      expect(find.text('New job request'), findsOneWidget);
      expect(find.text('Earnings paid out'), findsNothing);
      expect(find.text('Payment processed'), findsNothing);
      await tester.tap(find.text('New job request'));
      await tester.pumpAndSettle();
      expect(opened, notificationBooking);
      expect(b.snapshot!.unread, 0);
      await tester.tap(find.text('Unread'));
      await tester.pumpAndSettle();
      expect(filters.last, NotificationFilter.unread);
      expect(find.text('No unread notifications.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      b.dispose();
    });
    testWidgets(
        'notification filters and help fit narrow 200% text, dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final b = make(
          (filter, {before, asOf}) async => notificationReport(filter: filter));
      b.setActive(true);
      Widget wrap(Widget child) => MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (_, child) => MediaQuery(
              data: const MediaQueryData(
                  size: Size(320, 568), textScaler: TextScaler.linear(2)),
              child: child!),
          home: child);
      await tester.pumpWidget(wrap(NotificationsScreen(binding: b)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(wrap(const AboutScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      b.dispose();
    });
  }
  testWidgets('mark all read waits for server and uses snapshot bound',
      (tester) async {
    var read = false;
    final ack = Completer<void>();
    String? through;
    final b = make(
        (filter, {before, asOf}) async =>
            notificationReport(filter: filter, read: read),
        mark: ({ids, throughAt}) async {
      expect(ids, isNull);
      through = throughAt;
      await ack.future;
      read = true;
    });
    b.setActive(true);
    await tester.pumpWidget(MaterialApp(home: NotificationsScreen(binding: b)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pump();
    expect(b.snapshot!.unread, 1);
    expect(through, b.snapshot!.asOf);
    expect(find.text('Current notifications marked as read'), findsNothing);
    ack.complete();
    await tester.pumpAndSettle();
    expect(b.snapshot!.unread, 0);
    expect(find.text('Current notifications marked as read'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    b.dispose();
  });
  testWidgets('notification error is not fake empty success and pull retries',
      (tester) async {
    var fail = true;
    final b = make((filter, {before, asOf}) async {
      if (fail) throw StateError('PRIVATE NETWORK DETAIL');
      return NotificationSnapshot.parse({
        ...notificationJson(),
        'items': [],
        'total_count': 0,
        'unread_count': 0,
        'action_count': 0
      }, notificationActor, filter);
    });
    b.setActive(true);
    await tester.pumpWidget(MaterialApp(home: NotificationsScreen(binding: b)));
    await tester.pumpAndSettle();
    expect(find.text('Could not load notifications'), findsOneWidget);
    expect(find.text('No notifications'), findsNothing);
    expect(find.textContaining('PRIVATE NETWORK'), findsNothing);
    fail = false;
    await tester.drag(find.byType(ListView), const Offset(0, 420));
    await tester.pumpAndSettle();
    expect(find.text('No notifications'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    b.dispose();
  });
  testWidgets('help articles open and no unpublished contact promises remain',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const AboutScreen(environmentLabel: 'staging')));
    expect(find.text('Staging environment'), findsNothing);
    expect(find.textContaining('Sprint'), findsNothing);
    await tester.ensureVisible(find.text('Help center'));
    await tester.tap(find.text('Help center'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
        find.textContaining(
            'Platform fees, payments and payouts are not connected'),
        findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Contact support'), findsNothing);
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not been published as a final privacy notice'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'configured support copies only actual address without pretending to send',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
        home: const AboutScreen(supportEmail: 'support@example.invalid')));
    await tester.ensureVisible(find.text('Contact support'));
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy email'));
    await tester.pumpAndSettle();
    expect(copied, 'support@example.invalid');
    expect(find.textContaining('Send your message from your email app'),
        findsOneWidget);
  });
}
