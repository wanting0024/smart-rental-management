// lib/services/booking_store.dart
// In-memory pub/sub for bookings. Single source of truth across all screens.
// Real-time sync between Owner and Provider views happens automatically
// when either side calls store methods.
//
// Sprint 0: pure in-memory. Sprint 1: backed by Supabase Realtime.
//
// Round 14 bug fix: updateStatus() now uses copyWith to preserve all
// lifecycle timestamps, reason texts, proof paths, and ratings. Previous
// raw DemoBooking() constructor call dropped ~16 fields on every transition.

import 'package:flutter/foundation.dart';
import '../models/demo_data.dart';

/// Maximum number of times a single booking can be rescheduled.
/// After this limit, the booking must be cancelled and re-created.
/// Per Chapter 2.4.5 conflict-prevention rule.
const int kMaxRescheduleCount = 2;

class BookingStore extends ChangeNotifier {
  BookingStore() {
    _bookings = List.of(DemoBooking.all());
  }

  late List<DemoBooking> _bookings;
  List<DemoBooking> get bookings => List.unmodifiable(_bookings);

  /// The most recently updated booking — used for "new update" effects.
  String? _lastUpdatedId;
  String? get lastUpdatedId => _lastUpdatedId;

  // ===== READ =====

  DemoBooking? byId(String id) {
    try {
      return _bookings.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  List<DemoBooking> forProvider(String providerName) =>
      _bookings.where((b) => b.providerName == providerName).toList();

  List<DemoBooking> forProperty(String property) =>
      _bookings.where((b) => b.property == property).toList();

  // ===== WRITE =====

  DemoBooking add({
    required String property,
    required String serviceType,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    String? providerName,
    String? specialInstructions,
    bool isRecurring = false,
    int totalDays = 1,
  }) {
    final newBooking = DemoBooking(
      id: 'b-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      property: property,
      serviceType: serviceType,
      providerName: providerName,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: DemoBookingStatus.requested,
      specialInstructions: specialInstructions,
      isRecurring: isRecurring,
      totalDays: totalDays,
    );
    _bookings = [newBooking, ..._bookings];
    _lastUpdatedId = newBooking.id;
    notifyListeners();
    return newBooking;
  }

  /// Transition a booking to a new status. Returns true if the transition
  /// was valid (matches the FSM), false otherwise.
  ///
  /// Preserves ALL fields not explicitly changed — lifecycle timestamps,
  /// reason texts, proof paths, ratings, reschedule count, etc. — by
  /// using `copyWith` rather than the raw constructor.
  ///
  /// If the booking is recurring and the transition is -> completed, a new
  /// booking is auto-spawned for the next occurrence.
  bool updateStatus(String id, DemoBookingStatus next) {
    final i = _bookings.indexWhere((b) => b.id == id);
    if (i < 0) return false;
    final current = _bookings[i];
    if (!_isValidTransition(current.status, next)) return false;
    final updated = current.copyWith(status: next);
    final newList = List.of(_bookings)..[i] = updated;
    // When a recurring booking completes, auto-spawn the next occurrence.
    if (next == DemoBookingStatus.completed &&
        updated.isRecurring &&
        updated.recurrencePattern != null) {
      final nextStart = updated.recurrencePattern!.nextAfter(updated.scheduledEnd);
      final duration = updated.scheduledEnd.difference(updated.scheduledStart);
      final newBooking = DemoBooking(
        id: 'b-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        property: updated.property,
        serviceType: updated.serviceType,
        providerName: updated.providerName,
        scheduledStart: nextStart,
        scheduledEnd: nextStart.add(duration),
        status: DemoBookingStatus.scheduled,
        specialInstructions: updated.specialInstructions,
        isRecurring: true,
        recurrencePattern: updated.recurrencePattern,
      );
      newList.insert(0, newBooking);
    }
    _bookings = newList;
    _lastUpdatedId = id;
    notifyListeners();
    return true;
  }

  /// Generic update (for reschedule, special-instructions edits).
  void update(DemoBooking updated) {
    final i = _bookings.indexWhere((b) => b.id == updated.id);
    if (i < 0) return;
    _bookings = List.of(_bookings)..[i] = updated;
    _lastUpdatedId = updated.id;
    notifyListeners();
  }

  void remove(String id) {
    _bookings = _bookings.where((b) => b.id != id).toList();
    notifyListeners();
  }

  // ===== F1: Reject + Reschedule =====

  /// Reject a booking. Optional [reason] (F1a: rejection reason is optional).
  /// Sets status to [DemoBookingStatus.rejected] and records the reason
  /// and timestamp. No-op if the booking is already in a terminal state.
  void rejectBooking(String id, {String? reason}) {
    final i = _bookings.indexWhere((b) => b.id == id);
    if (i < 0) return;
    if (_bookings[i].status.isTerminal) return;
    _bookings[i] = _bookings[i].copyWith(
      status: DemoBookingStatus.rejected,
      rejectionReason: reason,
      rejectedAt: DateTime.now(),
    );
    _lastUpdatedId = id;
    notifyListeners();
  }

  /// Reschedule a booking. [reason] is required (F1b decision).
  /// Increments [rescheduleCount] by 1 and sets status to
  /// [DemoBookingStatus.rescheduled]. Caller is responsible for checking
  /// [kMaxRescheduleCount] before invoking.
  /// No-op if the booking is in a terminal state or reschedule count is
  /// already at the limit.
  void rescheduleBooking({
    required String id,
    required DateTime newStart,
    required DateTime newEnd,
    required String reason,
  }) {
    final i = _bookings.indexWhere((b) => b.id == id);
    if (i < 0) return;
    final current = _bookings[i];
    if (current.status.isTerminal) return;
    if (current.rescheduleCount >= kMaxRescheduleCount) return;
    _bookings[i] = current.copyWith(
      scheduledStart: newStart,
      scheduledEnd: newEnd,
      status: DemoBookingStatus.rescheduled,
      rescheduleReason: reason,
      rescheduledAt: DateTime.now(),
      rescheduleCount: current.rescheduleCount + 1,
    );
    _lastUpdatedId = id;
    notifyListeners();
  }

  // ===== F2: Proof + Rating =====

  /// Save the path of a proof-of-completion photo. [isBefore] picks the
  /// before/after field. Path is typically a file path under the app's
  /// temporary directory (path_provider) but any non-null String is accepted.
  void setProofPath(String id, {required bool isBefore, required String path}) {
    final i = _bookings.indexWhere((b) => b.id == id);
    if (i < 0) return;
    _bookings[i] = isBefore
        ? _bookings[i].copyWith(beforeImagePath: path)
        : _bookings[i].copyWith(afterImagePath: path);
    _lastUpdatedId = id;
    notifyListeners();
  }

  /// Submit (or update) the owner's rating for a completed booking.
  /// [rating] must be 1..5. [comment] is optional.
  /// No-op if the booking is not in a completed state.
  void rateCompleted(String id, {required int rating, String? comment}) {
    assert(rating >= 1 && rating <= 5, 'rating must be 1..5');
    final i = _bookings.indexWhere((b) => b.id == id);
    if (i < 0) return;
    if (_bookings[i].status != DemoBookingStatus.completed) return;
    _bookings[i] = _bookings[i].copyWith(
      ownerRating: rating,
      ownerRatingComment: comment,
    );
    _lastUpdatedId = id;
    notifyListeners();
  }

  // ===== FSM (mirrors Chapter 2.4.5 + 2.7.3, 9 states) =====

  static bool _isValidTransition(DemoBookingStatus from, DemoBookingStatus to) {
    if (from.isTerminal) return false;
    switch (from) {
      case DemoBookingStatus.requested:
        return to == DemoBookingStatus.accepted ||
               to == DemoBookingStatus.rejected ||
               to == DemoBookingStatus.cancelled;
      case DemoBookingStatus.accepted:
        return to == DemoBookingStatus.scheduled ||
               to == DemoBookingStatus.rescheduled ||  // Owner only
               to == DemoBookingStatus.cancelled;
      case DemoBookingStatus.scheduled:
        return to == DemoBookingStatus.inProgress ||
               to == DemoBookingStatus.rescheduled ||  // Owner only
               to == DemoBookingStatus.delayed ||      // Maid only
               to == DemoBookingStatus.cancelled;
      case DemoBookingStatus.rescheduled:
        return to == DemoBookingStatus.scheduled ||
               to == DemoBookingStatus.cancelled;
      case DemoBookingStatus.delayed:
        return to == DemoBookingStatus.inProgress || to == DemoBookingStatus.cancelled;
      case DemoBookingStatus.inProgress:
        return to == DemoBookingStatus.completed || to == DemoBookingStatus.delayed;
      case DemoBookingStatus.rejected:
      case DemoBookingStatus.completed:
      case DemoBookingStatus.cancelled:
        return false;
    }
  }

  /// Public transition check (used by UI for available action buttons).
  static bool canTransitionTo(DemoBookingStatus from, DemoBookingStatus to) =>
      _isValidTransition(from, to);

  /// Exposed for tests.
  @visibleForTesting
  static bool debugIsValidTransition(DemoBookingStatus from, DemoBookingStatus to) =>
      _isValidTransition(from, to);
}
