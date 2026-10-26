import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/content/prototype_legal_drafts.dart';
import 'package:rental_app_demo/screens/prototype_legal_draft_screen.dart';
import 'package:rental_app_demo/screens/workspace_entry_screen.dart';
import 'package:rental_app_demo/screens/workspace_login_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/cleaning_service_scope.dart';
import 'package:rental_app_demo/widgets/connected_workspace_components.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Widget app(Widget home, {bool dark = false, double scale = 1}) => MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: home,
    );

void phone(WidgetTester tester, {bool short = false}) {
  tester.view.physicalSize =
      short ? const Size(320, 568) : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> capture(GlobalKey key, WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('output/owner-uat-batch-three-ui').create(recursive: true);
    await File('output/owner-uat-batch-three-ui/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      final parent = sdk.parent;
      if (parent.path == sdk.path)
        throw StateError('Flutter fonts unavailable');
      sdk = parent;
    }
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      await (FontLoader(entry.key)
            ..addFont(Future.value(ByteData.sublistView(await File(
                    '${sdk.path}/bin/cache/artifacts/material_fonts/${entry.value}')
                .readAsBytes()))))
          .load();
    }
  });
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  testWidgets(
      'welcome opens real registration and login in place; back returns',
      (tester) async {
    final sdk = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(sdk.dispose));
    phone(tester);
    await tester.pumpWidget(
        app(WorkspaceEntryScreen(backend: SupabaseBackendProvider(sdk))));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceLoginScreen), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('welcome-create-account')));
    await tester.tap(find.byKey(const Key('welcome-create-account')));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2 · Account details'), findsOneWidget);
    expect(find.byKey(const Key('registration-name')), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('registration-name')))
            .controller!
            .text,
        isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Smart Rental'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('welcome-log-in')));
    await tester.tap(find.byKey(const Key('welcome-log-in')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('registration-name')), findsNothing);
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Smart Rental'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final kind in LegalDraftKind.values) {
    testWidgets('welcome can read ${kind.name} before creating an account',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(app(const WorkspaceEntryScreen()));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.text(PrototypeLegalDraft.forKind(kind).title));
      await tester.tap(find.text(PrototypeLegalDraft.forKind(kind).title));
      await tester.pumpAndSettle();
      expect(find.byType(PrototypeLegalDraftScreen), findsOneWidget);
      expect(find.text(PrototypeLegalDraft.status), findsOneWidget);
      expect(find.text('Before public launch — unresolved'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Smart Rental'), findsOneWidget);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('welcome remains usable at 320px and 200% text, dark=$dark',
        (tester) async {
      phone(tester, short: true);
      await tester
          .pumpWidget(app(const WorkspaceEntryScreen(), dark: dark, scale: 2));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('welcome-log-in')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('welcome-log-in')).hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('welcome-log-in')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('welcome and service scope visual review, dark=$dark',
        (tester) async {
      phone(tester);
      final key = GlobalKey();
      await tester.pumpWidget(app(
          RepaintBoundary(key: key, child: const WorkspaceEntryScreen()),
          dark: dark));
      await tester.pumpAndSettle();
      await capture(key, tester, 'welcome-${dark ? 'dark' : 'light'}');
      await tester.pumpWidget(app(
          RepaintBoundary(
              key: key,
              child: Scaffold(
                appBar: AppBar(title: const Text('Cleaning service')),
                body: ListView(
                    padding: const EdgeInsets.all(20),
                    children: const [
                      Text('Standard cleaning',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      SizedBox(height: 18),
                      CleaningServiceScope(
                          description:
                              'Floors, accessible surfaces, bathrooms and kitchen counters.'),
                    ]),
              )),
          dark: dark));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Service scope'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Floors, accessible surfaces, bathrooms and kitchen counters.'),
          findsOneWidget);
      expect(find.text('Outside this service'), findsOneWidget);
      await capture(key, tester, 'scope-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
    });

    for (final isProvider in [false, true]) {
      testWidgets(
          'saved extra tasks are visible to ${isProvider ? 'Provider' : 'Owner'} at 200% text, dark=$dark',
          (tester) async {
        phone(tester, short: true);
        final notes = bookingRequestInstructions(
            'Use the side gate.', 'Can you clean inside the oven?');
        await tester.pumpWidget(app(
            Scaffold(
                body: ListView(children: [
              ConnectedBookingCard(
                row: {
                  'booking_id': 'booking-1',
                  'current_status': 'Accepted',
                  'unit_name': 'A-12',
                  'building_name': 'Menara Suria',
                  'service_name': 'Standard cleaning',
                  'instructions': notes,
                  'quoted_amount': 80
                },
                isProvider: isProvider,
                busy: false,
                onAction: (_) {},
                onHistory: () {},
                onMessages: () {},
                onEvidence: () {},
                onReview: () {},
                onCancel: () {},
              ),
            ])),
            dark: dark,
            scale: 2));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
            find.textContaining('Can you clean inside the oven?'));
        expect(
            find.textContaining('not included in the quote'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('missing catalog description never invents an included task list',
      (tester) async {
    phone(tester, short: true);
    await tester.pumpWidget(app(
        const Scaffold(
            body: SingleChildScrollView(
          child: CleaningServiceScope(),
        )),
        scale: 2));
    await tester.tap(find.text('Service scope'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A detailed task list has not been provided'),
        findsOneWidget);
    expect(find.text('Service description'), findsNothing);
    await tester.ensureVisible(
        find.textContaining('Extra tasks are not automatically included'));
    expect(tester.takeException(), isNull);
  });
}
