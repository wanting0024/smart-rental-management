import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import '../tool/staging_business_acceptance_support.dart';

void main() {
  const run = '460574d3-d567-4082-8221-72b1f4fa8bec';
  Map<String, dynamic> config() => {
        'APP_ENV': 'staging',
        'SUPABASE_PROJECT_REF': businessStagingRef,
        'SUPABASE_URL': 'https://$businessStagingRef.supabase.co',
        'ALLOW_PRODUCTION_BACKEND': false,
      };
  Map<String, dynamic> fixture() => {
        'environment': 'staging',
        'project_ref': businessStagingRef,
        'run_id': run,
        'fixture': businessFixtureKind,
        'accounts': ['owner', 'provider']
            .map(
              (role) => {
                'role': role,
                'email': '$role.$run@rental-test.invalid',
                'user_id': role == 'owner'
                    ? run
                    : 'bef9994a-e2cc-4d65-8581-677875040f07',
                'password': 'synthetic-test-only-not-a-real-secret-32',
              },
            )
            .toList(),
      };
  test('exact isolated target accepted without any network', () {
    expect(
      () => requireBusinessTarget(config(), fixture(), businessStagingRef),
      returnsNormally,
    );
  });
  for (final key in [
    'APP_ENV',
    'SUPABASE_PROJECT_REF',
    'SUPABASE_URL',
    'ALLOW_PRODUCTION_BACKEND',
  ]) {
    test('target refuses changed $key', () {
      final c = config()..[key] = 'production';
      expect(
        () => requireBusinessTarget(c, fixture(), businessStagingRef),
        throwsStateError,
      );
    });
  }
  test('write confirmation mandatory', () {
    expect(
      () => requireBusinessTarget(config(), fixture(), ''),
      throwsStateError,
    );
  });
  for (final key in ['environment', 'project_ref', 'run_id', 'fixture']) {
    test('fixture refuses changed $key', () {
      final f = fixture()..[key] = 'other';
      expect(
        () => requireBusinessTarget(config(), f, businessStagingRef),
        throwsStateError,
      );
    });
  }
  for (final email in ['owner.a@rental-test.invalid', 'person@example.com']) {
    test('no adoption of $email', () {
      final f = fixture();
      (f['accounts'] as List).first['email'] = email;
      expect(
        () => requireBusinessTarget(config(), f, businessStagingRef),
        throwsStateError,
      );
    });
  }
  test('synthetic photo pixels valid distinct and deterministic', () {
    final before = businessTestPhoto(true), after = businessTestPhoto(false);
    expect(before, orderedEquals(businessTestPhoto(true)));
    expect(before, isNot(orderedEquals(after)));
    for (final bytes in [before, after]) {
      final pixels = image.decodePng(bytes)!;
      expect(pixels.width, 160);
      expect(pixels.height, 80);
      expect(bytes.length, lessThan(10000));
    }
  });
  Map<String, dynamic> checkpoint() => {
        'version': 1,
        'project_ref': businessStagingRef,
        'run_id': run,
        for (final field in [
          'request_id',
          'owner_message_id',
          'provider_message_id',
          'before_upload_id',
          'after_upload_id',
          'property_id',
          'service_type_id',
        ])
          field: run,
        'start': '2026-10-25T02:00:00.000Z',
        'end': '2026-10-25T04:00:00.000Z',
        'amount': 80,
        'basis': 'hourly',
      };
  test('checkpoint validated before any booking write', () {
    expect(
      () => requireBusinessState(checkpoint(), fixture()),
      returnsNormally,
    );
  });
  for (final key in [
    'version',
    'project_ref',
    'run_id',
    'amount',
    'basis',
    'request_id',
    'owner_message_id',
    'provider_message_id',
    'before_upload_id',
    'after_upload_id',
  ]) {
    test('reject mismatched checkpoint $key', () {
      final s = checkpoint()..[key] = 'wrong';
      expect(() => requireBusinessState(s, fixture()), throwsStateError);
    });
  }
  test('no changed duration', () {
    final s = checkpoint()..['end'] = '2026-10-25T05:00:00.000Z';
    expect(() => requireBusinessState(s, fixture()), throwsStateError);
  });
}
