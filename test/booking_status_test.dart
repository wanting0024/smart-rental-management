// test/booking_status_test.dart
// Verifies the single authoritative lifecycle used throughout the report.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';

void main() {
  group('Authoritative booking states', () {
    test('contains exactly the six report-approved states', () {
      expect(
        BookingStatus.values,
        const [
          BookingStatus.pending,
          BookingStatus.accepted,
          BookingStatus.inProgress,
          BookingStatus.completed,
          BookingStatus.declined,
          BookingStatus.cancelled,
        ],
      );
    });

    test('every state has a label and presentation colour', () {
      for (final status in BookingStatus.values) {
        expect(status.label, isNotEmpty);
        expect(status.color, isNotNull);
      }
    });

    test('only Completed, Declined, and Cancelled are terminal', () {
      expect(BookingStatus.completed.isTerminal, isTrue);
      expect(BookingStatus.declined.isTerminal, isTrue);
      expect(BookingStatus.cancelled.isTerminal, isTrue);
      expect(BookingStatus.pending.isTerminal, isFalse);
      expect(BookingStatus.accepted.isTerminal, isFalse);
      expect(BookingStatus.inProgress.isTerminal, isFalse);
    });

    test('only Accepted and In Progress block provider capacity', () {
      expect(BookingStatus.accepted.blocksProviderSlot, isTrue);
      expect(BookingStatus.inProgress.blocksProviderSlot, isTrue);
      expect(BookingStatus.pending.blocksProviderSlot, isFalse);
      expect(BookingStatus.completed.blocksProviderSlot, isFalse);
      expect(BookingStatus.declined.blocksProviderSlot, isFalse);
      expect(BookingStatus.cancelled.blocksProviderSlot, isFalse);
    });
  });

  group('Permitted transitions', () {
    test('Pending has the three permitted outcomes', () {
      expect(_next(BookingStatus.pending), {
        BookingStatus.accepted,
        BookingStatus.declined,
        BookingStatus.cancelled,
      });
    });

    test('Accepted may start work or be cancelled before work starts', () {
      expect(_next(BookingStatus.accepted), {
        BookingStatus.inProgress,
        BookingStatus.cancelled,
      });
      expect(_next(BookingStatus.inProgress), {BookingStatus.completed});
    });

    test('cancellation actor rules are explicit', () {
      expect(
          BookingLifecycle.canCancel(BookingStatus.pending, BookingActor.owner),
          isTrue);
      expect(
          BookingLifecycle.canCancel(
              BookingStatus.pending, BookingActor.provider),
          isFalse);
      expect(
          BookingLifecycle.canCancel(
              BookingStatus.accepted, BookingActor.owner),
          isTrue);
      expect(
          BookingLifecycle.canCancel(
              BookingStatus.accepted, BookingActor.provider),
          isTrue);
      expect(
          BookingLifecycle.canCancel(
              BookingStatus.inProgress, BookingActor.owner),
          isFalse);
    });

    test('all terminal states have no outgoing transition', () {
      for (final terminal in const [
        BookingStatus.completed,
        BookingStatus.declined,
        BookingStatus.cancelled,
      ]) {
        expect(_next(terminal), isEmpty);
      }
    });

    test('a state cannot transition to itself', () {
      for (final status in BookingStatus.values) {
        expect(BookingStore.canTransitionTo(status, status), isFalse);
      }
    });

    test('store API and authoritative policy agree for every pair', () {
      for (final from in BookingStatus.values) {
        for (final to in BookingStatus.values) {
          expect(
            BookingStore.canTransitionTo(from, to),
            BookingLifecycle.canTransition(from, to),
            reason: '$from -> $to',
          );
        }
      }
    });
  });
}

Set<BookingStatus> _next(BookingStatus from) => BookingStatus.values
    .where((to) => BookingStore.canTransitionTo(from, to))
    .toSet();
