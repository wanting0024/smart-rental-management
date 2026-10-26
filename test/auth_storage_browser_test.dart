@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/auth_storage_web.dart';
import 'package:rental_app_demo/services/backend/auth_session_storage.dart';
import 'support/auth_storage_fixtures.dart';

void main() {
  late BrowserAuthStore tab, local;
  late AuthSessionStorage storage;
  setUp(() async {
    tab = BrowserAuthStore(sessionOnly: true);
    local = BrowserAuthStore(sessionOnly: false);
    storage = AuthSessionStorage(
      protectedStore: tab,
      legacyStore: local,
      projectRef: testAuthProject,
      environment: 'staging',
    );
    for (final key in [
      storage.sessionKey,
      storage.pkceKey,
      storage.migrationKey,
      storage.installationKey,
      storage.logoutKey,
      storage.legacySessionKey,
      AuthSessionStorage.legacyPkceKey,
    ]) {
      await tab.delete(key);
      await local.delete(key);
    }
  });
  tearDown(() async {
    await storage.clearForSignOut();
    await tab.delete(storage.migrationKey);
    await local.delete(storage.installationKey);
    await local.delete(storage.logoutKey);
  });
  test('real browser moves legacy localStorage session into sessionStorage',
      () async {
    final value = syntheticSession();
    await local.write(storage.legacySessionKey, value);
    await storage.initialize();
    expect(await tab.read(storage.sessionKey), value);
    expect(await local.read(storage.legacySessionKey), isNull);
    expect(await local.read(storage.sessionKey), isNull);
  });
  test(
      'cleared tab state does not restore a session from persistent browser metadata',
      () async {
    await storage.initialize();
    await storage.persistSession(syntheticSession());
    await tab.delete(storage.sessionKey);
    await tab.delete(storage.migrationKey);
    final next = AuthSessionStorage(
        protectedStore: tab,
        legacyStore: local,
        projectRef: testAuthProject,
        environment: 'staging',);
    await next.initialize();
    expect(await next.accessToken(), isNull);
  });
  test(
      'browser logout clears session and PKCE without writing credentials to localStorage',
      () async {
    await storage.initialize();
    await storage.persistSession(syntheticSession());
    await storage.writePkce('test-browser-verifier');
    await storage.clearForSignOut();
    expect(await tab.read(storage.sessionKey), isNull);
    expect(await tab.read(storage.pkceKey), isNull);
    expect(await local.read(storage.logoutKey), '1');
  });
}
