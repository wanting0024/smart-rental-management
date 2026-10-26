import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/auth_session_storage.dart';
import 'package:rental_app_demo/services/backend/supabase_auth_repository.dart';
import 'package:rental_app_demo/services/backend/password_recovery_controller.dart';
import 'package:rental_app_demo/services/backend/auth_recovery_redirect.dart';
import 'support/auth_storage_fixtures.dart';

class _SdkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _SdkBinding();
  late HttpServer server;
  late MemoryAuthStore vault, legacy;
  late AuthSessionStorage storage;
  late SupabaseAuthRepository repository;
  late bool failRemoteLogout;
  Future<void> initialize() async {
    await Supabase.initialize(
      url: 'http://${server.address.host}:${server.port}',
      publishableKey: 'SYNTHETIC_LOCAL_TEST_KEY',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: storage,
        pkceAsyncStorage: ProtectedPkceStorage(storage),
      ),
    );
    repository =
        SupabaseAuthRepository(Supabase.instance.client, persistence: storage);
  }

  setUp(() async {
    failRemoteLogout = false;
    vault = MemoryAuthStore();
    legacy = MemoryAuthStore();
    storage = AuthSessionStorage(
      protectedStore: vault,
      legacyStore: legacy,
      projectRef: testAuthProject,
      environment: 'staging',
      isCurrentSession: (raw) => authStorageSessionMatches(
        raw,
        Supabase.instance.client.auth.currentSession?.accessToken ?? '',
      ),
      hasCurrentSession: () =>
          Supabase.instance.client.auth.currentSession != null,
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/auth/v1/token') {
        request.response.write(syntheticSession());
      } else if (request.uri.path == '/rest/v1/user_account') {
        request.response.write(
          jsonEncode([
            {
              'user_id': testAuthUser,
              'email': 'test-user@fixture.invalid',
              'role': 'owner',
            }
          ]),
        );
      } else if (request.uri.path == '/auth/v1/logout') {
        request.response.statusCode = failRemoteLogout ? 500 : 204;
        if (failRemoteLogout) {
          request.response.write('{"msg":"synthetic outage"}');
        }
      } else if (request.uri.path == '/auth/v1/recover') {
        request.response.write('{}');
      } else {
        request.response.statusCode = 404;
        request.response.write('{}');
      }
      await request.response.close();
    });
    await initialize();
  });
  tearDown(() async {
    await Supabase.instance.dispose();
    await server.close(force: true);
  });
  Future<void> signIn() async {
    await repository.signIn(
      'test-user@fixture.invalid',
      'SYNTHETIC_TEST_PASSWORD',
    );
  }

  test('actual SDK sign-in is confirmed in protected store, never preferences',
      () async {
    await signIn();
    expect(await storage.hasAccessToken(), isTrue);
    expect(vault.values[storage.sessionKey], isNotNull);
    expect(
      legacy.values.values.any((value) => value.contains('access_token')),
      isFalse,
    );
  });
  test(
      'SDK restart restores a persisted protected session without a hosted request',
      () async {
    await signIn();
    await Supabase.instance.dispose();
    await initialize();
    expect(Supabase.instance.client.auth.currentUser?.id, testAuthUser);
    expect(await storage.hasAccessToken(), isTrue);
  });
  test(
      'real signedOut event clears storage and cannot be undone by old SDK event',
      () async {
    await signIn();
    final previous = await storage.accessToken();
    await repository.signOut();
    await Future<void>.delayed(Duration.zero);
    await storage.persistSession(previous!);
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(await storage.accessToken(), isNull);
    expect(vault.values[storage.sessionKey], isNull);
    await signIn();
    expect(await storage.hasAccessToken(), isTrue);
  });
  test(
      'persistence failure rejects login and clears SDK memory instead of claiming success',
      () async {
    vault.failWrite = storage.sessionKey;
    await expectLater(signIn(), throwsA(isA<AuthStorageException>()));
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(await storage.accessToken(), isNull);
    expect(legacy.values[storage.logoutKey], '1');
  });
  test(
      'vault deletion failure still emits SDK sign-out and retains recoverable tombstone',
      () async {
    await signIn();
    vault.failDelete = storage.sessionKey;
    final signedOut = Supabase.instance.client.auth.onAuthStateChange
        .firstWhere((state) => state.event == AuthChangeEvent.signedOut);
    await expectLater(
      repository.signOut(),
      throwsA(isA<AuthStorageException>()),
    );
    await signedOut;
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(await storage.accessToken(), isNull);
    expect(legacy.values[storage.logoutKey], '1');
    vault.failDelete = null;
    await storage.clearForSignOut();
  });
  test(
      'remote logout failure does not restore local credentials or claim remote revocation',
      () async {
    await signIn();
    failRemoteLogout = true;
    await expectLater(repository.signOut(), throwsA(isA<AuthException>()));
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(await storage.accessToken(), isNull);
    expect(legacy.values[storage.logoutKey], '1');
  });
  test('actual SDK recovery request stores PKCE only in protected namespace',
      () async {
    final recovery = PasswordRecoveryController(
        client: Supabase.instance.client,
        storage: storage,
        redirect:
            AuthRecoveryRedirect('https://app.fixture.invalid/auth/recovery'),);
    await recovery.requestEmail('test-user@fixture.invalid');
    recovery.dispose();
    expect(vault.values[storage.pkceKey], isNotEmpty);
    expect(legacy.values[AuthSessionStorage.legacyPkceKey], isNull);
  });
}
