import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/features/bookings/domain/cleaning_request_flow.dart';
import 'package:rental_app_demo/features/matching/domain/provider_matching.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/screens/new_booking_screen.dart';
import 'package:rental_app_demo/screens/provider_results_screen.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/services/property_store.dart';
import 'package:rental_app_demo/services/review_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  final property = DemoProperty.all.first;
  final service = ServiceTypeOption.all.first;

  CleaningRequestDraft draftAt(DateTime start, {Duration? duration}) =>
      CleaningRequestDraft(
        property: property,
        service: service,
        requestedStart: start,
        duration: duration ?? const Duration(hours: 2),
        instructions: 'Clean the kitchen and bathrooms.',
      );

  DemoBooking blockingBooking(
    DateTime start,
    DateTime end, {
    BookingStatus status = BookingStatus.accepted,
  }) =>
      DemoBooking(
        id: 'block-${start.microsecondsSinceEpoch}',
        property: property.display,
        serviceType: service.label,
        providerName: 'Provider A',
        scheduledStart: start,
        scheduledEnd: end,
        status: status,
        specialInstructions: null,
      );

  group('dynamic alternative windows', () {
    test('preserves duration and ranks equally close windows earlier first',
        () {
      final start = DateTime(2030, 7, 15, 10);
      final draft = draftAt(start);
      final options = const AlternativeWindowService().generate(
        draft: draft,
        providers: [DemoProvider.seeded().first],
        bookings: [blockingBooking(start, start.add(draft.duration))],
        now: DateTime(2030, 7, 14),
      );

      expect(options, [DateTime(2030, 7, 15, 8), DateTime(2030, 7, 15, 12)]);
      for (final option in options) {
        final revised = draft.at(option);
        expect(revised.duration, draft.duration);
        final eligible = const ProviderMatchingService().match(
          providers: [DemoProvider.seeded().first],
          request: revised.matchRequest,
          bookings: [blockingBooking(start, start.add(draft.duration))],
        );
        expect(eligible.rankedProviders, isNotEmpty);
      }
    });

    test('Pending requests never remove a feasible requested interval', () {
      final start = DateTime(2030, 7, 15, 10);
      final draft = draftAt(start);
      final pending = blockingBooking(
        start,
        start.add(draft.duration),
        status: BookingStatus.pending,
      );
      final matches = const ProviderMatchingService().match(
        providers: [DemoProvider.seeded().first],
        request: draft.matchRequest,
        bookings: [pending],
      );

      expect(matches.rankedProviders, isNotEmpty);
    });

    test('does not invent an alternative for an unsupported service', () {
      final draft = CleaningRequestDraft(
        property: property,
        service: ServiceTypeOption.all.firstWhere((s) => s.id == 'move-in'),
        requestedStart: DateTime(2030, 7, 15, 10),
        duration: const Duration(hours: 3),
        instructions: 'Prepare the unit for move-in.',
      );

      expect(
        const AlternativeWindowService().generate(
          draft: draft,
          providers: DemoProvider.seeded(),
          bookings: const [],
          now: DateTime(2030, 7, 14),
        ),
        isEmpty,
      );
    });

    test('returns no alternative when every free period is too short', () {
      final start = DateTime(2030, 7, 15, 10);
      final draft = draftAt(start, duration: const Duration(hours: 5));
      final options = const AlternativeWindowService().generate(
        draft: draft,
        providers: [DemoProvider.seeded().first],
        bookings: [
          blockingBooking(DateTime(2030, 7, 15, 12), DateTime(2030, 7, 15, 14)),
        ],
        now: DateTime(2030, 7, 14),
      );

      expect(options, isEmpty);
    });
  });

  testWidgets('owner selects and reviews a provider before creating a booking',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(850, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bookingStore = BookingStore();
    final providerStore = ProviderStore();
    final draft = draftAt(DateTime(2030, 7, 15, 10));
    SelectedCleaningRequest? selection;

    await tester.pumpWidget(
      AppProviders(
        themeMode: ThemeMode.light,
        onToggleTheme: () {},
        bookingStore: bookingStore,
        providerStore: providerStore,
        propertyStore: PropertyStore(),
        reviewStore: ReviewStore(),
        messageStore: MessageStore(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  selection = await Navigator.of(context)
                      .push<SelectedCleaningRequest>(MaterialPageRoute(
                    builder: (_) => ProviderResultsScreen(draft: draft),
                  ));
                },
                child: const Text('Start request'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start request'));
    await tester.pumpAndSettle();
    expect(find.text('2 eligible providers'), findsOneWidget);
    expect(bookingStore.bookings.length, 5);

    await tester.tap(find.text('Select').first);
    await tester.pumpAndSettle();
    expect(find.text('Review & submit request'), findsOneWidget);
    expect(find.text('Provider A'), findsOneWidget);
    expect(bookingStore.bookings.length, 5);

    await tester.tap(find.text('Submit Pending request'));
    await tester.pumpAndSettle();
    expect(selection?.provider.name, 'Provider A');
    expect(selection?.draft.requestedStart, draft.requestedStart);
    expect(bookingStore.bookings.length, 5);
  });

  testWidgets(
      'alternative selection rechecks eligibility before showing providers',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(850, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bookingStore = BookingStore();
    final start = DateTime(2030, 7, 15, 10);
    for (final providerName in ['Provider A', 'Provider B']) {
      final occupied = bookingStore.add(
        property: property.display,
        serviceType: service.label,
        scheduledStart: start,
        scheduledEnd: start.add(const Duration(hours: 2)),
        providerName: providerName,
      );
      expect(bookingStore.updateStatus(occupied.id, BookingStatus.accepted),
          isTrue);
    }

    await tester.pumpWidget(
      AppProviders(
        themeMode: ThemeMode.light,
        onToggleTheme: () {},
        bookingStore: bookingStore,
        providerStore: ProviderStore(),
        propertyStore: PropertyStore(),
        reviewStore: ReviewStore(),
        messageStore: MessageStore(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ProviderResultsScreen(draft: draftAt(start)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No eligible provider for this interval'), findsOneWidget);
    expect(find.text('Feasible alternative windows'), findsOneWidget);
    expect(find.text('2 eligible providers'), findsNothing);

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('3 eligible providers'), findsOneWidget);
    expect(find.text('No eligible provider for this interval'), findsNothing);
  });

  testWidgets(
      'the complete owner flow saves one provider-directed Pending request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(850, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bookingStore = BookingStore();

    await tester.pumpWidget(
      AppProviders(
        themeMode: ThemeMode.light,
        onToggleTheme: () {},
        bookingStore: bookingStore,
        providerStore: ProviderStore(),
        propertyStore: PropertyStore(),
        reviewStore: ReviewStore(),
        messageStore: MessageStore(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewBookingScreen()),
                ),
                child: const Text('Start request'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start request'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DemoProperty>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(property.display).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ServiceTypeOption>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(service.label).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(
        find.byType(TextFormField), 'Clean the kitchen and both bathrooms.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Find suitable providers'));
    await tester.pumpAndSettle();
    expect(find.text('2 eligible providers'), findsOneWidget);
    expect(bookingStore.bookings.length, 5);

    await tester.tap(find.text('Select').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Pending request'));
    await tester.pumpAndSettle();

    expect(bookingStore.bookings.length, 6);
    final created = bookingStore.bookings.first;
    expect(created.status, BookingStatus.pending);
    expect(created.providerName, 'Provider A');
    expect(created.property, property.display);
    expect(
        created.specialInstructions, 'Clean the kitchen and both bathrooms.');
  });
}
