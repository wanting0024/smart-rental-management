import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/authenticated_memory_cache.dart';

void main() {
  test('same-key concurrent reads share one load and TTL expires exactly',
      () async {
    var now = DateTime.utc(2030);
    var calls = 0;
    final response = Completer<String>();
    final cache =
        AuthenticatedMemoryCache(currentUserId: () => 'a', now: () => now);
    Future<String> read() => cache.read(
          key: 'photo',
          ttl: const Duration(seconds: 2),
          sizeOf: (value) => value.length,
          load: () {
            calls++;
            return response.future;
          },
        );
    final first = read(), second = read();
    response.complete('photo bytes');
    expect(await first, await second);
    expect(calls, 1);
    await read();
    expect(calls, 1);
    now = now.add(const Duration(seconds: 2));
    await read();
    expect(calls, 2);
  });

  test('LRU evicts by byte and entry limits and keeps accounting correct',
      () async {
    final cache = AuthenticatedMemoryCache(
      currentUserId: () => 'a',
      maxBytes: 6,
      maxEntries: 2,
    );
    final loads = <String>[];
    Future<String> read(String key) => cache.read(
          key: key,
          ttl: const Duration(minutes: 1),
          sizeOf: (value) => value.length,
          load: () async {
            loads.add(key);
            return 'abc';
          },
        );
    await read('a');
    await read('b');
    await read('a');
    await read('c');
    expect(cache.entryCount, 2);
    expect(cache.sizeBytes, 6);
    await read('a');
    expect(loads, ['a', 'b', 'c']);
    await read('b');
    expect(loads.last, 'b');
    cache.clear();
    expect(cache.entryCount, 0);
    expect(cache.sizeBytes, 0);
  });

  test('oversized entries are returned but are never retained', () async {
    final cache =
        AuthenticatedMemoryCache(currentUserId: () => 'a', maxBytes: 2);
    var calls = 0;
    Future<String> read() => cache.read(
          key: 'large',
          ttl: const Duration(minutes: 1),
          sizeOf: (v) => v.length,
          load: () async {
            calls++;
            return 'too big';
          },
        );
    expect(await read(), 'too big');
    await read();
    expect(calls, 2);
    expect(cache.sizeBytes, 0);
  });

  test('signed-out reads do not access the network or return cached values',
      () async {
    String? user = 'a';
    final cache = AuthenticatedMemoryCache(currentUserId: () => user);
    var calls = 0;
    Future<String> read() => cache.read(
          key: 'private',
          ttl: const Duration(minutes: 1),
          sizeOf: (v) => v.length,
          load: () async {
            calls++;
            return user!;
          },
        );
    await read();
    user = null;
    await expectLater(read(), throwsA(isA<CacheSessionChanged>()));
    expect(calls, 1);
    expect(cache.entryCount, 0);
  });

  test('account switch never reuses the previous accounts same-path bytes',
      () async {
    String? user = 'a';
    final cache = AuthenticatedMemoryCache(currentUserId: () => user);
    Future<String> read() => cache.read(
          key: 'same-path',
          ttl: const Duration(minutes: 1),
          sizeOf: (v) => v.length,
          load: () async => user!,
        );
    expect(await read(), 'a');
    user = 'b';
    expect(await read(), 'b');
    expect(cache.entryCount, 1);
  });

  test('A to signed-out to A invalidates late work even with the same final ID',
      () async {
    String? user = 'a';
    final cache = AuthenticatedMemoryCache(currentUserId: () => user);
    final response = Completer<String>();
    final old = cache.read(
      key: 'private',
      ttl: const Duration(minutes: 1),
      sizeOf: (String v) => v.length,
      load: () => response.future,
    );
    final rejected = expectLater(old, throwsA(isA<CacheSessionChanged>()));
    cache.bindSession(null);
    user = null;
    cache.bindSession('a');
    user = 'a';
    response.complete('previous session');
    await rejected;
    expect(cache.entryCount, 0);
    expect(cache.inFlightCount, 0);
  });

  test('eviction invalidates in-flight work and an old result cannot refill it',
      () async {
    final cache = AuthenticatedMemoryCache(currentUserId: () => 'a');
    final response = Completer<String>();
    final old = cache.read(
      key: 'photo:booking/old',
      ttl: const Duration(minutes: 1),
      sizeOf: (String v) => v.length,
      load: () => response.future,
    );
    final rejected = expectLater(old, throwsA(isA<CacheReadInvalidated>()));
    cache.evictWhere((key) => key.startsWith('photo:booking/'));
    response.complete('old bytes');
    await rejected;
    expect(cache.entryCount, 0);
  });

  test('failed loads are not cached and the next read retries', () async {
    final cache = AuthenticatedMemoryCache(currentUserId: () => 'a');
    var calls = 0;
    Future<String> read() => cache.read(
          key: 'photo',
          ttl: const Duration(minutes: 1),
          sizeOf: (v) => v.length,
          load: () async {
            if (++calls == 1) throw StateError('offline');
            return 'ok';
          },
        );
    await expectLater(read(), throwsStateError);
    expect(await read(), 'ok');
    expect(calls, 2);
  });

  test('in-flight cap counts old reads until completion, including after clear',
      () async {
    final cache =
        AuthenticatedMemoryCache(currentUserId: () => 'a', maxInFlight: 1);
    final response = Completer<String>();
    final old = cache.read(
      key: 'one',
      ttl: const Duration(minutes: 1),
      sizeOf: (String v) => v.length,
      load: () => response.future,
    );
    final rejected = expectLater(old, throwsA(isA<CacheSessionChanged>()));
    cache.clear();
    await expectLater(
      cache.read(
        key: 'two',
        ttl: const Duration(minutes: 1),
        sizeOf: (String v) => v.length,
        load: () async => 'two',
      ),
      throwsA(isA<CacheBusy>()),
    );
    response.complete('one');
    await rejected;
    expect(cache.inFlightCount, 0);
  });
}
