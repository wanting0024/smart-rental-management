import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/password_recovery_screen.dart';
import 'package:rental_app_demo/screens/workspace_login_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('local recovery page is honest about email delivery',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const PasswordRecoveryScreen(initialEmail: 'owner@example.com'),
    ));

    expect(find.text('Password recovery'), findsOneWidget);
    expect(find.textContaining('Connect to your workspace to request a password recovery email.'),
        findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton))
            .onPressed,
        isNull);
  });

  testWidgets('valid email sends a link and shows a neutral confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? sentTo;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: PasswordRecoveryScreen(
        sendResetEmail: (email) async => sentTo = email,
      ),
    ));

    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Email address is required'), findsOneWidget);
    expect(sentTo, isNull);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(sentTo, isNull);

    await tester.enterText(find.byType(TextFormField), 'provider@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(sentTo, 'provider@example.com');
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('If an account exists for provider@example.com'),
        findsOneWidget);

    await tester.tap(find.text('Use a different email'));
    await tester.pumpAndSettle();
    expect(find.text('Send reset link'), findsOneWidget);
  });

  testWidgets('email sending failure stays on the form for retry',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: PasswordRecoveryScreen(
        initialEmail: 'provider@example.com',
        sendResetEmail: (_) async => throw StateError('network unavailable'),
      ),
    ));

    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Could not send the link right now. Please try again.'),
        findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
    expect(find.text('Send reset link'), findsOneWidget);
  });

  testWidgets('forgot-password link opens recovery and pre-fills login email',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = SupabaseBackendProvider(SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ));
    await tester.pumpWidget(UserSessionAccess(
      session: UserSession(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: WorkspaceLoginScreen(backend: backend),
      ),
    ));

    await tester.enterText(
        find.byType(TextFormField).first, 'owner@example.com');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Password recovery'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'owner@example.com');

    await tester.tap(find.text('Back to login').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
