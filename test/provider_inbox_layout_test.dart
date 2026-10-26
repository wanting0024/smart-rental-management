import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/screens/provider_inbox_screen.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/property_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/services/review_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  testWidgets('provider inbox stays readable on a short narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = ProviderStore();
    final properties = PropertyStore();
    final bookings = BookingStore(
      providerStore: providers,
      propertyStore: properties,
    );

    await tester.pumpWidget(AppProviders(
      themeMode: ThemeMode.light,
      onToggleTheme: () {},
      bookingStore: bookings,
      providerStore: providers,
      propertyStore: properties,
      reviewStore: ReviewStore(),
      messageStore: MessageStore(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ProviderInboxScreen(showShell: false)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('At a glance'), findsOneWidget);
    expect(find.text('RM 0'), findsOneWidget);
    expect(find.text('New requests'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final headingBefore = tester.getTopLeft(find.text('At a glance')).dy;
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('At a glance')).dy,
        lessThan(headingBefore));
    expect(find.text('Accept'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider inbox counts only the selected provider jobs',
      (tester) async {
    final providers = ProviderStore();
    final properties = PropertyStore();
    final bookings = BookingStore(
      providerStore: providers,
      propertyStore: properties,
    );

    await tester.pumpWidget(AppProviders(
      themeMode: ThemeMode.light,
      onToggleTheme: () {},
      bookingStore: bookings,
      providerStore: providers,
      propertyStore: properties,
      reviewStore: ReviewStore(),
      messageStore: MessageStore(),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: ProviderInboxScreen(provider: DemoProvider.seeded()[1]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('New (0)'), findsOneWidget);
    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('Done (0)'), findsOneWidget);
    expect(find.text('No new requests'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
