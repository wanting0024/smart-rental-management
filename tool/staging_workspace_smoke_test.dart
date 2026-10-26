// Explicit opt-in hosted read-only acceptance. Never part of the default suite.
// Reads ignored local client/test credentials; never prints passwords or JWTs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/services/backend/backend_config.dart';
import 'package:rental_app_demo/services/backend/supabase_backend_provider.dart';
import 'package:rental_app_demo/services/backend/workspace_binding.dart';
import 'package:rental_app_demo/services/backend/schedule_binding.dart';
import 'package:rental_app_demo/services/backend/supabase_earnings_repository.dart';
import 'package:rental_app_demo/services/backend/earnings_snapshot.dart';
import 'package:rental_app_demo/services/backend/notification_snapshot.dart';
import 'package:rental_app_demo/services/backend/supabase_notification_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_workspace_repository.dart';
import 'package:rental_app_demo/screens/workspace_reports.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _HostedReadBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _HostedReadBinding();
  const enabled = bool.fromEnvironment('RUN_STAGING_READ_SMOKE');
  for (final role in ['owner', 'provider']) {
    test('Staging $role password login and original-workspace data binding',
        () async {
      const ref = 'gqtetdavmrautoojaqrk';
      final config = jsonDecode(
          await File('supabase/backend_config.staging.local.json')
              .readAsString()) as Map;
      final credentials = jsonDecode(
          await File('output/staging-private/accounts.local.json')
              .readAsString()) as Map;
      expect(config['APP_ENV'], 'staging');
      expect(config['SUPABASE_PROJECT_REF'], ref);
      expect(config['SUPABASE_URL'], 'https://$ref.supabase.co');
      expect(config['ALLOW_PRODUCTION_BACKEND'], false);
      expect(credentials['project_ref'], ref);
      final account = (credentials['accounts'] as List)
          .cast<Map>()
          .singleWhere((a) => a['role'] == role);
      expect(account['email'], '$role.a@rental-test.invalid');
      final client = SupabaseClient(config['SUPABASE_URL'] as String,
          config['SUPABASE_PUBLISHABLE_KEY'] as String,
          authOptions: const AuthClientOptions(autoRefreshToken: false));
      WorkspaceBinding? binding;
      ScheduleBinding? schedule;
      try {
        final marker = await client.rpc('get_app_environment');
        expect(marker['environment'], 'staging');
        expect(marker['project_ref'], ref);
        final auth = await client.auth.signInWithPassword(
            email: account['email'] as String,
            password: account['password'] as String);
        expect(auth.session, isNotNull);
        final backend = SupabaseBackendProvider(client);
        final workspace = SupabaseWorkspaceRepository(backend);
        if (role == 'owner') {
          final own = await workspace.ownerProfile();
          expect(own['actor_id'], auth.user!.id);
          final properties = await workspace.properties();
          expect((properties['items'] as List).length, lessThanOrEqualTo(20));
          for (final period in ['last30', 'thisMonth', 'allTime']) {
            final report = await workspace
                .read('owner_spending', params: {'p_period': period});
            validateWorkspaceReport(report, provider: false, period: period);
          }
        } else {
          final report = await workspace.read('my_provider_statistics');
          validateWorkspaceReport(report, provider: true, period: 'allTime');
        }
        final conversations = await backend.messages.conversations('');
        expect(conversations.page.items.length, lessThanOrEqualTo(20));
        final identity = await backend.auth.currentIdentity();
        expect(identity!.role.name, role);
        expect(identity.email, account['email']);
        final notifications = SupabaseNotificationRepository(client);
        for (final filter in NotificationFilter.values) {
          final page = await notifications.page(filter);
          expect(page.filter, filter);
          expect(page.items.length, lessThanOrEqualTo(20));
          expect(page.total, greaterThanOrEqualTo(page.items.length));
        }
        final earnings = SupabaseEarningsRepository(client);
        if (role == 'provider') {
          final profile = await backend.provider.myProfile();
          expect(profile.id, identity.userId);
          expect(profile.email, identity.email);
          expect(profile.revision, greaterThanOrEqualTo(1));
          expect(profile.approval, 'pending');
          for (final period in EarningsPeriod.values) {
            final report = await earnings.read(period);
            expect(report.period, period);
            expect(report.records.length, lessThanOrEqualTo(20));
            expect(report.jobs, greaterThanOrEqualTo(report.records.length));
          }
        } else {
          await expectLater(
              backend.provider.myProfile(),
              throwsA(isA<PostgrestException>().having(
                  (e) => e.code, 'private profile role denied', '42501')));
          await expectLater(
              earnings.read(EarningsPeriod.allTime),
              throwsA(isA<PostgrestException>()
                  .having((e) => e.code, 'denied role', '42501')));
        }
        schedule =
            ScheduleBinding.connected(backend, provider: role == 'provider');
        schedule.setActive(true);
        await schedule.refresh().timeout(const Duration(seconds: 30));
        final scheduleDeadline = Stopwatch()..start();
        while (schedule.loading &&
            scheduleDeadline.elapsed < const Duration(seconds: 30)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(schedule.error, isNull);
        expect(schedule.loading, false);
        expect(schedule.complete, true);
        // Empty fixed accounts are sufficient to verify the new hosted query
        // and RLS path, not populated calendar or cross-account acceptance.
        schedule.dispose();
        schedule = null;
        binding =
            WorkspaceBinding.connected(backend, provider: role == 'provider');
        binding.setActive(true);
        await binding.refresh().timeout(const Duration(seconds: 30));
        // A Realtime initial-reset may legitimately start one newer overview
        // while the explicit refresh is completing. Wait for that read too.
        final deadline = Stopwatch()..start();
        while (
            binding.loading && deadline.elapsed < const Duration(seconds: 30)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(binding.error, isNull,
            reason: 'Workspace must load without fallback data.');
        expect(binding.loading, false);
        expect(binding.bookings.length, binding.feed.items.length);
        for (final row in binding.feed.items) {
          expect(row[role == 'provider' ? 'provider_id' : 'owner_id'],
              identity.userId);
        }
        if (role == 'owner') {
          expect(binding.ownerSummary, isNotNull);
          expect(binding.providerProfile, isNull);
        } else {
          expect(binding.providerProfile!['provider_id'], identity.userId);
          expect(binding.providerProfile!['approval_status'], 'pending');
        }
      } finally {
        schedule?.dispose();
        binding?.dispose();
        if (client.auth.currentSession != null)
          await client.auth.signOut(scope: SignOutScope.local);
        await client.dispose();
      }
    }, skip: !enabled, timeout: const Timeout(Duration(minutes: 2)));
  }
}
