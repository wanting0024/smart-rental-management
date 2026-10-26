import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/owner_home_screen.dart';
import 'package:rental_app_demo/screens/property_list_screen.dart';
import 'package:rental_app_demo/screens/property_detail_screen.dart';
import 'package:rental_app_demo/screens/provider_stats_screen.dart';
import 'package:rental_app_demo/screens/owner_spend_screen.dart';
import 'package:rental_app_demo/screens/workspace_reports.dart';
import 'package:rental_app_demo/screens/connected_property_form_screen.dart';
import 'package:rental_app_demo/services/backend/owned_workspace_binding.dart';
import 'package:rental_app_demo/services/backend/supabase_workspace_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

const actor = 'owner';
Map<String, dynamic> property() => {
      'property_id': 'server-unit',
      'unit_name': 'Live A',
      'building_name': 'Actual building',
      'address': 'Synthetic address',
      'bedrooms': 2,
      'size_sqft': 800,
      'property_revision': 1,
      'cleaning_window_start': '08:00:00',
      'cleaning_window_end': '18:00:00'
    };
Map<String, dynamic> stats() => {
      'actor_id': actor,
      'as_of': '2026-10-24T01:00:00Z',
      'total': 10,
      'accepted': 10,
      'completed': 8,
      'closed_other': 0,
      'decisions': 10,
      'accepted_decisions': 10,
      'response_minutes': 24.5,
      'repeat_jobs': 4,
      'undated_completions': 0,
      'ratings': {'5': 6, '4': 2},
      'weeks': List.generate(
          8, (i) => {'week_start': '2026-10-01', 'jobs': i == 7 ? 8 : 0})
    };
Map<String, dynamic> spending() => {
      'actor_id': actor,
      'as_of': '2026-10-24T01:00:00Z',
      'period': 'allTime',
      'currency': 'MYR',
      'jobs': 2,
      'unpriced': 1,
      'undated': 0,
      'gross': 100.01,
      'this_month': 100.01,
      'last_month': 0,
      'providers': [
        {'provider_name': 'Actual provider', 'gross': 100.01}
      ],
      'items': [
        {
          'booking_id': 'actual-booking',
          'completed_at': '2026-10-24T01:00:00Z',
          'quoted_amount': 100.01,
          'service_name': 'Cleaning',
          'unit_name': 'Live A',
          'building_name': 'Actual building',
          'provider_name': 'Actual provider'
        },
        {
          'booking_id': 'unknown-quote',
          'completed_at': '2026-10-23T01:00:00Z',
          'quoted_amount': null,
          'service_name': 'Cleaning',
          'unit_name': 'Live A',
          'building_name': 'Actual building',
          'provider_name': 'Actual provider'
        }
      ]
    };

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
  });
  test('reports preserve unpriced vs zero and reject fabricated metrics/ranges',
      () {
    final summary = ownerSpendSummary(spending());
    expect(summary.totalSpent, 100.01);
    expect(summary.avgPerJob, 100.01);
    expect(summary.records.last.amountAvailable, false);
    validateWorkspaceReport(stats(), provider: true, period: 'allTime');
    expect(
        () => validateWorkspaceReport({...stats(), 'repeat_jobs': 100},
            provider: true, period: 'allTime'),
        throwsFormatException);
    expect(
        () => validateWorkspaceReport(spending(),
            provider: false, period: 'thisMonth'),
        throwsFormatException);
  });
  testWidgets(
      'owned paging retains snapshot and rejects account changes / late reads',
      (tester) async {
    String? identity = actor;
    final sessions = StreamController<String?>.broadcast();
    final pending = Completer<Map<String, dynamic>>();
    var heads = 0;
    final binding = OwnedWorkspaceBinding(
        userId: actor,
        currentUserId: () => identity,
        sessions: sessions.stream,
        load: ({before, asOf}) async {
          if (before != null)
            return {
              'actor_id': actor,
              'items': [
                {'booking_id': 'older'}
              ]
            };
          if (heads++ > 0) return pending.future;
          return {
            'actor_id': actor,
            'items': [
              {'booking_id': 'first'}
            ],
            'next_cursor': {'timestamp': '2026-10-24T01:00:00Z', 'id': 'first'}
          };
        });
    binding.setActive(true);
    await tester.pump();
    await binding.loadMore();
    expect(binding.items.length, 2);
    final work = binding.refresh();
    expect(binding.items.length, 2);
    identity = 'other';
    sessions.add(identity);
    await tester.pump();
    expect(binding.snapshot, isNull);
    pending.complete({'actor_id': actor, 'items': []});
    await work;
    expect(binding.sessionEnded, true);
    binding.dispose();
    await sessions.close();
  });
  for (final dark in [false, true]) {
    testWidgets(
        'original connected pages fit 320px / 200% dark=$dark without preview stores',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = SupabaseWorkspaceRepository.propertyPresentation(property());
      for (final screen in <Widget>[
        OwnerProfileScreen(snapshot: const {
          'display_name': 'Actual owner',
          'email': 'owner@fixture.invalid',
          'property_count': 0
        }, onOpenBookings: () {}),
        PropertyListScreen(bookings: const [], connectedProperties: [
          p
        ], connectedCounts: {
          p.id: [3, 5, 10]
        }, totalCount: 30, onAddConnected: () {}, onOpenConnected: (_) {}),
        PropertyDetailScreen(
            connected: true,
            property: p,
            bookings: const [],
            totalBookings: 10,
            onEditConnected: () {},
            onRequestConnected: () {}),
        OwnerSpendScreen(
            bookings: const [],
            connectedSummary: ownerSpendSummary(spending()),
            onRefresh: () async {},
            onSelectPeriod: (_) {},
            unpriced: 1),
        ProviderStatsScreen(snapshot: stats(), onRefresh: () async {}),
      ]) {
        await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: screen));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${screen.runtimeType} initial');
        final list = find.byType(ListView).first;
        await tester.drag(list, const Offset(0, -1600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${screen.runtimeType} scrolled');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'Owner profile shows actual counts, no fake verification; property callbacks use ID',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: OwnerProfileScreen(snapshot: const {
      'display_name': 'Actual owner',
      'email': 'owner@fixture.invalid',
      'property_count': 0
    }, onOpenBookings: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Owner · 0 properties'), findsOneWidget);
    expect(find.text('NRIC verified'), findsNothing);
    String? opened;
    final p = SupabaseWorkspaceRepository.propertyPresentation(property());
    await tester.pumpWidget(MaterialApp(
        home: PropertyListScreen(
            bookings: const [],
            connectedProperties: [
          p
        ],
            connectedCounts: {
          p.id: [1, 2, 3]
        },
            totalCount: 1,
            onAddConnected: () {},
            onOpenConnected: (v) => opened = v.id)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(p.display), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(p.display));
    expect(opened, p.id);
  });
  testWidgets(
      'property edit prefills and saves real fields, guard preserves unsaved changes',
      (tester) async {
    final p = SupabaseWorkspaceRepository.propertyPresentation(property());
    ConnectedPropertyInput? saved;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => ConnectedPropertyFormScreen(
                                initial: p,
                                onSave: (input) async {
                                  saved = input;
                                }))),
                    child: const Text('Edit'))))));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Live A'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Updated A');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(saved?.unitName, 'Updated A');
    expect(saved?.bedrooms, 2);
  });
}
