// test/round14_field_preservation_test.dart
// Guards against losing unrelated booking fields during lifecycle updates.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/services/booking_store.dart';

void main() {
  group('Booking field preservation', () {
    late BookingStore store;

    setUp(() {
      store = BookingStore();
    });

    test('instructions and requested interval survive normal transitions', () {
      final original = store.byId('b-003')!;
      expect(store.acceptPending(original.id).accepted, isTrue);
      expect(
        store.updateStatus(original.id, BookingStatus.inProgress),
        isTrue,
      );

      final current = store.byId(original.id)!;
      expect(current.scheduledStart, original.scheduledStart);
      expect(current.scheduledEnd, original.scheduledEnd);
      expect(current.specialInstructions, original.specialInstructions);
      expect(current.acceptedAt, isNotNull);
      expect(current.startedAt, isNotNull);
    });

    test('proof and remarks survive completion transition', () {
      expect(store.acceptPending('b-003').accepted, isTrue);
      expect(
        store.updateStatus('b-003', BookingStatus.inProgress),
        isTrue,
      );
      store.setProofPath('b-003', isBefore: true, path: '/before.jpg');
      store.setProofPath('b-003', isBefore: false, path: '/after.jpg');
      store.setCompletionRemarks('b-003', 'All requested areas cleaned.');

      expect(
        store.updateStatus('b-003', BookingStatus.completed),
        isTrue,
      );
      final completed = store.byId('b-003')!;
      expect(completed.beforeImagePath, '/before.jpg');
      expect(completed.afterImagePath, '/after.jpg');
      expect(completed.completionRemarks, 'All requested areas cleaned.');
      expect(completed.completedAt, isNotNull);
    });

    test('decline reason is retained on the terminal record', () {
      expect(
        store.declineBooking('b-003', reason: 'Not available'),
        isTrue,
      );
      final declined = store.byId('b-003')!;
      expect(declined.status, BookingStatus.declined);
      expect(declined.declineReason, 'Not available');
      expect(
        store.updateStatus(declined.id, BookingStatus.accepted),
        isFalse,
      );
      expect(store.byId(declined.id)!.declineReason, 'Not available');
    });

    test('copyWith can explicitly remove a proof path', () {
      final booking = store.byId('b-002')!;
      store.setProofPath(booking.id, isBefore: true, path: '/before.jpg');
      final withProof = store.byId(booking.id)!;
      store.update(withProof.copyWith(clearBeforeImagePath: true));
      expect(store.byId(booking.id)!.beforeImagePath, isNull);
    });

    test('owner rating is preserved on a Completed booking', () {
      store.rateCompleted('b-004', rating: 4, comment: 'Good work');
      final rated = store.byId('b-004')!;
      expect(rated.ownerRating, 4);
      expect(rated.ownerRatingComment, 'Good work');
    });
  });
}
