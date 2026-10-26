// Explicit opt-in hosted synthetic message receipt acceptance. No admin key.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/backend/supabase_booking_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_workspace_repository.dart';
import 'staging_business_acceptance_support.dart';

class _ReadsNetwork extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _ReadsNetwork();
  const enabled = bool.fromEnvironment('RUN_STAGING_MESSAGE_READS');
  const confirmation = String.fromEnvironment('STAGING_WRITE_PROJECT');
  test(
      'hosted own-message exclusion, partial read, new arrivals, closed thread and fresh sign-in',
      () async {
    var stage = 'target';
    final clients = <SupabaseClient>[];
    RandomAccessFile? lock;
    try {
      const dir = 'output/staging-private';
      final config = jsonDecode(
          await File('supabase/backend_config.staging.local.json')
              .readAsString()) as Map;
      final fixture = jsonDecode(
          await File('$dir/booking-fixture.local.json').readAsString()) as Map;
      requireBusinessTarget(config, fixture, confirmation);
      final file = File('$dir/message-reads-acceptance.local.json');
      for (final p in [dir, file.path, '$dir/business-acceptance.lock']) {
        if (FileSystemEntity.isLinkSync(p)) throw StateError('Links refused');
      }
      lock =
          File('$dir/business-acceptance.lock').openSync(mode: FileMode.append);
      lock.lockSync(FileLock.exclusive);
      final accounts = (fixture['accounts'] as List).cast<Map>();
      final oa = accounts.singleWhere((a) => a['role'] == 'owner'),
          pa = accounts.singleWhere((a) => a['role'] == 'provider');
      Future<SupabaseBackendProvider> login(Map account) async {
        final client = SupabaseClient(config['SUPABASE_URL'] as String,
            config['SUPABASE_PUBLISHABLE_KEY'] as String,
            authOptions: const AuthClientOptions(autoRefreshToken: false));
        clients.add(client);
        final marker = await client.rpc('get_app_environment');
        expect(marker['environment'], 'staging');
        expect(marker['project_ref'], businessStagingRef);
        final result = await client.auth.signInWithPassword(
            email: account['email'] as String,
            password: account['password'] as String);
        if (account['user_id'] != null)
          expect(result.user!.id, account['user_id']);
        return SupabaseBackendProvider(client);
      }

      final owner = await login(oa), provider = await login(pa);
      final property = ((await SupabaseWorkspaceRepository(owner)
              .properties())['items'] as List)
          .cast<Map>()
          .singleWhere((p) => p['unit_name'] == '[TEST] Unit A');
      final service = (await owner.owner.serviceTypes())
          .singleWhere((s) => s['name'] == 'Standard cleaning');
      late Map state;
      Future<void> save() async {
        final temp = File('${file.path}.pending');
        if (FileSystemEntity.isLinkSync(temp.path))
          throw StateError('Links refused');
        await temp.writeAsString(jsonEncode(state), flush: true);
        await temp.rename(file.path);
      }

      if (file.existsSync()) {
        state = jsonDecode(await file.readAsString()) as Map;
      } else {
        final myt = DateTime.now().toUtc().add(const Duration(hours: 8));
        final start = DateTime.utc(myt.year, myt.month, myt.day + 9, 2);
        state = {
          'project_ref': businessStagingRef,
          'run_id': fixture['run_id'],
          'version': 1,
          'property_id': property['property_id'],
          'service_type_id': service['service_type_id'],
          'start': start.toIso8601String(),
          'end': start.add(const Duration(hours: 2)).toIso8601String(),
          for (final key in ['request_id', 'one', 'two', 'three', 'reply'])
            key: BookingRequestToken.newV4()
        };
        await save();
      }
      expect(state['project_ref'], businessStagingRef);
      expect(state['run_id'], fixture['run_id']);
      expect(state['version'], 1);
      expect(state['property_id'], property['property_id']);
      expect(state['service_type_id'], service['service_type_id']);
      for (final key in ['request_id', 'one', 'two', 'three', 'reply'])
        expect(state[key], matches(businessUuid));
      expect(
          ['request_id', 'one', 'two', 'three', 'reply']
              .map((k) => state[k])
              .toSet()
              .length,
          5);
      final from = DateTime.parse(state['start'] as String),
          to = DateTime.parse(state['end'] as String);
      expect(to.difference(from), const Duration(hours: 2));
      expect(from.isUtc && to.isUtc, true);
      stage = 'dedicated request';
      final existing = await owner.bookings
          .createdBookingIdForToken(state['request_id'] as String);
      final id = existing ??
          (await owner.bookings.createPending(
                  clientRequestId: state['request_id'] as String,
                  providerId: pa['user_id'] as String,
                  propertyId: state['property_id'] as String,
                  serviceTypeId: state['service_type_id'] as String,
                  start: from,
                  end: to,
                  expectedAmount: 80,
                  expectedBasis: 'hourly',
                  instructions:
                      '[TEST] P2-1 receipt acceptance; no actual service or payment.'))
              .bookingId;
      if (state['booking_id'] != null) expect(state['booking_id'], id);
      state['booking_id'] = id;
      await save();
      if (await provider.bookings.currentStatus(id) == 'Pending')
        expect((await provider.bookings.acceptPending(id)).accepted, true);
      Future<int> count(SupabaseBackendProvider backend) async =>
          (await backend.messages.conversations(''))
              .page
              .items
              .singleWhere((r) => r.bookingId == id)
              .unread;
      Future<String> send(SupabaseBackendProvider backend, String key) async {
        await backend.messages.send(
            bookingId: id,
            clientMessageId: state[key] as String,
            body: '[TEST] P2-1 $key synthetic receipt message.');
        return (await backend.messages.page(id, null))
            .items
            .singleWhere(
                (m) => m.body == '[TEST] P2-1 $key synthetic receipt message.')
            .id;
      }

      if (state['read_proof'] != true) {
        stage = 'partial read and newly arriving unread';
        final one = await send(owner, 'one'), two = await send(owner, 'two');
        if (state['partial_proof'] != true) {
          expect(await count(owner), 0);
          expect(await count(provider), 2);
          await provider.messages.markRead(id, [one]);
          expect(await count(provider), 1);
          state['partial_proof'] = true;
          await save();
        }
        final three = await send(owner, 'three');
        expect(await count(provider), 2);
        await provider.messages.markRead(id, [one]);
        expect(await count(provider), 2);
        final reply = await send(provider, 'reply');
        expect(await count(owner), 1);
        await expectLater(
            provider.messages.markRead(id, [reply]),
            throwsA(isA<PostgrestException>()
                .having((e) => e.code, 'own denied', '42501')));
        await provider.messages.markRead(id, [two, three]);
        expect(await count(provider), 0);
        await owner.messages.markRead(id, [reply]);
        expect(await count(owner), 0);
        state['read_proof'] = true;
        await save();
      }
      stage = 'closed thread retains receipts';
      if (await owner.bookings.currentStatus(id) == 'Accepted') {
        await owner.bookings.transition(id, 'Cancelled',
            reason: '[TEST] message receipt acceptance completed');
      }
      expect(state['partial_proof'], true);
      expect(state['read_proof'], true);
      stage = 'fresh login, global counts, filter and denied outsider';
      for (final account in accounts) {
        final again = await login(account);
        expect(await again.bookings.currentStatus(id), 'Cancelled');
        expect(await count(again), 0);
        expect(
            (await again.messages.conversations('', unreadOnly: true))
                .page
                .items
                .any((r) => r.bookingId == id),
            false);
        expect((await again.messages.conversations('')).unreadTotal,
            await again.messages.unread());
        expect((await again.messages.page(id, null)).items.length, 4);
      }
      final original =
          jsonDecode(await File('$dir/accounts.local.json').readAsString())
              as Map;
      expect(original['project_ref'], businessStagingRef);
      final otherAccount = (original['accounts'] as List)
          .cast<Map>()
          .singleWhere((a) => a['role'] == 'owner');
      expect(otherAccount['email'], 'owner.a@rental-test.invalid');
      final other = await login(otherAccount);
      final target = (await owner.messages.page(id, null)).items.first.id;
      await expectLater(
          other.messages.markRead(id, [target]),
          throwsA(isA<PostgrestException>()
              .having((e) => e.code, 'outsider denied', '42501')));
      state['passed'] = true;
      state['passed_at'] = DateTime.now().toUtc().toIso8601String();
      await save();
      print(
          'PASS: exact inbound-only receipts, partial read/new arrival, both-role re-login, global/filter consistency, closed history, outsider denial. No old conversation was marked read.');
    } catch (error) {
      throw TestFailure(
          'Message acceptance stopped at $stage; type=${error.runtimeType}; '
          'SQLSTATE=${error is PostgrestException ? error.code : 'n/a'}. Keep checkpoint; no private output.');
    } finally {
      for (final client in clients.reversed) {
        try {
          if (client.auth.currentSession != null)
            await client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {}
        await client.dispose();
      }
      if (lock != null) {
        lock.unlockSync();
        await lock.close();
      }
    }
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 5)));
}
