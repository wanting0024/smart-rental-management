import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/workspace_login_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/owner_uat_steps.dart';

void main() {
  testWidgets(
      'connected registration requests report-required owner/provider fields',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = SupabaseBackendProvider(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    await tester.pumpWidget(UserSessionAccess(
      session: UserSession(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: WorkspaceLoginScreen(backend: backend),
      ),
    ));

    final email =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(email.controller!.text, isEmpty);
    await tester.tap(find.text('Register owner account'));
    await tester.pumpAndSettle();
    await advanceRegistration(tester);
    expect(find.text('Contact number'), findsWidgets);
    expect(find.text('Service area'), findsNothing);

    await tester.tap(find.text('Edit account details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Service Provider'));
    await tester.pumpAndSettle();
    await advanceRegistration(tester);
    await tester.ensureVisible(find.text('Service area'));
    expect(find.text('Service area'), findsOneWidget);
    expect(find.text('Service origin address'), findsOneWidget);
    expect(find.text('Hourly rate (RM) · optional'), findsOneWidget);
    expect(find.text('8-hour daily rate (RM) · optional'), findsOneWidget);
  });

  testWidgets('switching to registration clears login errors', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = SupabaseBackendProvider(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    await tester.pumpWidget(UserSessionAccess(
      session: UserSession(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: WorkspaceLoginScreen(backend: backend),
      ),
    ));

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Email address is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    final messenger =
        tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger));
    messenger.showSnackBar(
      const SnackBar(content: Text('Invalid login credentials')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Invalid login credentials'), findsOneWidget);

    await tester.ensureVisible(find.text('Register owner account'));
    await tester.tap(find.text('Register owner account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Email address is required'), findsNothing);
    expect(find.text('Password is required'), findsNothing);
    expect(find.text('Invalid login credentials'), findsNothing);
  });

  testWidgets('provider registration explains and validates contact and area',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = SupabaseBackendProvider(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    await tester.pumpWidget(UserSessionAccess(
      session: UserSession(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: WorkspaceLoginScreen(backend: backend),
      ),
    ));

    await tester.tap(find.text('Service Provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register provider account'));
    await tester.pumpAndSettle();
    await advanceRegistration(tester);
    expect(
        find.text('Malaysia: 012-345 6789 or +60 12-345 6789'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(
        find.text('Used to estimate route distance to jobs.'), findsOneWidget);
    expect(
        find.text('Your price per hour in Malaysian ringgit.'), findsOneWidget);

    final contact = find.widgetWithText(TextFormField, '+60 12 345 6789');
    await tester.ensureVisible(contact);
    await tester.enterText(contact, '123');
    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter a Malaysian number, e.g. 012-345 6789'),
        findsOneWidget);
    expect(find.text('Select a service area'), findsOneWidget);

    await tester.enterText(contact, '+60 12-345 6789');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuala Lumpur').last);
    await tester.pumpAndSettle();
    expect(find.text('Kuala Lumpur'), findsOneWidget);
    expect(
        find.text('Enter a Malaysian number, e.g. 012-345 6789'), findsNothing);
    expect(find.text('Select a service area'), findsNothing);
  });

  testWidgets('choosing an area does not flag untouched registration fields',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = SupabaseBackendProvider(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    await tester.pumpWidget(UserSessionAccess(
      session: UserSession(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: WorkspaceLoginScreen(backend: backend),
      ),
    ));

    await tester.tap(find.text('Service Provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register provider account'));
    await tester.pumpAndSettle();
    await advanceRegistration(tester);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kuala Lumpur').last);
    await tester.pumpAndSettle();

    expect(find.text('Kuala Lumpur'), findsOneWidget);
    expect(find.text('Email address is required'), findsNothing);
    expect(find.text('Password is required'), findsNothing);
    expect(find.text('Contact number is required'), findsNothing);
    expect(find.text('Service origin is required'), findsNothing);
    expect(find.text('Enter a rate greater than RM 0'), findsNothing);
  });
}
