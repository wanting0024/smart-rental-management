import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/local_preview_data.dart';
import 'package:rental_app_demo/screens/provider_job_detail_screen.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  testWidgets('owner instructions read as a message on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ProviderJobDetailScreen(
        booking: LocalPreviewData.bookings().first,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cleaning instructions'), findsOneWidget);
    expect(find.text('Property Owner'), findsOneWidget);
    expect(find.text('Please focus on the kitchen and bathrooms.'),
        findsOneWidget);
    expect(find.byIcon(Icons.format_quote), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
