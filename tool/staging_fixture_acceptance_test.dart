// Explicit opt-in REAL Staging reads only. No booking acceptance, messages,
// evidence, status transitions, reviews, simulated payments or cleanup writes.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/backend/supabase_workspace_repository.dart';
import 'package:rental_app_demo/services/backend/workspace_binding.dart';
import 'package:rental_app_demo/services/user_session.dart';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _NetworkBinding();
  const enabled = bool.fromEnvironment('RUN_STAGING_FIXTURE_SMOKE');
  test(
      'isolated fixture identities, availability, server quote and RLS isolation',
      () async {
    const ref = 'gqtetdavmrautoojaqrk';
    final config = jsonDecode(
        await File('supabase/backend_config.staging.local.json')
            .readAsString()) as Map;
    final fixture = jsonDecode(
        await File('output/staging-private/booking-fixture.local.json')
            .readAsString()) as Map;
    final original = jsonDecode(
        await File('output/staging-private/accounts.local.json')
            .readAsString()) as Map;
    expect(config['APP_ENV'], 'staging');
    expect(config['SUPABASE_PROJECT_REF'], ref);
    expect(config['SUPABASE_URL'], 'https://$ref.supabase.co');
    expect(config['ALLOW_PRODUCTION_BACKEND'], false);
    expect(fixture['fixture'], 'isolated-booking-run-v1');
    expect(fixture['project_ref'], ref);
    final accounts = (fixture['accounts'] as List).cast<Map>();
    final owner = accounts.singleWhere((a) => a['role'] == 'owner');
    final provider = accounts.singleWhere((a) => a['role'] == 'provider');
    expect(accounts.length, 2);
    for (final account in accounts) {
      expect(account['email'],
          '${account['role']}.${fixture['run_id']}@rental-test.invalid');
      expect((account['password'] as String).length >= 32, true);
      expect(
          (original['accounts'] as List)
              .cast<Map>()
              .any((a) => a['email'] == account['email']),
          false);
    }
    final clients = <SupabaseClient>[];
    Future<SupabaseBackendProvider> login(Map account) async {
      final client = SupabaseClient(config['SUPABASE_URL'] as String,
          config['SUPABASE_PUBLISHABLE_KEY'] as String,
          authOptions: const AuthClientOptions(autoRefreshToken: false));
      clients.add(client);
      final marker = await client.rpc('get_app_environment');
      expect(marker['environment'], 'staging');
      expect(marker['project_ref'], ref);
      final result = await client.auth.signInWithPassword(
          email: account['email'] as String,
          password: account['password'] as String);
      if (account['user_id'] != null)
        expect(result.user!.id, account['user_id']);
      return SupabaseBackendProvider(client);
    }

    try {
      final ownerBackend = await login(owner);
      final providerBackend = await login(provider);
      final ownerIdentity = await ownerBackend.auth.currentIdentity();
      final providerIdentity = await providerBackend.auth.currentIdentity();
      expect(ownerIdentity!.role, UserRole.owner);
      expect(providerIdentity!.role, UserRole.provider);
      final ownerRepo = SupabaseWorkspaceRepository(ownerBackend);
      final portfolio = await ownerRepo.properties();
      expect(portfolio['total_count'], greaterThanOrEqualTo(2));
      final properties =
          List<Map<String, dynamic>>.from(portfolio['items'] as List);
      final property =
          properties.singleWhere((p) => p['unit_name'] == '[TEST] Unit A');
      expect(
          SupabaseWorkspaceRepository.propertyPresentation(property).bedrooms,
          2);
      final profile = await providerBackend.provider.myProfile();
      expect(profile.approval, 'approved');
      expect(profile.selected.length, 2);
      expect(profile.row['hourly_rate'], 40);
      expect(profile.row['daily_rate'], 280);
      expect((profile.row['weekly_slots'] as List).length, 7);
      final services = await ownerBackend.owner.serviceTypes();
      final service =
          services.singleWhere((s) => s['name'] == 'Standard cleaning');
      final day = DateTime.parse(fixture['fixture_date'] as String);
      // This is only eligibility, not a new reservation. Pending does not block.
      final start = DateTime.utc(day.year, day.month, day.day, 2);
      final eligible = await ownerBackend.owner.eligibleProviders(
          propertyId: property['property_id'] as String,
          serviceTypeId: service['service_type_id'] as String,
          start: start,
          end: start.add(const Duration(hours: 2)));
      final found =
          eligible.singleWhere((p) => p.providerId == providerIdentity.userId);
      expect(found.quoteBasis, 'hourly');
      expect(found.quotedAmount, 80);
      final dailyStart = DateTime.utc(day.year, day.month, day.day);
      final fullDay = await ownerBackend.owner.eligibleProviders(
          propertyId: property['property_id'] as String,
          serviceTypeId: service['service_type_id'] as String,
          start: dailyStart,
          end: dailyStart.add(const Duration(hours: 8)));
      final daily =
          fullDay.singleWhere((p) => p.providerId == providerIdentity.userId);
      expect(daily.quoteBasis, 'daily');
      expect(daily.quotedAmount, 280);
      for (final backend in [ownerBackend, providerBackend]) {
        final page = await backend.bookings.page();
        expect(page.items, isNotEmpty);
        for (final row in page.items) {
          expect(row['owner_id'], ownerIdentity.userId);
          expect(row['provider_id'], providerIdentity.userId);
          expect(WorkspaceBinding.projectBooking(row).id, row['booking_id']);
        }
        await expectLater(
            backend.client.rpc('preview_test_fixture_cleanup',
                params: {'p_project_ref': ref, 'p_run_id': fixture['run_id']}),
            throwsA(isA<PostgrestException>()
                .having((e) => e.code, 'admin-only', '42501')));
      }
      // Original A accounts are not the synthetic run: they cannot read its unit
      // or booking rows. Their approval/name/contact/slots are never updated.
      final originalOwner = (original['accounts'] as List)
          .cast<Map>()
          .singleWhere((a) => a['role'] == 'owner');
      final unrelated = await login(originalOwner);
      await expectLater(
          SupabaseWorkspaceRepository(unrelated)
              .property(property['property_id'] as String),
          throwsA(isA<PostgrestException>()
              .having((e) => e.code, 'other Owner denied', '42501')));
      final booking = (await ownerBackend.bookings.page()).items.first;
      expect(await unrelated.bookings.readCard(booking['booking_id'] as String),
          isNull);
      final originalProvider = (original['accounts'] as List)
          .cast<Map>()
          .singleWhere((a) => a['role'] == 'provider');
      final originalProviderBackend = await login(originalProvider);
      expect((await originalProviderBackend.provider.myProfile()).approval,
          'pending');
    } finally {
      for (final client in clients.reversed) {
        if (client.auth.currentSession != null)
          await client.auth.signOut(scope: SignOutScope.local);
        await client.dispose();
      }
    }
  }, skip: !enabled, timeout: const Timeout(Duration(minutes: 3)));
}
