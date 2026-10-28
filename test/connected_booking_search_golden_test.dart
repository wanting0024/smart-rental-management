import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/time_slot_steps.dart';
import 'package:rental_app_demo/screens/connected_booking_request_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var directory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${directory.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      directory = directory.parent;
    }
    Future<ByteData> font(String name) async => ByteData.sublistView(
          await File(
                  '${directory.path}/bin/cache/artifacts/material_fonts/$name')
              .readAsBytes(),
        );
    await (FontLoader('Roboto')..addFont(font('roboto-regular.ttf'))).load();
    await (FontLoader('MaterialIcons')
          ..addFont(font('materialicons-regular.otf')))
        .load();
  });

  testWidgets('connected Owner eligibility search visual preview',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: ConnectedBookingRequestScreen(
        loadProperties: () async => [
          {
            'property_id': 'unit-1',
            'unit_name': 'Unit A-12',
            'building_name': 'Menara Suria',
          }
        ],
        loadServiceTypes: () async => [
          {'service_type_id': 'standard', 'name': 'Standard cleaning'}
        ],
        findEligible: ({
          required propertyId,
          required serviceTypeId,
          required start,
          required end,
        }) async =>
            const [],
        createPending: ({
          required clientRequestId,
          required providerId,
          required propertyId,
          required serviceTypeId,
          required start,
          required end,
          required expectedAmount,
          required expectedBasis,
          required instructions,
        }) async =>
            throw StateError('No request selected'),
        findCreatedBooking: (_) async => null,
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ConnectedBookingRequestScreen),
      matchesGoldenFile('goldens/connected_booking_search.png'),
    );
  });

  testWidgets('priced Pending request review visual preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: ConnectedBookingRequestScreen(
        now: () => DateTime.utc(2026, 10, 22, 1),
        loadProperties: () async => [
          {
            'property_id': 'unit-1',
            'unit_name': 'Unit A-12',
            'building_name': 'Menara Suria',
          },
        ],
        loadServiceTypes: () async => [
          {'service_type_id': 'standard', 'name': 'Standard cleaning'},
        ],
        findEligible: ({
          required propertyId,
          required serviceTypeId,
          required start,
          required end,
        }) async =>
            const [
          EligibleProviderItem(
            providerId: 'provider-1',
            serviceArea: 'Petaling Jaya',
            bio: 'Rental unit cleaning',
            hourlyRate: 40,
            dailyRate: 280,
            ratingAverage: 4.7,
            completedJobCount: 12,
            quoteBasis: 'hourly',
            quotedAmount: 80,
          ),
        ],
        createPending: ({
          required clientRequestId,
          required providerId,
          required propertyId,
          required serviceTypeId,
          required start,
          required end,
          required expectedAmount,
          required expectedBasis,
          required instructions,
        }) async =>
            throw StateError('Preview only'),
        findCreatedBooking: (_) async => null,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unit A-12, Menara Suria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard cleaning').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue to date & time'));
    await tester.tap(find.text('Continue to date & time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select service date'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select time').first);
    await tester.pumpAndSettle();
    await chooseTimeSlot(tester, 540);
    await tester.tap(find.text('Select time').last);
    await tester.pumpAndSettle();
    await chooseTimeSlot(tester, 660);
    await tester.ensureVisible(find.text('Find eligible providers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find eligible providers'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Select and review'),
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select and review'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Submit Pending request'),
      find.byType(ListView),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ConnectedBookingRequestScreen),
      matchesGoldenFile('goldens/connected_booking_review.png'),
    );
  });
}
