import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/screens/booking_detail_screen.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/property_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/services/review_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  test(
      'successful transitions record one event; failed acceptance records none',
      () {
    final properties = PropertyStore();
    final providers = ProviderStore();
    final store = BookingStore(
      providerStore: providers,
      propertyStore: properties,
    );
    final start = DateTime(2030, 7, 17, 10);
    final first = store.add(
      property: DemoProperty.all.first.display,
      serviceType: 'Standard cleaning',
      scheduledStart: start,
      scheduledEnd: start.add(const Duration(hours: 2)),
      providerName: 'Provider A',
    );
    final second = store.add(
      property: DemoProperty.all.first.display,
      serviceType: 'Standard cleaning',
      scheduledStart: start,
      scheduledEnd: start.add(const Duration(hours: 2)),
      providerName: 'Provider A',
    );

    expect(store.historyFor(first.id).single.previousStatus, isNull);
    expect(store.historyFor(first.id).single.newStatus, BookingStatus.pending);
    expect(store.acceptPending(first.id).accepted, isTrue);
    expect(
        store.historyFor(first.id).last.previousStatus, BookingStatus.pending);
    expect(store.historyFor(first.id).last.newStatus, BookingStatus.accepted);

    expect(store.acceptPending(second.id).accepted, isFalse);
    expect(store.byId(second.id)!.status, BookingStatus.pending);
    expect(store.historyFor(second.id).length, 1);
    expect(store.updateStatus(first.id, BookingStatus.completed), isFalse);
    expect(store.historyFor(first.id).length, 2);
  });

  test('decline records a reason, and generic field edits cannot forge status',
      () {
    final store = BookingStore();
    final booking = store.byId('b-003')!;
    expect(store.historyFor(booking.id), isEmpty);
    store.update(booking.copyWith(status: BookingStatus.accepted));
    expect(store.byId(booking.id)!.status, BookingStatus.pending);
    expect(store.historyFor(booking.id), isEmpty);

    expect(store.declineBooking(booking.id, reason: 'Not available'), isTrue);
    expect(store.historyFor(booking.id).single.previousStatus,
        BookingStatus.pending);
    expect(
        store.historyFor(booking.id).single.newStatus, BookingStatus.declined);
    expect(store.historyFor(booking.id).single.reason, 'Not available');
  });

  testWidgets(
      'booking detail shows recorded events without inventing seed history',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = BookingStore();
    final booking = store.add(
      property: DemoProperty.all.first.display,
      serviceType: 'Standard cleaning',
      scheduledStart: DateTime(2030, 7, 17, 10),
      scheduledEnd: DateTime(2030, 7, 17, 12),
      providerName: 'Provider A',
    );
    await tester.pumpWidget(AppProviders(
      themeMode: ThemeMode.light,
      onToggleTheme: () {},
      bookingStore: store,
      providerStore: ProviderStore(),
      propertyStore: PropertyStore(),
      reviewStore: ReviewStore(),
      messageStore: MessageStore(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: BookingDetailScreen(booking: booking),
      ),
    ));
    await tester.scrollUntilVisible(find.text('STATUS HISTORY'), 250);
    expect(find.textContaining('Property Owner ·'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
