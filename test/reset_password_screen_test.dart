import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/screens/reset_password_screen.dart';
import 'package:rental_app_demo/screens/workspace_login_screen.dart';
import 'package:rental_app_demo/services/backend/auth_session_storage.dart';
import 'package:rental_app_demo/services/backend/password_recovery_controller.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'support/auth_storage_fixtures.dart';

/// UI-only fake; actual PKCE/HTTP/session behavior has separate SDK tests.
class _UiRecovery extends PasswordRecoveryController {
  _UiRecovery()
      : super(
          client: SupabaseClient(
            'https://fixture.invalid',
            'sb_publishable_fixture',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
          storage: AuthSessionStorage(
            protectedStore: MemoryAuthStore(),
            legacyStore: MemoryAuthStore(),
            projectRef: testAuthProject,
            environment: 'staging',
          ),
          redirect: null,
        );
  RecoveryPhase simulated = RecoveryPhase.ready;
  int submitted = 0, exits = 0;
  Completer<void>? hold;
  @override
  RecoveryPhase get phase => simulated;
  void show(RecoveryPhase phase) {
    simulated = phase;
    notifyListeners();
  }

  @override
  Future<void> updatePassword(String password) async {
    if (phase != RecoveryPhase.ready) return;
    submitted++;
    show(RecoveryPhase.saving);
    await hold?.future;
    show(RecoveryPhase.complete);
  }

  @override
  Future<void> leave() async {
    exits++;
    show(RecoveryPhase.idle);
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var directory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${directory.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      final parent = directory.parent;
      if (parent.path == directory.path) {
        throw StateError('Flutter fonts not found.');
      }
      directory = parent;
    }
    await (FontLoader('MaterialIcons')
          ..addFont(
            File(
              '${directory.path}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
        .load();
  });
  late _UiRecovery recovery;
  setUp(() => recovery = _UiRecovery());
  tearDown(() async {
    recovery.dispose();
    await recovery.client.dispose();
  });

  Future<void> open(
    WidgetTester tester, {
    bool dark = false,
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ResetPasswordScreen(controller: recovery),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'requires length and matching passwords, with accessible visibility buttons',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(recovery.submitted, 0);
    await tester.enterText(
      find.byKey(const ValueKey('recovery-password')),
      'SYNTHETIC_NEW_PASSWORD',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm')),
      'SYNTHETIC_DIFFERENT_PASSWORD',
    );
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(recovery.submitted, 0);
    await tester.tap(find.byTooltip('Show new password'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('recovery-password')),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isFalse,
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm')),
      'SYNTHETIC_NEW_PASSWORD',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(recovery.submitted, 1);
    expect(find.text('Password updated'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets(
      'submission disables buttons; passwords are cleared on terminal result',
      (tester) async {
    await open(tester);
    recovery.hold = Completer<void>();
    await tester.enterText(
      find.byKey(const ValueKey('recovery-password')),
      'SYNTHETIC_NEW_PASSWORD',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm')),
      'SYNTHETIC_NEW_PASSWORD',
    );
    final input = tester
        .widget<TextFormField>(find.byKey(const ValueKey('recovery-password')))
        .controller!;
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    recovery.hold!.complete();
    await tester.pumpAndSettle();
    expect(input.text, isEmpty);
    expect(recovery.submitted, 1);
  });
  testWidgets(
      'invalid and uncertain outcomes do not expose a password submission',
      (tester) async {
    await open(tester);
    for (final phase in [
      RecoveryPhase.invalid,
      RecoveryPhase.uncertain,
      RecoveryPhase.cleanupRequired,
    ]) {
      recovery.show(phase);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Update password'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('small phone and enlarged text remain scrollable in dark theme',
      (tester) async {
    await open(tester, dark: true, width: 320, scale: 1.5);
    await tester.ensureVisible(find.text('Cancel and return to login'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets('reset form 320px/200% keyboard validation dark=$dark',
        (tester) async {
      await open(tester, dark: dark, width: 320, scale: 2);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('recovery-password')));
      await tester.enterText(find.byKey(const ValueKey('recovery-password')),
          'SYNTHETIC_PASSWORD_ONLY');
      await tester
          .ensureVisible(find.byKey(const ValueKey('recovery-confirm')));
      await tester.enterText(find.byKey(const ValueKey('recovery-confirm')),
          'SYNTHETIC_DIFFERENT_VALUE');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Update password'));
      await tester.tap(find.text('Update password'));
      await tester.pumpAndSettle();
      expect(recovery.submitted, 0);
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final phase in [
        RecoveryPhase.invalid,
        RecoveryPhase.uncertain,
        RecoveryPhase.cleanupRequired,
        RecoveryPhase.complete
      ]) {
        recovery.show(phase);
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets(
      'recovery callback closes a pushed route and cannot restore the workspace',
      (tester) async {
    recovery.show(RecoveryPhase.idle);
    final backend =
        SupabaseBackendProvider(recovery.client, recovery: recovery);
    await tester.pumpWidget(RentalAppDemo(backend: backend));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('welcome-log-in')));
    await tester.tap(find.byKey(const Key('welcome-log-in')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(WorkspaceLoginScreen));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('PRIVATE_ROUTE_FIXTURE')),
      ),
    );
    await tester.pumpAndSettle();
    recovery.show(RecoveryPhase.ready);
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE_ROUTE_FIXTURE'), findsNothing);
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.byType(WorkspaceLoginScreen), findsNothing);
    await tester.tap(find.text('Cancel and return to login'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('welcome-log-in')));
    await tester.tap(find.byKey(const Key('welcome-log-in')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceLoginScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final dark in [false, true]) {
    testWidgets('new password ${dark ? 'dark' : 'light'} preview',
        (tester) async {
      await open(tester, dark: dark);
      await expectLater(
        find.byType(ResetPasswordScreen),
        matchesGoldenFile(
          'goldens/reset_password_${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }
}
