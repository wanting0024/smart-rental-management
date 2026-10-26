import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202610220009_booking_quote_snapshot.sql',
  ).readAsStringSync();

  test('daily basis requires exactly eight booked hours', () {
    expect(sql, contains("quote_basis in ('hourly', 'daily')"));
    expect(sql,
        contains("quote_basis <> 'daily' or quoted_duration_minutes = 480"));
    expect(sql, contains('v_minutes = 480 and v_daily_rate > 0'));
    expect(sql, contains('v_seconds > 28800'));
  });

  test('short bookings require hourly rate and are calculated on server', () {
    expect(sql, contains('v_minutes < 480 and p.hourly_rate > 0'));
    expect(sql, contains('round(v_hourly_rate * v_minutes / 60, 2)'));
    expect(sql, contains('p_expected_amount <> v_amount'));
    expect(sql, contains("'reason', 'price_changed'"));
  });

  test('quote snapshot cannot be rewritten or omitted by old RPC', () {
    expect(sql, contains('drop function public.create_pending_booking('));
    expect(sql, contains('quoted_duration_minutes, quoted_amount'));
    expect(sql, contains('guard_booking_quote_change_before'));
    expect(sql, contains('Changing duration requires a new priced request'));
    expect(sql, contains('Unpriced legacy request cannot be accepted'));
    expect(sql, contains('booking_quote_complete'));
    expect(sql, contains("quote_currency text not null default 'MYR'"));
  });
}
