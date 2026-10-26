import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('property-window trigger retains its lock despite private provider RLS',
      () {
    final privateProfileMigration = File(
      'supabase/migrations/202610220005_provider_data_visibility.sql',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/202610220007_property_window_lock_visibility.sql',
    ).readAsStringSync();

    expect(privateProfileMigration, contains('provider_profile_self_read'));
    expect(
      migration,
      contains('create or replace function public.lock_property_window_change()'),
    );
    expect(migration, contains('security definer set search_path ='));
    expect(migration, contains('order by b.provider_id'));
    expect(migration, contains('where p.provider_id = v_provider_id for update'));
    expect(
      migration,
      contains("b.current_status in ('Accepted', 'In Progress')"),
    );
    expect(
      migration,
      contains('revoke execute on function public.lock_property_window_change()'),
    );
  });
}
