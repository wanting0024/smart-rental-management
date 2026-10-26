import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/features/availability/domain/provider_setup.dart';
import 'package:rental_app_demo/screens/connected_booking_evidence_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_history_sheet.dart';
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_request_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_review_screen.dart';
import 'package:rental_app_demo/screens/connected_provider_setup_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_evidence_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

void main() {
  testWidgets('request options retry performs another read', (tester) async {
    var reads = 0;
    await tester.pumpWidget(_app(ConnectedBookingRequestScreen(
      loadProperties: () async {
        reads++;
        if (reads == 1) throw StateError('offline');
        return const <Map<String, dynamic>>[];
      },
      loadServiceTypes: () async => const <Map<String, dynamic>>[],
      findEligible: ({
        required String propertyId,
        required String serviceTypeId,
        required DateTime start,
        required DateTime end,
      }) async =>
          const <EligibleProviderItem>[],
      createPending: ({
        required String clientRequestId,
        required String providerId,
        required String propertyId,
        required String serviceTypeId,
        required DateTime start,
        required DateTime end,
        required num expectedAmount,
        required String expectedBasis,
        required String instructions,
      }) async =>
          throw StateError('not used'),
      findCreatedBooking: (_) async => null,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Could not prepare your request'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Add a rental unit first'), findsOneWidget);
  });

  testWidgets('provider setup retry replaces failure with empty catalogue',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(_app(ConnectedProviderSetupScreen(
      load: () async {
        reads++;
        if (reads == 1) throw StateError('offline');
        return const ProviderSetupData(
          services: [],
          selectedServiceIds: {},
          slots: [],
          unavailableDates: {},
        );
      },
      saveServices: (_) async {},
      addSlot: (_, __, ___) async {},
      removeSlot: (_) async {},
      addUnavailableDate: (_) async {},
      removeUnavailableDate: (_) async {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Could not load your availability'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('No cleaning services available'), findsOneWidget);
  });

  testWidgets('uncertain availability save requires readback and keeps choice',
      (tester) async {
    var reads = 0;
    var saves = 0;
    await tester.pumpWidget(_app(ConnectedProviderSetupScreen(
      load: () async {
        reads++;
        return const ProviderSetupData(
          services: [
            ProviderServiceItem(id: 'service-1', name: 'Standard cleaning'),
          ],
          selectedServiceIds: {},
          slots: [],
          unavailableDates: {},
        );
      },
      saveServices: (_) async {
        saves++;
        throw StateError('response lost');
      },
      addSlot: (_, __, ___) async {},
      removeSlot: (_) async {},
      addUnavailableDate: (_) async {},
      removeUnavailableDate: (_) async {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-Standard cleaning')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save service types'));
    await tester.tap(find.text('Save service types'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Check saved availability'), findsOneWidget);
    await tester.tap(find.text('Check latest data'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Standard cleaning'), findsOneWidget);
    expect(find.text('Save service types'), findsOneWidget);
  });

  testWidgets('chat retry resubscribes without losing draft', (tester) async {
    var reads = 0;
    await tester.pumpWidget(_app(ConnectedBookingMessagesScreen(
      bookingId: 'booking-1',
      currentUserId: 'owner-1',
      isProvider: false,
      messages: () {
        reads++;
        if (reads == 1) return Stream.error(StateError('offline'));
        return Stream.value(const <BookingMessage>[]);
      },
      bookingStatus: () => Stream.value('Accepted'),
      send: (_, __) async {},
      wasSent: (_, __) async => false,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Could not load messages'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Please use the side gate');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Please use the side gate');
  });

  testWidgets('booking status failure is shown and can be retried',
      (tester) async {
    var statusReads = 0;
    await tester.pumpWidget(_app(ConnectedBookingMessagesScreen(
      bookingId: 'booking-1',
      currentUserId: 'owner-1',
      isProvider: false,
      messages: () => Stream.value(const <BookingMessage>[]),
      bookingStatus: () {
        statusReads++;
        if (statusReads == 1) return Stream.error(StateError('offline'));
        return Stream.value('Accepted');
      },
      send: (_, __) async {},
      wasSent: (_, __) async => false,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Could not check this booking'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(statusReads, 2);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('evidence failure prevents editing until a successful reload',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(_app(ConnectedBookingEvidenceScreen(
      bookingId: 'booking-1',
      isProvider: true,
      status: 'In Progress',
      load: (_) async {
        reads++;
        if (reads == 1) throw StateError('offline');
        return const BookingEvidenceRecord(
          bookingId: 'booking-1',
          remarks: '',
        );
      },
      download: (_) async => throw StateError('not used'),
      upload: (_, __, ___, ____, _____) async => throw StateError('not used'),
      saveRemarks: (_, __) async {},
      complete: (_) async {},
      checkStatus: (_) async => 'In Progress',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Could not load service record'), findsOneWidget);
    expect(find.text('Mark as Completed'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Document your work'), findsOneWidget);
  });

  testWidgets('review retry performs a fresh load', (tester) async {
    var reads = 0;
    await tester.pumpWidget(_app(ConnectedBookingReviewScreen(
      bookingId: 'booking-1',
      isOwner: false,
      load: (_) async {
        reads++;
        if (reads == 1) throw StateError('offline');
        return null;
      },
      save: (_, __, ___) async => throw StateError('not used'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Could not load review'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('No review yet'), findsOneWidget);
  });

  testWidgets('history opens immediately and retries a failed read',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: ConnectedBookingHistorySheet(
        bookingId: 'booking-1',
        load: (_) async {
          reads++;
          if (reads == 1) throw StateError('offline');
          return const <Map<String, dynamic>>[];
        },
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Could not load status history'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('No status changes yet'), findsOneWidget);
  });
}
