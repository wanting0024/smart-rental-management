import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/screens/owner_home_screen.dart';
import 'package:rental_app_demo/screens/provider_inbox_screen.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/workspace_binding.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/property_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/services/review_store.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

// Offline rendered-widget QA. These captures are not browser/real-user evidence.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(
      {'coachmark_seen_provider_inbox_v1': true}));
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      if (sdk.parent.path == sdk.path)
        throw StateError('Cannot locate Flutter font assets.');
      sdk = sdk.parent;
    }
    for (final font in [
      ('Roboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf')
    ]) {
      final bytes = await File(
              '${sdk.path}/bin/cache/artifacts/material_fonts/${font.$2}')
          .readAsBytes();
      await (FontLoader(font.$1)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });
  for (final provider in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
          'original ${provider ? 'provider' : 'owner'} empty UI ${dark ? 'dark' : 'light'}',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final feed = CursorFeed<Map<String, dynamic>>(
            active: false,
            loadPage: (_) async => const CursorPage(items: []),
            idOf: (row) => row['booking_id'] as String,
            compare: (_, __) => 0);
        final binding = WorkspaceBinding(
            feed: feed,
            provider: provider,
            loadOverview: () async => provider
                ? <String, dynamic>{
                    'approval_status': 'pending',
                    'completed_job_count': 0,
                    'rating_average': null
                  }
                : const OwnerDashboardSnapshot(
                    propertyCount: 0,
                    pendingCount: 0,
                    activeCount: 0,
                    completedCount: 0));
        binding.setActive(true);
        await binding.refresh();
        final session = UserSession()
          ..signIn(
              email: 'fixture@example.invalid',
              displayName: provider ? 'Test Provider' : 'Test Owner',
              role: provider ? UserRole.provider : UserRole.owner);
        final bookingStore = BookingStore();
        final providerStore = ProviderStore();
        final propertyStore = PropertyStore();
        final reviewStore = ReviewStore();
        final messageStore = MessageStore();
        final boundary = GlobalKey();
        await tester.pumpWidget(AppProviders(
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            onToggleTheme: () {},
            bookingStore: bookingStore,
            providerStore: providerStore,
            propertyStore: propertyStore,
            reviewStore: reviewStore,
            messageStore: messageStore,
            child: UserSessionAccess(
                session: session,
                child: RepaintBoundary(
                    key: boundary,
                    child: MaterialApp(
                        debugShowCheckedModeBanner: false,
                        theme: dark ? AppTheme.dark() : AppTheme.light(),
                        home: provider
                            ? ProviderInboxScreen(binding: binding)
                            : OwnerHomeScreen(binding: binding))))));
        await tester.pumpAndSettle();
        expect(find.text(provider ? 'Provider Inbox' : 'Owner Dashboard'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = Directory('output/workspace-ui');
          await output.create(recursive: true);
          await File(
                  '${output.path}/${provider ? 'provider' : 'owner'}-${dark ? 'dark' : 'light'}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
        binding.dispose();
        session.dispose();
        bookingStore.dispose();
        providerStore.dispose();
        propertyStore.dispose();
        reviewStore.dispose();
        messageStore.dispose();
      });
    }
  }
}
