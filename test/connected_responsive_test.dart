import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/features/availability/domain/provider_setup.dart';
import 'package:rental_app_demo/screens/connected_booking_history_sheet.dart';
import 'package:rental_app_demo/screens/connected_booking_evidence_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_request_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_review_screen.dart';
import 'package:rental_app_demo/screens/connected_property_form_screen.dart';
import 'package:rental_app_demo/screens/connected_provider_setup_screen.dart';
import 'package:rental_app_demo/screens/workspace_login_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_evidence_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_review_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/connected_workspace_components.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdkDirectory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdkDirectory.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      final parent = sdkDirectory.parent;
      if (parent.path == sdkDirectory.path) {
        throw StateError('Could not locate Flutter SDK fonts.');
      }
      sdkDirectory = parent;
    }
    Future<ByteData> localFont(String name) async => ByteData.sublistView(
          await File(
                  '${sdkDirectory.path}/bin/cache/artifacts/material_fonts/$name')
              .readAsBytes(),
        );
    await (FontLoader('Roboto')..addFont(localFont('roboto-regular.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(localFont('materialicons-regular.otf')))
        .load();
  });

  void phone(WidgetTester tester, {double width = 320, double height = 640}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home, {double scale = 2, bool dark = false}) => MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      );

  testWidgets(
      'long booking content and actions fit a narrow phone at 200% text',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(app(Scaffold(
      body: ListView(children: [
        ConnectedBookingCard(
          row: const {
            'current_status': 'Accepted',
            'service_name': 'Deep cleaning with additional requirements',
            'requested_start_at': '2026-10-28T02:00:00Z',
            'requested_end_at': '2026-10-28T06:00:00Z',
            'property_address':
                'A long rental unit address in Kuala Lumpur, Malaysia',
          },
          propertyName:
              'Unit A-12, A particularly long building name in Kuala Lumpur',
          isProvider: true,
          busy: false,
          onAction: (_) {},
          onHistory: () {},
          onMessages: () {},
          onEvidence: () {},
          onReview: () {},
          onCancel: () {},
        ),
      ]),
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Messages'));
    expect(tester.takeException(), isNull);
    expect(find.text('Messages'), findsOneWidget);
  });

  testWidgets('Owner request controls fit a narrow phone at 200% text',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(app(ConnectedBookingRequestScreen(
      loadProperties: () async => [
        {
          'property_id': 'unit-1',
          'unit_name': 'Unit A-12',
          'building_name': 'A particularly long building name',
        }
      ],
      loadServiceTypes: () async => [
        {'service_type_id': 'type-1', 'name': 'Deep cleaning'}
      ],
      findEligible: ({
        required propertyId,
        required serviceTypeId,
        required start,
        required end,
      }) async =>
          [],
      createPending: ({
        required clientRequestId,
        required providerId,
        required propertyId,
        required serviceTypeId,
        required start,
        required end,
        required expectedAmount,
        required expectedBasis,
        required instructions,
      }) async =>
          throw UnimplementedError(),
      findCreatedBooking: (_) async => null,
    )));
    await tester.pumpAndSettle();
    for (final key in ['request-unit', 'request-service']) {
      final field = find.byKey(Key(key));
      await tester.scrollUntilVisible(field, 180,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenuItem<String>).last);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(find.text('Continue to date & time'), 160, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Continue to date & time'));
    await tester.tap(find.text('Continue to date & time'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start time'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    expect(find.text('Select time'), findsNWidgets(2));
  });

  testWidgets(
      'Owner property form remains usable with keyboard on a narrow phone',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(app(
        ConnectedPropertyFormScreen(
          onSave: (_) async {},
        ),
        scale: 1.5));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Size (sqft)'), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(TextFormField).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Add property'), findsOneWidget);
    expect(tester.getBottomRight(find.text('Add property')).dy,
        lessThanOrEqualTo(360));
  });

  testWidgets('property time controls fit at 200% text', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(ConnectedPropertyFormScreen(
      onSave: (_) async {},
    )));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('window-start')), 180,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Provider slot dialog fits a short phone at 200% text',
      (tester) async {
    phone(tester, height: 568);
    await tester.pumpWidget(app(
        ConnectedProviderSetupScreen(
          load: () async => const ProviderSetupData(
            services: [
              ProviderServiceItem(id: 'type-1', name: 'Deep cleaning')
            ],
            selectedServiceIds: {'type-1'},
            slots: [],
            unavailableDates: {},
          ),
          saveServices: (_) async {},
          addSlot: (_, __, ___) async {},
          removeSlot: (_) async {},
          addUnavailableDate: (_) async {},
          removeUnavailableDate: (_) async {},
        ),
        dark: true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Monday'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Add working slot').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add working slot').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Keep unchanged'), findsOneWidget);
  });

  testWidgets('booking chat keeps composer above keyboard with long text',
      (tester) async {
    phone(tester);
    var sends = 0;
    await tester.pumpWidget(app(
        ConnectedBookingMessagesScreen(
          bookingId: 'booking-1',
          currentUserId: 'owner-1',
          isProvider: false,
          messages: () => Stream.value([
            BookingMessage(
              id: 'message-1',
              bookingId: 'booking-1',
              senderUserId: 'provider-1',
              body: 'Please send access instructions for the rental unit. ' * 6,
              createdAt: DateTime.utc(2026, 10, 22, 9),
            ),
          ]),
          bookingStatus: () => Stream.value('Accepted'),
          send: (_, __) async => sends++,
          wasSent: (_, __) async => false,
        ),
        scale: 1.5,
        dark: true));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byType(TextField), 'Please use the side gate.');
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.byTooltip('Send message')).dy,
        lessThanOrEqualTo(360));
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(sends, 1);
  });

  testWidgets('history error stays readable in a short sheet with large text',
      (tester) async {
    phone(tester, height: 568);
    await tester.pumpWidget(app(Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ConnectedBookingHistorySheet(
          bookingId: 'booking-1',
          load: (_) async => throw StateError('offline'),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('completion remarks and action remain reachable above keyboard',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(app(
        ConnectedBookingEvidenceScreen(
          bookingId: 'booking-1',
          isProvider: true,
          status: 'In Progress',
          load: (_) async => const BookingEvidenceRecord(
            bookingId: 'booking-1',
            remarks: '',
          ),
          download: (_) async => Uint8List(0),
          upload: (_, __, ___, ____, _____) async => 'booking-1/photo.jpg',
          saveRemarks: (_, __) async {},
          complete: (_) async {},
          checkStatus: (_) async => 'In Progress',
        ),
        scale: 1.5));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextField), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField),
        'Kitchen and bathrooms cleaned. All requested areas checked. ' * 4);
    await tester.scrollUntilVisible(find.text('Mark as Completed'), 140,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Mark as Completed').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Owner can submit a review with keyboard and 200% text',
      (tester) async {
    phone(tester, width: 390, height: 844);
    var saves = 0;
    await tester.pumpWidget(app(
        ConnectedBookingReviewScreen(
          bookingId: 'booking-1',
          isOwner: true,
          load: (_) async => null,
          save: (id, rating, comment) async {
            saves++;
            return BookingReviewRecord(
              bookingId: id,
              rating: rating,
              comment: comment,
            );
          },
        ),
        dark: true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byIcon(Icons.star_outline_rounded).last, 140,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byIcon(Icons.star_outline_rounded).last);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TextField), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField),
        'The provider followed the instructions and shared clear photos.');
    await tester.scrollUntilVisible(find.text('Submit rating'), 160,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login actions grow with 200% text on a narrow phone',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const WorkspaceLoginScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Register owner account'), 180,
        scrollable: find.byType(Scrollable).first);
    final action = find.ancestor(
      of: find.text('Register owner account'),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.getSize(action).height, greaterThan(48));
    expect(find.text('Register owner account').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
