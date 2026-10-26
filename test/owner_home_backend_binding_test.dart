import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/owner_home_screen.dart';
import 'package:rental_app_demo/screens/owner_workspace_dashboard.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';
import 'package:rental_app_demo/services/backend/workspace_binding.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/workspace_actions.dart';

Map<String, dynamic> _row(String id) => {
      'booking_id': id,
      'current_status': 'Pending',
      'unit_name': 'Server unit $id',
      'building_name': 'Server building',
      'service_name': 'Server cleaning',
      'requested_start_at': '2026-10-28T02:00:00Z',
      'requested_end_at': '2026-10-28T04:00:00Z',
    };

const _summary = OwnerDashboardSnapshot(
    propertyCount: 7, pendingCount: 41, activeCount: 22, completedCount: 13);
const _next = PageCursor('2026-10-20T00:00:00Z', 'older');

WorkspaceBinding _binding({
  Future<CursorPage<Map<String, dynamic>>> Function(PageCursor?)? load,
  Future<dynamic> Function()? overview,
}) =>
    WorkspaceBinding(
      provider: false,
      feed: CursorFeed<Map<String, dynamic>>(
        active: false,
        idOf: (row) => row['booking_id'] as String,
        compare: (a, b) =>
            (a['booking_id'] as String).compareTo(b['booking_id'] as String),
        loadPage:
            load ?? (_) async => CursorPage(items: [_row('one')], next: _next),
      ),
      loadOverview: overview ?? () async => _summary,
    );

// Routes are recorded here; feed and summary binding are the real implementation.
class _Actions implements WorkspaceActions {
  int requests = 0;
  int propertyCreates = 0, propertyRoutes = 0, profileRoutes = 0;
  @override
  Future<void> properties(BuildContext context) async => propertyRoutes++;
  @override
  Future<void> profile(BuildContext context, {bool edit = false}) async =>
      profileRoutes++;
  int signOuts = 0;
  int messageRoutes = 0;
  int browseRoutes = 0;
  @override
  Future<void> browse(BuildContext context) async => browseRoutes++;
  @override
  Future<void> messages(BuildContext context) async => messageRoutes++;
  String? bookingId;
  bool failRequest = false;
  final unavailableLabels = <String>[];

  @override
  Future<void> request(BuildContext context) async {
    requests++;
    if (failRequest) throw StateError('private route failure');
  }

  @override
  Future<void> addProperty(BuildContext context) async => propertyCreates++;

  @override
  Future<void> booking(BuildContext context, String id) async => bookingId = id;

  @override
  Future<void> signOut(BuildContext context) async => signOuts++;

  @override
  void unavailable(BuildContext context, String label) {
    unavailableLabels.add(label);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label is not connected yet.')));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, WorkspaceBinding binding,
    {WorkspaceActions? actions, bool dark = false}) async {
  tester.view.physicalSize = const Size(320, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final session = UserSession()
    ..signIn(
        email: 'owner@example.test',
        displayName: 'Real Owner',
        role: UserRole.owner);
  addTearDown(session.dispose);
  // Deliberately omit AppProviders: connected mode must never need local stores.
  await tester.pumpWidget(UserSessionAccess(
    session: session,
    child: MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: OwnerHomeScreen(binding: binding, actions: actions),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _nav(String text) => find.descendant(
    of: find.byType(OwnerWorkspaceNav), matching: find.text(text));

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
  });

  for (final dark in [false, true]) {
    testWidgets(
        '320px ${dark ? 'dark' : 'light'} keeps original design and server totals',
        (tester) async {
      final binding = _binding();
      addTearDown(binding.dispose);
      binding.setActive(true); // Activity remains owned by the caller.
      await _pump(tester, binding, dark: dark);

      expect(find.byType(OwnerWorkspaceDashboard), findsOneWidget);
      expect(find.text('Owner Dashboard'), findsOneWidget);
      expect(find.text('Ready for your next cleaning?'), findsOneWidget);
      expect(find.text('41'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.textContaining('Earliest appointment first'), findsOneWidget);
      for (final label in [
        'Home',
        'Properties',
        'Providers',
        'Bookings',
        'Profile'
      ]) {
        expect(_nav(label), findsOneWidget);
      }
      expect(find.text('Provider demo'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('real feed refresh, pagination, search, and server booking ID',
      (tester) async {
    var heads = 0;
    var more = 0;
    final binding = _binding(load: (cursor) async {
      if (cursor == null) {
        heads++;
        return CursorPage(items: [_row('one')], next: _next);
      }
      more++;
      return CursorPage(items: [_row('two')]);
    });
    final actions = _Actions();
    addTearDown(binding.dispose);
    binding.setActive(true);
    await _pump(tester, binding, actions: actions);
    final initialHeads = heads;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(heads, initialHeads + 1);
    await tester.ensureVisible(find.text('Load more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(more, 1);
    await tester.scrollUntilVisible(find.text('2 bookings shown.'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('2 bookings shown.'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    await tester.tap(_nav('Bookings'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Search and filters apply to bookings shown below. Show more to include older bookings.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Server unit two');
    await tester.pumpAndSettle();
    expect(find.text('1 result shown'), findsOneWidget);
    expect(find.text('Server unit one, Server building'), findsNothing);
    await tester.tap(find.text('Server unit two, Server building'));
    await tester.pumpAndSettle();
    expect(actions.bookingId, 'two');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Home has one request action, primary tabs and a Messages utility',
      (tester) async {
    final binding = _binding();
    final actions = _Actions();
    addTearDown(binding.dispose);
    binding.setActive(true);
    await _pump(tester, binding, actions: actions);
    await tester.tap(find.text('Request cleaning'));
    await tester.pumpAndSettle();
    expect(actions.requests, 1);
    await tester.tap(_nav('Providers'));
    await tester.pumpAndSettle();
    expect(actions.browseRoutes, 1);
    expect(find.text('Find providers'), findsNothing);
    expect(find.text('Quick actions'), findsNothing);
    expect(actions.requests, 1);
    await tester.tap(find.byTooltip('Messages'));
    await tester.pumpAndSettle();
    expect(actions.messageRoutes, 1);
    expect(find.text('Add rental unit'), findsNothing);
    await tester.tap(_nav('Properties'));
    await tester.pumpAndSettle();
    expect(actions.propertyRoutes, 1);
    expect(find.byTooltip('More owner options'), findsNothing);
    expect(find.text('Provider demo'), findsNothing);
    await tester.tap(_nav('Profile'));
    await tester.pumpAndSettle();
    expect(actions.profileRoutes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route failures and unavailable destinations never open demo UI',
      (tester) async {
    final binding = _binding();
    final actions = _Actions()..failRequest = true;
    addTearDown(binding.dispose);
    binding.setActive(true);
    await _pump(tester, binding, actions: actions);
    await tester.tap(find.text('Request cleaning'));
    await tester.pumpAndSettle();
    expect(find.text('Could not complete this action. Please try again.'),
        findsOneWidget);
    expect(find.textContaining('private route failure'), findsNothing);
    await tester.tap(_nav('Profile'));
    await tester.pumpAndSettle();
    expect(actions.profileRoutes, 1);
    expect(actions.unavailableLabels, isEmpty);
    expect(find.byType(OwnerWorkspaceDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed overview shows unknown totals and supports real retry',
      (tester) async {
    var fail = true;
    final binding = _binding(overview: () async {
      if (fail) throw StateError('private backend details');
      return _summary;
    });
    addTearDown(binding.dispose);
    binding.setActive(true);
    await _pump(tester, binding);
    expect(find.text('—'), findsNWidgets(3));
    expect(find.textContaining('private backend details'), findsNothing);
    expect(find.text('No open booking yet. Start a cleaning request.'),
        findsNothing);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('41'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid server projections show error without reading bookings',
      (tester) async {
    final binding = _binding(
        load: (_) async => CursorPage(items: [
              {..._row('broken'), 'current_status': 'Invalid'},
            ]));
    addTearDown(binding.dispose);
    binding.setActive(true);
    await _pump(tester, binding);
    expect(find.textContaining('Could not refresh your workspace'),
        findsOneWidget);
    expect(find.text('Server cleaning'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
