import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/auth_session_storage.dart';
import 'support/auth_storage_fixtures.dart';

void main() {
  late MemoryAuthStore vault, legacy;
  late AuthSessionStorage storage;
  setUp(() {
    vault = MemoryAuthStore();
    legacy = MemoryAuthStore();
    storage = AuthSessionStorage(
      protectedStore: vault,
      legacyStore: legacy,
      projectRef: testAuthProject,
      environment: 'staging',
    );
  });
  AuthSessionStorage restart() => AuthSessionStorage(
        protectedStore: vault,
        legacyStore: legacy,
        projectRef: testAuthProject,
        environment: 'staging',
      );

  test('legacy session moves only after protected write and readback',
      () async {
    final value = syntheticSession();
    legacy.values[storage.legacySessionKey] = value;
    final started = Completer<void>(), release = Completer<void>();
    vault.beforeWrite = (key) async {
      if (key == storage.sessionKey) {
        started.complete();
        await release.future;
      }
    };
    final initialization = storage.initialize();
    await started.future;
    expect(legacy.values[storage.legacySessionKey], value);
    expect(vault.values[storage.migrationKey], isNull);
    release.complete();
    await initialization;
    expect(await storage.accessToken(), value);
    expect(legacy.values[storage.legacySessionKey], isNull);
    expect(vault.values[storage.migrationKey], '1');
  });
  test(
      'missing plugin/locked vault blocks initialization without plaintext fallback',
      () async {
    legacy.values[storage.legacySessionKey] = syntheticSession();
    vault.failRead = storage.migrationKey;
    await expectLater(
        storage.initialize(), throwsA(isA<AuthStorageException>()),);
    expect(legacy.values[storage.legacySessionKey], isNotNull);
  });
  test('failed secure migration retains source and emits sanitized error',
      () async {
    legacy.values[storage.legacySessionKey] = syntheticSession();
    vault.failWrite = storage.sessionKey;
    await expectLater(
      storage.initialize(),
      throwsA(
        predicate(
          (error) =>
              error is AuthStorageException &&
              !error.toString().contains('SYNTHETIC_SECRET'),
        ),
      ),
    );
    expect(legacy.values[storage.legacySessionKey], isNotNull);
    vault.failWrite = null;
    await storage.initialize();
    expect(await storage.hasAccessToken(), isTrue);
  });
  test('silent plugin write failure is detected before deleting plaintext',
      () async {
    legacy.values[storage.legacySessionKey] = syntheticSession();
    vault.dropWrites = true;
    await expectLater(
        storage.initialize(), throwsA(isA<AuthStorageException>()),);
    expect(legacy.values[storage.legacySessionKey], isNotNull);
  });
  test('interrupted legacy deletion retries from verified protected copy',
      () async {
    final value = syntheticSession();
    legacy.values[storage.legacySessionKey] = value;
    legacy.failDelete = storage.legacySessionKey;
    await expectLater(
        storage.initialize(), throwsA(isA<AuthStorageException>()),);
    expect(vault.values[storage.sessionKey], value);
    expect(vault.values[storage.migrationKey], '1');
    legacy.failDelete = null;
    await restart().initialize();
    expect(legacy.values[storage.legacySessionKey], isNull);
  });
  test('completed migration with empty vault never reimports a stale token',
      () async {
    await storage.initialize();
    legacy.values[storage.legacySessionKey] = syntheticSession();
    final next = restart();
    await next.initialize();
    expect(await next.accessToken(), isNull);
    expect(legacy.values[storage.legacySessionKey], isNull);
  });
  test('corrupt protected entry never falls back to older plaintext', () async {
    await storage.initialize();
    vault.values[storage.sessionKey] = 'corrupt';
    legacy.values[storage.legacySessionKey] = syntheticSession();
    final next = restart();
    await next.initialize();
    expect(await next.accessToken(), isNull);
  });
  test('protected entry wins over a different legacy session', () async {
    final value = syntheticSession(suffix: 'new');
    vault.values[storage.sessionKey] = value;
    legacy.values[storage.legacySessionKey] = syntheticSession(suffix: 'old');
    await storage.initialize();
    expect(await storage.accessToken(), value);
  });
  test(
      'malformed, other-project and subject-mismatched legacy sessions are discarded',
      () async {
    final wrongSubject = jsonDecode(syntheticSession()) as Map;
    wrongSubject['user']['id'] = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
    for (final value in [
      'not json',
      syntheticSession(project: 'cccccccccccccccccccc'),
      jsonEncode(wrongSubject),
    ]) {
      final v = MemoryAuthStore(), l = MemoryAuthStore();
      final s = AuthSessionStorage(
          protectedStore: v,
          legacyStore: l,
          projectRef: testAuthProject,
          environment: 'staging',);
      l.values[s.legacySessionKey] = value;
      await s.initialize();
      expect(await s.accessToken(), isNull);
    }
  });
  test('expired well-formed session remains available for server refresh',
      () async {
    final value = syntheticSession(expires: 1);
    legacy.values[storage.legacySessionKey] = value;
    await storage.initialize();
    expect(await storage.accessToken(), value);
  });
  test('concurrent initialization is single-flight', () async {
    await Future.wait(List.generate(20, (_) => storage.initialize()));
    expect(
        vault.operations.where((op) => op == 'write:${storage.migrationKey}'),
        hasLength(1),);
  });
  test('logout removes session and PKCE, preserving unrelated settings',
      () async {
    await storage.initialize();
    await storage.persistSession(syntheticSession());
    await storage.writePkce('test-verifier');
    legacy.values['theme'] = 'dark';
    vault.values['other-project-session'] = 'untouched';
    await storage.clearForSignOut();
    expect(await storage.accessToken(), isNull);
    expect(vault.values[storage.pkceKey], isNull);
    expect(legacy.values[storage.logoutKey], '1');
    expect(legacy.values['theme'], 'dark');
    expect(vault.values['other-project-session'], 'untouched');
  });
  test('queued and late session writes cannot undo logout', () async {
    await storage.initialize();
    final started = Completer<void>(), release = Completer<void>();
    vault.beforeWrite = (key) async {
      if (key == storage.sessionKey) {
        started.complete();
        await release.future;
      }
    };
    final write = storage.persistSession(syntheticSession());
    await started.future;
    final logout = storage.clearForSignOut();
    release.complete();
    await write;
    await logout;
    await storage.persistSession(syntheticSession(suffix: 'late'));
    expect(await storage.accessToken(), isNull);
    expect(vault.values[storage.sessionKey], isNull);
  });
  test(
      'failed logout retains durable intent and cannot restore on next startup',
      () async {
    await storage.initialize();
    await storage.persistSession(syntheticSession());
    vault.failDelete = storage.sessionKey;
    await expectLater(
        storage.clearForSignOut(), throwsA(isA<AuthStorageException>()),);
    expect(legacy.values[storage.logoutKey], '1');
    expect(await storage.accessToken(), isNull);
    // The SDK may still remove PKCE while reporting signedOut; a locked vault
    // must not suppress its in-memory logout notification.
    await storage.removePkce();
    vault.failDelete = null;
    final next = restart();
    await next.initialize();
    expect(await next.accessToken(), isNull);
    expect(vault.values[storage.sessionKey], isNull);
  });
  test('logout intent is recorded even before vault initialization can succeed',
      () async {
    vault.failRead = storage.migrationKey;
    await expectLater(
        storage.clearForSignOut(), throwsA(isA<AuthStorageException>()),);
    expect(legacy.values[storage.logoutKey], '1');
  });
  test(
      'explicit new authentication clears logout intent and allows a new session',
      () async {
    await storage.clearForSignOut();
    await storage.prepareForAuthentication();
    final value = syntheticSession(suffix: 'next');
    await storage.persistSession(value);
    expect(await storage.accessToken(), value);
    expect(legacy.values[storage.logoutKey], isNull);
  });
  test('current SDK token check rejects a stale persistence event', () async {
    final active = syntheticSession(suffix: 'active');
    final s = AuthSessionStorage(
      protectedStore: vault,
      legacyStore: legacy,
      projectRef: testAuthProject,
      environment: 'staging',
      isCurrentSession: (raw) => raw == active,
    );
    await s.initialize();
    await s.persistSession(active);
    await s.persistSession(syntheticSession(suffix: 'stale'));
    expect(await s.accessToken(), active);
  });
  test('late signedOut persistence event cannot erase a newer live SDK session',
      () async {
    final s = AuthSessionStorage(
      protectedStore: vault,
      legacyStore: legacy,
      projectRef: testAuthProject,
      environment: 'staging',
      hasCurrentSession: () => true,
    );
    await s.initialize();
    final value = syntheticSession();
    await s.persistSession(value);
    await s.removePersistedSession();
    expect(await s.accessToken(), value);
    await s.clearForSignOut();
    expect(await s.accessToken(), isNull);
  });
  test('reinstall does not silently reuse surviving Keychain credentials',
      () async {
    await storage.initialize();
    await storage.persistSession(syntheticSession());
    legacy.values.clear();
    final next = restart();
    await next.initialize();
    expect(await next.accessToken(), isNull);
  });
  test(
      'PKCE shares protected namespace and does not import unscoped old verifier',
      () async {
    legacy.values[AuthSessionStorage.legacyPkceKey] = 'old-global-verifier';
    await storage.initialize();
    expect(await storage.readPkce(), isNull);
    final pkce = ProtectedPkceStorage(storage);
    await pkce.setItem(
        key: AuthSessionStorage.legacyPkceKey, value: 'new-test-verifier',);
    expect(await pkce.getItem(key: AuthSessionStorage.legacyPkceKey),
        'new-test-verifier',);
    expect(legacy.values[AuthSessionStorage.legacyPkceKey], isNull);
    await pkce.removeItem(key: AuthSessionStorage.legacyPkceKey);
    expect(await storage.readPkce(), isNull);
    expect(() => pkce.getItem(key: 'unexpected-sdk-key'),
        throwsA(isA<AuthStorageException>()),);
  });
  test('project and environment namespaces are independent', () async {
    final prod = AuthSessionStorage(
      protectedStore: vault,
      legacyStore: legacy,
      projectRef: testAuthProject,
      environment: 'production',
    );
    await storage.initialize();
    await storage.persistSession(syntheticSession());
    await prod.initialize();
    expect(await prod.accessToken(), isNull);
    await prod.clearForSignOut();
    expect(await storage.hasAccessToken(), isTrue);
  });
  test('unknown marker and unsupported environment fail closed', () async {
    vault.values[storage.migrationKey] = 'future-unsupported-format';
    await expectLater(
        storage.initialize(), throwsA(isA<AuthStorageException>()),);
    expect(
      () => AuthSessionStorage(
        protectedStore: vault,
        legacyStore: legacy,
        projectRef: testAuthProject,
        environment: 'local',
      ),
      throwsA(isA<AuthStorageException>()),
    );
  });
  test('SDK session matcher tolerates malformed data without leaking it', () {
    expect(authStorageSessionMatches('not json', 'test'), isFalse);
    final raw = syntheticSession();
    expect(authStorageSessionMatches(raw, jsonDecode(raw)['access_token']),
        isTrue,);
  });
}
