import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/auth_recovery_redirect.dart';
import 'package:rental_app_demo/services/backend/backend_config.dart';

void main() {
  test('only exact callback target and a single code are accepted', () {
    final redirect =
        AuthRecoveryRedirect('https://app.fixture.invalid/auth/recovery');
    expect(
        redirect.code(Uri.parse(
            'https://app.fixture.invalid/auth/recovery?code=SYNTHETIC_CODE',),),
        'SYNTHETIC_CODE',);
    for (final value in [
      'https://app.fixture.invalid/auth/recovery?code=SYNTHETIC_CODE&code=OTHER_CODE',
      'https://app.fixture.invalid/auth/recovery?code=SYNTHETIC_CODE&redirect_to=https://other.invalid',
      'https://app.fixture.invalid/auth/recovery#access_token=SYNTHETIC_VALUE',
      'https://app.fixture.invalid/auth/recovery?error=access_denied',
      'https://user@app.fixture.invalid/auth/recovery?code=SYNTHETIC_CODE',
      'https://app.fixture.invalid:444/auth/recovery?code=SYNTHETIC_CODE',
      'http://app.fixture.invalid/auth/recovery?code=SYNTHETIC_CODE',
      'https://app.fixture.invalid/auth/recovery/?code=SYNTHETIC_CODE',
    ]) {
      expect(redirect.code(Uri.parse(value)), isNull);
    }
  });
  test('unsafe recovery configuration is rejected rather than repaired', () {
    for (final value in [
      '',
      'https://app.fixture.invalid',
      'http://app.fixture.invalid/auth/recovery',
      'https://user@app.fixture.invalid/auth/recovery',
      'https://app.fixture.invalid/auth/recovery?next=anything',
      'https://app.fixture.invalid/auth/recovery#anything',
      'https://app.fixture.invalid:444/auth/recovery',
      'smartrental://auth/recovery',
    ]) {
      expect(() => AuthRecoveryRedirect(value), throwsFormatException);
    }
  });
  test('loopback and app scheme are deliberate development options only', () {
    for (final value in [
      'http://127.0.0.1:7390/auth/recovery',
      'smartrental://auth/recovery',
    ]) {
      expect(() => AuthRecoveryRedirect(value, allowDevelopment: true),
          returnsNormally,);
      expect(() => AuthRecoveryRedirect(value), throwsFormatException);
    }
  });
  test('release builds require HTTPS recovery even in staging', () {
    BackendConfig config(String value) => BackendConfig(
        url: 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
        publishableKey: 'sb_publishable_fixture',
        projectRef: 'aaaaaaaaaaaaaaaaaaaa',
        environmentName: 'staging',
        recoveryRedirectUrl: value,);
    for (final value in [
      '',
      'smartrental://auth/recovery',
      'http://localhost:7390/auth/recovery',
    ]) {
      expect(() => config(value).validateForBuild(isRelease: true),
          throwsFormatException,);
    }
    expect(
        () => config('https://app.fixture.invalid/auth/recovery')
            .validateForBuild(isRelease: true),
        returnsNormally,);
  });
}
