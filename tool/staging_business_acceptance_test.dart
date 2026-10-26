// Explicitly opted-in HOSTED WRITES with ordinary dedicated fixture identities.
// No service_role, SQL overrides, admin seeding, payment or automatic cleanup.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/backend/supabase_booking_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_workspace_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_notification_repository.dart';
import 'package:rental_app_demo/services/backend/notification_snapshot.dart';
import 'package:rental_app_demo/services/backend/supabase_earnings_repository.dart';
import 'package:rental_app_demo/services/backend/earnings_snapshot.dart';
import 'package:rental_app_demo/services/backend/evidence_upload_flow.dart';
import 'staging_business_acceptance_support.dart';

class _RealBusinessBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _RealBusinessBinding();
  const enabled = bool.fromEnvironment('RUN_STAGING_BUSINESS_ACCEPTANCE');
  const confirmation = String.fromEnvironment('STAGING_WRITE_PROJECT');
  test(
    'real isolated two-role business lifecycle, evidence and reports',
    () async {
      var stage = 'target guards';
      final clients = <SupabaseClient>[];
      RandomAccessFile? runLock;
      try {
        final config = jsonDecode(
          await File('supabase/backend_config.staging.local.json')
              .readAsString(),
        ) as Map;
        final privateDir = Directory('output/staging-private');
        final manifest = File('${privateDir.path}/booking-fixture.local.json');
        final stateFile =
            File('${privateDir.path}/business-acceptance.local.json');
        for (final path in [privateDir.path, manifest.path, stateFile.path]) {
          if (FileSystemEntity.isLinkSync(path)) {
            throw StateError('Links refused.');
          }
        }
        final fixture = jsonDecode(await manifest.readAsString()) as Map;
        requireBusinessTarget(config, fixture, confirmation);
        final lockFile = File('${privateDir.path}/business-acceptance.lock');
        if (FileSystemEntity.isLinkSync(lockFile.path)) {
          throw StateError('Links refused.');
        }
        runLock = lockFile.openSync(mode: FileMode.append);
        runLock.lockSync(FileLock.exclusive);
        final accounts = (fixture['accounts'] as List).cast<Map>();
        final ownerAccount = accounts.singleWhere((a) => a['role'] == 'owner');
        final providerAccount =
            accounts.singleWhere((a) => a['role'] == 'provider');

        Future<SupabaseBackendProvider> login(Map account) async {
          final client = SupabaseClient(
            config['SUPABASE_URL'] as String,
            config['SUPABASE_PUBLISHABLE_KEY'] as String,
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
          expect(result.user!.id, account['user_id']);
          expect(result.user!.appMetadata['test_run_id'], fixture['run_id']);
          expect(result.user!.appMetadata['synthetic_test_account'], true);
          final backend = SupabaseBackendProvider(client);
          expect(
            (await backend.auth.currentIdentity())!.role.name,
            account['role'],
          );
          return backend;
        }

        stage = 'ordinary fixture password login';
        final owner = await login(ownerAccount);
        final provider = await login(providerAccount);
        final profile = await provider.provider.myProfile();
        expect(profile.approval, 'approved');
        final properties =
            await SupabaseWorkspaceRepository(owner).properties();
        final property = (properties['items'] as List)
            .cast<Map>()
            .singleWhere((p) => p['unit_name'] == '[TEST] Unit A');
        final service = (await owner.owner.serviceTypes())
            .singleWhere((s) => s['name'] == 'Standard cleaning');
        late Map<String, dynamic> state;
        Future<void> saveState() async {
          // Non-secret stable request/upload/message IDs persisted before writes.
          // Same manifest/checkpoint must be retained to resume uncertain responses.
          final pending = File('${stateFile.path}.pending');
          if (FileSystemEntity.isLinkSync(pending.path)) {
            throw StateError('Links refused.');
          }
          await pending.writeAsString(jsonEncode(state), flush: true);
          await pending.rename(stateFile.path);
        }

        if (await stateFile.exists()) {
          state = Map<String, dynamic>.from(
            jsonDecode(await stateFile.readAsString()) as Map,
          );
        } else {
          stage = 'server eligibility selection';
          final myt = DateTime.now().toUtc().add(const Duration(hours: 8));
          DateTime? selected;
          for (var day = 1; day <= 7 && selected == null; day++) {
            final start = DateTime.utc(myt.year, myt.month, myt.day + day, 2);
            final found = await owner.owner.eligibleProviders(
              propertyId: property['property_id'] as String,
              serviceTypeId: service['service_type_id'] as String,
              start: start,
              end: start.add(const Duration(hours: 2)),
            );
            if (found.any(
              (p) =>
                  p.providerId == providerAccount['user_id'] &&
                  p.quotedAmount == 80 &&
                  p.quoteBasis == 'hourly',
            )) selected = start;
          }
          expect(
            selected,
            isNotNull,
            reason: 'A genuinely eligible future slot is required.',
          );
          state = {
            'version': 1,
            'project_ref': businessStagingRef,
            'run_id': fixture['run_id'],
            'request_id': BookingRequestToken.newV4(),
            'owner_message_id': BookingRequestToken.newV4(),
            'provider_message_id': BookingRequestToken.newV4(),
            'before_upload_id': BookingRequestToken.newV4(),
            'after_upload_id': BookingRequestToken.newV4(),
            'property_id': property['property_id'],
            'service_type_id': service['service_type_id'],
            'start': selected!.toIso8601String(),
            'end': selected.add(const Duration(hours: 2)).toIso8601String(),
            'amount': 80,
            'basis': 'hourly',
            'synthetic_service': true,
            'synthetic_pixels': true,
            'payment_verified': false,
          };
          requireBusinessState(state, fixture);
          await saveState();
        }
        requireBusinessState(state, fixture);
        expect(state['property_id'], property['property_id']);
        expect(state['service_type_id'], service['service_type_id']);
        final start = DateTime.parse(state['start'] as String);
        final end = DateTime.parse(state['end'] as String);
        final instructions =
            '[TEST] P1-3 synthetic business acceptance ${fixture['run_id']}; '
            'no real cleaning or payment. Synthetic before/after pixels.';

        stage = 'Owner create request and same-token retry';
        Future<BookingCreationOutcome> create() => owner.bookings.createPending(
              clientRequestId: state['request_id'] as String,
              providerId: providerAccount['user_id'] as String,
              propertyId: state['property_id'] as String,
              serviceTypeId: state['service_type_id'] as String,
              start: start,
              end: end,
              expectedAmount: 80,
              expectedBasis: 'hourly',
              instructions: instructions,
            );
        final created = await create();
        final retry = await create();
        expect(retry.bookingId, created.bookingId);
        expect(retry.reused, true);
        final id = created.bookingId;
        if (state['booking_id'] != null) expect(state['booking_id'], id);
        state['booking_id'] = id;
        await saveState();
        expect(
          await owner.bookings
              .createdBookingIdForToken(state['request_id'] as String),
          id,
        );
        for (final backend in [owner, provider]) {
          final card = (await backend.bookings.readCard(id))!;
          expect(card['owner_id'], ownerAccount['user_id']);
          expect(card['provider_id'], providerAccount['user_id']);
          expect(card['quoted_amount'], 80);
          final calendar = await backend.bookings.schedulePage(
            startUtc: start.subtract(const Duration(hours: 1)),
            endUtc: end.add(const Duration(hours: 1)),
          );
          expect(calendar.items.any((b) => b['booking_id'] == id), true);
        }
        String status = (await provider.bookings.currentStatus(id))!;
        expect(
          ['Pending', 'Accepted', 'In Progress', 'Completed'],
          contains(status),
        );
        if (status == 'Pending') {
          final noti = await SupabaseNotificationRepository(provider.client)
              .page(NotificationFilter.action);
          expect(
            noti.items.any((n) => n.bookingId == id && n.status == 'Pending'),
            true,
          );
          stage = 'assigned Provider acceptance';
          expect((await provider.bookings.acceptPending(id)).accepted, true);
          status = 'Accepted';
        }
        print(
          'PASS: real Owner request + idempotent retry, both calendars, Provider acceptance.',
        );

        stage = 'both-role persisted messages';
        if (status == 'Accepted' || status == 'In Progress') {
          await owner.messages.send(
            bookingId: id,
            clientMessageId: state['owner_message_id'] as String,
            body: '[TEST] Owner: synthetic appointment access confirmed.',
          );
          await provider.messages.send(
            bookingId: id,
            clientMessageId: state['provider_message_id'] as String,
            body: '[TEST] Provider: synthetic test instructions received.',
          );
        }
        for (final backend in [owner, provider]) {
          final messages = (await backend.messages.page(id, null)).items;
          expect(messages.length, 2);
          expect(
            messages.map((m) => m.senderUserId).toSet(),
            {ownerAccount['user_id'], providerAccount['user_id']},
          );
          expect(
            (await backend.messages.conversations(''))
                .page
                .items
                .any((c) => c.bookingId == id),
            true,
          );
        }
        stage = 'Provider start and missing-evidence refusal';
        if (status == 'Accepted') {
          expect(
            await provider.bookings.transition(id, 'In Progress'),
            'In Progress',
          );
          status = 'In Progress';
        }
        if (status == 'In Progress') {
          final initial = await provider.evidence.forBooking(id);
          if (initial?.beforePath == null ||
              initial?.afterPath == null ||
              initial!.remarks.isEmpty) {
            await expectLater(
              provider.bookings.transition(id, 'Completed'),
              throwsA(
                isA<PostgrestException>()
                    .having((e) => e.code, 'evidence required', '23514'),
              ),
            );
            expect(await provider.bookings.currentStatus(id), 'In Progress');
          }
          for (final kind in EvidenceKind.values) {
            stage = 'real Edge validation and private ${kind.name} upload';
            final upload = state['${kind.name}_upload_id'] as String;
            final current = await provider.evidence.forBooking(id);
            final previous = kind == EvidenceKind.before
                ? current?.beforePath
                : current?.afterPath;
            final expectedPath = '$id/${kind.name}_$upload.png';
            if (previous != expectedPath) {
              expect(
                previous,
                isNull,
                reason: 'Never replace another selected photo.',
              );
              expect(
                await provider.evidence.upload(
                  bookingId: id,
                  kind: kind,
                  bytes: businessTestPhoto(kind == EvidenceKind.before),
                  uploadId: upload,
                  expectedPreviousPath: null,
                ),
                expectedPath,
              );
            }
          }
          stage = 'Provider remarks and completion';
          await provider.evidence.saveRemarks(
            id,
            '[TEST] Synthetic pixel fixtures only. Functional acceptance, not actual service or payment.',
          );
          expect(
            await provider.bookings.transition(id, 'Completed'),
            'Completed',
          );
          status = 'Completed';
        }
        stage = 'both-role private image downloads';
        final evidence = (await provider.evidence.forBooking(id))!;
        for (final path in [evidence.beforePath!, evidence.afterPath!]) {
          final ownerBytes = await owner.evidence.download(path);
          final providerBytes = await provider.evidence.download(path);
          expect(ownerBytes, orderedEquals(providerBytes));
          final decoded = image.decodePng(ownerBytes)!;
          expect(decoded.width, 160);
          expect(decoded.height, 80);
        }
        print(
          'PASS: start, missing-evidence refusal, real validator/Storage, both private downloads, completion.',
        );

        stage = 'Owner persisted review';
        final review = await owner.reviews.save(
          id,
          5,
          '[TEST] Functional test rating; not a real customer endorsement.',
        );
        expect(review.rating, 5);
        expect((await provider.reviews.forBooking(id))!.rating, 5);
        stage = 'completion-based reports across all ranges';
        for (final period in EarningsPeriod.values) {
          final earnings =
              await SupabaseEarningsRepository(provider.client).read(period);
          expect(
            earnings.records.any(
              (r) =>
                  r.bookingId == id && r.gross == 80 && !r.settlementAvailable,
            ),
            true,
          );
          final spending = await SupabaseWorkspaceRepository(owner)
              .read('owner_spending', params: {'p_period': period.name});
          expect(
            (spending['items'] as List)
                .cast<Map>()
                .any((r) => r['booking_id'] == id && r['quoted_amount'] == 80),
            true,
          );
        }
        final stats = await SupabaseWorkspaceRepository(provider)
            .read('my_provider_statistics');
        expect(stats['completed'], greaterThanOrEqualTo(1));
        expect((stats['ratings'] as Map)['5'], greaterThanOrEqualTo(1));
        stage = 'notification read receipts';
        final notificationRepo = SupabaseNotificationRepository(owner.client);
        final notices = await notificationRepo.page(NotificationFilter.all);
        final completion = notices.items
            .singleWhere((n) => n.bookingId == id && n.status == 'Completed');
        await notificationRepo.mark(ids: [completion.id]);
        expect(
          (await notificationRepo.page(NotificationFilter.all))
              .items
              .singleWhere((n) => n.id == completion.id)
              .read,
          true,
        );
        stage = 'history and sign-in persistence';
        final history = (await owner.bookings.historyPage(id, null)).items;
        expect(
          history.map((h) => h['new_status']).toSet(),
          {'Pending', 'Accepted', 'In Progress', 'Completed'},
        );
        expect(history.length, 4);
        for (final account in accounts) {
          final again = await login(account);
          expect(await again.bookings.currentStatus(id), 'Completed');
          expect((await again.messages.page(id, null)).items.length, 2);
          expect((await again.reviews.forBooking(id))!.rating, 5);
          expect(
            (await again.evidence.forBooking(id))!.beforePath,
            evidence.beforePath,
          );
          if (account['role'] == 'owner') {
            expect(
              (await SupabaseNotificationRepository(again.client)
                      .page(NotificationFilter.all))
                  .items
                  .singleWhere((n) => n.id == completion.id)
                  .read,
              true,
            );
          }
        }
        state['last_passed_at'] = DateTime.now().toUtc().toIso8601String();
        state['status'] = 'Completed';
        state['repository_acceptance'] = 'passed';
        state['device_uat'] = 'not_run';
        await saveState();
        print(
          'PASS: review, three report ranges, history, receipts, re-login persistence.',
        );
        print(
          'P1-3 repository acceptance PASS; booking=$id; synthetic service/photos; no payment or device UAT claimed.',
        );
      } catch (error) {
        final code = error is PostgrestException ? error.code : null;
        // Do not serialize upstream responses, tokens, passwords or file bytes.
        throw TestFailure('Business acceptance stopped at: $stage; '
            'type=${error.runtimeType}; SQLSTATE=${code ?? 'n/a'}. '
            'Keep the checkpoint; never reset/overwrite cloud history to retry.');
      } finally {
        for (final client in clients.reversed) {
          try {
            if (client.auth.currentSession != null) {
              await client.auth.signOut(scope: SignOutScope.local);
            }
          } catch (_) {/* Only this tool session; never global sign-out. */}
          await client.dispose();
        }
        if (runLock != null) {
          runLock.unlockSync();
          await runLock.close();
        }
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
