@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:rental_app_demo/services/backend/recovery_web_callback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String original;
  setUp(() => original = web.window.location.href);
  tearDown(() => web.window.history.replaceState(null, '', original));
  test(
      'captures code once, scrubs query and fragment without creating history entry',
      () {
    final count = web.window.history.length;
    web.window.history
        .replaceState(null, '', '/auth/recovery?code=SYNTHETIC_CODE');
    final callback = takeRecoveryWebCallback();
    expect(callback?.queryParameters['code'], 'SYNTHETIC_CODE');
    expect(web.window.location.pathname, '/');
    expect(web.window.location.search, isEmpty);
    expect(web.window.location.hash, isEmpty);
    expect(web.window.history.length, count);
    expect(takeRecoveryWebCallback(), isNull);
  });
  test('error callbacks and implicit fragments are scrubbed for safe rejection',
      () {
    web.window.history
        .replaceState(null, '', '/auth/recovery#error=SYNTHETIC_ERROR');
    expect(takeRecoveryWebCallback()?.fragment, 'error=SYNTHETIC_ERROR');
    expect(web.window.location.hash, isEmpty);
  });
  test('does not alter ordinary application pages', () {
    web.window.history.replaceState(null, '', '/?preview=provider');
    expect(takeRecoveryWebCallback(), isNull);
    expect(web.window.location.search, '?preview=provider');
  });
  test('removes an Auth-only query instead of retaining the original query', () {
    web.window.history.replaceState(null, '', '/?code=SYNTHETIC_SIGNUP_CODE');
    expect(takeRecoveryWebCallback(), isNull);
    expect(web.window.location.search, isEmpty);
  });
  test('other Auth callbacks are scrubbed but never become recovery', () {
    web.window.history.replaceState(null, '', '/?code=SYNTHETIC_SIGNUP_CODE&preview=provider');
    expect(takeRecoveryWebCallback(), isNull);
    expect(web.window.location.search, '?preview=provider');
  });
}
