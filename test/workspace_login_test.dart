import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/workspace_login_screen.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  testWidgets('provider role uses the matching demo account and signs in',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = UserSession();
    await tester.pumpWidget(UserSessionAccess(
      session: session,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const WorkspaceLoginScreen(),
      ),
    ));

    expect(find.text('Register owner account'), findsOneWidget);
    await tester.tap(find.text('Service Provider'));
    await tester.pump();
    expect(find.text('Register provider account'), findsOneWidget);
    final email =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(email.controller!.text, 'provider@example.com');

    await tester.tap(find.text('Log in'));
    await tester.pump(const Duration(milliseconds: 650));
    expect(session.isLoggedIn, isTrue);
    expect(session.role, UserRole.provider);
    expect(tester.takeException(), isNull);
  });
}
