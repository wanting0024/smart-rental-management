// lib/services/booking_store.dart
//
// In-memory booking repository used by the local preview. The formal data
// source will be Supabase, but the same lifecycle policy is shared by both.

import 'package:flutter/foundation.dart';

import '../models/demo_data.dart';

enum BookingAcceptanceFailure {
  bookingNotFound,
  invalidState,
  providerNotAssigned,
  slotConflict,
}

class BookingAcceptanceResult {
  const BookingAcceptanceResult.success()
      : accepted = true,
        failure = null;

  const BookingAcceptanceResult.failure(this.failure) : accepted = false;

  final bool accepted;
  final BookingAcceptanceFailure? failure;

  String get message => switch (failure) {
        BookingAcceptanceFailure.bookingNotFound => 'Booking not found.',
        BookingAcceptanceFailure.invalidState =>
          'Only a Pending request can be accepted.',
        BookingAcceptanceFailure.providerNotAssigned =>
          'A provider must be assigned before acceptance.',
        BookingAcceptanceFailure.slotConflict =>
          'The requested time is no longer available. The request remains Pending.',
        null => 'Booking accepted.',
      };
}

class BookingStore extends ChangeNotifier {
  BookingStore() : _bookings = List.of(DemoBooking.all());

  List<DemoBooking> _bookings;
  int _localSequence = 0;
  List<DemoBooking> get bookings => List.unmodifiable(_bookings);

  String? _lastUpdatedId;
  String? get lastUpdatedId => _lastUpdatedId;

  DemoBooking? byId(String id) {
    try {
      return _bookings.firstWhere((booking) => booking.id == id);
    } catch (_) {
      return null;
    }
  }

  List<DemoBooking> forProvider(String providerName) => _bookings
      .where((booking) => booking.providerName == providerName)
      .toList();

  List<DemoBooking> forProperty(String property) =>
      _bookings.where((booking) => booking.property == property).toList();

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
      id: _nextLocalId(),
      property: property,
      serviceType: serviceType,
      providerName: providerName,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: BookingStatus.pending,
      specialInstructions: specialInstructions,
      isRecurring: isRecurring,
      totalDays: totalDays,
    );
    _bookings = [newBooking, ..._bookings];
    _notifyUpdated(newBooking.id);
    return newBooking;
  }

  /// Performs the local equivalent of the transaction-safe acceptance check.
  /// The Supabase implementation will repeat this check and commit the status
  /// plus history record atomically on the server.
  BookingAcceptanceResult acceptPending(String id) {
    final booking = byId(id);
    if (booking == null) {
      return const BookingAcceptanceResult.failure(
        BookingAcceptanceFailure.bookingNotFound,
      );
    }
    if (booking.status != BookingStatus.pending) {
      return const BookingAcceptanceResult.failure(
        BookingAcceptanceFailure.invalidState,
      );
    }
    if (booking.providerName == null) {
      return const BookingAcceptanceResult.failure(
        BookingAcceptanceFailure.providerNotAssigned,
      );
    }
    if (_hasBlockingOverlap(booking)) {
      return const BookingAcceptanceResult.failure(
        BookingAcceptanceFailure.slotConflict,
      );
    }

    final accepted = _applyStatus(id, BookingStatus.accepted);
    return accepted
        ? const BookingAcceptanceResult.success()
        : const BookingAcceptanceResult.failure(
            BookingAcceptanceFailure.invalidState,
          );
  }

  bool _hasBlockingOverlap(DemoBooking candidate) => _bookings.any(
        (existing) =>
            existing.id != candidate.id &&
            existing.providerName == candidate.providerName &&
            existing.status.blocksProviderSlot &&
            candidate.scheduledStart.isBefore(existing.scheduledEnd) &&
            existing.scheduledStart.isBefore(candidate.scheduledEnd),
      );

  /// Applies the authoritative six-state lifecycle.
  bool updateStatus(String id, BookingStatus next) {
    if (next == BookingStatus.accepted) {
      return acceptPending(id).accepted;
    }
    return _applyStatus(id, next);
  }

  bool _applyStatus(String id, BookingStatus next) {
    final index = _bookings.indexWhere((booking) => booking.id == id);
    if (index < 0) return false;

    final current = _bookings[index];
    if (!BookingLifecycle.canTransition(current.status, next)) return false;
    if (next == BookingStatus.completed && !current.hasCompletionEvidence) {
      return false;
    }

    final now = DateTime.now();
    final updated = current.copyWith(
      status: next,
      acceptedAt: next == BookingStatus.accepted ? now : current.acceptedAt,
      startedAt: next == BookingStatus.inProgress ? now : current.startedAt,
      completedAt: next == BookingStatus.completed ? now : current.completedAt,
      declinedAt: next == BookingStatus.declined ? now : current.declinedAt,
      cancelledAt: next == BookingStatus.cancelled ? now : current.cancelledAt,
    );

    final updatedBookings = List.of(_bookings)..[index] = updated;

    // A recurring occurrence still requires provider acceptance. It therefore
    // creates a new Pending request rather than silently reserving a slot.
    if (next == BookingStatus.completed &&
        updated.isRecurring &&
        updated.recurrencePattern != null) {
      final nextStart =
          updated.recurrencePattern!.nextAfter(updated.scheduledEnd);
      final duration = updated.scheduledEnd.difference(updated.scheduledStart);
      updatedBookings.insert(
        0,
        DemoBooking(
          id: _nextLocalId(),
          property: updated.property,
          serviceType: updated.serviceType,
          providerName: updated.providerName,
          scheduledStart: nextStart,
          scheduledEnd: nextStart.add(duration),
          status: BookingStatus.pending,
          specialInstructions: updated.specialInstructions,
          isRecurring: true,
          recurrencePattern: updated.recurrencePattern,
        ),
      );
    }

    _bookings = updatedBookings;
    _notifyUpdated(id);
    return true;
  }

  void update(DemoBooking updated) {
    final index = _bookings.indexWhere((booking) => booking.id == updated.id);
    if (index < 0) return;
    _bookings = List.of(_bookings)..[index] = updated;
    _notifyUpdated(updated.id);
  }

  /// A provider may decline only an incoming Pending request.
  bool declineBooking(String id, {String? reason}) {
    final booking = byId(id);
    if (booking == null || booking.status != BookingStatus.pending)
      return false;

    final index = _bookings.indexWhere((item) => item.id == id);
    _bookings = List.of(_bookings)
      ..[index] = booking.copyWith(
        status: BookingStatus.declined,
        declineReason: (reason?.trim().isEmpty ?? true) ? null : reason!.trim(),
        declinedAt: DateTime.now(),
      );
    _notifyUpdated(id);
    return true;
  }

  /// Revises date, time, and instructions without creating a Rescheduled
  /// lifecycle state. Only Pending requests can be revised.
  DemoBooking? revisePendingBooking({
    required String id,
    required DateTime newStart,
    required DateTime newEnd,
    String? specialInstructions,
  }) {
    final booking = byId(id);
    if (booking == null || booking.status != BookingStatus.pending) return null;
    if (!newEnd.isAfter(newStart)) return null;

    final index = _bookings.indexWhere((item) => item.id == id);
    final updated = booking.copyWith(
      scheduledStart: newStart,
      scheduledEnd: newEnd,
      specialInstructions: specialInstructions,
    );
    _bookings = List.of(_bookings)..[index] = updated;
    _notifyUpdated(id);
    return updated;
  }

  void setProofPath(String id, {required bool isBefore, required String path}) {
    final booking = byId(id);
    if (booking == null) return;
    update(
      isBefore
          ? booking.copyWith(beforeImagePath: path)
          : booking.copyWith(afterImagePath: path),
    );
  }

  void setCompletionRemarks(String id, String remarks) {
    final booking = byId(id);
    if (booking == null) return;
    update(booking.copyWith(completionRemarks: remarks.trim()));
  }

  void rateCompleted(String id, {required int rating, String? comment}) {
    assert(rating >= 1 && rating <= 5, 'rating must be 1..5');
    final booking = byId(id);
    if (booking == null || booking.status != BookingStatus.completed) return;
    update(
      booking.copyWith(
        ownerRating: rating,
        ownerRatingComment: comment,
      ),
    );
  }

  static bool canTransitionTo(BookingStatus from, BookingStatus to) =>
      BookingLifecycle.canTransition(from, to);

  @visibleForTesting
  static bool debugIsValidTransition(BookingStatus from, BookingStatus to) =>
      BookingLifecycle.canTransition(from, to);

  void _notifyUpdated(String id) {
    _lastUpdatedId = id;
    notifyListeners();
  }

  String _nextLocalId() {
    _localSequence += 1;
    return 'b-local-${DateTime.now().microsecondsSinceEpoch}-$_localSequence';
  }
}
