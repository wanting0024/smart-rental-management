import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/supabase_booking_repository.dart';

void main() {
  test('request token is a distinct version-4 UUID', () {
    final first = BookingRequestToken.newV4();
    final second = BookingRequestToken.newV4();
    final version4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(version4.hasMatch(first), isTrue);
    expect(version4.hasMatch(second), isTrue);
    expect(first, isNot(second));
  });

  test('creation result exposes reused requests and typed rejections', () {
    final created = BookingCreationOutcome.fromResponse({
      'created': true,
      'booking_id': 'booking-1',
      'reused': false,
      'quoted_amount': 120,
      'quote_basis': 'hourly',
      'quote_currency': 'MYR',
    });
    final retried = BookingCreationOutcome.fromResponse({
      'created': true,
      'booking_id': 'booking-1',
      'reused': true,
      'quoted_amount': 120,
      'quote_basis': 'hourly',
      'quote_currency': 'MYR',
    });
    expect(created.bookingId, retried.bookingId);
    expect(created.reused, isFalse);
    expect(retried.reused, isTrue);
    expect(retried.quotedAmount, 120);
    expect(retried.quoteBasis, 'hourly');
    expect(
      () => BookingCreationOutcome.fromResponse({
        'created': false,
        'reason': 'availability',
      }),
      throwsA(isA<BookingRequestRejected>().having(
        (error) => error.reason,
        'reason',
        'availability',
      )),
    );
  });

  test('creation migration removes direct inserts and checks hard filters', () {
    final sql = File(
      'supabase/migrations/202610220006_secure_booking_creation.sql',
    ).readAsStringSync();
    expect(sql, contains('drop policy if exists booking_owner_insert'));
    expect(sql, contains('revoke insert on public.booking'));
    expect(sql, contains('guard_booking_request_id_change_before'));
    expect(sql, contains('booking_owner_request_id_unique'));
    expect(sql, contains("v_provider_status is distinct from 'approved'"));
    expect(
        sql, contains("other.current_status in ('Accepted', 'In Progress')"));
    expect(sql, contains("'Pending', p_client_request_id"));
  });
}
