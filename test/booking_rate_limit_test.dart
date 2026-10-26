import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/booking_rate_limit.dart';
import 'package:rental_app_demo/services/backend/safe_diagnostics.dart';

void main() {
  test(
      'only the expected fixed RPC rejection is classified as a definite limit',
      () {
    const error = PostgrestException(
        code: 'PT429',
        message: 'CHAT_RATE_LIMITED',
        details: 'retry_after_seconds=17',);
    final value = ServerActionLimit.from(error, BookingLimitedAction.message)!;
    expect(value.retryAfterSeconds, 17);
    expect(value.action, BookingLimitedAction.message);
    expect(
        ServerActionLimit.from(error, BookingLimitedAction.evidence), isNull,);
    expect(
        ServerActionLimit.from(
            const PostgrestException(code: '429', message: 'CHAT_RATE_LIMITED'),
            BookingLimitedAction.message,),
        isNull,);
    expect(
        ServerActionLimit.from(
            const PostgrestException(
                code: 'PT429', message: 'UNKNOWN_PRIVATE_MESSAGE',),
            BookingLimitedAction.message,),
        isNull,);
  });
  test('untrusted/missing retry detail uses a bounded safe default', () {
    for (final detail in [
      null,
      '',
      'retry_after_seconds=0',
      'retry_after_seconds=-1',
      'retry_after_seconds=86401',
      'retry_after_seconds=99999999999999',
      'retry_after_seconds=10\nPRIVATE_DATA',
      {'private': 'DO_NOT_SHOW'},
    ]) {
      final value = ServerActionLimit.from(
          PostgrestException(
              code: 'PT429', message: 'EVIDENCE_RATE_LIMITED', details: detail,),
          BookingLimitedAction.evidence,)!;
      expect(value.retryAfterSeconds, 60);
      expect(value.toString(), isNot(contains('PRIVATE')));
    }
  });
  test('friendly duration labels do not imply an exact countdown', () {
    expect(const ServerActionLimit(BookingLimitedAction.message, 1).waitLabel,
        '1 second',);
    expect(const ServerActionLimit(BookingLimitedAction.message, 61).waitLabel,
        '2 minutes',);
    expect(
        const ServerActionLimit(BookingLimitedAction.evidence, 3600).waitLabel,
        '1 hour',);
    expect(
        const ServerActionLimit(BookingLimitedAction.evidence, 86400).waitLabel,
        '24 hours',);
  });
  test('wrapper preserves successful values and unrelated failures', () async {
    expect(
        await withServerRateLimit(
            BookingLimitedAction.message, () async => 'ok',),
        'ok',);
    final error = StateError('SYNTHETIC_PRIVATE_ERROR');
    await expectLater(
        withServerRateLimit(
            BookingLimitedAction.message, () async => throw error,),
        throwsA(same(error)),);
    await expectLater(
        withServerRateLimit(
            BookingLimitedAction.message,
            () async => throw const PostgrestException(
                code: 'PT429',
                message: 'CHAT_RATE_LIMITED',
                details: 'retry_after_seconds=10',),),
        throwsA(isA<ServerActionLimit>()),);
  });
  test('rate diagnostics use only the fixed category, never the server payload',
      () {
    final lines = <String>[];
    SafeDiagnostics(sink: lines.add).record(SafeOperation.messageSend,
        const ServerActionLimit(BookingLimitedAction.message, 10),);
    expect(lines.single, contains('category=rateLimited'));
    expect(lines.single, isNot(contains('10')));
  });
  testWidgets('pause ends without retrying and disposal cancels the timer',
      (tester) async {
    final pause = ActionRatePause();
    var changes = 0;
    pause.addListener(() => changes++);
    pause.start(const ServerActionLimit(BookingLimitedAction.message, 10));
    expect(pause.active, isTrue);
    await tester.pump(const Duration(seconds: 9));
    expect(pause.active, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(pause.active, isFalse);
    expect(changes, 2);
    pause.start(const ServerActionLimit(BookingLimitedAction.message, 60));
    pause.dispose();
    await tester.pump(const Duration(seconds: 61));
    expect(changes, 3);
  });
}
