import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/screens/new_booking_screen.dart';
import 'package:rental_app_demo/screens/property_form_screen.dart';
import 'package:rental_app_demo/screens/property_list_screen.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/property_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/services/review_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'support/owner_uat_steps.dart';

void main() {
  const windowStart = TimeOfDay(hour: 8, minute: 0);
  const windowEnd = TimeOfDay(hour: 18, minute: 0);

  test('a registered property becomes available in the local owner store', () {
    final store = PropertyStore();
    final result = store.add(
      unit: 'F-16',
      tower: 'Vista Bayu',
      address: 'Demo address, Kuala Lumpur',
      bedrooms: 2,
      sizeSqft: 850,
      cleaningWindowStart: windowStart,
      cleaningWindowEnd: windowEnd,
    );
    expect(result.saved, isTrue);
    expect(store.properties.length, 6);
    expect(store.byDisplay('Unit F-16, Vista Bayu')?.address,
        'Demo address, Kuala Lumpur');
    expect(
      store
          .add(
            unit: 'f-16',
            tower: 'VISTA BAYU',
            address: 'Another address',
            bedrooms: 2,
            sizeSqft: 850,
            cleaningWindowStart: windowStart,
            cleaningWindowEnd: windowEnd,
          )
          .failure,
      PropertySaveFailure.duplicateUnit,
    );
  });

  test('a booked property keeps its identity while other details can change',
      () {
    final store = PropertyStore();
    final original = store.byId('prop-a12')!;
    final bookings = BookingStore().bookings;

    final renamed = store.update(
      original.copyWith(unit: 'A-13', address: 'Demo address'),
      bookings: bookings,
    );
    expect(renamed.failure, PropertySaveFailure.bookedIdentity);
    expect(store.byId(original.id)!.display, original.display);

    final edited = store.update(
      original.copyWith(address: 'Demo address', sizeSqft: 990),
      bookings: bookings,
    );
    expect(edited.saved, isTrue);
    expect(store.byId(original.id)!.sizeSqft, 990);
  });

  test(
      'pending revision rejects invalid owner window, provider hours and overlap',
      () {
    final providers = ProviderStore();
    final properties = PropertyStore();
    final bookings =
        BookingStore(providerStore: providers, propertyStore: properties);
    final original = DateTime(2030, 7, 17, 10);
    final pending = bookings.add(
      property: DemoProperty.all.first.display,
      serviceType: 'Standard cleaning',
      scheduledStart: original,
      scheduledEnd: original.add(const Duration(hours: 2)),
      providerName: 'Provider A',
      specialInstructions: 'Original',
    );

    final outsideWindow = DateTime(2030, 7, 17, 7);
    expect(
      bookings.revisePendingBooking(
        id: pending.id,
        newStart: outsideWindow,
        newEnd: outsideWindow.add(const Duration(hours: 2)),
      ),
      isNull,
    );

    providers.setUnavailableDate('p-a', original, true);
    final unavailable = DateTime(2030, 7, 17, 13);
    expect(
      bookings.revisionError(
        id: pending.id,
        newStart: unavailable,
        newEnd: unavailable.add(const Duration(hours: 2)),
      ),
      contains('unavailable'),
    );
    providers.setUnavailableDate('p-a', original, false);

    final accepted = bookings.add(
      property: DemoProperty.all.first.display,
      serviceType: 'Standard cleaning',
      scheduledStart: DateTime(2030, 7, 17, 14),
      scheduledEnd: DateTime(2030, 7, 17, 16),
      providerName: 'Provider A',
    );
    expect(bookings.acceptPending(accepted.id).accepted, isTrue);
    expect(
      bookings.revisionError(
        id: pending.id,
        newStart: DateTime(2030, 7, 17, 15),
        newEnd: DateTime(2030, 7, 17, 17),
      ),
      contains('conflicts'),
    );
    expect(bookings.byId(pending.id)!.scheduledStart, original);
    expect(bookings.byId(pending.id)!.status, BookingStatus.pending);

    final valid = bookings.revisePendingBooking(
      id: pending.id,
      newStart: DateTime(2030, 7, 17, 16),
      newEnd: DateTime(2030, 7, 17, 18),
      specialInstructions: 'Updated',
    );
    expect(valid?.status, BookingStatus.pending);
    expect(valid?.specialInstructions, 'Updated');
  });

  testWidgets('property form remains usable at a narrow phone size',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: PropertyFormScreen(store: PropertyStore(), bookings: const []),
    ));
    expect(find.text('Property address'), findsOneWidget);
    expect(find.text('Add property'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('property statistics roll up registered units and update',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final properties = PropertyStore();
    final providers = ProviderStore();
    final bookings =
        BookingStore(providerStore: providers, propertyStore: properties);

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
        home: PropertyListScreen(bookings: bookings.bookings),
      ),
    ));
    await tester.pumpAndSettle();

    List<String?> valuesFor(String key) => tester
        .widgetList<Text>(find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(Text),
        ))
        .map((text) => text.data)
        .toList();

    expect(valuesFor('property-stats-Menara Suria'),
        ['Menara Suria', '4', '1', '5']);
    expect(
        valuesFor('property-stats-Vista Bayu'), ['Vista Bayu', '0', '0', '0']);
    expect(
        valuesFor('property-stats-total'), ['All properties', '4', '1', '5']);

    bookings.add(
      property: 'Unit E-15, Vista Bayu',
      serviceType: 'Routine cleaning',
      scheduledStart: DateTime(2030, 7, 14, 9),
      scheduledEnd: DateTime(2030, 7, 14, 11),
      providerName: 'Provider A',
    );
    await tester.pumpAndSettle();

    expect(
        valuesFor('property-stats-Vista Bayu'), ['Vista Bayu', '1', '0', '1']);
    expect(
        valuesFor('property-stats-total'), ['All properties', '5', '1', '6']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newly added unit appears in the booking property picker',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final properties = PropertyStore();
    final providers = ProviderStore();
    final bookings =
        BookingStore(providerStore: providers, propertyStore: properties);
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidget(AppProviders(
      themeMode: ThemeMode.light,
      onToggleTheme: () {},
      bookingStore: bookings,
      providerStore: providers,
      propertyStore: properties,
      reviewStore: ReviewStore(),
      messageStore: MessageStore(),
      child: MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.light(),
        home: PropertyListScreen(bookings: bookings.bookings),
      ),
    ));

    await tester.tap(find.byTooltip('Add property').first);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'F-16');
    await tester.enterText(fields.at(1), 'Vista Bayu');
    await tester.enterText(fields.at(2), 'Demo address, Kuala Lumpur');
    await chooseBedrooms(tester, 2);
    await tester.ensureVisible(fields.last);
    await tester.enterText(fields.last, '850');
    await tester.ensureVisible(find.text('Add property').last);
    await tester.tap(find.text('Add property').last);
    await tester.pumpAndSettle();
    expect(properties.byDisplay('Unit F-16, Vista Bayu'), isNotNull);
    expect(find.text('6 properties'), findsOneWidget);

    navigator.currentState!.push(
      MaterialPageRoute(builder: (_) => const NewBookingScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DemoProperty>));
    await tester.pumpAndSettle();
    expect(find.text('Unit F-16, Vista Bayu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
