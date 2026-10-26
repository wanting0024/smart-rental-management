import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/password_recovery_controller.dart';
import 'package:rental_app_demo/services/backend/supabase_auth_repository.dart';
import 'package:rental_app_demo/services/backend/auth_session_storage.dart';
import 'support/recovery_sdk_fixture.dart';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _NetworkBinding();
  late RecoverySdkFixture fixture;
  setUp(() async {
    fixture = RecoverySdkFixture();
    await fixture.start();
  });
  tearDown(() => fixture.dispose());

  test('PKCE email pins redirect and valid callback opens only recovery',
      () async {
    expect(fixture.recovery.blocksWorkspace, isFalse);
    await fixture.ready();
    expect(
      fixture.requestedRedirect.toString(),
      'https://app.fixture.invalid/auth/recovery',
    );
    expect(fixture.recovery.phase, RecoveryPhase.ready);
    expect(fixture.recovery.blocksWorkspace, isTrue);
    expect(await fixture.storage.hasRecoveryIntent(), isTrue);
    final repository = SupabaseAuthRepository(
      Supabase.instance.client,
      recovery: fixture.recovery,
    );
    expect(await repository.currentIdentity(), isNull);
    await expectLater(
      repository.signIn('test-user@fixture.invalid', 'SYNTHETIC_PASSWORD'),
      throwsA(isA<AuthException>()),
    );
  });
  test('untrusted callback never exchanges a code or changes routing',
      () async {
    await fixture.recovery.requestEmail('test-user@fixture.invalid');
    for (final url in [
      'https://attacker.invalid/auth/recovery?code=SYNTHETIC_CODE',
      'https://app.fixture.invalid.attacker.invalid/auth/recovery?code=SYNTHETIC_CODE',
      'https://app.fixture.invalid/other?code=SYNTHETIC_CODE',
    ]) {
      await fixture.recovery.handleLink(Uri.parse(url));
    }
    expect(fixture.exchanges, 0);
    expect(fixture.recovery.blocksWorkspace, isFalse);
  });
  test('missing verifier cannot establish recovery even with recovery type',
      () async {
    await fixture.recovery
        .handleLink(Uri.parse('${fixture.link()}&type=recovery'));
    expect(fixture.exchanges, 0);
    expect(fixture.recovery.phase, RecoveryPhase.invalid);
    expect(Supabase.instance.client.auth.currentSession, isNull);
  });
  test('signup verifier is not accepted as recovery proof', () async {
    await fixture.storage.prepareForAuthentication();
    await fixture.storage.writePkce('a' * 64);
    await fixture.recovery.handleLink(fixture.link());
    expect(fixture.exchanges, 0);
    expect(fixture.recovery.phase, RecoveryPhase.invalid);
  });
  test('expired/used server code clears temporary session and intent',
      () async {
    fixture.failExchange = true;
    await fixture.ready();
    expect(fixture.recovery.phase, RecoveryPhase.invalid);
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(await fixture.storage.hasRecoveryIntent(), isFalse);
    expect(await fixture.storage.readPkce(), isNull);
  });
  test(
      'duplicate callback makes one exchange; durable gate precedes server work',
      () async {
    await fixture.recovery.requestEmail('test-user@fixture.invalid');
    fixture.holdExchange = Completer<void>();
    final first = fixture.recovery.handleLink(fixture.link());
    expect(fixture.recovery.blocksWorkspace, isTrue);
    while (fixture.exchanges == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(await fixture.storage.hasRecoveryIntent(), isTrue);
    await fixture.recovery.handleLink(fixture.link());
    fixture.holdExchange!.complete();
    await first;
    expect(fixture.exchanges, 1);
    expect(fixture.recovery.phase, RecoveryPhase.ready);
  });
  test('successful password change clears Auth and does not auto-login',
      () async {
    await fixture.ready();
    await fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
    expect(fixture.updates, 1);
    expect(fixture.lastUpdate?['password'], 'SYNTHETIC_NEW_PASSWORD');
    expect(fixture.recovery.phase, RecoveryPhase.complete);
    expect(fixture.recovery.blocksWorkspace, isTrue);
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(await fixture.storage.hasAccessToken(), isFalse);
    expect(await fixture.storage.hasRecoveryIntent(), isFalse);
    await fixture.recovery.leave();
    expect(fixture.recovery.blocksWorkspace, isFalse);
  });
  test('weak/same password allows a safe corrected submission', () async {
    await fixture.ready();
    for (final code in ['weak_password', 'same_password']) {
      fixture.updateError = code;
      await fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
      expect(fixture.recovery.phase, RecoveryPhase.ready);
      expect(fixture.recovery.message, isNot(contains('SYNTHETIC_PRIVATE')));
    }
    fixture.updateError = null;
    await fixture.recovery.updatePassword('SYNTHETIC_BETTER_PASSWORD');
    expect(fixture.recovery.phase, RecoveryPhase.complete);
  });
  test('unknown server outcome asks user to sign in, not blindly resubmit',
      () async {
    await fixture.ready();
    fixture.updateError = 'outage';
    await fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
    expect(fixture.recovery.phase, RecoveryPhase.uncertain);
    expect(Supabase.instance.client.auth.currentSession, isNull);
    await fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
    expect(fixture.updates, 1);
  });
  test('expired recovery session never claims password success', () async {
    await fixture.ready();
    fixture.updateError = 'expired';
    await fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
    expect(fixture.recovery.phase, RecoveryPhase.invalid);
  });
  test('lost HTTP response after submitting update is an uncertain outcome',
      () async {
    await fixture.ready();
    fixture.dropUpdateResponse = true;
    await fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
    expect(fixture.updates, 1);
    expect(fixture.recovery.phase, RecoveryPhase.uncertain);
    expect(fixture.recovery.blocksWorkspace, isTrue);
    expect(Supabase.instance.client.auth.currentSession, isNull);
  });
  test('double update and cancellation while submitting do not race', () async {
    await fixture.ready();
    fixture.holdUpdate = Completer<void>();
    final first = fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
    while (fixture.updates == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
    await fixture.recovery.leave();
    expect(fixture.recovery.phase, RecoveryPhase.saving);
    fixture.holdUpdate!.complete();
    await first;
    expect(fixture.updates, 1);
  });
  test('vault cleanup failure keeps gate; retry clears it after unlock',
      () async {
    await fixture.ready();
    fixture.vault.failDelete = fixture.storage.sessionKey;
    await fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
    expect(fixture.recovery.phase, RecoveryPhase.cleanupRequired);
    expect(await fixture.storage.hasRecoveryIntent(), isTrue);
    fixture.vault.failDelete = null;
    await fixture.recovery.retryCleanup();
    expect(fixture.recovery.phase, RecoveryPhase.complete);
    expect(await fixture.storage.hasRecoveryIntent(), isFalse);
  });
  test('remote logout outage cannot resurrect local recovery credentials',
      () async {
    await fixture.ready();
    fixture.failLogout = true;
    await fixture.recovery.updatePassword('SYNTHETIC_NEW_PASSWORD');
    expect(fixture.recovery.phase, RecoveryPhase.complete);
    expect(await fixture.storage.hasAccessToken(), isFalse);
    expect(Supabase.instance.client.auth.currentSession, isNull);
  });
  test(
      'regular authentication already in flight settles before recovery exchange',
      () async {
    await fixture.recovery.requestEmail('test-user@fixture.invalid');
    final hold = Completer<void>();
    final regular = fixture.recovery.regularAuthentication(() => hold.future);
    final callback = fixture.recovery.handleLink(fixture.link());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(fixture.exchanges, 0);
    expect(fixture.recovery.blocksWorkspace, isTrue);
    hold.complete();
    await regular;
    await callback;
    expect(fixture.recovery.phase, RecoveryPhase.ready);
  });
  test('cancelling recovery clears verifier and remains at ordinary login',
      () async {
    await fixture.ready();
    await fixture.recovery.leave();
    expect(fixture.recovery.phase, RecoveryPhase.idle);
    expect(await fixture.storage.hasAccessToken(), isFalse);
    await fixture.recovery.handleLink(fixture.link());
    expect(fixture.exchanges, 1); // Consumed code is never sent twice.
  });
  test('restarted storage refuses to restore an interrupted recovery session',
      () async {
    await fixture.ready();
    // Simulate an app restart with the same persistent stores, not UI memory.
    final restarted = AuthSessionStorage(
      protectedStore: fixture.vault,
      legacyStore: fixture.legacy,
      projectRef: fixture.storage.projectRef,
      environment: 'staging',
    );
    expect(await restarted.accessToken(), isNull);
    expect(await restarted.discardInterruptedRecovery(), isTrue);
    expect(fixture.vault.values[restarted.sessionKey], isNull);
    expect(fixture.vault.values[restarted.pkceKey], isNull);
    expect(await restarted.hasRecoveryIntent(), isTrue);
    final controller = PasswordRecoveryController(
      client: Supabase.instance.client,
      storage: restarted,
      redirect: fixture.recovery.redirect,
      interrupted: true,
    );
    expect(controller.phase, RecoveryPhase.invalid);
    expect(controller.blocksWorkspace, isTrue);
    controller.dispose();
  });
  test('recovery marker cannot be cleared while a recovery session is active',
      () async {
    await fixture.ready();
    await expectLater(
      fixture.storage.clearRecoveryIntent(),
      throwsA(isA<AuthStorageException>()),
    );
    expect(await fixture.storage.hasRecoveryIntent(), isTrue);
  });
  test('unsolicited recovery callback cannot log out a normally signed-in user',
      () async {
    final repository = SupabaseAuthRepository(Supabase.instance.client,
        persistence: fixture.storage, recovery: fixture.recovery,);
    await repository.signIn('test-user@fixture.invalid', 'SYNTHETIC_PASSWORD');
    final exchangesBefore = fixture.exchanges;
    await fixture.recovery.handleLink(fixture.link());
    expect(fixture.exchanges, exchangesBefore);
    expect(fixture.recovery.blocksWorkspace, isFalse);
    expect(Supabase.instance.client.auth.currentSession, isNotNull);
    expect(await fixture.storage.hasRecoveryIntent(), isFalse);
  });
  test('email failure never opens the password form or normal workspace',
      () async {
    fixture.failRecover = true;
    await expectLater(
      fixture.recovery.requestEmail('test-user@fixture.invalid'),
      throwsA(isA<AuthException>()),
    );
    expect(fixture.recovery.phase, RecoveryPhase.idle);
    expect(fixture.recoveries, 1);
    expect(fixture.updates, 0);
  });
}
