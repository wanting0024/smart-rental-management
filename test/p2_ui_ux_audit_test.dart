import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/owner_uat_steps.dart';
import 'package:rental_app_demo/screens/owner_home_screen.dart';
import 'package:rental_app_demo/screens/provider_inbox_screen.dart';
import 'package:rental_app_demo/screens/provider_edit_profile_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_evidence_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_history_sheet.dart';
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_request_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_review_screen.dart';
import 'package:rental_app_demo/screens/connected_provider_setup_screen.dart';
import 'package:rental_app_demo/screens/password_recovery_screen.dart';
import 'package:rental_app_demo/screens/workspace_owner_profile.dart';
import 'package:rental_app_demo/screens/workspace_login_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/screens/owner_workspace_dashboard.dart';
import 'package:rental_app_demo/features/availability/domain/provider_setup.dart';
import 'package:rental_app_demo/services/backend/supabase_evidence_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/provider_profile_snapshot.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';
import 'package:rental_app_demo/services/backend/workspace_binding.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/cancellation_reason_sheet.dart';
import 'package:rental_app_demo/widgets/filter_sheet.dart';
import 'package:rental_app_demo/widgets/unsaved_changes_guard.dart';
import 'support/profile_fixture.dart';

// Offline widget rendering/interaction, never hosted accounts or manual UAT.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget app(Widget screen, {required bool dark, double scale = 2}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: screen,
    );

Future<void> capture(
    WidgetTester tester, GlobalKey boundary, String name) async {
  await tester.runAsync(() async {
    final image = await (boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary)
        .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('output/p2-ui').create(recursive: true);
    await File('output/p2-ui/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      if (sdk.parent.path == sdk.path)
        throw StateError('Flutter fonts missing');
      sdk = sdk.parent;
    }
    for (final font in [
      ('Roboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf'),
    ]) {
      final data = await File(
              '${sdk.path}/bin/cache/artifacts/material_fonts/${font.$2}')
          .readAsBytes();
      await (FontLoader(font.$1)
            ..addFont(Future.value(ByteData.sublistView(data))))
          .load();
    }
  });
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  for (final dark in [false, true]) {
    testWidgets('Owner navigation dark=$dark full labels and touch targets',
        (tester) async {
      phone(tester);
      final semantics = tester.ensureSemantics();
      String? selected;
      await tester.pumpWidget(app(
          Scaffold(
              bottomNavigationBar: OwnerWorkspaceNav(
                  activeId: 'home', onChange: (id) => selected = id)),
          dark: dark));
      await tester.pumpAndSettle();
      for (final label in [
        'Home',
        'Properties',
        'Providers',
        'Bookings',
        'Profile'
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      final propertyNode =
          tester.getSemantics(find.bySemanticsLabel('Properties'));
      expect(propertyNode.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          true);
      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(propertyNode.id, ui.SemanticsAction.tap);
      expect(selected, 'properties');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets(
        'Owner editor dark=$dark keyboard validation/busy/uncertain draft',
        (tester) async {
      phone(tester);
      var writes = 0;
      final save = Completer<void>();
      await tester.pumpWidget(app(
          OwnerProfileEditor(
              row: const {
                'display_name': 'Synthetic Owner',
                'email': 'synthetic@rental-test.invalid',
                'contact_number': '+60123456789'
              },
              canSave: () => true,
              save: (_) {
                writes++;
                return save.future;
              }),
          dark: dark));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.text('Enter a name of 2–60 characters'), findsOneWidget);
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.enterText(
          find.byType(TextFormField).first, 'Updated synthetic Owner');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(writes, 1);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      save.completeError(StateError('PRIVATE DATABASE ERROR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PRIVATE DATABASE ERROR'), findsNothing);
      expect(find.textContaining('Your entries are kept'), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Updated synthetic Owner');
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Provider editor dark=$dark keyboard discard preserves draft',
        (tester) async {
      phone(tester);
      final snapshot = profileReport();
      await tester.pumpWidget(app(
          Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProviderEditProfileScreen(
                                  provider: snapshot.presentation,
                                  snapshot: snapshot,
                                  canEditConnected: () => true,
                                  onSaveConnected: (_, __) async => snapshot,
                                  onReloadConnected: () async => snapshot,
                                  onManageAvailability: () async {}))),
                      child: const Text('Open editor')))),
          dark: dark));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('profile-Display name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Synthetic changed draft');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Keep editing'));
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(name).controller!.text,
          'Synthetic changed draft');
    });

    testWidgets(
        'cancellation dark=$dark inline required reason even without optional comment',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(app(
          const Scaffold(
              body: CancellationReasonSheet(
                  bookingId: 'synthetic', allowComment: false)),
          dark: dark));
      await tester.ensureVisible(find.text('Cancel booking'));
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();
      expect(find.text('Please pick a reason'), findsOneWidget);
      await tester.ensureVisible(find.text('Other (tell us more)'));
      await tester.tap(find.text('Other (tell us more)'));
      await tester.pumpAndSettle();
      expect(find.text('Describe your reason (required)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Please pick a reason'), findsNothing);
      await tester.ensureVisible(find.text('Cancel booking'));
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();
      expect(find.text('Please describe the reason.'), findsOneWidget);
      final cancel = tester.widget<FilledButton>(
          find.byWidgetPredicate((w) => w is FilledButton));
      final theme = dark ? AppTheme.dark() : AppTheme.light();
      expect(
          cancel.style!.backgroundColor!.resolve({}), theme.colorScheme.error);
      expect(cancel.style!.foregroundColor!.resolve({}),
          theme.colorScheme.onError);
      expect(tester.takeException(), isNull);
    });

    for (final provider in [false, true]) {
      testWidgets(
          'registration provider=$provider dark=$dark keyboard/200% validation',
          (tester) async {
        phone(tester);
        final client = (await tester.runAsync(() async => SupabaseClient(
            'https://fixture.invalid', 'sb_publishable_fixture',
            authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
        addTearDown(() => tester.runAsync(client.dispose));
        final session = UserSession();
        addTearDown(session.dispose);
        await tester.pumpWidget(UserSessionAccess(
            session: session,
            child: app(
                WorkspaceLoginScreen(backend: SupabaseBackendProvider(client)),
                dark: dark)));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Register owner account'));
        await tester.tap(find.text('Register owner account'));
        await tester.pumpAndSettle();
        if (provider) {
          await tester.ensureVisible(find.text('Service Provider'));
          await tester.tap(find.text('Service Provider'));
          await tester.pumpAndSettle();
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final create = find.widgetWithText(FilledButton, 'Continue');
        await tester.scrollUntilVisible(create, 180,
            scrollable: find.byType(Scrollable).first, maxScrolls: 50);
        await tester.tap(create);
        await tester.pumpAndSettle();
        expect(find.text('Email address is required'), findsOneWidget);
        await advanceRegistration(tester);
        final finish = find.widgetWithText(FilledButton, 'Create account');
        await tester.ensureVisible(finish);
        await tester.tap(finish);
        await tester.pumpAndSettle();
        expect(find.text('Contact number is required'), findsOneWidget);
        expect(session.isLoggedIn, false);
        expect(tester.takeException(), isNull);
      });
    }

    for (final page in [
      'request',
      'availability',
      'evidence',
      'review',
      'history',
      'chat'
    ]) {
      for (final state in ['loading', 'empty', 'error']) {
        testWidgets('$page $state dark=$dark 320px/200% short viewport',
            (tester) async {
          phone(tester);
          final hold = Completer<void>();
          var failed = state == 'error';
          var reads = 0;
          Future<T> load<T>(T empty) async {
            reads++;
            if (state == 'loading') await hold.future;
            if (failed) throw StateError('PRIVATE TEST FAILURE');
            return empty;
          }

          const setup = ProviderSetupData(
              services: [],
              selectedServiceIds: {},
              slots: [],
              unavailableDates: {});
          final Widget screen = switch (page) {
            'request' => ConnectedBookingRequestScreen(
                loadProperties: () => load(<Map<String, dynamic>>[]),
                loadServiceTypes: () async => [],
                findEligible: (
                        {required propertyId,
                        required serviceTypeId,
                        required start,
                        required end}) async =>
                    [],
                createPending: (
                        {required clientRequestId,
                        required providerId,
                        required propertyId,
                        required serviceTypeId,
                        required start,
                        required end,
                        required expectedAmount,
                        required expectedBasis,
                        required instructions}) async =>
                    throw StateError('No writes'),
                findCreatedBooking: (_) async => null),
            'availability' => ConnectedProviderSetupScreen(
                load: () => load(setup),
                saveServices: (_) async {},
                addSlot: (_, __, ___) async {},
                removeSlot: (_) async {},
                addUnavailableDate: (_) async {},
                removeUnavailableDate: (_) async {}),
            'evidence' => ConnectedBookingEvidenceScreen(
                bookingId: 'test',
                isProvider: true,
                status: 'In Progress',
                load: (_) => load<BookingEvidenceRecord?>(null),
                download: (_) async => Uint8List(0),
                upload: (_, __, ___, ____, _____) async =>
                    throw StateError('No upload'),
                saveRemarks: (_, __) async {},
                complete: (_) async {},
                checkStatus: (_) async => 'In Progress'),
            'review' => ConnectedBookingReviewScreen(
                bookingId: 'test',
                isOwner: true,
                load: (_) => load(null),
                save: (_, __, ___) async => throw StateError('No writes')),
            'history' => Scaffold(
                body: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConnectedBookingHistorySheet(
                        bookingId: 'test',
                        load: (_) => load(<Map<String, dynamic>>[])))),
            _ => ConnectedBookingMessagesScreen(
                bookingId: 'test',
                currentUserId: 'test-owner',
                isProvider: false,
                messages: () => Stream.fromFuture(load(<BookingMessage>[])),
                bookingStatus: () => Stream.value('Accepted'),
                send: (_, __) async {},
                wasSent: (_, __) async => false),
          };
          await tester.pumpWidget(app(screen, dark: dark));
          if (state == 'loading') {
            await tester.pump(const Duration(milliseconds: 100));
          } else {
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(find.textContaining('PRIVATE TEST FAILURE'), findsNothing);
          if (state == 'error') {
            final retry = find.widgetWithText(OutlinedButton, 'Retry');
            final anyRetry = retry.evaluate().isNotEmpty
                ? retry
                : find.textContaining('Retry').first;
            await tester.ensureVisible(anyRetry);
            await tester.pumpAndSettle();
            final before = reads;
            failed = false;
            await tester.tap(anyRetry);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(reads, greaterThan(before));
            expect(find.textContaining('Could not'), findsNothing);
            expect(find.textContaining('PRIVATE TEST FAILURE'), findsNothing);
          }
          await tester.pumpWidget(const SizedBox());
          hold.complete();
          await tester.pump();
        });
      }
    }

    testWidgets('recovery dark=$dark keyboard / 200% error and neutral success',
        (tester) async {
      phone(tester);
      var fail = true;
      var sends = 0;
      await tester
          .pumpWidget(app(PasswordRecoveryScreen(sendResetEmail: (_) async {
        sends++;
        if (fail) throw StateError('PRIVATE MAIL ERROR');
      }), dark: dark));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(
          find.byType(TextFormField), 'synthetic@rental-test.invalid');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.ancestor(
          of: find.text('Send reset link'),
          matching: find.byWidgetPredicate((w) => w is FilledButton));
      final textRect = tester.getRect(find.text('Send reset link'));
      final buttonRect = tester.getRect(button);
      expect(buttonRect.top, lessThanOrEqualTo(textRect.top));
      expect(buttonRect.bottom, greaterThanOrEqualTo(textRect.bottom));
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(sends, 1);
      expect(find.textContaining('PRIVATE MAIL ERROR'), findsNothing);
      expect(find.text('Could not send the link right now. Please try again.'),
          findsOneWidget);
      fail = false;
      await tester.ensureVisible(find.text('Send reset link'));
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(sends, 2);
      expect(find.text('Check your email'), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final provider in [false, true]) {
      for (final state in ['loading', 'empty', 'error', 'ready']) {
        testWidgets('home provider=$provider dark=$dark 320px/200% $state',
            (tester) async {
          phone(tester);
          final pending = Completer<CursorPage<Map<String, dynamic>>>();
          final binding = WorkspaceBinding(
            provider: provider,
            feed: CursorFeed<Map<String, dynamic>>(
              active: false,
              loadPage: (_) async {
                if (state == 'loading') return pending.future;
                if (state == 'error') throw StateError('PRIVATE NETWORK ERROR');
                return CursorPage(
                    items: state == 'empty'
                        ? []
                        : [
                            {
                              'booking_id': 'synthetic-booking',
                              'current_status': 'In Progress',
                              'unit_name':
                                  'A very long synthetic rental unit name',
                              'building_name':
                                  'A particularly long synthetic building',
                              'service_name':
                                  'Deep cleaning with additional requirements',
                              'requested_start_at': '2030-01-01T02:00:00Z',
                              'requested_end_at': '2030-01-01T04:00:00Z',
                            }
                          ]);
              },
              idOf: (r) => r['booking_id'] as String,
              compare: (_, __) => 0,
            ),
            loadOverview: () async => provider
                ? <String, dynamic>{
                    'approval_status': 'pending',
                    'completed_job_count': 100,
                    'rating_average': 4.75,
                  }
                : const OwnerDashboardSnapshot(
                    propertyCount: 15,
                    pendingCount: 41,
                    activeCount: 22,
                    completedCount: 100),
          );
          binding.setActive(true);
          final session = UserSession()
            ..signIn(
                email: 'synthetic@rental-test.invalid',
                displayName: 'Syntheticlongfirstname Test Account',
                role: provider ? UserRole.provider : UserRole.owner);
          final boundary = GlobalKey();
          await tester.pumpWidget(UserSessionAccess(
            session: session,
            child: RepaintBoundary(
              key: boundary,
              child: app(
                provider
                    ? Scaffold(
                        body: ProviderInboxScreen(
                            binding: binding, showShell: false))
                    : OwnerHomeScreen(binding: binding),
                dark: dark,
              ),
            ),
          ));
          if (state == 'loading') {
            await tester.pump(const Duration(milliseconds: 100));
          } else {
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          expect(find.textContaining('PRIVATE NETWORK ERROR'), findsNothing);
          // Exercise lazy content, not merely the initial viewport.
          if (provider && state == 'ready') {
            final active = find.descendant(
                of: find.byType(TabBar),
                matching: find.textContaining('Active'));
            await tester.scrollUntilVisible(active.hitTestable(), 180,
                scrollable: find
                    .descendant(
                        of: find.byType(NestedScrollView),
                        matching: find.byType(Scrollable))
                    .first);
            await tester.tap(active);
            await tester.pumpAndSettle();
          }
          final scroll = provider
              ? find
                  .descendant(
                      of: find.byType(NestedScrollView),
                      matching: find.byType(Scrollable))
                  .first
              : find.byType(Scrollable).first;
          for (var i = 0; i < 12; i++) {
            await tester.drag(scroll, const Offset(0, -240));
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          }
          if (!provider && state == 'ready') {
            expect(find.byTooltip('Messages').hitTestable(), findsOneWidget);
            await capture(
                tester, boundary, 'owner-actions-${dark ? 'dark' : 'light'}');
          }
          await tester.pumpWidget(const SizedBox());
          if (!pending.isCompleted)
            pending.complete(const CursorPage(items: []));
          binding.dispose();
          session.dispose();
          await tester.pump();
        });
      }

      testWidgets('cancellation provider=$provider dark=$dark 200% / keyboard',
          (tester) async {
        phone(tester);
        Map<String, String>? result;
        await tester.pumpWidget(app(
            Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () async {
                          result = await showModalBottomSheet<
                                  Map<String, String>>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => CancellationReasonSheet(
                                  bookingId:
                                      '12345678-1234-4234-8234-123456789abc',
                                  forProvider: provider));
                        },
                        child: const Text('Open cancellation')))),
            dark: dark));
        await tester.tap(find.text('Open cancellation'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final other = find.text(provider ? 'Other' : 'Other (tell us more)');
        await tester.ensureVisible(other);
        await tester.tap(other);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(
            find.byType(TextField), 'Synthetic reason only.');
        // Finish the editable's queued caret reveal before simulating a scroll.
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cancel booking'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getBottomRight(find.text('Cancel booking')).dy,
            lessThanOrEqualTo(288));
        await tester.tap(find.text('Cancel booking'));
        await tester.pumpAndSettle();
        expect(result?['reason_id'], 'other');
        expect(result?['comment'], 'Synthetic reason only.');
      });
    }

    testWidgets('unsaved guard dark=$dark short keyboard / 200% keeps draft',
        (tester) async {
      phone(tester);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(
          Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                              builder: (_) => UnsavedChangesGuard(
                                  dirty: () => controller.text.isNotEmpty,
                                  busy: () => false,
                                  child: Scaffold(
                                      appBar: AppBar(
                                          title: const Text('Test editor')),
                                      body:
                                          TextField(controller: controller))))),
                      child: const Text('Open editor')))),
          dark: dark));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Synthetic unsaved draft');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Keep editing'));
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Synthetic unsaved draft');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Discard'));
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
    });

    testWidgets('filter dark=$dark 200% sort and apply remain reachable',
        (tester) async {
      phone(tester);
      FilterResult? result;
      await tester.pumpWidget(app(
          Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () async {
                        result = await showModalBottomSheet<FilterResult>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const FilterSheet(
                                    initial: FilterResult.empty,
                                    properties: [
                                      'A particularly long synthetic property name'
                                    ]));
                      },
                      child: const Text('Open filter')))),
          dark: dark));
      await tester.tap(find.text('Open filter'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Newest first'));
      await tester.tap(find.text('Newest first'));
      await tester.ensureVisible(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result?.sortMode, SortMode.newest);
    });

    testWidgets(
        'Provider editor dark=$dark keyboard / 200% validation and save',
        (tester) async {
      phone(tester);
      final snapshot = profileReport();
      var saves = 0;
      final pending = Completer<ProviderProfileSnapshot>();
      await tester.pumpWidget(app(
          ProviderEditProfileScreen(
              provider: snapshot.presentation,
              snapshot: snapshot,
              onSaveConnected: (_, __) async {
                saves++;
                return pending.future;
              },
              onReloadConnected: () async => snapshot,
              canEditConnected: () => true,
              onManageAvailability: () async {}),
          dark: dark));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      final name = find.byKey(const ValueKey('profile-Display name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, '');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Updated synthetic Provider');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(saves, 1);
      expect(tester.takeException(), isNull);
      pending.complete(snapshot);
      await tester.pumpAndSettle();
    });
  }
}
