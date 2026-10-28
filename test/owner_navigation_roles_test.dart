import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/screens/owner_home_screen.dart';
import 'package:rental_app_demo/screens/owner_records_view.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/owner_navigation_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

const actor = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const provider = {
  'provider_id': 'provider-1',
  'listed_at': '2026-10-01T00:00:00Z',
  'display_name': 'Suria Cleaning',
  'bio': 'Cleaning for rental units.',
  'service_area': 'Kuala Lumpur',
  'hourly_rate': 40,
  'daily_rate': 280,
  'rating_average': null,
  'completed_job_count': 2,
  'services': [
    {
      'name': 'Standard cleaning',
      'description': 'Floors and accessible surfaces.'
    }
  ],
};
const booking = {
  'booking_id': 'booking-1',
  'created_at': '2026-10-01T00:00:00Z',
  'unit_name': 'A-12',
  'building_name': 'Menara Suria',
  'service_name': 'Standard cleaning',
  'current_status': 'Completed',
  'requested_start_at': '2026-11-01T01:00:00Z',
  'requested_end_at': '2026-11-01T03:00:00Z',
};

class _Auth extends GoTrueClient {
  _Auth()
      : super(url: 'https://fixture.invalid/auth/v1', autoRefreshToken: false);
  String? actorId = actor;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  @override
  User? get currentUser => actorId == null
      ? null
      : User(
          id: actorId!,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01');
}

class _Client extends SupabaseClient {
  _Client(this.fixture, http.Client transport)
      : super('https://fixture.invalid', 'test-key',
            httpClient: transport,
            authOptions: const AuthClientOptions(autoRefreshToken: false));
  final _Auth fixture;
  @override
  GoTrueClient get auth => fixture;
}

Widget app(Widget home, {bool dark = false, double scale = 1}) => MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: home);
void phone(WidgetTester tester, {bool short = false}) {
  tester.view.physicalSize =
      short ? const Size(320, 568) : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

CursorFeed<Map<String, dynamic>> feed(List<Map<String, dynamic>> items,
        {Future<CursorPage<Map<String, dynamic>>> Function(PageCursor?)?
            load}) =>
    CursorFeed(
        active: false,
        loadPage: load ?? (_) async => CursorPage(items: items),
        idOf: (r) => (r['booking_id'] ?? r['provider_id']) as String,
        compare: (_, __) => 0);
Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('output/owner-navigation-ui').create(recursive: true);
    await File('output/owner-navigation-ui/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      final parent = sdk.parent;
      if (parent.path == sdk.path)
        throw StateError('Flutter fonts unavailable');
      sdk = parent;
    }
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf'
    }.entries) {
      await (FontLoader(entry.key)
            ..addFont(Future.value(ByteData.sublistView(await File(
                    '${sdk.path}/bin/cache/artifacts/material_fonts/${entry.value}')
                .readAsBytes()))))
          .load();
    }
  });
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  test(
      'directory uses bounded filtered RPC, preserves cursor precision and rejects a different actor',
      () async {
    final auth = _Auth();
    final calls = <Map<String, dynamic>>[];
    String returnedActor = actor;
    final client = _Client(auth, MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/page_approved_provider_directory');
      calls.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
          jsonEncode({
            'actor_id': returnedActor,
            'items': [provider],
            'has_more': false
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
    final backend = SupabaseBackendProvider(client);
    final cursor = const PageCursor(
        '2026-10-01T00:00:00.123456Z', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    final directory = OwnerNavigationRepository(backend)
        .open(providers: true, query: ' Standard ');
    expect((await directory.loadPage(cursor)).items.single['display_name'],
        'Suria Cleaning');
    expect(calls.single['p_limit'], 20);
    expect(calls.single['p_query'], 'Standard');
    expect(calls.single['p_before_at'], cursor.timestamp);
    expect(calls.single.containsKey('owner_id'), isFalse);
    returnedActor = 'other';
    await expectLater(directory.loadPage(null), throwsStateError);
    directory.dispose();
    await client.dispose();
    auth.dispose();
  });

  testWidgets(
      'search swaps feeds and ignores a delayed result from the previous query',
      (tester) async {
    final pending = Completer<CursorPage<Map<String, dynamic>>>();
    final queries = <String>[];
    var opens = 0;
    await tester.pumpWidget(app(Scaffold(
        body: OwnerRecordsView(
      providers: false,
      openFeed: (
          {required providers,
          required query,
          required group,
          required oldest}) {
        queries.add('$query/$group/$oldest');
        opens++;
        return feed([],
            load: (_) async => opens == 1
                ? pending.future
                : const CursorPage(items: [booking]));
      },
    ))));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('owner-record-search')), 'A-12');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(queries.last, 'A-12/all/false');
    expect(find.text('A-12, Menara Suria'), findsOneWidget);
    pending.complete(const CursorPage(items: []));
    await tester.pumpAndSettle();
    expect(find.text('A-12, Menara Suria'), findsOneWidget);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    expect(queries.last, 'A-12/history/false');
    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();
    expect(queries.last, 'A-12/history/true');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('provider browsing opens profile and never opens a request form',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Providers')),
              body: OwnerRecordsView(
                providers: true,
                openFeed: (
                        {required providers,
                        required query,
                        required group,
                        required oldest}) =>
                    feed([provider]),
                onProvider: (row) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => OwnerProviderDetails(row: row))),
              ),
            ))));
    await tester.pumpAndSettle();
    expect(find.text('Select service date'), findsNothing);
    expect(find.text('Request cleaning'), findsNothing);
    await tester.ensureVisible(find.text('View profile'));
    await tester.tap(find.text('View profile'));
    await tester.pumpAndSettle();
    expect(find.text('Provider profile'), findsOneWidget);
    expect(find.text('Floors and accessible surfaces.'), findsOneWidget);
    expect(find.textContaining('not a booking quote'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Browse cleaning providers'), findsOneWidget);
  });

  testWidgets(
      'long Unicode search stays in the form without starting an invalid request',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(app(Scaffold(
        body: OwnerRecordsView(
      providers: true,
      openFeed: (
          {required providers,
          required query,
          required group,
          required oldest}) {
        opens++;
        return feed([]);
      },
    ))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('owner-record-search')),
        'e${List.filled(90, '\u0301').join()}');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(
        find.text('Use at most 80 characters in your search.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final providers in [false, true]) {
      testWidgets(
          '${providers ? 'providers' : 'bookings'} fits 320px/200%, failures retry, dark=$dark',
          (tester) async {
        phone(tester, short: true);
        var fails = true, loads = 0;
        await tester.pumpWidget(app(
            Scaffold(
                body: OwnerRecordsView(
              providers: providers,
              openFeed: (
                      {required providers,
                      required query,
                      required group,
                      required oldest}) =>
                  feed([], load: (_) async {
                loads++;
                if (fails) throw StateError('PRIVATE INTERNAL DETAIL');
                return CursorPage(items: [providers ? provider : booking]);
              }),
            )),
            dark: dark,
            scale: 2));
        await tester.pumpAndSettle();
        expect(find.textContaining('PRIVATE INTERNAL DETAIL'), findsNothing);
        await tester.scrollUntilVisible(find.text('Retry').hitTestable(), 160,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        fails = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(loads, 2);
        await tester.scrollUntilVisible(
            find.text(providers ? 'View profile' : 'A-12, Menara Suria'), 140,
            scrollable: find.byType(Scrollable).first);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets(
          '${providers ? 'providers' : 'bookings'} visual preview dark=$dark',
          (tester) async {
        phone(tester);
        final key = GlobalKey();
        await tester.pumpWidget(app(
            RepaintBoundary(
                key: key,
                child: Scaffold(
                  appBar:
                      AppBar(title: Text(providers ? 'Providers' : 'Bookings')),
                  body: OwnerRecordsView(
                    providers: providers,
                    openFeed: (
                            {required providers,
                            required query,
                            required group,
                            required oldest}) =>
                        feed([providers ? provider : booking]),
                  ),
                )),
            dark: dark));
        await tester.pumpAndSettle();
        await capture(tester, key,
            '${providers ? 'providers' : 'bookings'}-${dark ? 'dark' : 'light'}');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'Profile centralizes activity/preferences/help without a second primary menu',
      (tester) async {
    phone(tester);
    final actions = <String>[];
    await tester.pumpWidget(app(OwnerProfileScreen(
      onOpenBookings: () {},
      snapshot: const {
        'display_name': 'Owner',
        'email': 'owner@test.invalid',
        'property_count': 2
      },
      onAction: actions.add,
    )));
    await tester.pumpAndSettle();
    for (final title in [
      'Appearance',
      'Schedule',
      'Spending',
      'About & help',
      'Sign out'
    ]) {
      await tester.scrollUntilVisible(find.text(title), 160,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
    expect(actions,
        ['Appearance', 'Schedule', 'Spending', 'About & help', 'Sign out']);
    expect(find.text('Manage properties'), findsNothing);
    expect(find.text('Terms of service'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
