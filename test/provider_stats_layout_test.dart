import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/models/local_preview_data.dart';
import 'package:rental_app_demo/screens/provider_stats_screen.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/property_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/services/review_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('weekly trend fits ${size.width}px in $mode', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final providers = ProviderStore();
        final properties = PropertyStore();
        final bookings = BookingStore(
          providerStore: providers,
          propertyStore: properties,
          initialBookings: LocalPreviewData.bookings(),
        );

        await tester.pumpWidget(AppProviders(
          themeMode: mode,
          onToggleTheme: () {},
          bookingStore: bookings,
          providerStore: providers,
          propertyStore: properties,
          reviewStore: ReviewStore(),
          messageStore: MessageStore(),
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            home: const ProviderStatsScreen(),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Jobs completed (last 4 weeks)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
