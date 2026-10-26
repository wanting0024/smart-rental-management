import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental_app_demo/main.dart';
import 'package:rental_app_demo/services/user_session.dart';
import 'package:rental_app_demo/screens/provider_inbox_screen.dart';
import 'package:rental_app_demo/screens/about_screen.dart';
import 'package:rental_app_demo/screens/prototype_support_screen.dart';
import 'package:rental_app_demo/services/prototype_support_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

const draft = PrototypeSupportDraft(
    category: 'Booking',
    subject: 'Test booking question',
    description:
        'This is a synthetic issue used only to test the prototype support flow.');
void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
  });
  test('disabled/unsigned store cannot create or read simulation tickets', () {
    final store = PrototypeSupportStore(enabled: false);
    store.bindSession('a');
    expect(store.lease, isNull);
    expect(
        () => store.create(const PrototypeSupportLease('a', 1), draft,
            acknowledged: true),
        throwsStateError);
    store.dispose();
  });
  test(
      'validation and acknowledgement required, immutable tickets and bounded capacity',
      () {
    final store = PrototypeSupportStore(enabled: true, maxTickets: 1)
      ..bindSession('a');
    final lease = store.lease!;
    expect(() => store.create(lease, draft, acknowledged: false),
        throwsArgumentError);
    expect(
        () => store.create(
            lease,
            const PrototypeSupportDraft(
                category: 'Fake',
                subject: 'Test title',
                description: 'A synthetic description that is long enough.'),
            acknowledged: true),
        throwsArgumentError);
    final item = store.create(lease, draft, acknowledged: true);
    expect(item.id, startsWith('SIM-'));
    expect(() => store.tickets(lease).clear(), throwsUnsupportedError);
    expect(
        () => store.create(lease, draft, acknowledged: true), throwsStateError);
    store.dispose();
  });
  test(
      'simulate reply, close/reopen, reset and reply bound are local controlled states',
      () {
    final store = PrototypeSupportStore(enabled: true)..bindSession('a');
    final lease = store.lease!;
    final item = store.create(lease, draft, acknowledged: true);
    store.simulateReply(lease, item.id);
    expect(store.ticket(lease, item.id)!.status, PrototypeTicketStatus.replied);
    store.setClosed(lease, item.id, true);
    expect(() => store.simulateReply(lease, item.id), throwsStateError);
    store.setClosed(lease, item.id, false);
    for (var i = 1; i < 10; i++) store.simulateReply(lease, item.id);
    expect(() => store.simulateReply(lease, item.id), throwsStateError);
    expect(
        store
            .ticket(lease, item.id)!
            .responses
            .every((r) => r.contains('demonstration only')),
        true);
    store.reset(lease);
    expect(store.tickets(lease), isEmpty);
    store.dispose();
  });
  test(
      'account changes, logout/login epoch and disposal invalidate private drafts and reads',
      () {
    final store = PrototypeSupportStore(enabled: true)..bindSession('a');
    final lease = store.lease!;
    final item = store.create(lease, draft, acknowledged: true);
    store.bindSession('b');
    expect(store.ticket(lease, item.id), isNull);
    expect(store.tickets(store.lease!), isEmpty);
    expect(
        () => store.create(lease, draft, acknowledged: true), throwsStateError);
    store.bindSession(null);
    store.bindSession('a');
    expect(store.valid(lease), false);
    final next = store.lease!;
    store.dispose();
    expect(store.valid(next), false);
    expect(store.ticket(next, item.id), isNull);
  });

  Future<void> openForm(WidgetTester tester, PrototypeSupportStore store,
      {bool dark = false, double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: PrototypeSupportScreen(store: store)));
    await tester.tap(find.text('New test request'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('support-subject')), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.byKey(const ValueKey('support-subject')), draft.subject);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('support-description')), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.byKey(const ValueKey('support-description')), draft.description);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('support-acknowledge')), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-acknowledge')).hitTestable(),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('support-acknowledge')));
    await tester.pump();
  }

  testWidgets(
      'complete test request, view history, simulate reply, close and reopen',
      (tester) async {
    final store = PrototypeSupportStore(enabled: true)..bindSession('a');
    await openForm(tester, store);
    await fill(tester);
    await tester.tap(find.text('Save simulated ticket'));
    await tester.pumpAndSettle();
    expect(store.tickets(store.lease!), hasLength(1));
    expect(find.text('SIM-0001'), findsOneWidget);
    expect(find.textContaining('No email is sent'), findsOneWidget);
    await tester.ensureVisible(find.text('Simulate support reply'));
    await tester.tap(find.text('Simulate support reply'));
    await tester.pump();
    expect(find.text('Replied (simulated)'), findsOneWidget);
    await tester.ensureVisible(find.text('Close test ticket'));
    await tester.tap(find.text('Close test ticket'));
    await tester.pump();
    expect(find.text('Closed (simulated)'), findsOneWidget);
    await tester.ensureVisible(find.text('Reopen test ticket'));
    await tester.tap(find.text('Reopen test ticket'));
    await tester.pump();
    expect(
        store.tickets(store.lease!).single.status, PrototypeTicketStatus.open);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(draft.subject), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets('invalid form stays open and acknowledgement is mandatory',
      (tester) async {
    final store = PrototypeSupportStore(enabled: true)..bindSession('a');
    await openForm(tester, store);
    await tester.tap(find.text('Save simulated ticket'));
    await tester.pump();
    expect(store.tickets(store.lease!), isEmpty);
    expect(find.text('Enter at least 5 characters.'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('support-subject')), draft.subject);
    await tester
        .ensureVisible(find.byKey(const ValueKey('support-description')));
    await tester.enterText(
        find.byKey(const ValueKey('support-description')), draft.description);
    await tester.tap(find.text('Save simulated ticket'));
    await tester.pump();
    expect(store.tickets(store.lease!), isEmpty);
    expect(find.text('Confirm that this is a simulation before saving.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets('discard guard keeps draft until explicitly confirmed',
      (tester) async {
    final store = PrototypeSupportStore(enabled: true)..bindSession('a');
    await openForm(tester, store);
    await tester.enterText(
        find.byKey(const ValueKey('support-subject')), draft.subject);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard this test request?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text(draft.subject), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Your test requests'), findsOneWidget);
    expect(store.tickets(store.lease!), isEmpty);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets(
      'identity change while editing blocks submission and hides private text',
      (tester) async {
    final store = PrototypeSupportStore(enabled: true)..bindSession('a');
    await openForm(tester, store);
    await fill(tester);
    store.bindSession('b');
    await tester.pump();
    expect(find.text('Save simulated ticket'), findsNothing);
    expect(find.textContaining('prototype session has ended'), findsOneWidget);
    expect(find.text(draft.description), findsNothing);
    expect(store.tickets(store.lease!), isEmpty);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  for (final dark in [false, true]) {
    testWidgets('prototype support usable at narrow 200% text dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = PrototypeSupportStore(enabled: true)..bindSession('a');
      await openForm(tester, store, dark: dark, scale: 2);
      await fill(tester);
      await tester.tap(find.text('Save simulated ticket'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('SIM-0001'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Close test ticket'), 180,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
  testWidgets('About uses simulation only for enabled non-production account',
      (tester) async {
    final store = PrototypeSupportStore(enabled: true)..bindSession('a');
    await tester.pumpWidget(MaterialApp(
        home:
            AboutScreen(environmentLabel: 'staging', prototypeSupport: store)));
    await tester.ensureVisible(find.text('Contact support'));
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    expect(find.text('Your test requests'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
        home: AboutScreen(
            environmentLabel: 'production', prototypeSupport: store)));
    await tester.ensureVisible(find.text('Contact support'));
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    expect(find.text('Your test requests'), findsNothing);
    expect(find.textContaining('No support request has been sent'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets(
      'real local app composition binds prototype tickets and clears on sign-out',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'coachmark_seen_provider_inbox_v1': true});
    await tester
        .pumpWidget(const RentalAppDemo(localPreviewRole: UserRole.provider));
    await tester.pumpAndSettle();
    final app = tester.widget<AppProviders>(find.byType(AppProviders));
    final store = app.prototypeSupport!;
    expect(store.available, true);
    final old = store.lease!;
    store.create(old, draft, acknowledged: true);
    final session =
        UserSessionAccess.of(tester.element(find.byType(ProviderInboxScreen)));
    session.signOut();
    await tester.pumpAndSettle();
    expect(store.available, false);
    expect(store.tickets(old), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reset confirmation removes only simulated requests',
      (tester) async {
    final store = PrototypeSupportStore(enabled: true)..bindSession('a');
    store.create(store.lease!, draft, acknowledged: true);
    await tester
        .pumpWidget(MaterialApp(home: PrototypeSupportScreen(store: store)));
    await tester.tap(find.byTooltip('Reset simulated tickets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(store.tickets(store.lease!), hasLength(1));
    await tester.tap(find.byTooltip('Reset simulated tickets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(store.tickets(store.lease!), isEmpty);
    expect(find.text('No simulated tickets yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
