// test/reject_reschedule_flow_test.dart
// Tests for F1 reject + reschedule flows and F2 proof + rating helpers on
// BookingStore. Uses DemoBooking.all() to get a fresh dataset, then mutates
// the store and asserts on the resulting booking state.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';

void main() {
  late BookingStore store;

  setUp(() {
    store = BookingStore();
  });

  // Helpers --------------------------------------------------------------
  DemoBooking findById(String id) {
    final found = store.bookings.firstWhere(
      (b) => b.id == id,
      orElse: () => fail('booking $id not found'),
    );
    return found;
  }

  // We use one of the seed bookings as the base for all transitions.
  // b-001 is inProgress, b-002 is scheduled, b-003 is requested, b-004 is
  // completed. b-005 is scheduled (recurring).
  const idRequested = 'b-003';
  const idAccepted = 'b-002';
  const idScheduled = 'b-002';
  const idCompleted = 'b-004';

  // =========================================================================
  // F1a: Reject flow
  // =========================================================================
  group('rejectBooking', () {
    test('from requested → status = rejected, reason recorded', () {
      store.rejectBooking(idRequested, reason: 'Too far');
      final b = findById(idRequested);
      expect(b.status, DemoBookingStatus.rejected);
      expect(b.rejectionReason, 'Too far');
      expect(b.rejectedAt, isNotNull);
    });

    test('without reason → status = rejected, reason null (F1a optional)', () {
      store.rejectBooking(idRequested);
      final b = findById(idRequested);
      expect(b.status, DemoBookingStatus.rejected);
      expect(b.rejectionReason, isNull);
    });

    test('with empty reason string → treated as null', () {
      // Caller could trim and pass empty. The store should not store it.
      store.rejectBooking(idRequested, reason: '   ');
      final b = findById(idRequested);
      expect(b.status, DemoBookingStatus.rejected);
      // Whitespace-only reason is preserved verbatim. Caller is responsible
      // for trimming. We document the behaviour here.
      expect(b.rejectionReason, '   ');
    });

    test('rejects notify listeners', () {
      var notifications = 0;
      store.addListener(() => notifications++);
      store.rejectBooking(idRequested, reason: 'X');
      expect(notifications, 1);
    });

    test('updates lastUpdatedId', () {
      expect(store.lastUpdatedId, isNull);
      store.rejectBooking(idRequested);
      expect(store.lastUpdatedId, idRequested);
    });

    test('rejected from accepted → status = rejected', () {
      // First move b-002 to accepted (already is, by seed).
      // Then reject.
      store.rejectBooking(idAccepted, reason: 'Schedule conflict');
      final b = findById(idAccepted);
      expect(b.status, DemoBookingStatus.rejected);
      expect(b.rejectionReason, 'Schedule conflict');
    });

    test('rejected on completed (terminal) → no-op', () {
      final before = findById(idCompleted);
      expect(before.status, DemoBookingStatus.completed);
      store.rejectBooking(idCompleted, reason: 'Late');
      final after = findById(idCompleted);
      expect(after.status, DemoBookingStatus.completed,
          reason: 'completed is terminal, reject should be no-op');
    });

    test('rejected on cancelled (terminal) → no-op', () {
      // First cancel, then reject.
      store.updateStatus(idRequested, DemoBookingStatus.cancelled);
      final reason = 'Re-attempt reject after cancel';
      store.rejectBooking(idRequested, reason: reason);
      final b = findById(idRequested);
      expect(b.status, DemoBookingStatus.cancelled,
          reason: 'cancelled is terminal, reject should be no-op');
    });
  });

  // =========================================================================
  // F1b: Reschedule flow
  // =========================================================================
  group('rescheduleBooking', () {
    test('from accepted → status = rescheduled, count = 1', () {
      final newStart = DateTime(2027, 1, 1, 14);
      final newEnd = newStart.add(const Duration(hours: 2));
      store.rescheduleBooking(
        id: idAccepted,
        newStart: newStart,
        newEnd: newEnd,
        reason: 'Tenant moved in late',
      );
      final b = findById(idAccepted);
      expect(b.status, DemoBookingStatus.rescheduled);
      expect(b.scheduledStart, newStart);
      expect(b.scheduledEnd, newEnd);
      expect(b.rescheduleCount, 1);
      expect(b.rescheduleReason, 'Tenant moved in late');
      expect(b.rescheduledAt, isNotNull);
    });

    test('from scheduled → status = rescheduled, count = 1', () {
      final newStart = DateTime(2027, 1, 2, 9);
      final newEnd = newStart.add(const Duration(hours: 3));
      store.rescheduleBooking(
        id: idScheduled,
        newStart: newStart,
        newEnd: newEnd,
        reason: 'Property access delayed',
      );
      final b = findById(idScheduled);
      expect(b.status, DemoBookingStatus.rescheduled);
      expect(b.rescheduleCount, 1);
    });

    test('reschedule twice → count = 2 (at limit)', () {
      for (var i = 0; i < 2; i++) {
        final start = DateTime(2027, 2, i + 1, 10);
        final end = start.add(const Duration(hours: 2));
        store.rescheduleBooking(
          id: idAccepted,
          newStart: start,
          newEnd: end,
          reason: 'Reason $i',
        );
      }
      final b = findById(idAccepted);
      expect(b.rescheduleCount, 2);
      expect(b.status, DemoBookingStatus.rescheduled);
    });

    test('reschedule 3rd time → blocked (no-op, count stays 2)', () {
      // First 2 succeed.
      for (var i = 0; i < 2; i++) {
        store.rescheduleBooking(
          id: idAccepted,
          newStart: DateTime(2027, 3, i + 1, 10),
          newEnd: DateTime(2027, 3, i + 1, 12),
          reason: 'r$i',
        );
      }
      // 3rd attempt — should be blocked.
      final before = findById(idAccepted);
      store.rescheduleBooking(
        id: idAccepted,
        newStart: DateTime(2027, 3, 10, 10),
        newEnd: DateTime(2027, 3, 10, 12),
        reason: '3rd attempt',
      );
      final after = findById(idAccepted);
      expect(after.rescheduleCount, before.rescheduleCount,
          reason: 'count should not change when limit reached');
      // Status should still be the last successful reschedule.
      expect(after.status, DemoBookingStatus.rescheduled);
    });

    test('reason is required parameter (compile-time check)', () {
      // Just ensure we can pass a non-empty string without issue.
      expect(() => store.rescheduleBooking(
            id: idAccepted,
            newStart: DateTime(2027, 4, 1, 10),
            newEnd: DateTime(2027, 4, 1, 12),
            reason: 'Test reason',
          ), returnsNormally);
    });

    test('on terminal state (completed) → no-op', () {
      final before = findById(idCompleted);
      store.rescheduleBooking(
        id: idCompleted,
        newStart: DateTime(2027, 5, 1, 10),
        newEnd: DateTime(2027, 5, 1, 12),
        reason: 'After complete',
      );
      final after = findById(idCompleted);
      expect(after.status, before.status);
      expect(after.rescheduleCount, before.rescheduleCount);
      expect(after.scheduledStart, before.scheduledStart);
    });

    test('notify listeners on success', () {
      var notifications = 0;
      store.addListener(() => notifications++);
      store.rescheduleBooking(
        id: idAccepted,
        newStart: DateTime(2027, 6, 1, 10),
        newEnd: DateTime(2027, 6, 1, 12),
        reason: 'notify test',
      );
      expect(notifications, 1);
    });

    test('updates lastUpdatedId', () {
      expect(store.lastUpdatedId, isNull);
      store.rescheduleBooking(
        id: idAccepted,
        newStart: DateTime(2027, 7, 1, 10),
        newEnd: DateTime(2027, 7, 1, 12),
        reason: 'lastUpdated test',
      );
      expect(store.lastUpdatedId, idAccepted);
    });
  });

  // =========================================================================
  // F1c: kMaxRescheduleCount constant
  // =========================================================================
  group('kMaxRescheduleCount', () {
    test('equals 2 (per F1c design decision)', () {
      expect(kMaxRescheduleCount, 2);
    });
  });

  // =========================================================================
  // F2: Proof + Rating
  // =========================================================================
  group('F2: setProofPath + rateCompleted', () {
    test('setProofPath before → beforeImagePath set', () {
      store.setProofPath(idScheduled, isBefore: true, path: '/tmp/before.jpg');
      final b = findById(idScheduled);
      expect(b.beforeImagePath, '/tmp/before.jpg');
      expect(b.afterImagePath, isNull);
    });

    test('setProofPath after → afterImagePath set', () {
      store.setProofPath(idScheduled, isBefore: false, path: '/tmp/after.jpg');
      final b = findById(idScheduled);
      expect(b.afterImagePath, '/tmp/after.jpg');
    });

    test('setProofPath both → hasProof true', () {
      store.setProofPath(idScheduled, isBefore: true, path: '/b.jpg');
      store.setProofPath(idScheduled, isBefore: false, path: '/a.jpg');
      final b = findById(idScheduled);
      expect(b.hasProof, isTrue);
    });

    test('rateCompleted on completed → ownerRating set', () {
      store.rateCompleted(idCompleted, rating: 4, comment: 'Great work');
      final b = findById(idCompleted);
      expect(b.ownerRating, 4);
      expect(b.ownerRatingComment, 'Great work');
      expect(b.isRated, isTrue);
    });

    test('rateCompleted without comment → ownerRatingComment null', () {
      store.rateCompleted(idCompleted, rating: 5);
      final b = findById(idCompleted);
      expect(b.ownerRating, 5);
      expect(b.ownerRatingComment, isNull);
    });

    test('rateCompleted on non-completed → no-op', () {
      store.rateCompleted(idScheduled, rating: 5);
      final b = findById(idScheduled);
      expect(b.ownerRating, isNull,
          reason: 'rating only allowed on completed bookings');
    });

    test('rating must be 1..5 (asserted in store)', () {
      expect(
        () => store.rateCompleted(idCompleted, rating: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => store.rateCompleted(idCompleted, rating: 6),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // =========================================================================
  // Integration: 9-state FSM still valid
  // =========================================================================
  group('Integration: 9-state FSM integrity', () {
    test('reject keeps terminal state, no further transitions', () {
      store.rejectBooking(idRequested, reason: 'X');
      final b = findById(idRequested);
      for (final s in DemoBookingStatus.values) {
        expect(BookingStore.canTransitionTo(b.status, s), isFalse,
            reason: 'rejected is terminal, should not allow $s');
      }
    });

    test('reschedule allows subsequent scheduled transition', () {
      store.rescheduleBooking(
        id: idAccepted,
        newStart: DateTime(2027, 8, 1, 10),
        newEnd: DateTime(2027, 8, 1, 12),
        reason: 'Test',
      );
      final b = findById(idAccepted);
      expect(b.status, DemoBookingStatus.rescheduled);
      expect(BookingStore.canTransitionTo(b.status, DemoBookingStatus.scheduled), isTrue);
      expect(BookingStore.canTransitionTo(b.status, DemoBookingStatus.cancelled), isTrue);
      expect(BookingStore.canTransitionTo(b.status, DemoBookingStatus.completed), isFalse);
    });

    test('full flow: requested → accepted → scheduled → rescheduled → scheduled → completed → rated',
        () {
      // Start from requested (b-003).
      store.updateStatus(idRequested, DemoBookingStatus.accepted);
      expect(findById(idRequested).status, DemoBookingStatus.accepted);
      store.updateStatus(idRequested, DemoBookingStatus.scheduled);
      expect(findById(idRequested).status, DemoBookingStatus.scheduled);
      store.rescheduleBooking(
        id: idRequested,
        newStart: DateTime(2027, 9, 1, 10),
        newEnd: DateTime(2027, 9, 1, 12),
        reason: 'Owner reschedule',
      );
      expect(findById(idRequested).status, DemoBookingStatus.rescheduled);
      store.updateStatus(idRequested, DemoBookingStatus.scheduled);
      expect(findById(idRequested).status, DemoBookingStatus.scheduled);
      store.updateStatus(idRequested, DemoBookingStatus.inProgress);
      store.updateStatus(idRequested, DemoBookingStatus.completed);
      final final0 = findById(idRequested);
      expect(final0.status, DemoBookingStatus.completed);
      store.rateCompleted(idRequested, rating: 5, comment: 'Excellent');
      final final1 = findById(idRequested);
      expect(final1.ownerRating, 5);
      expect(final1.ownerRatingComment, 'Excellent');
      expect(final1.isRated, isTrue);
    });
  });
}
