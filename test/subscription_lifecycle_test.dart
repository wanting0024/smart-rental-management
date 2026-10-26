import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/paged_realtime.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

class WatchFixture {
  int active = 0, peak = 0, opens = 0;
  Completer<void>? pendingCancellation;
  final controllers = <StreamController<PageChange>>[];
  Stream<PageChange> open() {
    late StreamController<PageChange> controller;
    controller = StreamController<PageChange>(
      onListen: () {
        active++;
        opens++;
        if (active > peak) peak = active;
      },
      onCancel: () async {
        await pendingCancellation?.future;
        active--;
      },
    );
    controllers.add(controller);
    return controller.stream;
  }

  Future<void> close() async {
    for (final controller in controllers) {
      await controller.close();
    }
  }
}

CursorFeed<int> feedFor(
  WatchFixture watch, {
  bool active = true,
  Future<CursorPage<int>> Function(PageCursor?)? load,
  Stream<String?>? sessions,
  String? Function()? user,
}) =>
    CursorFeed(
      loadPage: load ?? (_) async => const CursorPage(items: [3, 2]),
      idOf: (row) => '$row',
      compare: (a, b) => b.compareTo(a),
      active: active,
      watchChanges: watch.open,
      ownerUserId: user == null ? null : 'owner-a',
      currentUserId: user,
      sessionChanges: sessions,
    );

void main() {
  test('explicit live retry replaces the failed channel and refreshes the head',
      () async {
    final watch = WatchFixture();
    var reads = 0;
    final feed =
        feedFor(watch, load: (_) async => CursorPage(items: [++reads]));
    await tick();
    watch.controllers.single.addError(StateError('connection interrupted'));
    await tick();
    expect(feed.liveError, isNotNull);
    expect(feed.items, [1]);
    feed.retryLive();
    await tick();
    expect(watch.active, 1);
    expect(watch.peak, 1);
    expect(watch.opens, 2);
    expect(feed.items, [2]);
    expect(feed.liveError, isNull);
    feed.dispose();
    await tick();
    await watch.close();
  });
  test('inactive feed opens no channel and performs no first read', () async {
    final watch = WatchFixture();
    var reads = 0;
    final feed = feedFor(
      watch,
      active: false,
      load: (_) async {
        reads++;
        return const CursorPage(items: [3]);
      },
    );
    await tick();
    expect(watch.opens, 0);
    expect(reads, 0);
    feed.setActive(true);
    await tick();
    expect(watch.active, 1);
    expect(reads, 1);
    feed.dispose();
    await tick();
    await watch.close();
  });

  test('twenty leave/return cycles settle to one channel, then zero', () async {
    final watch = WatchFixture();
    final feed = feedFor(watch);
    await tick();
    for (var index = 0; index < 20; index++) {
      feed.setActive(false);
      await tick();
      expect(watch.active, 0);
      expect(feed.items, [3, 2]);
      feed.setActive(true);
      feed.setActive(true);
      await tick();
      expect(watch.active, 1);
    }
    expect(watch.peak, 1);
    feed.dispose();
    await tick();
    expect(watch.active, 0);
    await watch.close();
  });

  test('rapid resume waits for channel cancellation before opening another',
      () async {
    final watch = WatchFixture();
    final feed = feedFor(watch);
    await tick();
    watch.pendingCancellation = Completer<void>();
    feed.setActive(false);
    feed.setActive(true);
    await tick();
    expect(watch.opens, 1);
    expect(watch.active, 1);
    watch.pendingCancellation!.complete();
    await tick();
    expect(watch.opens, 2);
    expect(watch.active, 1);
    expect(watch.peak, 1);
    watch.pendingCancellation = null;
    feed.dispose();
    await tick();
    await watch.close();
  });

  test('background invalidates older and live reads; foreground catches up',
      () async {
    final watch = WatchFixture();
    final lateRead = Completer<CursorPage<int>>();
    var reads = 0;
    final feed = feedFor(
      watch,
      load: (_) {
        reads++;
        return reads == 2
            ? lateRead.future
            : Future.value(CursorPage(items: [reads]));
      },
    );
    await tick();
    final pending = feed.refresh();
    feed.setActive(false);
    await tick();
    lateRead.complete(const CursorPage(items: [99]));
    await pending;
    expect(feed.items, [1]);
    await feed.refresh();
    await feed.loadMore();
    expect(reads, 2);
    feed.setActive(true);
    await tick();
    expect(feed.items, [3]);
    feed.dispose();
    await tick();
    await watch.close();
  });

  for (final change in <String?>[null, 'owner-b']) {
    test('session change to $change clears rows and permanently ends old feed',
        () async {
      final watch = WatchFixture();
      final sessions = StreamController<String?>();
      String? user = 'owner-a';
      final pending = Completer<CursorPage<int>>();
      var reads = 0;
      final feed = feedFor(
        watch,
        user: () => user,
        sessions: sessions.stream,
        load: (_) async =>
            ++reads == 1 ? const CursorPage(items: [3]) : pending.future,
      );
      await tick();
      final oldRead = feed.refresh();
      user = change;
      sessions.add(change);
      await tick();
      expect(feed.sessionEnded, isTrue);
      expect(feed.items, isEmpty);
      expect(watch.active, 0);
      pending.complete(const CursorPage(items: [99]));
      await oldRead;
      user = 'owner-a';
      feed.setActive(true);
      await feed.refresh();
      expect(feed.items, isEmpty);
      expect(reads, 2);
      feed.dispose();
      await tick();
      await sessions.close();
      await watch.close();
    });
  }

  test('same-user token refresh does not reopen the channel or erase rows',
      () async {
    final watch = WatchFixture();
    final sessions = StreamController<String?>();
    final feed =
        feedFor(watch, user: () => 'owner-a', sessions: sessions.stream);
    await tick();
    sessions.add('owner-a');
    sessions.addError(StateError('offline token refresh'));
    await tick();
    expect(feed.sessionEnded, isFalse);
    expect(feed.items, [3, 2]);
    expect(watch.opens, 1);
    expect(feed.liveError, isNotNull);
    feed.dispose();
    await tick();
    await sessions.close();
    await watch.close();
  });

  test('identity is checked after reads even before an auth event arrives',
      () async {
    final watch = WatchFixture();
    String? user = 'owner-a';
    final pending = Completer<CursorPage<int>>();
    final feed = feedFor(watch, user: () => user, load: (_) => pending.future);
    await tick();
    user = 'owner-b';
    pending.complete(const CursorPage(items: [99]));
    await tick();
    expect(feed.items, isEmpty);
    expect(feed.sessionEnded, isTrue);
    feed.dispose();
    await tick();
    await watch.close();
  });

  test('bounded status stream suppresses late reads and awaits cancellation',
      () async {
    final watch = WatchFixture();
    final reads = <Completer<String>>[];
    final values = <String>[];
    final subscription = boundedLiveValue<String>(
      read: () {
        final result = Completer<String>();
        reads.add(result);
        return result.future;
      },
      changes: watch.open,
    ).listen(values.add);
    watch.controllers.single.add(const PageChange(PageChangeKind.reset));
    await tick();
    reads[1].complete('Completed');
    await tick();
    reads[0].complete('Accepted');
    await tick();
    expect(values, ['Completed']);
    watch.pendingCancellation = Completer<void>();
    var finished = false;
    final closing = subscription.cancel().then((_) => finished = true);
    await tick();
    expect(finished, isFalse);
    watch.pendingCancellation!.complete();
    await closing;
    expect(watch.active, 0);
    await watch.close();
  });
}
