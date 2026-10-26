import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/models/demo_data.dart';
import 'package:rental_app_demo/screens/provider_inbox_screen.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/workspace_binding.dart';
import 'package:rental_app_demo/services/booking_store.dart';
import 'package:rental_app_demo/services/message_store.dart';
import 'package:rental_app_demo/services/property_store.dart';
import 'package:rental_app_demo/services/provider_store.dart';
import 'package:rental_app_demo/services/review_store.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/workspace_actions.dart';

Map<String, dynamic> row(String id, {String status = 'Pending'}) => {
      'booking_id': id,
      'current_status': status,
      'unit_name': 'Server unit $id',
      'building_name': 'Server building',
      'service_name': 'Cleaning',
      'requested_start_at': '2030-01-01T01:00:00Z',
      'requested_end_at': '2030-01-01T03:00:00Z',
    };

WorkspaceBinding bindingFor(
  Future<CursorPage<Map<String, dynamic>>> Function(PageCursor?) load,
) =>
    WorkspaceBinding(
      provider: true,
      feed: CursorFeed<Map<String, dynamic>>(
        active: false,
        loadPage: load,
        idOf: (item) => item['booking_id'] as String,
        compare: (a, b) =>
            (a['booking_id'] as String).compareTo(b['booking_id'] as String),
      ),
      loadOverview: () async => {
        'approval_status': 'approved',
        'rating_average': 4.75,
        'completed_job_count': 42,
      },
    );

class RecordingActions implements WorkspaceActions {
  String? opened;
  @override
  Future<void> messages(BuildContext context) async {
    opened = 'messages';
  }

  @override
  Future<void> notifications(BuildContext context) async {
    opened = 'notifications';
  }

  @override
  Future<void> about(BuildContext context) async {
    opened = 'about';
  }

  @override
  Future<void> profile(BuildContext context, {bool edit = false}) async {
    opened = edit ? 'edit-profile' : 'profile';
  }

  @override
  Future<void> booking(BuildContext context, String id) async {
    opened = id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> mount(
  WidgetTester tester,
  WorkspaceBinding binding, {
  WorkspaceActions? actions,
  bool dark = false,
  bool showShell = false,
}) async {
  binding.setActive(true);
  Widget screen = ProviderInboxScreen(
    binding: binding,
    actions: actions,
    // A preview name must never filter authenticated server rows.
    provider: DemoProvider.seeded()[1],
    showShell: showShell,
  );
  if (!showShell) screen = Scaffold(body: screen);
  Widget app = MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: screen,
  );
  if (showShell) {
    final session = UserSession();
    final bookings = BookingStore(initialBookings: []);
    final providers = ProviderStore();
    final properties = PropertyStore();
    final reviews = ReviewStore();
    final messages = MessageStore();
    for (final resource in <ChangeNotifier>[
      session,
      bookings,
      providers,
      properties,
      reviews,
      messages,
    ]) {
      addTearDown(resource.dispose);
    }
    app = UserSessionAccess(
      session: session,
      child: AppProviders(
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        onToggleTheme: () {},
        bookingStore: bookings,
        providerStore: providers,
        propertyStore: properties,
        reviewStore: reviews,
        messageStore: messages,
        child: app,
      ),
    );
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  // NestedScrollView must collapse its header before the lazy inner list can
  // build or expose the target. ensureVisible alone cannot do both reliably.
  await tester.scrollUntilVisible(
    target.hitTestable(),
    160,
    scrollable: find
        .descendant(
          of: find.byType(NestedScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 20,
  );
  await tester.pumpAndSettle();
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: 'The target must be built and reachable through actual scrolling.',
  );
}

void main() {
  testWidgets('real Inbox bell and About drawer route are connected',
      (tester) async {
    final binding = bindingFor((_) async => const CursorPage(items: []));
    final actions = RecordingActions();
    await mount(tester, binding, actions: actions, showShell: true);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(actions.opened, 'notifications');
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('About & help'), 180,
        scrollable: find
            .descendant(
                of: find.byType(Drawer), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('About & help'));
    await tester.pumpAndSettle();
    expect(actions.opened, 'about');

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Messages'), 180,
        scrollable: find
            .descendant(
                of: find.byType(Drawer), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(actions.opened, 'messages');
    expect(find.textContaining('not connected yet'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    binding.dispose();
  });
  for (final state in ['empty', 'populated', 'error']) {
    testWidgets(
        'pulling Inbox header refreshes $state state without a refresh button',
        (tester) async {
      var reads = 0;
      final binding = bindingFor((_) async {
        final call = ++reads;
        if (state == 'error' && call == 1) throw StateError('offline');
        if (state == 'empty' && call == 1) return const CursorPage(items: []);
        return CursorPage(items: [row(call == 1 ? 'before' : 'fresh')]);
      });
      await mount(tester, binding);
      expect(reads, 1);
      expect(find.text('Refresh inbox'), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.dragFrom(
          tester.getCenter(find.text('Your cleaning work, in one place.')),
          const Offset(0, 420));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(binding.bookings.single.id, 'fresh');
      expect(binding.error, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      binding.dispose();
    });
  }
  testWidgets(
      'every empty job tab supports pull to refresh with one request per gesture',
      (tester) async {
    var reads = 0;
    final binding = bindingFor((_) async {
      reads++;
      return const CursorPage(items: []);
    });
    await mount(tester, binding);
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    for (var index = 0; index < 4; index++) {
      tabs.controller!.animateTo(index);
      await tester.pumpAndSettle();
      final scroll = find.byType(ListView).hitTestable();
      // Expose the empty list, then expand the header back to its top boundary.
      final nested =
          tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
      nested.outerController
          .jumpTo(nested.outerController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(scroll, findsOneWidget);
      await tester.drag(scroll, const Offset(0, 500));
      await tester.pumpAndSettle();
      // Once at the very top, a further pull refreshes the selected tab.
      if (reads == index + 1) {
        await tester.drag(scroll, const Offset(0, 420));
        await tester.pumpAndSettle();
      }
      expect(reads, index + 2);
      expect(tester.takeException(), isNull);
    }
    tabs.controller!.animateTo(0);
    await tester.pumpAndSettle();
    final nested =
        tester.state<NestedScrollViewState>(find.byType(NestedScrollView));
    nested.outerController
        .jumpTo(nested.outerController.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TabBarView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(tabs.controller!.index, 1);
    expect(reads, 5); // Horizontal tab swipes must not request a refresh.
    await tester.pumpWidget(const SizedBox());
    binding.dispose();
  });
  testWidgets(
      'connected bottom Profile opens original-profile route rather than setup',
      (tester) async {
    final binding = bindingFor((_) async => const CursorPage(items: []));
    final actions = RecordingActions();
    await mount(tester, binding, actions: actions, showShell: true);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(actions.opened, 'profile');
    await tester.pumpWidget(const SizedBox());
    binding.dispose();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'coachmark_seen_provider_inbox_v1': true,
    });
  });
  testWidgets(
      'server cards ignore preview identity and review uses shared actions',
      (tester) async {
    final binding = bindingFor((_) async => CursorPage(items: [row('one')]));
    addTearDown(binding.dispose);
    final actions = RecordingActions();
    await mount(tester, binding, actions: actions);

    expect(find.text('Your cleaning work, in one place.'), findsOneWidget);
    expect(find.text('At a glance'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Rating 4.75 · 42 completed jobs'), findsOneWidget);
    expect(find.text('Open Earnings'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    await reveal(tester, find.text('Review request'));
    await tester.tap(find.text('Review request'));
    expect(actions.opened, 'one');
    expect(binding.bookings.single.status, BookingStatus.pending);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'malformed server projections render an error before reading cards',
      (tester) async {
    final binding = bindingFor(
      (_) async => CursorPage(
        items: [
          row('invalid', status: 'Unsupported status'),
        ],
      ),
    );
    addTearDown(binding.dispose);
    await mount(tester, binding, showShell: true);

    expect(binding.error, isA<FormatException>());
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('New (—)'),
      ),
      findsOneWidget,
    );
    await reveal(tester, find.text('Could not load inbox'));
    expect(find.text('Could not load inbox'), findsOneWidget);
    expect(find.textContaining('Unsupported status'), findsNothing);
    expect(find.text('Review request'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial counts and paging retry retain server cards',
      (tester) async {
    var nextCalls = 0;
    final binding = bindingFor((cursor) async {
      if (cursor == null) {
        return CursorPage(
          items: [row('one')],
          next: const PageCursor('2030-01-01T01:00:00Z', 'one'),
        );
      }
      if (nextCalls++ == 0) throw StateError('private transport diagnostic');
      return CursorPage(items: [row('two')]);
    });
    addTearDown(binding.dispose);
    await mount(tester, binding, showShell: true);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('New (1+)'),
      ),
      findsOneWidget,
    );
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabs.labelStyle?.fontFamily, 'Inter');
    expect(tabs.unselectedLabelStyle?.fontFamily, 'Inter');
    await reveal(tester, find.text('Load more jobs'));
    await tester.tap(find.text('Load more jobs'));
    await tester.pumpAndSettle();
    expect(binding.bookings, hasLength(1));
    expect(find.text('Retry load more'), findsOneWidget);
    expect(find.textContaining('private transport diagnostic'), findsNothing);
    await reveal(tester, find.text('Retry load more'));
    await tester.tap(find.text('Retry load more'));
    await tester.pumpAndSettle();
    expect(binding.bookings, hasLength(2));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('New (2)'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('original hero and cards fit a narrow dark connected workspace',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final binding = bindingFor((_) async => CursorPage(items: [row('dark')]));
    addTearDown(binding.dispose);
    await mount(tester, binding, dark: true);

    expect(find.text('Your cleaning work, in one place.'), findsOneWidget);
    expect(find.text('At a glance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Review request'));
    await tester.pumpAndSettle();
    expect(find.text('Server unit dark, Server building'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    // Widget removal must leave caller-owned binding usable.
    await binding.refresh();
    expect(binding.bookings, hasLength(1));
  });
}
