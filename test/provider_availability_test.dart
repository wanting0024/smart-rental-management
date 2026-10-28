import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/time_slot_steps.dart';
import 'package:rental_app_demo/features/availability/domain/provider_availability.dart';
import 'package:rental_app_demo/features/bookings/domain/cleaning_request_flow.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/screens/provider_availability_screen.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  final date = DateTime(2030, 7, 17); // Wednesday.
  final provider = DemoProvider.seeded().first;
  final draft = CleaningRequestDraft(
    property: DemoProperty.all.first,
    service: ServiceTypeOption.all.first,
    requestedStart: DateTime(2030, 7, 17, 10),
    duration: const Duration(hours: 2),
    instructions: 'Clean before move-in.',
  );

  test('edited weekly slots control matching and alternative windows', () {
    final store = ProviderStore();
    store.setWeeklySlots(provider.id, date.weekday, const [
      AvailabilitySlot(8 * 60, 10 * 60),
      AvailabilitySlot(14 * 60, 17 * 60),
    ]);

    final result = store.matchProviders(
      request: draft.matchRequest,
      bookings: const [],
    );
    expect(
        result.rankedProviders.map((item) => item.id), isNot(contains('p-a')));

    final options = const AlternativeWindowService().generate(
      draft: draft,
      providers: [store.byId(provider.id)!],
      bookings: const [],
      now: DateTime(2030, 7, 16),
    );
    expect(options, [
      DateTime(2030, 7, 17, 8),
      DateTime(2030, 7, 17, 14),
    ]);
  });

  test('edited slots can make a previously partial provider eligible', () {
    final store = ProviderStore();
    store.setWeeklySlots('p-c', date.weekday, const [
      AvailabilitySlot(8 * 60, 18 * 60),
    ]);

    final result = store.matchProviders(
      request: draft.matchRequest,
      bookings: const [],
    );
    expect(result.rankedProviders.map((item) => item.id), contains('p-c'));
  });

  test('unavailable date overrides weekly slots and can be removed', () {
    final store = ProviderStore();
    store.setUnavailableDate(provider.id, date, true);
    expect(
        store
            .byId(provider.id)!
            .availabilitySchedule
            .covers(draft.requestedStart, draft.requestedEnd),
        isFalse);
    expect(
      const AlternativeWindowService().generate(
        draft: draft,
        providers: [store.byId(provider.id)!],
        bookings: const [],
        now: DateTime(2030, 7, 16),
      ),
      isEmpty,
    );

    store.setUnavailableDate(provider.id, date, false);
    expect(
        store
            .byId(provider.id)!
            .availabilitySchedule
            .covers(draft.requestedStart, draft.requestedEnd),
        isTrue);
  });

  test('overlapping weekly slots are rejected without changing the store', () {
    final store = ProviderStore();
    final before = store.byId(provider.id)!.availabilitySchedule;
    expect(
      () => store.setWeeklySlots(provider.id, date.weekday, const [
        AvailabilitySlot(8 * 60, 12 * 60),
        AvailabilitySlot(11 * 60, 14 * 60),
      ]),
      throwsArgumentError,
    );
    expect(store.byId(provider.id)!.availabilitySchedule, same(before));
  });

  test('working slots shorter than two hours are rejected', () {
    final store = ProviderStore();
    final before = store.byId(provider.id)!.availabilitySchedule;
    expect(
      () => store.setWeeklySlots(provider.id, 2, const [
        AvailabilitySlot(19 * 60, 19 * 60 + 10),
      ]),
      throwsArgumentError,
    );
    expect(store.byId(provider.id)!.availabilitySchedule, same(before));
    expect(const AvailabilitySlot(19 * 60, 20 * 60).isValid, isFalse);
    expect(const AvailabilitySlot(19 * 60, 21 * 60).isValid, isTrue);
  });

  test('acceptance locally rechecks changed availability before confirmation',
      () {
    final providers = ProviderStore();
    final bookings = BookingStore(providerStore: providers);
    final booking = bookings.add(
      property: DemoProperty.all.first.display,
      serviceType: ServiceTypeOption.all.first.label,
      scheduledStart: draft.requestedStart,
      scheduledEnd: draft.requestedEnd,
      providerName: provider.name,
    );
    providers.setUnavailableDate(provider.id, date, true);

    final rejected = bookings.acceptPending(booking.id);
    expect(rejected.failure, BookingAcceptanceFailure.providerUnavailable);
    expect(bookings.byId(booking.id)!.status, BookingStatus.pending);

    providers.setUnavailableDate(provider.id, date, false);
    expect(bookings.acceptPending(booking.id).accepted, isTrue);
    expect(bookings.byId(booking.id)!.status, BookingStatus.accepted);
  });

  test('acceptance locally rechecks the rental-unit cleaning window', () {
    final providers = ProviderStore();
    providers.setWeeklySlots(provider.id, date.weekday, const [
      AvailabilitySlot(7 * 60, 20 * 60),
    ]);
    final bookings = BookingStore(providerStore: providers);
    final booking = bookings.add(
      property: DemoProperty.all.first.display,
      serviceType: ServiceTypeOption.all.first.label,
      scheduledStart: DateTime(2030, 7, 17, 7),
      scheduledEnd: DateTime(2030, 7, 17, 9),
      providerName: provider.name,
    );

    final rejected = bookings.acceptPending(booking.id);
    expect(rejected.failure, BookingAcceptanceFailure.rentalWindowIncompatible);
    expect(bookings.byId(booking.id)!.status, BookingStatus.pending);
  });

  testWidgets('provider can see weekly slots and date exceptions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ProviderStore();
    await tester.pumpWidget(MaterialApp(
      home: ProviderAvailabilityScreen(store: store, providerId: provider.id),
    ));
    expect(find.text('Weekly working slots'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Add unavailable date'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Add unavailable date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('availability editor stays readable when a day is expanded',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ProviderStore();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ProviderAvailabilityScreen(store: store, providerId: provider.id),
    ));
    await tester.pumpAndSettle();

    expect(find.text('7 active days'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Monday'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();
    expect(find.text('Add working slot'), findsOneWidget);
    expect(find.byTooltip('Remove slot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider adds a slot without the clock picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ProviderStore();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ProviderAvailabilityScreen(store: store, providerId: provider.id),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Monday'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add working slot'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('slot-start-time')), findsOneWidget);
    expect(find.byKey(const Key('slot-end-time')), findsOneWidget);
    Future<void> selectField(String key, int minute) async {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await chooseTimeSlot(tester, minute);
    }

    await selectField('slot-start-time', 480);
    await selectField('slot-end-time', 600);
    await tester.ensureVisible(find.text('Save working slot'));
    await tester.tap(find.text('Save working slot'));
    await tester.pumpAndSettle();
    expect(
        find.text('This slot overlaps another working slot.'), findsOneWidget);
    expect(store.byId(provider.id)!.availabilitySchedule.weeklySlots[1]!.length,
        1);

    await selectField('slot-start-time', 360);
    await selectField('slot-end-time', 480);
    await tester.ensureVisible(find.text('Save working slot'));
    await tester.tap(find.text('Save working slot'));
    await tester.pumpAndSettle();

    final slots = store.byId(provider.id)!.availabilitySchedule.weeklySlots[1]!;
    expect(slots.length, 2);
    expect(slots.first.startMinute, 6 * 60);
    expect(slots.first.endMinute, 8 * 60);
    expect(tester.takeException(), isNull);
  });
}
