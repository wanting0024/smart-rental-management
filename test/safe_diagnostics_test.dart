import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/safe_diagnostics.dart';
import 'package:rental_app_demo/services/backend/auth_failure_message.dart';
import 'package:rental_app_demo/services/backend/auth_session_storage.dart';
import 'package:rental_app_demo/widgets/safe_error_boundary.dart';

class _NeverRenderError implements Exception {
  @override
  String toString() => throw StateError('Raw error must not be rendered');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'framework/async boundaries and ErrorWidget never expose raw errors or stacks',
      () {
    final oldFramework = FlutterError.onError;
    final oldPlatform = PlatformDispatcher.instance.onError;
    final oldBuilder = ErrorWidget.builder;
    final oldPrint = debugPrint;
    final lines = <String>[];
    try {
      debugPrint = (message, {wrapWidth}) {
        if (message != null) lines.add(message);
      };
      installSafeErrorBoundaries();
      FlutterError.onError!(FlutterErrorDetails(
          exception: _NeverRenderError(),
          stack: StackTrace.fromString('PRIVATE_STACK'),),);
      expect(
          PlatformDispatcher.instance.onError!(
              _NeverRenderError(), StackTrace.fromString('PRIVATE_STACK'),),
          isTrue,);
      expect(
          ErrorWidget.builder(
              FlutterErrorDetails(exception: _NeverRenderError()),),
          isA<SafeErrorPlaceholder>(),);
      expect(lines, hasLength(2));
      expect(lines.join(), isNot(contains('PRIVATE')));
    } finally {
      FlutterError.onError = oldFramework;
      PlatformDispatcher.instance.onError = oldPlatform;
      ErrorWidget.builder = oldBuilder;
      debugPrint = oldPrint;
    }
  });
  test(
      'allow-list logger never renders exception payload, stack, URL or user data',
      () {
    final lines = <String>[];
    final diagnostics = SafeDiagnostics(enabled: true, sink: lines.add);
    diagnostics.record(SafeOperation.messageSend, _NeverRenderError());
    diagnostics.record(
        SafeOperation.evidenceUpload,
        const PostgrestException(
            message: 'PRIVATE_CHAT_AND_PHOTO_URL',
            details: 'PRIVATE_ADDRESS',
            hint: 'PRIVATE_TOKEN',
            code: '42501',),);
    expect(lines, hasLength(2));
    expect(lines[0], '[app] ref=000001 operation=messageSend category=unknown');
    expect(lines[1],
        '[app] ref=000002 operation=evidenceUpload category=permission',);
    expect(lines.join(), isNot(contains('PRIVATE')));
  });
  test('release-disabled diagnostics do not inspect errors or call sinks', () {
    var called = false;
    SafeDiagnostics(enabled: false, sink: (_) => called = true)
        .record(SafeOperation.signIn, _NeverRenderError());
    expect(called, isFalse);
  });
  test('sink failure does not throw or fall back to raw logging', () {
    expect(
        () => SafeDiagnostics(
                enabled: true, sink: (_) => throw StateError('unavailable'),)
            .record(SafeOperation.signOut, _NeverRenderError()),
        returnsNormally,);
  });
  test('typed failures map only to fixed categories', () {
    expect(SafeDiagnostics.category(TimeoutException('private')),
        SafeFailureCategory.connection,);
    expect(SafeDiagnostics.category(const SocketException('private')),
        SafeFailureCategory.connection,);
    expect(SafeDiagnostics.category(const AuthStorageException()),
        SafeFailureCategory.secureStorage,);
    expect(SafeDiagnostics.category(const AuthException('private')),
        SafeFailureCategory.authentication,);
    expect(
        SafeDiagnostics.category(
            const PostgrestException(message: 'private', code: '23514'),),
        SafeFailureCategory.conflict,);
  });
  test('Auth UI messages do not render server messages or exception strings',
      () {
    expect(
        AuthFailureMessage.forOperation(_NeverRenderError(),
            registering: false,),
        isNot(contains('Raw')),);
    expect(
        AuthFailureMessage.forOperation(
            const AuthException('PRIVATE_TOKEN', code: 'invalid_credentials'),
            registering: false,),
        'Email or password is incorrect. Check both and try again.',);
    expect(
        AuthFailureMessage.forOperation(
            const AuthException('PRIVATE_TOKEN', code: 'unrecognised'),
            registering: true,),
        isNot(contains('PRIVATE_TOKEN')),);
    expect(
        AuthFailureMessage.forOperation(const AccountRoleMismatch(),
            registering: false,),
        contains('other role'),);
  });
  testWidgets(
      'safe error placeholder is readable without exposing exception content',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SafeErrorPlaceholder()));
    expect(find.textContaining('Reopen the app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
      'connected initialization explicitly disables SDK default raw console logging',
      () {
    final source = File('lib/services/backend/supabase_backend_provider.dart')
        .readAsStringSync();
    expect(source, contains('debug: false'));
  }, testOn: 'vm',);
}
