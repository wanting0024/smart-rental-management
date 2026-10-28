import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/backend_setup_required_screen.dart';
import 'package:rental_app_demo/services/backend/backend_config.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/backend_environment_frame.dart';

void main() {
  const staging = BackendConfig(
    url: 'https://aaaaaaaaaaaaaaaaaaaa.supabase.co',
    publishableKey: 'sb_publishable_test',
    environmentName: 'staging',
    projectRef: 'aaaaaaaaaaaaaaaaaaaa',
  );

  Widget app({BackendConfig? config, bool connected = false}) => MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => BackendEnvironmentFrame(
          config: config,
          connected: connected,
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Next page')),
                  ),
                ),
                child: const Text('Open details'),
              ),
            ),
          ),
        ),
      );

  testWidgets('local preview is clearly distinguished from saved cloud data',
      (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('OFFLINE WORKSPACE · Changes stay on this device'), findsOneWidget);
  });

  testWidgets('connected staging has no top banner on pages or dialogs',
      (tester) async {
    await tester.pumpWidget(app(config: staging, connected: true));
    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    expect(find.text('Next page'), findsOneWidget);
    expect(find.textContaining('TEST ENVIRONMENT'), findsNothing);
    final context = tester.element(find.text('Next page'));
    showDialog<void>(
      context: context,
      builder: (_) => const AlertDialog(title: Text('Confirm action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm action'), findsOneWidget);
    expect(find.textContaining('TEST ENVIRONMENT'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'production has no test badge and unknown connection is not called staging',
      (tester) async {
    final production = BackendConfig(
      url: staging.url,
      publishableKey: staging.publishableKey,
      environmentName: 'production',
      projectRef: staging.projectRef,
      allowProduction: true,
    );
    await tester.pumpWidget(app(config: production, connected: true));
    expect(find.textContaining('TEST ENVIRONMENT'), findsNothing);
    expect(find.textContaining('LOCAL PREVIEW'), findsNothing);
    await tester.pumpWidget(app(connected: true));
    expect(find.textContaining('UNVERIFIED BACKEND'), findsOneWidget);
  });

  testWidgets(
      'connected staging uses full height at 320px and 200 percent text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: BackendEnvironmentFrame(
            config: staging,
            connected: true,
            child: Scaffold(body: Text('Test workspace')),
          ),
        ),
      ),
    );
    expect(find.textContaining('TEST ENVIRONMENT'), findsNothing);
    expect(tester.getSize(find.byType(Scaffold)).height, 568);
    expect(staging.environment, AppEnvironment.staging);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked startup exposes no login or test bypass',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const BackendSetupRequiredScreen(),
      ),
    );
    expect(find.text('Connection not verified'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Continue anyway'), findsNothing);
  });

  testWidgets('startup connection can be checked again without opening login',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: BackendSetupRequiredScreen(onRetry: () => retries++),
      ),
    );
    await tester.tap(find.text('Check connection again'));
    expect(retries, 1);
    expect(find.byType(TextFormField), findsNothing);
  });
}
