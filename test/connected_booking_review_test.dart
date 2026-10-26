import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/connected_booking_review_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_review_repository.dart';

void main() {
  testWidgets('Owner can submit a Completed booking rating and see it saved',
      (tester) async {
    var savedRating = 0;
    String? savedComment;
    await tester.pumpWidget(MaterialApp(
      home: ConnectedBookingReviewScreen(
        bookingId: 'booking-1',
        isOwner: true,
        load: (_) async => null,
        save: (id, rating, comment) async {
          savedRating = rating;
          savedComment = comment;
          return BookingReviewRecord(
            bookingId: id,
            rating: rating,
            comment: comment,
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('How was the cleaning?'), findsWidgets);
    expect(find.text('Submit rating'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  Good service  ');
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(savedRating, 4);
    expect(savedComment, 'Good service');
    expect(find.text('Update rating'), findsOneWidget);
  });

  testWidgets('Provider sees a review but cannot submit one', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ConnectedBookingReviewScreen(
        bookingId: 'booking-1',
        isOwner: false,
        load: (_) async => const BookingReviewRecord(
          bookingId: 'booking-1',
          rating: 5,
          comment: 'Excellent',
        ),
        save: (_, __, ___) async => throw StateError('Forbidden'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Owner review'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('Submit rating'), findsNothing);
  });

  testWidgets('lost review response is verified before showing failure',
      (tester) async {
    BookingReviewRecord? serverRecord;
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: ConnectedBookingReviewScreen(
        bookingId: 'booking-1',
        isOwner: true,
        load: (_) async => serverRecord,
        save: (id, rating, comment) async {
          saves++;
          serverRecord = BookingReviewRecord(
            bookingId: id,
            rating: rating,
            comment: comment,
          );
          throw StateError('response lost');
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Good service');
    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Update rating'), findsOneWidget);
    expect(find.text('Your review was saved.'), findsOneWidget);
  });
}
