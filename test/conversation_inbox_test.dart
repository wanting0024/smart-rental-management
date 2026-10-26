import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/chat_list_screen.dart';
import 'package:rental_app_demo/services/backend/conversation_binding.dart';
import 'package:rental_app_demo/services/backend/conversation_page.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

const actor = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const stamp = '2026-10-24T01:00:00.123456+00:00';
Map<String, dynamic> json(
        {String query = '',
        String id = 'thread',
        String name = 'Real provider',
        bool more = false}) =>
    {
      'recipient_id': actor,
      'as_of': stamp,
      'search': query,
      'unread_only': false,
      'unread_total': 0,
      'has_more': more,
      'next_cursor':
          more ? {'timestamp': '2026-10-23T01:00:00+00:00', 'id': id} : null,
      'items': [
        {
          'booking_id': id,
          'counterpart_name': name,
          'status': 'Accepted',
          'unit_name': 'Server unit',
          'building_name': 'Real building',
          'service_name': 'Cleaning',
          'last_message': 'Actual server message',
          'unread_count': 0,
          'last_at': '2026-10-23T01:00:00+00:00'
        }
      ]
    };
ConversationPage page(
        {String query = '', String id = 'thread', bool more = false}) =>
    ConversationPage.parse(
        json(query: query, id: id, more: more), actor, query);

void main() {
  test('real unread projection validates counts and filter identity', () {
    final data = json()
      ..['unread_total'] = 2
      ..['unread_only'] = true;
    (data['items'] as List).first['unread_count'] = 2;
    final parsed = ConversationPage.parse(data, actor, '', unreadOnly: true);
    expect(parsed.page.items.single.present(actor).unreadCount, 2);
    expect(parsed.unreadTotal, 2);
    expect(
        () => ConversationPage.parse(data, actor, ''), throwsFormatException);
    data['unread_total'] = 1;
    expect(() => ConversationPage.parse(data, actor, '', unreadOnly: true),
        throwsFormatException);
  });
  testWidgets(
      'original unread filter uses server loader and returning from read thread clears confirmed row',
      (tester) async {
    var read = false, filteredCalls = 0;
    ConversationPage result(bool only) {
      final data = json()
        ..['unread_total'] = (read ? 0 : 2)
        ..['unread_only'] = only;
      (data['items'] as List).first['unread_count'] = read ? 0 : 2;
      if (only && read) data['items'] = [];
      return ConversationPage.parse(data, actor, '', unreadOnly: only);
    }

    final binding = ConversationBinding(
        userId: actor,
        currentUserId: () => actor,
        sessions: const Stream.empty(),
        load: (_, {before, asOf}) async => result(false),
        loadUnread: (_, {before, asOf}) async {
          filteredCalls++;
          return result(true);
        });
    binding.setActive(true);
    await tester.pumpWidget(MaterialApp(
        home: ChatListScreen(
            binding: binding,
            onOpenConversation: (_) async {
              read = true;
            })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(binding.unreadOnly, true);
    expect(filteredCalls, 1);
    await tester.tap(find.text('Real provider'));
    await tester.pumpAndSettle();
    expect(binding.unreadTotal, 0);
    expect(find.text('Real provider'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    binding.dispose();
  });
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
  });
  test(
      'conversation model rejects foreign identity, false cursors and unordered data',
      () {
    expect(
        () => ConversationPage.parse(
            {...json(), 'recipient_id': 'other'}, actor, ''),
        throwsFormatException);
    expect(
        () => ConversationPage.parse({...json(), 'search': 'other'}, actor, ''),
        throwsFormatException);
    expect(
        () => ConversationPage.parse({
              ...json(more: true),
              'next_cursor': {'timestamp': stamp, 'id': 'wrong'}
            }, actor, ''),
        throwsFormatException);
    final bad = json();
    (bad['items'] as List).add((bad['items'] as List).first);
    expect(() => ConversationPage.parse(bad, actor, ''), throwsFormatException);
    final row = page().page.items.single.present(actor);
    expect(row.unreadCount, 0);
    expect(row.participantA, actor);
    final emoji = json();
    (emoji['items'] as List).first['last_message'] =
        List.filled(160, '😀').join();
    expect(
        ConversationPage.parse(emoji, actor, '')
            .page
            .items
            .single
            .preview
            .runes
            .length,
        160);
  });
  testWidgets('snapshot boundary preserved across pages, searching resets it',
      (tester) async {
    final calls = <String>[];
    final binding = ConversationBinding(
        userId: actor,
        currentUserId: () => actor,
        sessions: const Stream.empty(),
        load: (search, {before, asOf}) async {
          calls.add('$search/${before?.id}/$asOf');
          return page(
              query: search,
              id: before == null ? 'thread' : 'older',
              more: before == null);
        });
    binding.setActive(true);
    await tester.pump();
    await binding.feed.loadMore();
    expect(binding.feed.items.length, 2);
    expect(calls[1], '/thread/$stamp');
    await tester.pump(const Duration(seconds: 30));
    expect(calls.length, 2, reason: 'Polling must not collapse loaded history');
    binding.setSearch('  server  ');
    await tester.pump();
    expect(calls.last, 'server/null/null');
    expect(binding.feed.items.length, 1);
    binding.dispose();
  });
  testWidgets(
      'hidden list stops polling; visible refresh keeps stale data quietly',
      (tester) async {
    var count = 0;
    Completer<ConversationPage>? pending;
    final binding = ConversationBinding(
        userId: actor,
        currentUserId: () => actor,
        sessions: const Stream.empty(),
        load: (search, {before, asOf}) {
          count++;
          return pending?.future ?? Future.value(page());
        });
    binding.setActive(true);
    await tester.pump();
    pending = Completer();
    await tester.pump(const Duration(seconds: 30));
    expect(count, 2);
    expect(binding.feed.refreshing, true);
    expect(binding.feed.items.single.bookingId, 'thread');
    binding.setActive(false);
    await tester.pump(const Duration(seconds: 60));
    expect(count, 2);
    pending.complete(page(id: 'obsolete'));
    await tester.pump();
    expect(binding.feed.items.single.bookingId, 'thread');
    binding.dispose();
  });
  testWidgets('account change clears private rows and late network results',
      (tester) async {
    String? identity = actor;
    final sessions = StreamController<String?>.broadcast();
    Completer<ConversationPage>? pending;
    final binding = ConversationBinding(
        userId: actor,
        currentUserId: () => identity,
        sessions: sessions.stream,
        load: (search, {before, asOf}) =>
            pending?.future ?? Future.value(page()));
    binding.setActive(true);
    await tester.pump();
    pending = Completer();
    final refresh = binding.feed.refresh();
    identity = 'other';
    sessions.add(identity);
    await tester.pump();
    expect(binding.feed.sessionEnded, true);
    expect(binding.feed.items, isEmpty);
    pending.complete(page());
    await refresh;
    expect(binding.feed.items, isEmpty);
    binding.setSearch('another');
    expect(binding.search, '');
    binding.dispose();
    await sessions.close();
  });
  testWidgets(
      'search ignores older responses; auth failures discard stale snapshot',
      (tester) async {
    final old = Completer<ConversationPage>();
    var fail = false;
    final binding = ConversationBinding(
        userId: actor,
        currentUserId: () => actor,
        sessions: const Stream.empty(),
        load: (search, {before, asOf}) {
          if (search.isEmpty) return old.future;
          if (fail) return Future.error(const FormatException('Bad identity'));
          return Future.value(page(query: search, id: 'new'));
        });
    binding.setActive(true);
    binding.setSearch('new');
    await tester.pump();
    old.complete(page());
    await tester.pump();
    expect(binding.feed.items.single.bookingId, 'new');
    fail = true;
    await binding.feed.refresh();
    expect(binding.feed.items, isEmpty);
    expect(binding.feed.error, isA<FormatException>());
    binding.dispose();
  });
  testWidgets(
      'original list opens booking IDs without demo names, pins or unread claims',
      (tester) async {
    var reads = 0;
    String? opened;
    final binding = ConversationBinding(
        userId: actor,
        currentUserId: () => actor,
        sessions: const Stream.empty(),
        load: (search, {before, asOf}) async {
          reads++;
          return page(query: search);
        });
    binding.setActive(true);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: ChatListScreen(
            binding: binding,
            onOpenConversation: (id) async {
              opened = id;
            })));
    await tester.pumpAndSettle();
    expect(find.text('Real provider'), findsOneWidget);
    expect(find.text('Actual server message'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(find.text('Unread'), findsNothing);
    await tester.tap(find.text('Real provider'));
    await tester.pumpAndSettle();
    expect(opened, 'thread');
    final before = reads;
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(reads, greaterThan(before));
    await tester.enterText(find.byType(TextField), 'search');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(binding.search, 'search');
    await tester.pumpWidget(const SizedBox());
    binding.dispose();
  });
  for (final dark in [false, true]) {
    testWidgets('320px / 200% conversation and empty states dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var empty = false;
      final binding = ConversationBinding(
          userId: actor,
          currentUserId: () => actor,
          sessions: const Stream.empty(),
          loadUnread: (search, {before, asOf}) async =>
              const ConversationPage(stamp, CursorPage(items: [])),
          load: (search, {before, asOf}) async => empty
              ? const ConversationPage(stamp, CursorPage(items: []))
              : ConversationPage.parse(
                  json(name: 'A very long actual provider name'), actor, ''));
      binding.setActive(true);
      await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: ChatListScreen(
              binding: binding, onOpenConversation: (_) async {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      empty = true;
      await binding.feed.refresh();
      await tester.pumpAndSettle();
      expect(find.text('No conversations'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      binding.dispose();
    });
  }
}
