import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/connected_failure_message.dart';

void main() {
  test('network failures ask for verification without exposing exception', () {
    expect(
        ConnectedFailureMessage.isConnectionFailure(
            const SocketException('offline')),
        isTrue);
    expect(
        ConnectedFailureMessage.isConnectionFailure(TimeoutException('late')),
        isTrue);
    final text = ConnectedFailureMessage.forWrite(
      const SocketException('private host details'),
      item: 'booking',
    );
    expect(text, contains('Check its current state'));
    expect(text, isNot(contains('private host details')));
  });

  test('booking reasons become actionable, nontechnical messages', () {
    expect(ConnectedFailureMessage.forBookingReason('price_changed'),
        contains('Search again'));
    expect(ConnectedFailureMessage.forBookingReason('slot_conflict'),
        contains('Choose another time'));
    expect(ConnectedFailureMessage.forBookingReason('unknown_secret'),
        isNot(contains('unknown_secret')));
  });
}
