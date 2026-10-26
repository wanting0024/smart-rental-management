import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/booking_card.dart';

void main() {
  testWidgets('booking title and status remain separate on a narrow phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final booking = DemoBooking(
      id: 'layout-booking',
      property: 'Unit A-12, Menara Suria',
      serviceType: 'Standard cleaning',
      providerName: 'Provider A',
      scheduledStart: DateTime(2030, 7, 20, 10),
      scheduledEnd: DateTime(2030, 7, 20, 12),
      status: BookingStatus.accepted,
      specialInstructions: null,
      isRecurring: true,
      recurrencePattern: RecurrencePattern.weekly,
      totalDays: 2,
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [BookingCard(booking: booking, onTap: () {})],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text(booking.property));
    expect(title.maxLines, 2);
    expect(find.text('Accepted'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('2 days'), findsOneWidget);
    expect(find.text('Standard cleaning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
