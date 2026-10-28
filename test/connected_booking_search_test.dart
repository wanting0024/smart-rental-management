import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/connected_booking_request_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';

void main() {
  test('MYT booking conversion does not depend on device timezone', () {
    final instant = malaysiaBookingInstant(
      DateTime(2026, 10, 30),
      const TimeOfDay(hour: 9, minute: 30),
    );
    expect(instant, DateTime.utc(2026, 10, 30, 1, 30));
  });

  test('eligibility DTO does not expose private provider origin', () {
    final provider = EligibleProviderItem.fromJson({
      'provider_id': 'provider-1',
      'bio': 'Cleaning provider',
      'service_area': 'Petaling Jaya',
      'hourly_rate': 50,
      'daily_rate': null,
      'rating_average': null,
      'completed_job_count': 0,
      'quote_basis': 'hourly',
      'quoted_amount': 120,
      'service_origin_address': 'Private street address',
    });
    expect(provider.serviceArea, 'Petaling Jaya');
    expect(provider.hourlyRate, 50);
    expect(provider.quotedAmount, 120);
  });

  test('SQL hard filter excludes Pending and private fields', () {
    final sql = File(
      'supabase/migrations/202610220008_eligible_provider_search.sql',
    ).readAsStringSync();
    expect(sql, contains("a.role = 'owner'"));
    expect(sql, contains('p.owner_id = v_actor'));
    expect(sql, contains("p.approval_status = 'approved'"));
    expect(sql, contains('c.service_type_id = p_service_type_id'));
    expect(sql, contains('s.end_time >= v_end::time'));
    expect(sql, contains("b.current_status in ('Accepted', 'In Progress')"));
    expect(sql, isNot(contains("b.current_status in ('Pending'")));
    expect(sql, isNot(contains('service_origin_address')));
  });

  testWidgets('Owner search screen requires a valid request before submission',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ConnectedBookingRequestScreen(
        loadProperties: () async => [
          {
            'property_id': 'property-1',
            'unit_name': 'Unit A-12',
            'building_name': 'Menara Suria',
          }
        ],
        loadServiceTypes: () async => [
          {'service_type_id': 'service-1', 'name': 'Standard cleaning'}
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
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Select service date'), findsNothing);
    expect(find.text('Submit Pending request'), findsNothing);
    await tester.ensureVisible(find.text('Continue to date & time'));
    await tester.tap(find.text('Continue to date & time'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your rental unit.'), findsOneWidget);
    expect(find.text('Choose a cleaning service.'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
  });
}
