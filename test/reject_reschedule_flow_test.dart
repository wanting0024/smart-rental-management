// test/reject_reschedule_flow_test.dart
// Regression coverage for decline, Pending revision, atomic acceptance, and
// completion-evidence behaviour. The filename is retained to preserve history.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';

void main() {
  late BookingStore store;

  setUp(() {
    store = BookingStore();
  });

  group('Pending outcomes', () {
    test('provider may decline a Pending request with an optional reason', () {
      expect(
        store.declineBooking('b-003', reason: 'Outside service area'),
        isTrue,
      );
      final booking = store.byId('b-003')!;
      expect(booking.status, BookingStatus.declined);
      expect(booking.declineReason, 'Outside service area');
      expect(booking.declinedAt, isNotNull);
      expect(booking.status.isTerminal, isTrue);
    });

    test('whitespace-only decline reason is stored as null', () {
      expect(store.declineBooking('b-003', reason: '   '), isTrue);
      expect(store.byId('b-003')!.declineReason, isNull);
    });

    test('an Accepted or terminal booking cannot be declined', () {
      expect(store.declineBooking('b-002'), isFalse);
      expect(store.declineBooking('b-004'), isFalse);
    });

    test('owner revision changes details but remains Pending', () {
      final start = DateTime(2030, 9, 5, 14);
      final updated = store.revisePendingBooking(
        id: 'b-003',
        newStart: start,
        newEnd: start.add(const Duration(hours: 2)),
        specialInstructions: 'Collect the key from security.',
      );

      expect(updated, isNotNull);
      expect(updated!.status, BookingStatus.pending);
      expect(updated.scheduledStart, start);
      expect(updated.specialInstructions, 'Collect the key from security.');
    });

    test('revision is rejected after provider acceptance', () {
      expect(
        store.revisePendingBooking(
          id: 'b-002',
          newStart: DateTime(2030, 1, 1, 9),
          newEnd: DateTime(2030, 1, 1, 11),
        ),
        isNull,
      );
    });
  });

  group('Acceptance conflict check', () {
    test('Pending requests do not block one another', () {
      final start = DateTime(2030, 10, 1, 10);
      store.add(
        property: 'Unit Test A',
        serviceType: 'Routine cleaning',
        providerName: 'Provider Z',
        scheduledStart: start,
        scheduledEnd: start.add(const Duration(hours: 2)),
      );
      final second = store.add(
        property: 'Unit Test B',
        serviceType: 'Routine cleaning',
        providerName: 'Provider Z',
        scheduledStart: start,
        scheduledEnd: start.add(const Duration(hours: 2)),
      );

      final result = store.acceptPending(second.id);
      expect(result.accepted, isTrue);
      expect(store.byId(second.id)!.status, BookingStatus.accepted);
    });

    test('overlap with Accepted booking is rejected and remains Pending', () {
      final start = DateTime(2030, 11, 1, 10);
      final accepted = store.add(
        property: 'Unit Test A',
        serviceType: 'Routine cleaning',
        providerName: 'Provider Z',
        scheduledStart: start,
        scheduledEnd: start.add(const Duration(hours: 2)),
      );
      final competing = store.add(
        property: 'Unit Test B',
        serviceType: 'Routine cleaning',
        providerName: 'Provider Z',
        scheduledStart: start.add(const Duration(minutes: 30)),
        scheduledEnd: start.add(const Duration(hours: 2, minutes: 30)),
      );
      expect(store.acceptPending(accepted.id).accepted, isTrue);

      final result = store.acceptPending(competing.id);
      expect(result.accepted, isFalse);
      expect(result.failure, BookingAcceptanceFailure.slotConflict);
      expect(store.byId(competing.id)!.status, BookingStatus.pending);
    });

    test('half-open intervals allow one booking to start when another ends',
        () {
      final firstStart = DateTime(2030, 12, 1, 10);
      final first = store.add(
        property: 'Unit Test A',
        serviceType: 'Routine cleaning',
        providerName: 'Provider Z',
        scheduledStart: firstStart,
        scheduledEnd: firstStart.add(const Duration(hours: 2)),
      );
      final second = store.add(
        property: 'Unit Test B',
        serviceType: 'Routine cleaning',
        providerName: 'Provider Z',
        scheduledStart: firstStart.add(const Duration(hours: 2)),
        scheduledEnd: firstStart.add(const Duration(hours: 4)),
      );

      expect(store.acceptPending(first.id).accepted, isTrue);
      expect(store.acceptPending(second.id).accepted, isTrue);
    });
  });

  group('Completion evidence', () {
    test('completion is rejected until both photos and remarks exist', () {
      expect(store.acceptPending('b-003').accepted, isTrue);
      expect(
        store.updateStatus('b-003', BookingStatus.inProgress),
        isTrue,
      );
      expect(
        store.updateStatus('b-003', BookingStatus.completed),
        isFalse,
      );

      store.setProofPath('b-003', isBefore: true, path: '/before.jpg');
      store.setProofPath('b-003', isBefore: false, path: '/after.jpg');
      expect(
        store.updateStatus('b-003', BookingStatus.completed),
        isFalse,
      );

      store.setCompletionRemarks('b-003', 'Kitchen and bathrooms completed.');
      expect(
        store.updateStatus('b-003', BookingStatus.completed),
        isTrue,
      );
      expect(store.byId('b-003')!.status, BookingStatus.completed);
    });

    test('only a Completed booking can receive an owner rating', () {
      store.rateCompleted('b-002', rating: 5, comment: 'Too early');
      expect(store.byId('b-002')!.ownerRating, isNull);

      store.rateCompleted('b-004', rating: 5, comment: 'Excellent');
      expect(store.byId('b-004')!.ownerRating, 5);
      expect(store.byId('b-004')!.ownerRatingComment, 'Excellent');
    });
  });
}
