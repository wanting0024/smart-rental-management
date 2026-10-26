import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);
const next = PageCursor('2030-01-01T00:00:00.123456+00:00', '2');
CursorFeed<int> integers(
  Future<CursorPage<int>> Function(PageCursor?) load, {
  Stream<PageChange>? changes,
  Future<int?> Function(String)? read,
}) =>
    CursorFeed(
      loadPage: load,
      idOf: (v) => '$v',
      compare: (a, b) => b.compareTo(a),
      changes: changes,
      readOne: read,
    );

void main() {
  test('cursor retains timestamp precision and deterministic UUID boundary',
      () {
    final page = CursorPage.decode<int>(
      {
        'items': [
          {'n': 1},
        ],
        'has_more': true,
        'next_cursor': {'timestamp': next.timestamp, 'id': next.id},
      },
      (row) => row['n'] as int,
    );
    expect(page.next!.timestamp, next.timestamp);
    expect(page.items, [1]);
    expect(
      () => CursorPage.decode<int>({'items': [], 'has_more': true}, (_) => 0),
      throwsFormatException,
    );
  });

  test('load more serializes duplicate taps and de-duplicates records',
      () async {
    final older = Completer<CursorPage<int>>();
    var calls = 0;
    final feed = integers((cursor) async {
      calls++;
      return cursor == null
          ? const CursorPage(items: [4, 3], next: next)
          : older.future;
    });
    addTearDown(feed.dispose);
    await tick();
    final first = feed.loadMore();
    await feed.loadMore();
    expect(calls, 2);
    expect(feed.loadingMore, isTrue);
    older.complete(const CursorPage(items: [3, 2, 1]));
    await first;
    expect(feed.items, [4, 3, 2, 1]);
    expect(feed.hasMore, isFalse);
  });

  test('older-page failure retains records and retries exactly the same cursor',
      () async {
    var attempts = 0;
    final cursors = <PageCursor?>[];
    final feed = integers((cursor) async {
      cursors.add(cursor);
      if (cursor == null) return const CursorPage(items: [3], next: next);
      if (attempts++ == 0) throw StateError('offline');
      return const CursorPage(items: [2, 1]);
    });
    addTearDown(feed.dispose);
    await tick();
    await feed.loadMore();
    expect(feed.items, [3]);
    expect(feed.moreError, isNotNull);
    await feed.loadMore();
    expect(feed.items, [3, 2, 1]);
    expect(cursors[1], same(cursors[2]));
  });

  test('refresh invalidates a pending older response', () async {
    final older = Completer<CursorPage<int>>();
    var heads = 0;
    final feed = integers(
      (cursor) async => cursor == null
          ? CursorPage(items: heads++ == 0 ? [3] : [9], next: next)
          : older.future,
    );
    addTearDown(feed.dispose);
    await tick();
    final pending = feed.loadMore();
    await feed.refresh();
    older.complete(const CursorPage(items: [2, 1]));
    await pending;
    expect(feed.items, [9]);
  });

  test('unloaded updates do not make a later page lose records', () async {
    final changes = StreamController<PageChange>();
    final feed = integers(
      (cursor) async => cursor == null
          ? const CursorPage(items: [3], next: next)
          : const CursorPage(items: [2, 1]),
      changes: changes.stream,
      read: (_) async => 2,
    );
    addTearDown(feed.dispose);
    addTearDown(changes.close);
    await tick();
    changes.add(const PageChange(PageChangeKind.update, '2'));
    await tick();
    await feed.loadMore();
    expect(feed.items, [3, 2, 1]);
  });

  test('delete notification cannot be resurrected by an older in-flight page',
      () async {
    final changes = StreamController<PageChange>();
    final older = Completer<CursorPage<int>>();
    final feed = integers(
      (cursor) async => cursor == null
          ? const CursorPage(items: [3], next: next)
          : older.future,
      changes: changes.stream,
    );
    addTearDown(feed.dispose);
    addTearDown(changes.close);
    await tick();
    final pending = feed.loadMore();
    changes.add(const PageChange(PageChangeKind.remove, '2'));
    await tick();
    older.complete(const CursorPage(items: [2, 1]));
    await pending;
    expect(feed.items, [3, 1]);
  });

  test('insert during initial fetch is replayed after the first snapshot',
      () async {
    final head = Completer<CursorPage<int>>();
    final changes = StreamController<PageChange>();
    final feed = integers(
      (_) => head.future,
      changes: changes.stream,
      read: (_) async => 4,
    );
    addTearDown(feed.dispose);
    addTearDown(changes.close);
    changes.add(const PageChange(PageChangeKind.insert, '4'));
    await tick();
    head.complete(const CursorPage(items: [3, 2]));
    await tick();
    await tick();
    expect(feed.items, [4, 3, 2]);
  });

  test(
      'reconnect reloads a contiguous latest page and exposes its older cursor',
      () async {
    final changes = StreamController<PageChange>();
    var heads = 0;
    final feed = integers(
      (cursor) async => cursor == null
          ? CursorPage(items: heads++ == 0 ? [3] : [8, 7], next: next)
          : const CursorPage(items: [2, 1]),
      changes: changes.stream,
    );
    addTearDown(feed.dispose);
    addTearDown(changes.close);
    await tick();
    await feed.loadMore();
    changes.add(const PageChange(PageChangeKind.reset));
    await tick();
    await tick();
    expect(feed.items, [8, 7]);
    expect(feed.hasMore, isTrue);
  });

  test('out-of-order realtime reads cannot overwrite a newer row', () async {
    final changes = StreamController<PageChange>();
    final reads = <Completer<Map<String, dynamic>?>>[];
    final feed = CursorFeed<Map<String, dynamic>>(
      loadPage: (_) async => const CursorPage(
        items: [
          {'id': 'a', 'version': 0},
        ],
      ),
      idOf: (row) => row['id'] as String,
      compare: (_, __) => 0,
      changes: changes.stream,
      readOne: (_) {
        final pending = Completer<Map<String, dynamic>?>();
        reads.add(pending);
        return pending.future;
      },
    );
    addTearDown(feed.dispose);
    addTearDown(changes.close);
    await tick();
    changes.add(const PageChange(PageChangeKind.update, 'a'));
    changes.add(const PageChange(PageChangeKind.update, 'a'));
    await tick();
    reads[1].complete({'id': 'a', 'version': 2});
    await tick();
    reads[0].complete({'id': 'a', 'version': 1});
    await tick();
    expect(feed.items.single['version'], 2);
  });

  test('disposal cancels listening and ignores late network responses',
      () async {
    var cancellations = 0;
    final head = Completer<CursorPage<int>>();
    final changes =
        StreamController<PageChange>(onCancel: () => cancellations++);
    final feed = integers((_) => head.future, changes: changes.stream);
    await tick();
    feed.dispose();
    head.complete(const CursorPage(items: [1]));
    await tick();
    expect(cancellations, 1);
    expect(feed.items, isEmpty);
    await changes.close();
  });
}
