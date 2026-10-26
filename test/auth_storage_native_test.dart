import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental_app_demo/services/backend/auth_storage_native.dart';
import 'package:rental_app_demo/services/backend/backend_config.dart';
import 'package:rental_app_demo/screens/backend_setup_required_screen.dart';
import 'support/auth_storage_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const config = BackendConfig(
    url: 'https://$testAuthProject.supabase.co',
    publishableKey: 'sb_publishable_test',
    environmentName: 'staging',
    projectRef: testAuthProject,
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
      'native factory uses verified secure adapter and keeps preferences free of tokens',
      () async {
    final s = createPlatformAuthStorage(config,
        isCurrentSession: (_) => true, hasCurrentSession: () => false,);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(s.legacySessionKey, syntheticSession());
    await s.initialize();
    expect(await s.hasAccessToken(), isTrue);
    expect(prefs.getString(s.legacySessionKey), isNull);
    expect(
        prefs.getKeys().every(
            (key) => !prefs.get(key).toString().contains('access_token'),),
        isTrue,);
    await s.clearForSignOut();
    expect(await s.hasAccessToken(), isFalse);
  });
  test(
      'vault options disable automatic reset, keychain sync and transferable accessibility',
      () {
    final s = createPlatformAuthStorage(config,
        isCurrentSession: (_) => true, hasCurrentSession: () => false,);
    final vault = (s.protectedStore as NativeProtectedStore).storage;
    expect(vault.aOptions.toMap()['resetOnError'], 'false');
    expect(vault.aOptions.toMap()['storageNamespace'],
        'rental_auth_staging_$testAuthProject',);
    expect(vault.iOptions.toMap()['accessibility'], 'unlocked_this_device');
    expect(vault.iOptions.toMap()['synchronizable'], 'false');
  });
  test(
      'Android backup and transfer rules exclude private app state; iOS configs reference entitlement',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('@xml/auth_data_extraction_rules'));
    final rules =
        File('android/app/src/main/res/xml/auth_data_extraction_rules.xml')
            .readAsStringSync();
    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<device-transfer>'));
    expect(RegExp('domain="sharedpref"').allMatches(rules), hasLength(2));
    for (final name in ['Debug', 'Release']) {
      expect(File('ios/Flutter/$name.xcconfig').readAsStringSync(),
          contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'),);
    }
  });
  testWidgets(
      'vault startup failure explains retry without exposing errors or offering bypass',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
        home: BackendSetupRequiredScreen(
            storageUnavailable: true, onRetry: () => retried = true,),),);
    expect(find.text('Secure sign-in storage unavailable'), findsOneWidget);
    expect(find.textContaining('Unlock your device'), findsOneWidget);
    await tester.tap(find.text('Try secure storage again'));
    expect(retried, isTrue);
    expect(find.text('Continue anyway'), findsNothing);
  });
}
