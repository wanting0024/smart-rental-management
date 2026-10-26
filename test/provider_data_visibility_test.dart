import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';

void main() {
  test('approved directory maps only owner-safe fields', () {
    final item = ApprovedProviderDirectoryItem.fromJson({
      'provider_id': 'provider-1',
      'bio': 'Rental cleaning',
      'service_area': 'Petaling Jaya',
      'hourly_rate': 50,
      'daily_rate': null,
      'rating_average': 4.5,
      'completed_job_count': 12,
      'service_type_ids': ['service-1'],
      'service_origin_address': 'Private address must not be used',
    });
    expect(item.providerId, 'provider-1');
    expect(item.serviceArea, 'Petaling Jaya');
    expect(item.serviceTypeIds, ['service-1']);
    expect(item.hourlyRate, 50);
  });

  test('directory RPC cannot select the private service origin', () {
    final migration = File(
      'supabase/migrations/202610220005_provider_data_visibility.sql',
    ).readAsStringSync();
    final function = migration.substring(
      migration
          .indexOf('create function public.list_approved_provider_directory'),
    );
    expect(function, isNot(contains('service_origin_address')));
    expect(function, contains("p.approval_status = 'approved'"));
    expect(migration, contains('provider_profile_self_read'));
    expect(migration, contains('weekly_slot_self_read'));
    expect(migration, contains('unavailable_date_self_read'));
  });
}
