import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/screens/account_settings_screens.dart';
import 'package:rental_app_demo/screens/connected_pending_edit_screen.dart';
import 'package:rental_app_demo/screens/owner_records_view.dart';
import 'package:rental_app_demo/screens/owner_home_screen.dart';
import 'package:rental_app_demo/screens/about_screen.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/supabase_booking_repository.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/device_preferences.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/property_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/services/review_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/building_name_field.dart';
import 'package:rental_app_demo/widgets/compact_earnings_chart.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      if (sdk.parent.path == sdk.path)
        throw StateError('Flutter fonts unavailable');
      sdk = sdk.parent;
    }
    final data = await File(
            '${sdk.path}/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
        .readAsBytes();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(data))))
        .load();
  });
  Widget app(Widget child, {bool dark = false, double scale = 1}) =>
      MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: child);
  void phone(WidgetTester tester, {double width = 390}) {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('output/approved-ui').create(recursive: true);
      await File('output/approved-ui/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'building combobox opens without typing, filters and accepts a new name without overwriting an address',
      (tester) async {
    final name = TextEditingController(), address = TextEditingController();
    await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(
            child: BuildingNameField(
                controller: name,
                address: address,
                options: const [
          {'building_name': 'Menara Suria, Tower A', 'address': '1 Jalan Test'},
          {'building_name': 'Menara Suria, Tower B', 'address': '2 Jalan Test'},
        ])))));
    await tester.tap(find.byTooltip('Show saved buildings'));
    await tester.pumpAndSettle();
    expect(find.text('Menara Suria, Tower A'), findsOneWidget);
    expect(find.text('Menara Suria, Tower B'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'tower b');
    await tester.pumpAndSettle();
    expect(find.text('Menara Suria, Tower A'), findsNothing);
    await tester.tap(find.text('Menara Suria, Tower B'));
    expect(name.text, 'Menara Suria, Tower B');
    expect(address.text, '2 Jalan Test');
    address.text = 'User edited address';
    await tester.tap(find.byTooltip('Show saved buildings'));
    await tester.enterText(find.byType(TextFormField), 'tower a');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menara Suria, Tower A'));
    expect(address.text, 'User edited address');
    await tester.tap(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), 'New Vista Tower C');
    await tester.pumpAndSettle();
    expect(name.text, 'New Vista Tower C');
    expect(normalizedBuildingName(' Menara  SURIA '), 'menara suria');
    expect(normalizedBuildingName('Tower A'),
        isNot(normalizedBuildingName('Tower B')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    name.dispose();
    address.dispose();
  });

  test(
      'notification display preferences persist per account and never follow another role account',
      () async {
    final prefs = DevicePreferences();
    await prefs.bindAccount('owner');
    expect(await prefs.save(booking: true, enabled: false), isTrue);
    expect(await prefs.save(booking: false, enabled: false), isTrue);
    await prefs.bindAccount('provider');
    expect(prefs.bookingIndicators, isTrue);
    expect(prefs.messageIndicators, isTrue);
    await prefs.bindAccount('owner');
    expect(prefs.bookingIndicators, isFalse);
    expect(prefs.messageIndicators, isFalse);
    await prefs.bindAccount(null);
    expect(await prefs.save(booking: true, enabled: true), isFalse);
    prefs.dispose();
  });

  testWidgets(
      'History dropdown is always present, enabled only on History, resets and survives detail return',
      (tester) async {
    final groups = <String>[];
    await tester.pumpWidget(app(Scaffold(
        body: OwnerRecordsView(
            providers: false,
            openFeed: (
                {required providers,
                required query,
                required group,
                required oldest}) {
              groups.add(group);
              return CursorFeed<Map<String, dynamic>>(
                  active: false,
                  loadPage: (_) async => const CursorPage(items: []),
                  idOf: (r) => r['id'] as String,
                  compare: (_, __) => 0);
            }))));
    await tester.pumpAndSettle();
    DropdownButtonFormField<String> dropdown() =>
        tester.widget(find.byKey(const Key('owner-booking-group')));
    expect(dropdown().onChanged, isNull);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(dropdown().onChanged, isNotNull);
    await tester.tap(find.byKey(const Key('owner-booking-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled').last);
    await tester.pumpAndSettle();
    expect(groups.last, 'cancelled');
    final context = tester.element(find.byType(OwnerRecordsView));
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')))));
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(dropdown().initialValue, 'cancelled');
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    expect(groups.last, 'pending');
    expect(dropdown().onChanged, isNull);
    expect(dropdown().initialValue, 'history');
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(groups.last, 'history');
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'compact chart has genuine zero and selected colour only dark=$dark scale=$scale',
          (tester) async {
        phone(tester, width: scale == 2 ? 320 : 390);
        final key = GlobalKey();
        await tester.pumpWidget(app(
            RepaintBoundary(
                key: key,
                child: Scaffold(
                    appBar: AppBar(title: const Text('Earnings trend')),
                    body: ListView(
                        padding: const EdgeInsets.all(20),
                        children: const [
                          Text('Completed job value · before fees'),
                          SizedBox(height: 20),
                          CompactEarningsChart(points: [
                            EarningsChartPoint('1 Oct', '1–4 Oct 2026', 68, 1),
                            EarningsChartPoint('5 Oct', '5–11 Oct 2026', 68, 1),
                            EarningsChartPoint(
                                '12 Oct', '12–18 Oct 2026', 102, 2),
                            EarningsChartPoint(
                                '19 Oct', '19–25 Oct 2026', 204, 3),
                            EarningsChartPoint(
                                '26 Oct', '26–31 Oct 2026', 0, 0),
                          ]),
                        ]))),
            dark: dark,
            scale: scale));
        await tester.pumpAndSettle();
        Container fill(int i) =>
            tester.widget(find.byKey(ValueKey('earnings-bar-fill-$i')));
        expect(fill(4).constraints!.maxHeight, 0);
        final before = (fill(1).decoration as BoxDecoration).color;
        await tester
            .ensureVisible(find.byKey(const ValueKey('earnings-bar-1')));
        await tester.tap(find.byKey(const ValueKey('earnings-bar-1')));
        await tester.pumpAndSettle();
        expect((fill(1).decoration as BoxDecoration).color, isNot(before));
        expect(fill(4).constraints!.maxHeight, 0);
        expect(find.text('RM 68.00 · 1 completed job'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1)
          await capture(tester, key, 'earnings-${dark ? 'dark' : 'light'}');
      });
    }
  }

  testWidgets(
      'Pending editor retains duration, prevents duplicate saves and preserves draft on unknown result',
      (tester) async {
    phone(tester);
    var saves = 0;
    final pending = Completer<AcceptanceOutcome>();
    await tester.pumpWidget(app(ConnectedPendingEditScreen(
        row: const {
          'requested_start_at': '2027-10-28T02:00:00Z',
          'requested_end_at': '2027-10-28T04:00:00Z',
          'instructions': ''
        },
        canSave: () => true,
        save: (start, end, notes) {
          saves++;
          expect(end.difference(start), const Duration(hours: 2));
          expect(notes, 'Use gate B');
          return pending.future;
        })));
    await tester.enterText(find.byType(TextFormField), 'Use gate B');
    await tester.ensureVisible(find.text('Save request changes'));
    await tester.tap(find.text('Save request changes'));
    await tester.pump();
    expect(saves, 1);
    expect(find.text('Saving…'), findsOneWidget);
    pending.completeError(StateError('uncertain response'));
    await tester.pumpAndSettle();
    expect(find.text('Use gate B'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save request changes'))
            .onPressed,
        isNull);
    expect(saves, 1);
  });

  testWidgets(
      'Pending editor keeps existing combined notes longer than the create-note field',
      (tester) async {
    final original =
        '${List.filled(1000, 'n').join()}\n\nAdditional tasks to discuss (not included in the quote):\n${List.filled(500, 'x').join()}';
    String? savedNotes;
    await tester.pumpWidget(app(ConnectedPendingEditScreen(
        row: {
          'requested_start_at': '2027-10-28T02:00:00Z',
          'requested_end_at': '2027-10-28T04:00:00Z',
          'instructions': original
        },
        canSave: () => true,
        save: (start, end, notes) async {
          savedNotes = notes;
          return const AcceptanceOutcome(
              accepted: false, reason: 'availability');
        })));
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        original);
    await tester.scrollUntilVisible(find.text('Save request changes'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save request changes'));
    await tester.pumpAndSettle();
    expect(savedNotes, original);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'notification and privacy settings explain real capabilities at 320px/200% dark=$dark',
        (tester) async {
      phone(tester, width: 320);
      final prefs = DevicePreferences();
      await prefs.bindAccount('owner');
      await tester.pumpWidget(app(
          NotificationSettingsScreen(
              preferences: prefs, openNotifications: () {}),
          dark: dark,
          scale: 2));
      await tester.scrollUntilVisible(find.text('Booking updates'), 140,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Booking updates'));
      await tester.pumpAndSettle();
      expect(prefs.bookingIndicators, isFalse);
      expect(find.text('Saved on this device'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.scrollUntilVisible(
          find.text('Push notifications are not enabled'), 160,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(
          PrivacySecurityScreen(
              email: 'owner@example.invalid',
              role: 'Property Owner',
              onSignOut: () async {}),
          dark: dark,
          scale: 2));
      await tester.scrollUntilVisible(find.text('Delete account'), 180,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      expect(
          find.text(
              'Self-service deletion is not available yet. Signing out does not delete your account.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
    });
  }

  for (final dark in [false, true]) {
    testWidgets('profile and notification settings visual review dark=$dark',
        (tester) async {
      phone(tester);
      final key = GlobalKey();
      await tester.pumpWidget(app(
          RepaintBoundary(
              key: key,
              child: OwnerProfileScreen(
                snapshot: const {
                  'display_name': 'Aina Ahmad',
                  'email': 'owner@example.invalid',
                  'property_count': 8
                },
                onAction: (_) {},
                onOpenBookings: () {},
              )),
          dark: dark));
      await tester.pumpAndSettle();
      await capture(tester, key, 'profile-${dark ? 'dark' : 'light'}');
      final prefs = DevicePreferences();
      await prefs.bindAccount('owner');
      await tester.pumpWidget(app(
          RepaintBoundary(
              key: key,
              child: NotificationSettingsScreen(
                preferences: prefs,
                openNotifications: () {},
              )),
          dark: dark));
      await tester.pumpAndSettle();
      await capture(
          tester, key, 'notification-settings-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(
          RepaintBoundary(
              key: key, child: const AboutScreen(environmentLabel: 'staging')),
          dark: dark));
      await tester.pumpAndSettle();
      await capture(tester, key, 'about-help-${dark ? 'dark' : 'light'}');
      expect(find.text('Staging environment'), findsNothing);
      expect(find.text('Contact support'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
    });
  }

  testWidgets(
      'Appearance offers all three modes and sends explicit System selection',
      (tester) async {
    final providers = ProviderStore(), properties = PropertyStore();
    ThemeMode? chosen;
    await tester.pumpWidget(AppProviders(
        themeMode: ThemeMode.light,
        onToggleTheme: () {},
        onSetThemeMode: (mode) async => chosen = mode,
        bookingStore:
            BookingStore(providerStore: providers, propertyStore: properties),
        providerStore: providers,
        propertyStore: properties,
        reviewStore: ReviewStore(),
        messageStore: MessageStore(),
        child: app(const AppearanceSettingsScreen())));
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(chosen, ThemeMode.system);
  });
}
