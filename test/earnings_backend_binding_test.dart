import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/earnings_binding.dart';
import 'package:rental_app_demo/services/backend/earnings_snapshot.dart';
import 'support/earnings_fixture.dart';

void main() {
  test('server total is not first page sum; quote is not net settlement', () {
    final r = earningsReport();
    expect(r.jobs, 24);
    expect(r.records.length, 20);
    expect(r.gross, closeTo(2400.24, 0.00001));
    expect(r.records.first.settlementAvailable, false);
    expect(r.records.first.date.hour, 10);
    expect(r.records.first.date.day, 23); // completion, not scheduled day 21
  });
  test('wrong identity/currency and inconsistent totals fail closed', () {
    for (final patch in [
      {'provider_id': 'other'},
      {'currency': 'USD'},
      {'gross': 1},
      {'items': List.filled(21, (earningsFixture()['items'] as List).first)}
    ]) {
      expect(
          () => EarningsSnapshot.parse({...earningsFixture(), ...patch},
              earningsActor, EarningsPeriod.thisMonth),
          throwsFormatException);
    }
  });
  test(
      'unpriced record remains explicitly unavailable, not actual zero earnings',
      () {
    final map = earningsFixture();
    final items = map['items'] as List;
    items[0] = <String, dynamic>{
      ...items.first as Map<String, dynamic>,
      'quoted_amount': null
    };
    final r =
        EarningsSnapshot.parse(map, earningsActor, EarningsPeriod.thisMonth);
    expect(r.records.first.amountAvailable, false);
    expect(r.records.first.settlementAvailable, false);
  });
  test(
      'pages append without changing aggregate; overlaps/report changes rejected',
      () {
    final first = earningsReport();
    final last = earningsReport(count: 4, offset: 20, more: false);
    final all = first.append(last);
    expect(all.records.length, 24);
    expect(all.gross, first.gross);
    expect(all.next, isNull);
    expect(() => first.append(first), throwsFormatException);
    expect(() => first.append(earningsReport(jobs: 25, count: 4, offset: 20)),
        throwsFormatException);
  });
  late StreamController<String?> sessions;
  late StreamController<PageChange> live;
  late EarningsBinding binding;
  EarningsBinding? bindingToDispose;
  late String? identity;
  setUp(() {
    sessions = StreamController.broadcast();
    live = StreamController.broadcast();
    identity = earningsActor;
  });
  tearDown(() async {
    bindingToDispose?.dispose();
    bindingToDispose = null;
    await sessions.close();
    await live.close();
  });
  EarningsBinding make(EarningsLoader loader) =>
      bindingToDispose = binding = EarningsBinding(
          load: loader,
          userId: earningsActor,
          currentUserId: () => identity,
          sessionChanges: sessions.stream,
          changes: () => live.stream);

  test('range race discards stale response; bounded paging preserves snapshot',
      () async {
    final old = Completer<EarningsSnapshot>();
    final calls = <EarningsPeriod>[];
    make((period, {before, asOf}) async {
      calls.add(period);
      if (period == EarningsPeriod.thisMonth) return old.future;
      if (before != null) {
        expect(asOf, contains('123456'));
        return earningsReport(
            period: period, count: 4, offset: 20, more: false);
      }
      return earningsReport(period: period);
    });
    binding.setActive(true);
    binding.select(EarningsPeriod.allTime);
    await Future<void>.delayed(Duration.zero);
    old.complete(earningsReport());
    await Future<void>.delayed(Duration.zero);
    expect(binding.snapshot!.period, EarningsPeriod.allTime);
    await binding.loadMore();
    expect(binding.snapshot!.records.length, 24);
    expect(calls.length, 3);
  });
  test('session change clears data and late results cannot leak', () async {
    final wait = Completer<EarningsSnapshot>();
    make((p, {before, asOf}) => wait.future);
    binding.setActive(true);
    identity = 'other';
    sessions.add(identity);
    await Future<void>.delayed(Duration.zero);
    wait.complete(earningsReport());
    await Future<void>.delayed(Duration.zero);
    expect(binding.sessionEnded, true);
    expect(binding.snapshot, isNull);
    binding.setActive(true);
    expect(live.hasListener, false);
  });
  test(
      'failure stays failure; refresh retries; dispose/background cancels subscription',
      () async {
    var fail = true;
    make((p, {before, asOf}) async {
      if (fail) throw StateError('private');
      return earningsReport();
    });
    binding.setActive(true);
    await Future<void>.delayed(Duration.zero);
    expect(binding.error, isNotNull);
    expect(binding.snapshot, isNull);
    fail = false;
    await binding.refresh();
    expect(binding.snapshot, isNotNull);
    live.addError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(binding.liveError, isNotNull);
    binding.setActive(false);
    await Future<void>.delayed(Duration.zero);
    expect(live.hasListener, false);
  });
}
