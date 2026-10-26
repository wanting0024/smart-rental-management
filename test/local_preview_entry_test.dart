import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final (role, expectedTitle) in [
    (UserRole.owner, 'Owner Dashboard'),
    (UserRole.provider, 'Provider Inbox'),
  ]) {
    testWidgets('local $role preview opens without login', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(RentalAppDemo(localPreviewRole: role));
      await tester.pumpAndSettle();

      expect(find.text(expectedTitle), findsWidgets);
      expect(find.text('Welcome back'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ordinary local launch still requires login', (tester) async {
    await tester.pumpWidget(const RentalAppDemo());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Smart Rental'), findsOneWidget);
    expect(find.text('Owner Dashboard'), findsNothing);
  });

  testWidgets('connected backend ignores local preview role', (tester) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    await tester.pumpWidget(RentalAppDemo(
      backend: SupabaseBackendProvider(client),
      localPreviewRole: UserRole.owner,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Smart Rental'), findsOneWidget);
    expect(find.text('Owner Dashboard'), findsNothing);
    client.dispose();
  });
}
