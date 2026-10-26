import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/widgets/cancellation_reason_sheet.dart';

void main() {
  test('Owner cancellation of Pending requires a reason', () {
    final store = BookingStore(initialBookings: []);
    final booking = store.add(
      property: DemoProperty.all.first.display,
      serviceType: 'Standard cleaning',
      scheduledStart: DateTime(2030, 10, 20, 10),
      scheduledEnd: DateTime(2030, 10, 20, 12),
      providerName: 'Provider A',
    );
    expect(
        store.cancelBooking(booking.id,
            actor: BookingActor.provider, reason: 'Conflict'),
        isFalse);
    expect(
        store.cancelBooking(booking.id,
            actor: BookingActor.owner, reason: '  '),
        isFalse);
    expect(store.updateStatus(booking.id, BookingStatus.cancelled), isFalse);
    expect(
        store.cancelBooking(booking.id,
            actor: BookingActor.owner, reason: 'No longer needed'),
        isTrue);
    expect(store.byId(booking.id)!.cancellationReason, 'No longer needed');
    expect(store.byId(booking.id)!.cancelledAt, isNotNull);
    expect(store.historyFor(booking.id).last.reason, 'No longer needed');
    expect(store.historyFor(booking.id).last.changedBy, 'Property Owner');
    expect(
        store.cancelBooking(booking.id,
            actor: BookingActor.owner, reason: 'Again'),
        isFalse);
  });

  test('Accepted cancellation releases capacity; In Progress cannot cancel',
      () {
    final store = BookingStore(initialBookings: []);
    final start = DateTime(2030, 10, 20, 10);
    DemoBooking add() => store.add(
          property: DemoProperty.all.first.display,
          serviceType: 'Standard cleaning',
          scheduledStart: start,
          scheduledEnd: start.add(const Duration(hours: 2)),
          providerName: 'Provider A',
        );
    final first = add();
    final second = add();
    expect(store.acceptPending(first.id).accepted, isTrue);
    expect(store.acceptPending(second.id).accepted, isFalse);
    expect(
        store.cancelBooking(first.id,
            actor: BookingActor.provider, reason: 'Emergency'),
        isTrue);
    expect(
        store.historyFor(first.id).last.previousStatus, BookingStatus.accepted);
    expect(
        store.historyFor(first.id).last.changedBy, 'Cleaning Service Provider');
    expect(store.acceptPending(second.id).accepted, isTrue);
    expect(store.updateStatus(second.id, BookingStatus.inProgress), isTrue);
    expect(
        store.cancelBooking(second.id,
            actor: BookingActor.owner, reason: 'Too late'),
        isFalse);
  });

  test('UI reason mapping requires Other detail and preserves explanation', () {
    expect(bookingCancellationReason({'reason_id': 'other', 'comment': ''}),
        isNull);
    expect(
        bookingCancellationReason(
            {'reason_id': 'scheduling', 'comment': 'Meeting'},
            forProvider: true),
        'Scheduling conflict: Meeting');
  });
}
