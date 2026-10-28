import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/connected_workspace_components.dart';

final _booking = <String, dynamic>{
  'booking_id': 'booking-preview',
  'unit_name': 'Unit A-12',
  'building_name': 'Menara Suria',
  'property_address': 'Jalan Ampang, Kuala Lumpur',
  'service_name': 'Standard cleaning',
  'instructions': 'Please focus on the kitchen and bathrooms.',
  'current_status': 'Pending',
  'requested_start_at': '2026-10-28T02:00:00Z',
  'requested_end_at': '2026-10-28T04:00:00Z',
  'quoted_amount': 136,
};

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdkDirectory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdkDirectory.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      final parent = sdkDirectory.parent;
      if (parent.path == sdkDirectory.path) {
        throw StateError('Could not locate Flutter SDK fonts.');
      }
      sdkDirectory = parent;
    }
    Future<ByteData> localFont(String name) async => ByteData.sublistView(
          await File(
                  '${sdkDirectory.path}/bin/cache/artifacts/material_fonts/$name')
              .readAsBytes(),
        );
    await (FontLoader('Roboto')..addFont(localFont('roboto-regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(localFont('materialicons-regular.otf')))
        .load();
  });

  test('server UTC interval displays as readable Malaysia time', () {
    expect(
      connectedBookingTimeLabel('2026-10-28T02:00:00Z', '2026-10-28T04:00:00Z'),
      contains('10:00 AM–12:00 PM MYT'),
    );
    expect(connectedBookingTimeLabel(null, null), 'Schedule unavailable');
  });

  testWidgets('provider card shows booking context and next action at 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? action;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
          body: ListView(children: [
        ConnectedBookingCard(
          row: _booking,
          isProvider: true,
          busy: false,
          propertyName: 'Unit A-12, Menara Suria',
          onAction: (value) => action = value,
          onHistory: () {},
          onMessages: () {},
          onEvidence: () {},
          onReview: () {},
          onCancel: () {},
        )
      ])),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Unit A-12, Menara Suria'), findsOneWidget);
    expect(find.text('Standard cleaning'), findsOneWidget);
    expect(find.text('Jalan Ampang, Kuala Lumpur'), findsOneWidget);
    expect(find.textContaining('10:00 AM–12:00 PM MYT'), findsOneWidget);
    await tester.ensureVisible(find.text('Accept request'));
    await tester.tap(find.text('Accept request'));
    expect(action, 'Accepted');
  });

  testWidgets(
      'booking actions have contextual accessibility labels in both themes',
      (tester) async {
    final handle = tester.ensureSemantics();
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
            body: ConnectedBookingCard(
          row: {..._booking, 'current_status': 'Accepted'},
          isProvider: true,
          busy: false,
          propertyName: 'Unit A-12, Menara Suria',
          onAction: (_) {},
          onHistory: () {},
          onMessages: () {},
          onEvidence: () {},
          onReview: () {},
          onCancel: () {},
        )),
      ));
      await tester.pumpAndSettle();
      expect(
          find.bySemanticsLabel(
              'View status history for Unit A-12, Menara Suria'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Open messages for Unit A-12, Menara Suria'),
          findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    handle.dispose();
  });

  testWidgets('connected Owner visual preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const ConnectedWorkspaceHero(owner: true),
            const SizedBox(height: 18),
            const ConnectedSummaryTiles(values: [
              ('Properties', 2, Icons.apartment_outlined),
              ('Pending', 1, Icons.hourglass_top_outlined),
              ('Active', 1, Icons.cleaning_services_outlined),
              ('Completed', 3, Icons.task_alt_outlined),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.search),
              label: const Text('New cleaning request'),
            ),
            const SizedBox(height: 18),
            const Text('My properties',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 8),
            const ConnectedPropertyCard(row: {
              'unit_name': 'Unit A-12',
              'building_name': 'Menara Suria',
              'bedrooms': 3,
              'size_sqft': 980,
              'address': 'Jalan Ampang, Kuala Lumpur',
            }),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/connected_owner_home.png'));
  });

  testWidgets('connected Provider booking visual preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('My work')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const ConnectedWorkspaceHero(owner: false),
            const SizedBox(height: 18),
            const ConnectedProviderProfileCard(profile: {
              'approval_status': 'approved',
              'service_area': 'Kuala Lumpur',
            }),
            const SizedBox(height: 18),
            const Text('Bookings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 8),
            ConnectedBookingCard(
              row: _booking,
              isProvider: true,
              busy: false,
              propertyName: 'Unit A-12, Menara Suria',
              onAction: (_) {},
              onHistory: () {},
              onMessages: () {},
              onEvidence: () {},
              onReview: () {},
              onCancel: () {},
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/connected_provider_home.png'));
  });

  testWidgets('Provider booking remains readable with 150% text',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('My work')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            ConnectedBookingCard(
              row: {..._booking, 'current_status': 'Accepted'},
              isProvider: true,
              busy: false,
              propertyName: 'Unit A-12, Menara Suria',
              onAction: (_) {},
              onHistory: () {},
              onMessages: () {},
              onEvidence: () {},
              onReview: () {},
              onCancel: () {},
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/connected_provider_large_text.png'));
  });
}
