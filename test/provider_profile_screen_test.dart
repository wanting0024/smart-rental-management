import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/screens/provider_profile_screen.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  testWidgets('shows the report-aligned two-stage match breakdown',
      (tester) async {
    final provider = DemoProvider.seeded().first.copyWith(
          score: 2 / 3,
          distanceSuitability: 1,
          ratingSuitability: 0,
          workloadSuitability: 1,
          hasRankingBreakdown: true,
        );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProviderProfileScreen(provider: provider),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Two-stage match analysis'), findsOneWidget);
    expect(find.text('Distance'), findsWidgets);
    expect(find.text('Rating'), findsWidgets);
    expect(find.text('Workload'), findsWidgets);
    expect(find.text('Availability'), findsNothing);
    expect(find.text('1/3 weight'), findsNWidgets(3));
  });
}
