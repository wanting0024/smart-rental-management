// test/messaging_reviews_test.dart
// Verifies the ReviewStore and MessageStore behaviors.

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/message.dart';
import 'package:rental_app_demo/models/review.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/review_store.dart';

void main() {
  group('ReviewStore', () {
    test('seeds with 10 reviews across 3 providers', () {
      final store = ReviewStore();
      expect(store.all.length, 10);
    });

    test('forProvider filters by provider name', () {
      final store = ReviewStore();
      final a = store.forProvider('Provider A');
      expect(a.every((r) => r.providerName == 'Provider A'), isTrue);
      expect(a.length, 5);
    });

    test('averageFor computes correctly', () {
      final store = ReviewStore();
      // Provider A: 5 stars, 5 stars, 4 stars, 5 stars, 4 stars = 23/5 = 4.6
      expect(store.averageFor('Provider A'), closeTo(4.6, 0.01));
    });

    test('distributionFor returns a histogram with all 5 stars represented', () {
      final store = ReviewStore();
      final dist = store.distributionFor('Provider A');
      expect(dist.length, 5);
      final total = dist.values.fold<int>(0, (a, b) => a + b);
      expect(total, 5);
    });

    test('add() prepends and notifies', () {
      final store = ReviewStore();
      var notified = 0;
      store.addListener(() => notified++);
      final before = store.all.length;
      store.add(Review(
        id: 'x', bookingId: 'b-x', providerName: 'Provider A',
        ownerName: 'Test', rating: 5, comment: 'Great!',
        tags: const [], timestamp: DateTime.now(),
      ));
      expect(store.all.length, before + 1);
      expect(notified, 1);
      expect(store.all.first.id, 'x');
    });
  });

  group('MessageStore', () {
    test('seeds with 3 conversations', () {
      final store = MessageStore();
      expect(store.conversations.length, 3);
    });

    test('messagesFor returns messages for a conversation sorted by time', () {
      final store = MessageStore();
      final msgs = store.messagesFor('c-1');
      expect(msgs.length, greaterThan(0));
      for (int i = 0; i < msgs.length - 1; i++) {
        expect(msgs[i].timestamp.isBefore(msgs[i + 1].timestamp) ||
            msgs[i].timestamp.isAtSameMomentAs(msgs[i + 1].timestamp), isTrue);
      }
    });

    test('send() appends message and updates lastMessage', () {
      final store = MessageStore();
      var notified = 0;
      store.addListener(() => notified++);
      final before = store.messagesFor('c-1').length;
      store.send(
        conversationId: 'c-1',
        senderName: 'Oh Wan Ting',
        text: 'Hello there',
      );
      expect(store.messagesFor('c-1').length, before + 1);
      final convo = store.byId('c-1')!;
      expect(convo.lastMessage, 'Hello there');
      expect(notified, 1);
    });

    test('send() re-sorts conversations by lastTimestamp', () {
      final store = MessageStore();
      // Send a message in c-3 (which is the oldest)
      store.send(conversationId: 'c-3', senderName: 'Oh Wan Ting', text: 'Newest!');
      expect(store.conversations.first.id, 'c-3');
    });

    test('markRead clears unread for messages in a conversation', () {
      final store = MessageStore();
      store.markRead('c-1');
      final msgs = store.messagesFor('c-1');
      expect(msgs.every((m) => m.read), isTrue);
    });

    test('findOrCreate reuses an existing conversation', () {
      final store = MessageStore();
      final before = store.conversations.length;
      final id1 = store.findOrCreate(
        participantA: 'Oh Wan Ting', participantB: 'Provider A',
        bookingId: 'b-001', property: 'Unit A-12, Menara Suria',
      );
      expect(store.conversations.length, before);
      // Same participants, same booking -> same id
      final id2 = store.findOrCreate(
        participantA: 'Provider A', participantB: 'Oh Wan Ting',  // reversed order
        bookingId: 'b-001', property: 'Unit A-12, Menara Suria',
      );
      expect(id1, id2);
    });

    test('findOrCreate creates a new conversation for new participants', () {
      final store = MessageStore();
      final before = store.conversations.length;
      store.findOrCreate(
        participantA: 'A', participantB: 'B',
        bookingId: 'b-new', property: 'Unit X',
      );
      expect(store.conversations.length, before + 1);
    });
  });
}
