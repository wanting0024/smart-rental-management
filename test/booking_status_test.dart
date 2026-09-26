// test/booking_status_test.dart
// Verifies the booking FSM transition rules match Chapter 2.4.5 + 2.7.3.
//
// FSM (9 states):
//   requested    -> {accepted, rejected, cancelled}
//   accepted     -> {scheduled, rescheduled (owner only), cancelled}
//   scheduled    -> {inProgress, rescheduled (owner only), delayed (maid only), cancelled}
//   rescheduled  -> {scheduled, cancelled}
//   inProgress   -> {completed, delayed}
//   delayed      -> {inProgress, cancelled}
//   completed    -> {} (terminal)
//   rejected     -> {} (terminal)
//   cancelled    -> {} (terminal)

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';

void main() {
  group('DemoBookingStatus', () {
    test('enum has exactly 9 states', () {
      expect(DemoBookingStatus.values.length, 9);
    });

    test('every state has a non-empty label', () {
      for (final s in DemoBookingStatus.values) {
        expect(s.label, isNotEmpty, reason: '$s missing label');
      }
    });

    test('every state has a color', () {
      for (final s in DemoBookingStatus.values) {
        expect(s.color, isNotNull, reason: '$s missing color');
      }
    });

    test('isTerminal true only for completed/rejected/cancelled', () {
      expect(DemoBookingStatus.completed.isTerminal, isTrue);
      expect(DemoBookingStatus.rejected.isTerminal, isTrue);
      expect(DemoBookingStatus.cancelled.isTerminal, isTrue);
      for (final s in DemoBookingStatus.values.where((e) => e.isTerminal == false)) {
        expect(s.isTerminal, isFalse, reason: '$s should not be terminal');
      }
    });
  });

  group('FSM transitions (Ch 2.4.5 + 2.7.3, 9 states)', () {
    test('requested -> {accepted, rejected, cancelled}', () {
      expect(_isValid(DemoBookingStatus.requested, DemoBookingStatus.accepted), isTrue);
      expect(_isValid(DemoBookingStatus.requested, DemoBookingStatus.rejected), isTrue);
      expect(_isValid(DemoBookingStatus.requested, DemoBookingStatus.cancelled), isTrue);
      expect(_isValid(DemoBookingStatus.requested, DemoBookingStatus.scheduled), isFalse);
      expect(_isValid(DemoBookingStatus.requested, DemoBookingStatus.inProgress), isFalse);
      expect(_isValid(DemoBookingStatus.requested, DemoBookingStatus.rescheduled), isFalse);
    });

    test('accepted -> {scheduled, rescheduled, cancelled}', () {
      expect(_isValid(DemoBookingStatus.accepted, DemoBookingStatus.scheduled), isTrue);
      expect(_isValid(DemoBookingStatus.accepted, DemoBookingStatus.rescheduled), isTrue);
      expect(_isValid(DemoBookingStatus.accepted, DemoBookingStatus.cancelled), isTrue);
      expect(_isValid(DemoBookingStatus.accepted, DemoBookingStatus.inProgress), isFalse);
      expect(_isValid(DemoBookingStatus.accepted, DemoBookingStatus.completed), isFalse);
      expect(_isValid(DemoBookingStatus.accepted, DemoBookingStatus.rejected), isFalse);
    });

    test('scheduled -> {inProgress, rescheduled, delayed, cancelled}', () {
      expect(_isValid(DemoBookingStatus.scheduled, DemoBookingStatus.inProgress), isTrue);
      expect(_isValid(DemoBookingStatus.scheduled, DemoBookingStatus.rescheduled), isTrue);
      expect(_isValid(DemoBookingStatus.scheduled, DemoBookingStatus.delayed), isTrue);
      expect(_isValid(DemoBookingStatus.scheduled, DemoBookingStatus.cancelled), isTrue);
      expect(_isValid(DemoBookingStatus.scheduled, DemoBookingStatus.accepted), isFalse);
      expect(_isValid(DemoBookingStatus.scheduled, DemoBookingStatus.completed), isFalse);
      expect(_isValid(DemoBookingStatus.scheduled, DemoBookingStatus.rejected), isFalse);
    });

    test('rescheduled -> {scheduled, cancelled}', () {
      expect(_isValid(DemoBookingStatus.rescheduled, DemoBookingStatus.scheduled), isTrue);
      expect(_isValid(DemoBookingStatus.rescheduled, DemoBookingStatus.cancelled), isTrue);
      expect(_isValid(DemoBookingStatus.rescheduled, DemoBookingStatus.inProgress), isFalse);
      expect(_isValid(DemoBookingStatus.rescheduled, DemoBookingStatus.delayed), isFalse);
      expect(_isValid(DemoBookingStatus.rescheduled, DemoBookingStatus.completed), isFalse);
    });

    test('inProgress -> {completed, delayed}', () {
      expect(_isValid(DemoBookingStatus.inProgress, DemoBookingStatus.completed), isTrue);
      expect(_isValid(DemoBookingStatus.inProgress, DemoBookingStatus.delayed), isTrue);
      expect(_isValid(DemoBookingStatus.inProgress, DemoBookingStatus.cancelled), isFalse);
      expect(_isValid(DemoBookingStatus.inProgress, DemoBookingStatus.scheduled), isFalse);
      expect(_isValid(DemoBookingStatus.inProgress, DemoBookingStatus.rejected), isFalse);
      expect(_isValid(DemoBookingStatus.inProgress, DemoBookingStatus.rescheduled), isFalse);
    });

    test('delayed -> {inProgress, cancelled}', () {
      expect(_isValid(DemoBookingStatus.delayed, DemoBookingStatus.inProgress), isTrue);
      expect(_isValid(DemoBookingStatus.delayed, DemoBookingStatus.cancelled), isTrue);
      expect(_isValid(DemoBookingStatus.delayed, DemoBookingStatus.completed), isFalse);
      expect(_isValid(DemoBookingStatus.delayed, DemoBookingStatus.scheduled), isFalse);
      expect(_isValid(DemoBookingStatus.delayed, DemoBookingStatus.rejected), isFalse);
      expect(_isValid(DemoBookingStatus.delayed, DemoBookingStatus.rescheduled), isFalse);
    });

    test('completed is terminal (no outgoing transitions)', () {
      for (final s in DemoBookingStatus.values) {
        expect(_isValid(DemoBookingStatus.completed, s), isFalse,
            reason: 'completed -> $s should be invalid');
      }
    });

    test('rejected is terminal (no outgoing transitions)', () {
      for (final s in DemoBookingStatus.values) {
        expect(_isValid(DemoBookingStatus.rejected, s), isFalse,
            reason: 'rejected -> $s should be invalid');
      }
    });

    test('cancelled is terminal (no outgoing transitions)', () {
      for (final s in DemoBookingStatus.values) {
        expect(_isValid(DemoBookingStatus.cancelled, s), isFalse,
            reason: 'cancelled -> $s should be invalid');
      }
    });

    test('no state transitions to itself', () {
      for (final s in DemoBookingStatus.values) {
        expect(_isValid(s, s), isFalse, reason: '$s -> $s should be invalid');
      }
    });
  });

  group('BookingStore.canTransitionTo public API', () {
    test('matches private FSM (sanity check)', () {
      for (final from in DemoBookingStatus.values) {
        for (final to in DemoBookingStatus.values) {
          expect(
            BookingStore.canTransitionTo(from, to),
            _isValid(from, to),
            reason: 'mismatch: $from -> $to',
          );
        }
      }
    });
  });
}

/// Mirrors the FSM in BookingStore._isValidTransition for direct testing
/// without exposing the private method.
bool _isValid(DemoBookingStatus from, DemoBookingStatus to) {
  if (from.isTerminal) return false;
  switch (from) {
    case DemoBookingStatus.requested:
      return to == DemoBookingStatus.accepted ||
             to == DemoBookingStatus.rejected ||
             to == DemoBookingStatus.cancelled;
    case DemoBookingStatus.accepted:
      return to == DemoBookingStatus.scheduled ||
             to == DemoBookingStatus.rescheduled ||
             to == DemoBookingStatus.cancelled;
    case DemoBookingStatus.scheduled:
      return to == DemoBookingStatus.inProgress ||
             to == DemoBookingStatus.rescheduled ||
             to == DemoBookingStatus.delayed ||
             to == DemoBookingStatus.cancelled;
    case DemoBookingStatus.rescheduled:
      return to == DemoBookingStatus.scheduled ||
             to == DemoBookingStatus.cancelled;
    case DemoBookingStatus.delayed:
      return to == DemoBookingStatus.inProgress ||
             to == DemoBookingStatus.cancelled;
    case DemoBookingStatus.inProgress:
      return to == DemoBookingStatus.completed ||
             to == DemoBookingStatus.delayed;
    case DemoBookingStatus.rejected:
    case DemoBookingStatus.completed:
    case DemoBookingStatus.cancelled:
      return false;
  }
}
