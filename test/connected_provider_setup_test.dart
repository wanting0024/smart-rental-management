import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/features/availability/domain/provider_setup.dart';
import 'package:rental_app_demo/screens/connected_provider_setup_screen.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  Future<void> loadMaterialIconFont() async {
    var directory = File(Platform.resolvedExecutable).parent;
    for (var depth = 0; depth < 8; depth++) {
      final font = File(
        '${directory.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (font.existsSync()) {
        final bytes = font.readAsBytesSync();
        await (FontLoader('MaterialIcons')
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
        return;
      }
      directory = directory.parent;
    }
    throw StateError('Flutter Material icon font was not found.');
  }

  test('two-hour minimum and half-open overlap are validated', () {
    const existing = [
      ProviderWeeklySlotItem(
        id: 'slot-1',
        weekday: 1,
        startMinute: 8 * 60,
        endMinute: 10 * 60,
      )
    ];
    expect(
      ProviderSlotRules.validate(
        weekday: 1,
        startMinute: 11 * 60,
        endMinute: 12 * 60,
        existing: existing,
      ),
      'Each working slot must be at least 2 hours.',
    );
    expect(
      ProviderSlotRules.validate(
        weekday: 1,
        startMinute: 9 * 60,
        endMinute: 12 * 60,
        existing: existing,
      ),
      'Working slots on the same day cannot overlap.',
    );
    expect(
      ProviderSlotRules.validate(
        weekday: 1,
        startMinute: 10 * 60,
        endMinute: 12 * 60,
        existing: existing,
      ),
      isNull,
    );
    expect(ProviderSlotRules.parseDatabaseTime('08:15:00'), 8 * 60 + 15);
    expect(ProviderSlotRules.databaseTime(8 * 60 + 15), '08:15');
    expect(
      ProviderSlotRules.validate(
        weekday: 1,
        startMinute: 22 * 60,
        endMinute: 24 * 60,
        existing: existing,
      ),
      'Choose a valid day and time range.',
    );
  });

  testWidgets('connected screen saves selected real service IDs only',
      (tester) async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    await loadMaterialIconFont();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <Set<String>>[];
    const data = ProviderSetupData(
      services: [
        ProviderServiceItem(id: 'service-1', name: 'Standard cleaning'),
        ProviderServiceItem(id: 'service-2', name: 'Deep cleaning'),
      ],
      selectedServiceIds: {},
      slots: [],
      unavailableDates: {},
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ConnectedProviderSetupScreen(
        load: () async => data,
        saveServices: (ids) async {
          saved.add(ids);
        },
        addSlot: (weekday, start, end) async {},
        removeSlot: (id) async {},
        addUnavailableDate: (date) async {},
        removeUnavailableDate: (date) async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Standard cleaning'), findsOneWidget);
    expect(find.text('Deep cleaning'), findsOneWidget);
    await expectLater(
      find.byType(ConnectedProviderSetupScreen),
      matchesGoldenFile('goldens/connected_provider_setup.png'),
    );
    expect(saved, isEmpty);

    await tester.tap(find.byKey(const Key('service-Standard cleaning')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save service types'));
    await tester.tap(find.text('Save service types'));
    await tester.pumpAndSettle();
    expect(saved, [
      <String>{'service-1'}
    ]);
    expect(tester.takeException(), isNull);
  });
}
