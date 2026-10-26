import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/backend_config.dart';

void main() {
  const project = 'aaaaaaaaaaaaaaaaaaaa';
  BackendConfig staging({String? url, String? key, String? ref}) =>
      BackendConfig(
        url: url ?? 'https://$project.supabase.co',
        publishableKey: key ?? 'sb_publishable_test',
        environmentName: 'staging',
        projectRef: ref ?? project,
        recoveryRedirectUrl: 'https://app.fixture.invalid/auth/recovery',
      );

  test('no configuration keeps the local preview available', () {
    const config = BackendConfig(url: '', publishableKey: '');
    expect(config.isConfigured, isFalse);
    expect(config.validate, returnsNormally);
  });

  test('partial or insecure configuration fails before app startup', () {
    expect(
      () => staging(key: '').validate(),
      throwsFormatException,
    );
    expect(
      () => staging(url: 'http://$project.supabase.co').validate(),
      throwsFormatException,
    );
    expect(
      () => staging(key: 'sb_secret_x').validate(),
      throwsFormatException,
    );
  });

  test('complete publishable configuration is accepted', () {
    final config = staging();
    expect(config.isConfigured, isTrue);
    expect(config.validate, returnsNormally);
  });

  test('legacy service-role JWT is rejected even without sb_secret prefix', () {
    final payload = base64Url.encode(utf8.encode('{"role":"service_role"}'));
    final config = staging(key: 'eyJ.$payload.signature');
    expect(config.validate, throwsFormatException);
  });

  test('connected configuration cannot silently default to local preview', () {
    const config = BackendConfig(
      url: 'https://$project.supabase.co',
      publishableKey: 'sb_publishable_test',
    );
    expect(config.validate, throwsFormatException);
  });

  test('unknown environment and leftover local flags fail closed', () {
    expect(
      () => const BackendConfig(
        url: '',
        publishableKey: '',
        environmentName: 'stagng',
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => const BackendConfig(
        url: '',
        publishableKey: '',
        projectRef: project,
      ).validate(),
      throwsFormatException,
    );
  });

  test('endpoint must exactly match pinned hosted project without URL extras',
      () {
    for (final url in [
      'https://bbbbbbbbbbbbbbbbbbbb.supabase.co',
      'https://$project.supabase.co.attacker.example',
      'https://user:password@$project.supabase.co',
      'https://$project.supabase.co:8443',
      'https://$project.supabase.co/rest/v1',
      'https://$project.supabase.co?preview=staging',
      'https://$project.supabase.co#staging',
    ]) {
      expect(
        () => staging(url: url).validate(),
        throwsFormatException,
        reason: 'Reject unexpected endpoint: $url',
      );
    }
    expect(() => staging(ref: '').validate(), throwsFormatException);
  });

  test('local release and production development builds are blocked', () {
    const local = BackendConfig(url: '', publishableKey: '');
    expect(
      () => local.validateForBuild(isRelease: true),
      throwsFormatException,
    );
    expect(() => local.validateForBuild(isRelease: false), returnsNormally);
    const production = BackendConfig(
      url: 'https://$project.supabase.co',
      publishableKey: 'sb_publishable_test',
      environmentName: 'production',
      projectRef: project,
      allowProduction: true,
      recoveryRedirectUrl: 'https://app.fixture.invalid/auth/recovery',
    );
    expect(
      () => production.validateForBuild(isRelease: false),
      throwsFormatException,
    );
    expect(() => production.validateForBuild(isRelease: true), returnsNormally);
    expect(() => staging().validateForBuild(isRelease: true), returnsNormally);
  });

  test('production opt-in is required and cannot be copied into staging', () {
    for (final env in ['staging', 'production']) {
      final config = BackendConfig(
        url: 'https://$project.supabase.co',
        publishableKey: 'sb_publishable_test',
        environmentName: env,
        projectRef: project,
        allowProduction: env == 'staging',
      );
      expect(config.validate, throwsFormatException);
    }
  });

  test('server must confirm both environment and project before login', () {
    final config = staging();
    for (final marker in [
      null,
      [],
      {},
      {'environment': 'unassigned', 'project_ref': null},
      {'environment': 'production', 'project_ref': project},
      {'environment': 'staging', 'project_ref': 'bbbbbbbbbbbbbbbbbbbb'},
    ]) {
      expect(
        () => config.verifyServerEnvironment(marker),
        throwsFormatException,
      );
    }
    expect(
      () => config.verifyServerEnvironment(
        {'environment': 'staging', 'project_ref': project},
      ),
      returnsNormally,
    );
  });
}
