// Opt-in real Staging negative-path writes; at most seven dedicated appointments.
// No administrator key, role override, SQL mutation, clock override or deletion.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/backend/supabase_booking_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_workspace_repository.dart';
import 'package:rental_app_demo/services/backend/evidence_upload_flow.dart';
import 'staging_business_acceptance_support.dart';
import 'staging_negative_support.dart';

class _NegativeBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _NegativeBinding();
  const enabled = bool.fromEnvironment('RUN_STAGING_NEGATIVE_ACCEPTANCE');
  const confirmation = String.fromEnvironment('STAGING_WRITE_PROJECT');
  test(
    'isolated hosted cancellation/revision/conflict/network/permission acceptance',
    () async {
      var stage = 'target guards';
      final clients = <SupabaseClient>[];
      final transports = <StagingFaultClient>[];
      RandomAccessFile? lock;
      try {
        final config = jsonDecode(
          await File('supabase/backend_config.staging.local.json')
              .readAsString(),
        ) as Map;
        const dir = 'output/staging-private';
        final stateFile = File('$dir/negative-acceptance.local.json');
        for (final path in [
          dir,
          '$dir/booking-fixture.local.json',
          stateFile.path,
          '$dir/business-acceptance.lock',
        ]) {
          if (FileSystemEntity.isLinkSync(path)) {
            throw StateError('Links refused.');
          }
        }
        final fixture = jsonDecode(
          await File('$dir/booking-fixture.local.json').readAsString(),
        ) as Map;
        requireBusinessTarget(config, fixture, confirmation);
        lock = File('$dir/business-acceptance.lock')
            .openSync(mode: FileMode.append);
        lock.lockSync(FileLock.exclusive);
        final accounts = (fixture['accounts'] as List).cast<Map>();
        final oa = accounts.singleWhere((a) => a['role'] == 'owner');
        final pa = accounts.singleWhere((a) => a['role'] == 'provider');
        Future<SupabaseBackendProvider> login(Map account) async {
          final transport = StagingFaultClient(http.Client());
          transports.add(transport);
          final client = SupabaseClient(
            config['SUPABASE_URL'] as String,
            config['SUPABASE_PUBLISHABLE_KEY'] as String,
            httpClient: transport,
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          );
          clients.add(client);
          final marker = await client.rpc('get_app_environment');
          expect(marker['environment'], 'staging');
          expect(marker['project_ref'], businessStagingRef);
          final result = await client.auth.signInWithPassword(
            email: account['email'] as String,
            password: account['password'] as String,
          );
          if (account['user_id'] != null) {
            expect(result.user!.id, account['user_id']);
          }
          if (accounts.contains(account)) {
            expect(result.user!.appMetadata['test_run_id'], fixture['run_id']);
            expect(result.user!.appMetadata['synthetic_test_account'], true);
          }
          return SupabaseBackendProvider(client);
        }

        stage = 'dedicated identities and readiness';
        final owner = await login(oa);
        final ownerWire = transports.last;
        final provider = await login(pa);
        final providerWire = transports.last;
        final concurrentProvider = await login(pa);
        expect((await provider.provider.myProfile()).approval, 'approved');
        final property = ((await SupabaseWorkspaceRepository(owner)
                .properties())['items'] as List)
            .cast<Map>()
            .singleWhere((p) => p['unit_name'] == '[TEST] Unit A');
        final service = (await owner.owner.serviceTypes())
            .singleWhere((s) => s['name'] == 'Standard cleaning');
        late Map<String, dynamic> state;
        Future<void> save() async {
          final pending = File('${stateFile.path}.pending');
          if (FileSystemEntity.isLinkSync(pending.path)) {
            throw StateError('Links refused.');
          }
          requireNegativeState(state, fixture);
          await pending.writeAsString(jsonEncode(state), flush: true);
          await pending.rename(stateFile.path);
        }

        if (stateFile.existsSync()) {
          state = Map<String, dynamic>.from(
            jsonDecode(await stateFile.readAsString()) as Map,
          );
        } else {
          final myt = DateTime.now().toUtc().add(const Duration(hours: 8));
          final cases = <String, dynamic>{};
          const offsets = {
            'cancel_pending': 2,
            'decline': 3,
            'revise': 4,
            'cancel_provider': 5,
            'conflict_a': 6,
            'conflict_b': 6,
            'upload': 7,
          };
          for (final entry in offsets.entries) {
            final start =
                DateTime.utc(myt.year, myt.month, myt.day + entry.value, 2);
            cases[entry.key] = {
              for (final field in [
                'request_id',
                'message_id',
                'bad_upload_id',
                'before_upload_id',
                'after_upload_id',
              ])
                field: BookingRequestToken.newV4(),
              'start': start.toIso8601String(),
              'end': start.add(const Duration(hours: 2)).toIso8601String(),
              'passed': false,
            };
          }
          state = {
            'version': 1,
            'project_ref': businessStagingRef,
            'run_id': fixture['run_id'],
            'property_id': property['property_id'],
            'service_type_id': service['service_type_id'],
            'cases': cases,
          };
          await save();
        }
        requireNegativeState(state, fixture);
        expect(state['property_id'], property['property_id']);
        expect(state['service_type_id'], service['service_type_id']);
        final cases = state['cases'] as Map;
        Map c(String name) => cases[name] as Map;
        DateTime start(String name) =>
            DateTime.parse(c(name)['start'] as String);
        DateTime end(String name) => DateTime.parse(c(name)['end'] as String);
        String instructions(String name) =>
            '[TEST] P1-4 $name ${fixture['run_id']}; synthetic acceptance, no real service/payment.';
        Future<BookingCreationOutcome> create(
          String name, {
          SupabaseBackendProvider? actor,
          String? token,
          DateTime? from,
          DateTime? to,
          num amount = 80,
        }) =>
            (actor ?? owner).bookings.createPending(
                  clientRequestId: token ?? c(name)['request_id'] as String,
                  providerId: pa['user_id'] as String,
                  propertyId: state['property_id'] as String,
                  serviceTypeId: state['service_type_id'] as String,
                  start: from ?? start(name),
                  end: to ?? end(name),
                  expectedAmount: amount,
                  expectedBasis: 'hourly',
                  instructions: instructions(name),
                );
        Future<String> ensure(String name) async {
          final item = c(name);
          final existing = await owner.bookings
              .createdBookingIdForToken(item['request_id'] as String);
          final id = existing ?? (await create(name)).bookingId;
          if (item['booking_id'] != null) expect(item['booking_id'], id);
          final row = (await owner.bookings.readCard(id))!;
          expect(row['owner_id'], oa['user_id']);
          expect(row['provider_id'], pa['user_id']);
          expect(row['property_id'], state['property_id']);
          expect(row['instructions'], instructions(name));
          expect(row['quoted_amount'], 80);
          item['booking_id'] = id;
          await save();
          return id;
        }

        Future<void> denied(
          Future<dynamic> action,
          String code,
        ) async =>
            expectLater(
              action,
              throwsA(
                isA<PostgrestException>()
                    .having((e) => e.code, 'SQLSTATE', code),
              ),
            );
        Future<void> rejected(Future<dynamic> action, String reason) async =>
            expectLater(
              action,
              throwsA(
                isA<BookingRequestRejected>()
                    .having((e) => e.reason, 'reason', reason),
              ),
            );
        Future<void> done(String name, String status, int histories) async {
          final id = c(name)['booking_id'] as String;
          expect(await provider.bookings.currentStatus(id), status);
          expect(
            (await owner.bookings.historyPage(id, null)).items.length,
            histories,
          );
          c(name)['passed'] = true;
          await save();
          print('PASS: $name; state=$status; history=$histories.');
        }

        Future<void> unchanged(String id, DateTime at) async {
          final row = (await owner.bookings.readCard(id))!;
          expect(
            DateTime.parse(row['requested_start_at'] as String).toUtc(),
            at,
          );
          expect(row['quoted_amount'], 80);
        }

        stage =
            'before-send/lost-success request, Pending cancellation and direct-write denial';
        const cancel = 'cancel_pending';
        if (c(cancel)['passed'] != true) {
          final existing = await owner.bookings
              .createdBookingIdForToken(c(cancel)['request_id'] as String);
          if (existing == null) {
            ownerWire.arm(
              '/rest/v1/rpc/create_pending_booking',
              TestNetworkFault.beforeSend,
            );
            await expectLater(
              create(cancel),
              throwsA(isA<InjectedTransportTimeout>()),
            );
            expect(
              await owner.bookings
                  .createdBookingIdForToken(c(cancel)['request_id'] as String),
              isNull,
            );
            ownerWire.arm(
              '/rest/v1/rpc/create_pending_booking',
              TestNetworkFault.afterSuccess,
            );
            await expectLater(
              create(cancel),
              throwsA(isA<InjectedTransportTimeout>()),
            );
            expect(
              await owner.bookings
                  .createdBookingIdForToken(c(cancel)['request_id'] as String),
              isNotNull,
            );
            state['request_faults_proven'] = true;
            await save();
          }
          final id = await ensure(cancel);
          if (await owner.bookings.currentStatus(id) == 'Pending') {
            expect((await create(cancel)).reused, true);
            await denied(
              owner.client.rpc(
                'create_pending_booking',
                params: {
                  'p_client_request_id': c(cancel)['request_id'],
                  'p_provider_id': pa['user_id'],
                  'p_property_id': state['property_id'],
                  'p_service_type_id': state['service_type_id'],
                  'p_start_at': start(cancel).toIso8601String(),
                  'p_end_at': end(cancel).toIso8601String(),
                  'p_expected_amount': 80,
                  'p_expected_basis': 'hourly',
                  'p_instructions': 'changed payload',
                },
              ),
              '23514',
            );
            await denied(
              owner.client
                  .from('booking')
                  .update({'current_status': 'Completed'}).eq('booking_id', id),
              '42501',
            );
            await denied(
              provider.bookings.transition(
                id,
                'Cancelled',
                reason: '[TEST] forbidden Pending cancel',
              ),
              '42501',
            );
            await denied(
              owner.client.rpc(
                'transition_booking',
                params: {
                  'p_booking_id': id,
                  'p_new_status': 'Cancelled',
                  'p_reason': null,
                },
              ),
              '23514',
            );
            expect(await owner.bookings.currentStatus(id), 'Pending');
            ownerWire.arm(
              '/rest/v1/rpc/transition_booking',
              TestNetworkFault.afterSuccess,
            );
            await expectLater(
              owner.bookings.transition(
                id,
                'Cancelled',
                reason: '[TEST] Owner withdrew request',
              ),
              throwsA(isA<InjectedTransportTimeout>()),
            );
          }
          await denied(
            owner.bookings.transition(
              id,
              'Cancelled',
              reason: '[TEST] repeated cancellation',
            ),
            '42501',
          );
          await done(cancel, 'Cancelled', 2);
        }
        stage = 'Owner cannot decline; assigned Provider can decline Pending';
        if (c('decline')['passed'] != true) {
          final id = await ensure('decline');
          if (await provider.bookings.currentStatus(id) == 'Pending') {
            await denied(owner.bookings.transition(id, 'Declined'), '42501');
            expect(
              await provider.bookings.transition(id, 'Declined'),
              'Declined',
            );
          }
          expect(
            (await provider.bookings.acceptPending(id)).reason,
            'not_pending',
          );
          await done('decline', 'Declined', 2);
        }
        stage =
            'Pending revision: actor, duration, rental window and lost response';
        if (c('revise')['passed'] != true) {
          final id = await ensure('revise');
          Future<AcceptanceOutcome> revise(
            SupabaseBackendProvider actor,
            DateTime from,
            DateTime to,
          ) =>
              actor.bookings.revisePending(
                bookingId: id,
                start: from,
                end: to,
                instructions: instructions('revise'),
              );
          if (await provider.bookings.currentStatus(id) == 'Pending') {
            await denied(
              revise(provider, start('revise'), end('revise')),
              '42501',
            );
            final moved = start('revise').add(const Duration(hours: 4));
            if (DateTime.parse(
                  (await owner.bookings.readCard(id))!['requested_start_at']
                      as String,
                ).toUtc() !=
                moved) {
              ownerWire.arm(
                '/rest/v1/rpc/revise_pending_booking',
                TestNetworkFault.afterSuccess,
              );
              await expectLater(
                revise(owner, moved, moved.add(const Duration(hours: 2))),
                throwsA(isA<InjectedTransportTimeout>()),
              );
            }
            await unchanged(id, moved);
            await denied(
              revise(owner, moved, moved.add(const Duration(hours: 3))),
              '23514',
            );
            expect(
              (await revise(
                owner,
                moved.add(const Duration(hours: 8)),
                moved.add(const Duration(hours: 10)),
              ))
                  .reason,
              'rental_window',
            );
            await unchanged(id, moved);
            expect((await provider.bookings.acceptPending(id)).accepted, true);
          }
          if (await provider.bookings.currentStatus(id) == 'Accepted') {
            await denied(
              revise(owner, start('revise'), end('revise')),
              '42501',
            );
            expect(
              await owner.bookings.transition(
                id,
                'Cancelled',
                reason: '[TEST] Owner cancelled before work',
              ),
              'Cancelled',
            );
          }
          await done('revise', 'Cancelled', 3);
        }
        stage = 'acceptance response lost and Provider accepted cancellation';
        if (c('cancel_provider')['passed'] != true) {
          final id = await ensure('cancel_provider');
          if (await provider.bookings.currentStatus(id) == 'Pending') {
            await denied(owner.bookings.acceptPending(id), '42501');
            providerWire.arm(
              '/rest/v1/rpc/accept_pending_booking',
              TestNetworkFault.afterSuccess,
            );
            await expectLater(
              provider.bookings.acceptPending(id),
              throwsA(isA<InjectedTransportTimeout>()),
            );
          }
          if (await provider.bookings.currentStatus(id) == 'Accepted') {
            expect(
              (await provider.bookings.acceptPending(id)).reason,
              'not_pending',
            );
            await denied(owner.bookings.transition(id, 'In Progress'), '42501');
            expect(
              await provider.bookings.transition(
                id,
                'Cancelled',
                reason: '[TEST] Provider cancelled before work',
              ),
              'Cancelled',
            );
          }
          await done('cancel_provider', 'Cancelled', 3);
        }
        stage =
            'simultaneous acceptance, conflict refusal and cancellation releases slot';
        if (c('conflict_a')['passed'] != true ||
            c('conflict_b')['passed'] != true) {
          final a = await ensure('conflict_a'), b = await ensure('conflict_b');
          final sa = await provider.bookings.currentStatus(a),
              sb = await provider.bookings.currentStatus(b);
          if (sa == 'Pending' && sb == 'Pending') {
            final decisions = await Future.wait([
              provider.bookings.acceptPending(a),
              concurrentProvider.bookings.acceptPending(b),
            ]);
            expect(decisions.where((d) => d.accepted).length, 1);
            expect(
              decisions.singleWhere((d) => !d.accepted).reason,
              'slot_conflict',
            );
            state['concurrent_acceptance_proven'] = true;
            await save();
          }
          final states = {
            a: await provider.bookings.currentStatus(a),
            b: await provider.bookings.currentStatus(b),
          };
          if (states.values.contains('Accepted') &&
              states.values.contains('Pending')) {
            final winner =
                states.keys.singleWhere((id) => states[id] == 'Accepted');
            final loser =
                states.keys.singleWhere((id) => states[id] == 'Pending');
            final loserName = loser == a ? 'conflict_a' : 'conflict_b';
            expect(
              (await provider.bookings.acceptPending(loser)).reason,
              'slot_conflict',
            );
            expect(
              (await owner.bookings.revisePending(
                bookingId: loser,
                start: start(loserName),
                end: end(loserName),
                instructions: instructions(loserName),
              ))
                  .reason,
              'slot_conflict',
            );
            await rejected(
              create(
                'conflict_a',
                token: c('conflict_a')['bad_upload_id'] as String,
              ),
              'slot_conflict',
            );
            expect(
              await owner.bookings.createdBookingIdForToken(
                c('conflict_a')['bad_upload_id'] as String,
              ),
              isNull,
            );
            expect(
              await owner.bookings.transition(
                winner,
                'Cancelled',
                reason: '[TEST] release contested slot',
              ),
              'Cancelled',
            );
          }
          // Also resumes after the winner was cancelled but response/checkpoint lost.
          for (final name in ['conflict_a', 'conflict_b']) {
            final id = c(name)['booking_id'] as String;
            if (await provider.bookings.currentStatus(id) == 'Pending') {
              expect(
                (await provider.bookings.acceptPending(id)).accepted,
                true,
              );
            }
            if (await provider.bookings.currentStatus(id) == 'Accepted') {
              expect(
                await provider.bookings.transition(
                  id,
                  'Cancelled',
                  reason: '[TEST] conflict acceptance finished',
                ),
                'Cancelled',
              );
            }
            await done(name, 'Cancelled', 3);
          }
        }
        stage = 'upload entry, early review, In Progress cancellation denial';
        if (c('upload')['passed'] != true) {
          final id = await ensure('upload');
          if (await provider.bookings.currentStatus(id) == 'Pending') {
            expect((await provider.bookings.acceptPending(id)).accepted, true);
          }
          if (await provider.bookings.currentStatus(id) == 'Accepted') {
            expect(
              await provider.bookings.transition(id, 'In Progress'),
              'In Progress',
            );
          }
          if (await provider.bookings.currentStatus(id) == 'In Progress') {
            await denied(
              owner.bookings
                  .transition(id, 'Cancelled', reason: '[TEST] too late'),
              '42501',
            );
            await denied(
              provider.bookings
                  .transition(id, 'Cancelled', reason: '[TEST] too late'),
              '42501',
            );
            await denied(
              owner.reviews.save(id, 5, '[TEST] too early'),
              '23514',
            );
            await denied(
              owner.evidence.upload(
                bookingId: id,
                kind: EvidenceKind.before,
                bytes: businessTestPhoto(true),
                uploadId: c('upload')['before_upload_id'] as String,
                expectedPreviousPath: null,
              ),
              '42501',
            );
            stage =
                'message success response lost, reconcile and token mismatch';
            const body = '[TEST] P1-4 persisted message after response loss.';
            Future<void> message([String text = body]) => owner.messages.send(
                  bookingId: id,
                  clientMessageId: c('upload')['message_id'] as String,
                  body: text,
                );
            if (!await owner.messages
                .wasSent(id, c('upload')['message_id'] as String)) {
              ownerWire.arm(
                '/rest/v1/rpc/send_booking_message',
                TestNetworkFault.afterSuccess,
              );
              await expectLater(
                message(),
                throwsA(isA<InjectedTransportTimeout>()),
              );
            }
            expect(
              await owner.messages
                  .wasSent(id, c('upload')['message_id'] as String),
              true,
            );
            await message();
            await denied(message('different payload'), '23505');
            expect((await provider.messages.page(id, null)).items.length, 1);
            stage = 'real malformed photo rejected and cannot be completed';
            final bad = Uint8List.fromList(
              [137, 80, 78, 71, 13, 10, 26, 10, ...List.filled(32, 0)],
            );
            await expectLater(
              provider.evidence.upload(
                bookingId: id,
                kind: EvidenceKind.before,
                bytes: bad,
                uploadId: c('upload')['bad_upload_id'] as String,
                expectedPreviousPath: null,
              ),
              throwsA(
                isA<EvidenceUploadRejected>()
                    .having((e) => e.reason, 'malformed', 'photo_rejected'),
              ),
            );
            final evidenceBefore = await provider.evidence.forBooking(id);
            if (evidenceBefore?.beforePath == null ||
                evidenceBefore?.afterPath == null) {
              await denied(
                provider.bookings.transition(id, 'Completed'),
                '23514',
              );
            }
            stage =
                'lost real Edge success attaches one validated image and retry keeps same object';
            for (final kind in EvidenceKind.values) {
              final uploadId = c('upload')['${kind.name}_upload_id'] as String;
              final expected = '$id/${kind.name}_$uploadId.png';
              final current = await provider.evidence.forBooking(id);
              final path = kind == EvidenceKind.before
                  ? current?.beforePath
                  : current?.afterPath;
              Future<String> put() => provider.evidence.upload(
                    bookingId: id,
                    kind: kind,
                    bytes: businessTestPhoto(kind == EvidenceKind.before),
                    uploadId: uploadId,
                    expectedPreviousPath: null,
                  );
              if (path == null) {
                if (kind == EvidenceKind.before) {
                  providerWire.arm(
                    '/functions/v1/evidence-validate',
                    TestNetworkFault.afterSuccess,
                  );
                }
                expect(await put(), expected);
              } else {
                expect(path, expected);
              }
              expect(await put(), expected);
            }
            await provider.evidence.saveRemarks(
              id,
              '[TEST] P1-4 synthetic network/upload verification only, no actual service/payment.',
            );
            stage =
                'completion response lost, readback and no duplicate history';
            providerWire.arm(
              '/rest/v1/rpc/transition_booking',
              TestNetworkFault.afterSuccess,
            );
            await expectLater(
              provider.bookings.transition(id, 'Completed'),
              throwsA(isA<InjectedTransportTimeout>()),
            );
          }
          await denied(provider.bookings.transition(id, 'Completed'), '42501');
          await denied(
            provider.reviews.save(id, 5, '[TEST] forbidden self review'),
            '42501',
          );
          await denied(
            owner.messages.send(
              bookingId: id,
              clientMessageId: c('upload')['after_upload_id'] as String,
              body: '[TEST] forbidden new closed-thread message',
            ),
            '23514',
          );
          expect((await owner.messages.page(id, null)).items.length, 1);
          await done('upload', 'Completed', 4);
        }

        stage =
            'forged quote, elapsed interval and oversized duration produce no booking';
        final rejectedToken = c('upload')['bad_upload_id'] as String;
        await rejected(
          create('upload', token: rejectedToken, amount: 1),
          'price_changed',
        );
        final elapsed =
            DateTime.now().toUtc().subtract(const Duration(days: 1));
        await rejected(
          create(
            'upload',
            token: rejectedToken,
            from: elapsed,
            to: elapsed.add(const Duration(hours: 2)),
          ),
          'invalid_interval',
        );
        await rejected(
          create(
            'upload',
            token: rejectedToken,
            to: start('upload').add(const Duration(hours: 9)),
          ),
          'invalid_duration',
        );
        expect(
          await owner.bookings.createdBookingIdForToken(rejectedToken),
          isNull,
        );
        stage =
            'anonymous and unrelated accounts cannot read/mutate fixture records';
        final target = c('upload')['booking_id'] as String;
        final original =
            jsonDecode(await File('$dir/accounts.local.json').readAsString())
                as Map;
        expect(original['project_ref'], businessStagingRef);
        for (final account in (original['accounts'] as List).cast<Map>()) {
          expect(account['email'], '${account['role']}.a@rental-test.invalid');
          final other = await login(account);
          expect(await other.bookings.readCard(target), isNull);
          expect(await other.evidence.forBooking(target), isNull);
          expect(await other.reviews.forBooking(target), isNull);
          await denied(other.messages.page(target, null), '42501');
          await denied(
            other.bookings.transition(
              target,
              'Cancelled',
              reason: '[TEST] forbidden outsider',
            ),
            '42501',
          );
          await denied(other.bookings.acceptPending(target), '42501');
          if (account['role'] == 'owner') {
            await rejected(
              create(
                'upload',
                actor: other,
                token: c('upload')['bad_upload_id'] as String,
              ),
              'property',
            );
          } else {
            expect((await other.provider.myProfile()).approval, 'pending');
          }
          final evidence = (await owner.evidence.forBooking(target))!;
          await expectLater(
            other.client.storage
                .from('cleaning-evidence')
                .download(evidence.beforePath!),
            throwsA(isA<StorageException>()),
          );
        }
        final anon = SupabaseClient(
          config['SUPABASE_URL'] as String,
          config['SUPABASE_PUBLISHABLE_KEY'] as String,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        clients.add(anon);
        await denied(
          anon.rpc(
            'booking_cards_by_ids',
            params: {
              'p_ids': [target],
            },
          ),
          '42501',
        );
        stage = 'final inventory and untouched P1-3 original record';
        final all = (await owner.bookings.page()).items;
        for (final entry in cases.entries) {
          final item = entry.value as Map;
          expect(item['passed'], true);
          final row =
              all.singleWhere((r) => r['booking_id'] == item['booking_id']);
          expect(
            row['current_status'],
            entry.key == 'upload'
                ? 'Completed'
                : entry.key == 'decline'
                    ? 'Declined'
                    : 'Cancelled',
          );
        }
        final business = jsonDecode(
          await File('$dir/business-acceptance.local.json').readAsString(),
        ) as Map;
        requireBusinessState(business, fixture);
        expect(
          await owner.bookings.currentStatus(business['booking_id'] as String),
          'Completed',
        );
        expect(
          (await owner.messages.page(business['booking_id'] as String, null))
              .items
              .length,
          2,
        );
        expect(
          (await owner.reviews.forBooking(business['booking_id'] as String))!
              .rating,
          5,
        );
        expect(state['request_faults_proven'], true);
        expect(state['concurrent_acceptance_proven'], true);
        expect(ownerWire.armed || providerWire.armed, false);
        state['passed_at'] = DateTime.now().toUtc().toIso8601String();
        state['device_offline_uat'] = 'not_run';
        await save();
        print(
          'P1-4 hosted PASS: seven bounded cases, real upstream writes + controlled response loss; no production/user approval mutation or deletion.',
        );
      } catch (error) {
        throw TestFailure(
            'Negative acceptance stopped at $stage; type=${error.runtimeType}; '
            'SQLSTATE=${error is PostgrestException ? error.code : 'n/a'}. '
            'Keep checkpoint/history. No raw response, credential or file bytes logged.');
      } finally {
        for (final client in clients.reversed) {
          try {
            if (client.auth.currentSession != null) {
              await client.auth.signOut(scope: SignOutScope.local);
            }
          } catch (_) {}
          await client.dispose();
        }
        for (final transport in transports) {
          transport.close();
        }
        if (lock != null) {
          lock.unlockSync();
          await lock.close();
        }
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
