import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/screens/provider_browse_screen.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/property_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/services/review_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  testWidgets('general directory is clear and service filter works on a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requestOpens = 0;

    await tester.pumpWidget(
      AppProviders(
        themeMode: ThemeMode.light,
        onToggleTheme: () {},
        bookingStore: BookingStore(),
        providerStore: ProviderStore(),
        propertyStore: PropertyStore(),
        reviewStore: ReviewStore(),
        messageStore: MessageStore(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProviderBrowseScreen(
              onCreateRequest: () => requestOpens++,
              onViewProfile: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Find a cleaning provider'), findsOneWidget);
    expect(find.text('Recommended for your request'), findsNothing);
    expect(find.text('Eligible for the full requested interval'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Find available providers'));
    expect(requestOpens, 1);

    await tester.scrollUntilVisible(find.text('3 providers'), 120);
    expect(find.text('3 providers'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('service-filter-window')));
    await tester.tap(find.byKey(const Key('service-filter-window')));
    await tester.pumpAndSettle();
    expect(find.text('1 provider'), findsOneWidget);
    expect(find.text('Provider B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
