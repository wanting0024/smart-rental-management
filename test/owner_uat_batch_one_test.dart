import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/screens/owner_booking_feed.dart';
import 'package:rental_app_demo/screens/owner_workspace_dashboard.dart';
import 'package:rental_app_demo/screens/connected_property_form_screen.dart';
import 'package:rental_app_demo/screens/property_list_screen.dart';
import 'package:rental_app_demo/screens/workspace_login_screen.dart';
import 'package:rental_app_demo/screens/workspace_owner_profile.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/backend/supabase_booking_repository.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/booking_card.dart';
import 'support/owner_uat_steps.dart';

const actor = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
String id(int n) => '11111111-1111-4111-8111-${n.toString().padLeft(12, '0')}';
Map<String, dynamic> row(int n, {String status = 'Pending'}) => {
      'booking_id': id(n),
      'owner_id': actor,
      'provider_id': 'provider',
      'current_status': status,
      'unit_name': 'Unit $n',
      'building_name': 'Building',
      'service_name': 'Cleaning',
      'created_at': '2026-10-20T00:00:00.123456Z',
      'requested_start_at': '2026-11-01T02:00:00Z',
      'requested_end_at': '2026-11-01T04:00:00Z',
    };

class _Auth extends GoTrueClient {
  _Auth()
      : super(url: 'https://fixture.invalid/auth/v1', autoRefreshToken: false);
  Map<String, dynamic>? submitted;
  int signIns = 0;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  @override
  User get currentUser => User(
      id: actor,
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01');
  @override
  Future<AuthResponse> signUp(
      {String? email,
      String? phone,
      required String password,
      String? emailRedirectTo,
      Map<String, dynamic>? data,
      String? captchaToken,
      OtpChannel channel = OtpChannel.sms}) async {
    submitted = data;
    return AuthResponse(user: currentUser);
  }

  @override
  Future<AuthResponse> signInWithPassword(
      {String? email,
      String? phone,
      required String password,
      String? captchaToken}) async {
    signIns++;
    throw const AuthException('PRIVATE AUTH FAILURE',
        code: 'invalid_credentials');
  }
}

class _Client extends SupabaseClient {
  _Client(this.fixture, http.Client transport)
      : super('https://fixture.invalid', 'sb_publishable_fixture',
            httpClient: transport,
            authOptions: const AuthClientOptions(autoRefreshToken: false));
  final _Auth fixture;
  @override
  GoTrueClient get auth => fixture;
}

Future<(_Auth, _Client)> client(WidgetTester tester,
    {Future<http.Response> Function(http.Request)? handler}) async {
  final result = (await tester.runAsync(() async {
    final auth = _Auth();
    return (
      auth,
      _Client(
          auth,
          MockClient(handler ??
              (r) async => http.Response('[]', 200,
                  request: r, headers: {'content-type': 'application/json'})))
    );
  }))!;
  addTearDown(() async {
    await tester.runAsync(result.$2.dispose);
    result.$1.dispose();
  });
  return result;
}

Widget app(Widget home, {UserSession? session, bool dark = false}) =>
    UserSessionAccess(
        session: session ?? UserSession(),
        child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(), home: home));

void main() {
  testWidgets(
      'registration persists chosen name and keeps step-one entries on return',
      (tester) async {
    final (auth, sdk) = await client(tester);
    await tester.pumpWidget(
        app(WorkspaceLoginScreen(backend: SupabaseBackendProvider(sdk))));
    await tester.ensureVisible(find.text('Register owner account'));
    await tester.tap(find.text('Register owner account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name of 2–60 characters'), findsOneWidget);
    expect(auth.submitted, isNull);
    await advanceRegistration(tester);
    await tester.ensureVisible(find.text('Edit account details'));
    await tester.tap(find.text('Edit account details'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('registration-name')))
            .controller!
            .text,
        'Synthetic User');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final contact = find.widgetWithText(TextFormField, 'e.g. 012-345 6789');
    await tester.ensureVisible(contact);
    await tester.enterText(contact, '012-345 6789');
    final create = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(auth.submitted?['requested_display_name'], 'Synthetic User');
    expect(auth.submitted?['requested_role'], 'owner');
    expect(auth.submitted!.containsKey('approval_status'), false);
    expect(find.text('Check your email to confirm the account, then sign in.'),
        findsOneWidget);
  });

  testWidgets(
      'bad email stays local; credential failure is persistent and generic',
      (tester) async {
    final (auth, sdk) = await client(tester);
    await tester.pumpWidget(
        app(WorkspaceLoginScreen(backend: SupabaseBackendProvider(sdk))));
    final email = find.widgetWithText(TextFormField, 'name@example.com');
    final password = find.widgetWithText(TextFormField, 'Password');
    await tester.enterText(email, 'not-an-email');
    await tester.enterText(password, 'SyntheticPassword123!');
    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(auth.signIns, 0);
    expect(find.text('Enter a valid email'), findsOneWidget);
    await tester.enterText(email, 'synthetic@rental-test.invalid');
    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(auth.signIns, 1);
    await tester.pump(const Duration(seconds: 8));
    expect(
        find.text('Email or password is incorrect. Check both and try again.'),
        findsOneWidget);
    expect(find.textContaining('PRIVATE AUTH FAILURE'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'greeting and each statistic use saved name and matching destination dark=$dark',
        (tester) async {
      final session = UserSession()
        ..signIn(
            email: 'owner@fixture.invalid',
            displayName: 'Wan Ting',
            role: UserRole.owner);
      String? route;
      await tester.pumpWidget(app(
          Scaffold(
              body: OwnerWorkspaceDashboard(
                  bookings: const [],
                  propertyCount: 0,
                  onRequest: () {},
                  onNavigate: (v) => route = v,
                  onBooking: (_) {})),
          session: session,
          dark: dark));
      expect(find.textContaining(', Wan Ting'), findsOneWidget);
      expect(find.textContaining('owner@fixture.invalid'), findsNothing);
      for (final label in ['pending', 'ongoing', 'completed']) {
        final stat = find.byKey(ValueKey('owner-stat-$label'));
        await tester.ensureVisible(stat);
        await tester.tap(stat);
        await tester.pump();
        expect(route, 'bookings-$label');
      }
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }

  testWidgets(
      'follow-up expands in place and requests the next page only when needed',
      (tester) async {
    int reads = 0;
    final feed = CursorFeed<Map<String, dynamic>>(
        active: false,
        idOf: (r) => r['booking_id'] as String,
        compare: (a, b) =>
            (a['booking_id'] as String).compareTo(b['booking_id'] as String),
        loadPage: (cursor) async {
          reads++;
          return cursor == null
              ? CursorPage(
                  items: List.generate(6, (n) => row(n + 1)),
                  next: PageCursor('2026-11-01T02:00:00Z', id(6)))
              : CursorPage(items: [row(7)]);
        });
    await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(
            child: OwnerBookingFeed(
                feed: feed,
                group: OwnerBookingGroup.followUp,
                inline: true,
                onBooking: (_) {})))));
    await tester.pumpAndSettle();
    expect(find.byType(BookingCard), findsNWidgets(3));
    expect(reads, 1);
    await tester.ensureVisible(find.byKey(const Key('show-more-bookings')));
    await tester.tap(find.byKey(const Key('show-more-bookings')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingCard), findsNWidgets(6));
    expect(reads, 1);
    await tester.ensureVisible(find.byKey(const Key('show-more-bookings')));
    await tester.tap(find.byKey(const Key('show-more-bookings')));
    await tester.pumpAndSettle();
    expect(find.byType(BookingCard), findsNWidgets(7));
    expect(reads, 2);
    expect(find.byKey(const Key('show-more-bookings')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'owner queries filter before paging, preserve microsecond cursors, reject wrong-owner cards',
      (tester) async {
    final calls = <Uri>[];
    var wrongOwner = false;
    final (_, sdk) = await client(tester, handler: (r) async {
      calls.add(r.url);
      final dynamic body = r.url.path.endsWith('/booking')
          ? List.generate(
              21,
              (n) => {
                    'booking_id': id(n + 1),
                    'created_at': '2026-10-20T00:00:00.123456Z'
                  })
          : List.generate(
              20,
              (n) => {
                    ...row(n + 1,
                        status: n.isEven ? 'Accepted' : 'In Progress'),
                    if (wrongOwner) 'owner_id': 'other'
                  });
      return http.Response(jsonEncode(body), 200,
          request: r, headers: {'content-type': 'application/json'});
    });
    final repo = SupabaseBookingRepository(sdk);
    final page = (await tester
        .runAsync(() => repo.ownerPage(OwnerBookingGroup.active)))!;
    expect(page.items.length, 20);
    expect(page.next!.timestamp, '2026-10-20T00:00:00.123456Z');
    expect(calls.first.queryParameters['owner_id'], 'eq.$actor');
    expect(calls.first.queryParameters['current_status'], contains('Accepted'));
    expect(
        calls.first.queryParameters['current_status'], contains('In Progress'));
    await tester.runAsync(
        () => repo.ownerPage(OwnerBookingGroup.active, before: page.next));
    expect(calls[2].queryParameters['or'], contains('00:00:00.123456Z'));
    wrongOwner = true;
    await tester.runAsync(() async => expectLater(
        repo.ownerPage(OwnerBookingGroup.pending), throwsFormatException));
  });

  testWidgets(
      'new property requires both explicit times and same-day ordered range',
      (tester) async {
    var saves = 0;
    await tester.pumpWidget(
        app(ConnectedPropertyFormScreen(onSave: (_) async => saves++)));
    final fields = find.byType(TextFormField);
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(fields.at(i));
      await tester.enterText(
          fields.at(i), ['Unit', 'Building', 'Address', '800'][i]);
    }
    await chooseBedrooms(tester, 2);
    await tester.ensureVisible(find.text('Add property'));
    await tester.tap(find.text('Add property'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.text('Select a start time'), findsOneWidget);
    expect(find.text('Select an end time'), findsOneWidget);
    await selectPropertyWindow(tester);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    await tester.ensureVisible(find.text('Add property'));
    await tester.tap(find.text('Add property'));
    await tester.pumpAndSettle();
    expect(saves, 1);
  });

  testWidgets(
      'portfolio footer uses complete summary rather than only visible unit counts',
      (tester) async {
    await tester.pumpWidget(app(PropertyListScreen(
        bookings: const [],
        connectedProperties: const [],
        totalCount: 25,
        connectedCounts: const {},
        portfolio: const {
          'property_count': 25,
          'building_count': 4,
          'size_sqft': 20000,
          'open': 7,
          'done': 11,
          'total': 21
        },
        onAddConnected: () {})));
    expect(find.text('25 properties'), findsOneWidget);
    expect(find.text('Across 4 buildings · 20000 sqft total'), findsOneWidget);
    expect(find.text('All properties'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.textContaining('loaded'), findsNothing);
  });

  testWidgets(
      'profile separates editable personal details from immutable identity',
      (tester) async {
    Map<String, dynamic>? saved;
    await tester.pumpWidget(app(OwnerProfileEditor(row: const {
      'display_name': 'Saved Name',
      'email': 'owner@fixture.invalid',
      'contact_number': '0123456789'
    }, canSave: () => true, save: (v) async => saved = v)));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Property Owner'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Changed Name');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(saved!.keys.toSet(), {'display_name', 'contact_number'});
    expect(saved!['display_name'], 'Changed Name');
  });
}
