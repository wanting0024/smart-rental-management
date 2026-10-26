import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking messages require participant reads and RPC-only sends', () {
    final sql = File('supabase/migrations/202610220010_booking_messages.sql')
        .readAsStringSync();
    expect(
        sql,
        contains(
            'alter table public.booking_message enable row level security'));
    expect(sql, contains('booking_message_participant_read'));
    expect(sql, contains('b.owner_id = (select auth.uid())'));
    expect(sql, contains('b.provider_id = (select auth.uid())'));
    expect(
        sql,
        contains(
            'revoke all on public.booking_message from public, anon, authenticated'));
    expect(
        sql,
        contains(
            "v_booking.current_status not in ('Accepted', 'In Progress')"));
    expect(sql, contains('client_message_id'));
    expect(sql, contains('for share'));
    expect(
        sql,
        contains(
            'alter publication supabase_realtime add table public.booking_message'));
  });
}
