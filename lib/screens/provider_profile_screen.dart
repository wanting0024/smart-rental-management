// lib/screens/provider_profile_screen.dart
// Full provider profile. Tappable from Provider Browse, Provider Inbox,
// and Active Job Detail (the "View profile" buttons all go here).
//
// Round 10 polish (PP1-PP7):
//   PP1 Theme colors throughout (sem.* + AppColors.*) instead of hardcoded hex
//   PP2 AppColors.success for "Online" pill
//   PP3 Score bars use sem.surfaceAlt background + sem.textPrimary labels
//   PP4 Stat tiles use AppColors.success / warning / primary
//   PP5 Service chip uses AppColors.primarySurface + primaryBorder
//   PP6 Contact row uses sem tokens
//   PP7 Phone number respects provider.showPhoneToOwners (Round 7 privacy)

import 'package:flutter/material.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';

class ProviderProfileScreen extends StatelessWidget {
  const ProviderProfileScreen(
      {super.key, required this.provider, this.heroColor});
  final DemoProvider provider;
  final Color? heroColor;

  @override
  Widget build(BuildContext context) {
    final heroColorFinal = heroColor ?? AppColors.primary;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: heroColorFinal,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [heroColorFinal, heroColorFinal.withOpacity(0.7)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _initials(provider.name),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cleaning Service Provider',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // PP2: themed success pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Online',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _heroStat(
                              label: 'Rating',
                              value: provider.rating.toStringAsFixed(1),
                              sub: '/ 5.0',
                            ),
                            const SizedBox(width: 12),
                            _heroStat(
                              label: 'Distance',
                              value: provider.distanceKm.toStringAsFixed(1),
                              sub: 'km away',
                            ),
                            const SizedBox(width: 12),
                            _heroStat(
                              label: provider.hasRankingBreakdown
                                  ? 'Match'
                                  : 'Rate',
                              value: provider.hasRankingBreakdown
                                  ? '${(provider.score * 100).round()}%'
                                  : 'RM ${provider.hourlyRate.toStringAsFixed(0)}',
                              sub: provider.hasRankingBreakdown
                                  ? 'request score'
                                  : '/ hour',
                              highlight: provider.hasRankingBreakdown,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMatchCard(context),
                  const SizedBox(height: 16),
                  _buildStatsCard(context),
                  const SizedBox(height: 16),
                  _buildServicesCard(context),
                  const SizedBox(height: 16),
                  _buildWorkloadCard(context),
                  const SizedBox(height: 16),
                  _buildContactCard(context),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Message provider · Sprint 1 feature'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 16),
                          label: const Text('Message'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${provider.name} assigned (demo)'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Assign to job'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _heroStat({
    required String label,
    required String value,
    required String sub,
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: highlight
                    ? SemanticColors.lightTokens.textSecondary
                    : Colors.white70,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.primary : Colors.white,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                fontSize: 10,
                color: highlight
                    ? SemanticColors.lightTokens.textSecondary
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Two-stage match analysis',
              subtitle: provider.hasRankingBreakdown
                  ? 'Mandatory eligibility first, then equal-weight ranking'
                  : 'A score is calculated for a specific service request',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.hasRankingBreakdown
                          ? 'Passed service, full-interval availability, rental-window, and conflict checks.'
                          : 'Eligibility is checked when an owner submits a service request.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (provider.hasRankingBreakdown) ...[
              const SizedBox(height: 12),
              _scoreBar(
                'Distance',
                provider.distanceSuitability,
                '1/3 weight',
                color: AppColors.primary,
                sem: sem,
              ),
              const SizedBox(height: 8),
              _scoreBar(
                'Rating',
                provider.ratingSuitability,
                '1/3 weight',
                color: AppColors.secondary,
                sem: sem,
              ),
              const SizedBox(height: 8),
              _scoreBar(
                'Workload',
                provider.workloadSuitability,
                '1/3 weight',
                color: AppColors.warning,
                sem: sem,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // PP3: themed score bar
  Widget _scoreBar(
    String label,
    double value,
    String weight, {
    required Color color,
    required SemanticColors sem,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: sem.textPrimary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 8,
              backgroundColor: sem.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            weight,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: sem.textSecondary),
          ),
        ),
      ],
    );
  }

  // PP4: themed stat tiles
  Widget _buildStatsCard(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Lifetime stats'),
            const SizedBox(height: 12),
            Row(
              children: [
                _statTile('128', 'Jobs done', Icons.check_circle_outline,
                    AppColors.success, sem),
                const SizedBox(width: 8),
                _statTile(
                    '4.8', 'Avg rating', Icons.star, AppColors.warning, sem),
                const SizedBox(width: 8),
                _statTile('96%', 'On time', Icons.access_time,
                    AppColors.primary, sem),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(
    String v,
    String l,
    IconData icon,
    Color color,
    SemanticColors sem,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              v,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: sem.textPrimary,
              ),
            ),
            Text(l, style: TextStyle(fontSize: 11, color: sem.textSecondary)),
          ],
        ),
      ),
    );
  }

  // PP5: themed service chip
  Widget _buildServicesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
                title: 'Services offered', subtitle: 'Tap to filter jobs'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: provider.serviceTypes.map((s) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cleaning_services,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _serviceLabel(s),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkloadCard(BuildContext context) {
    final sem = SemanticColors.of(context);
    // PP4: themed workload color
    final color = provider.workload == 'Low'
        ? AppColors.success
        : provider.workload == 'Medium'
            ? AppColors.warning
            : AppColors.error;
    final percent = provider.workload == 'Low'
        ? 0.3
        : provider.workload == 'Medium'
            ? 0.6
            : 0.9;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Current workload',
              action: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  provider.workload,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 10,
                backgroundColor: sem.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.hasRankingBreakdown
                  ? '${provider.activeBookingCount} Accepted or In Progress '
                      'booking${provider.activeBookingCount == 1 ? '' : 's'} '
                      'overlap the seven-day workload window.'
                  : provider.workload == 'Low'
                      ? 'Plenty of room. Will accept new jobs quickly.'
                      : provider.workload == 'Medium'
                          ? 'Some jobs in progress. New jobs may take 1-2 days.'
                          : 'Heavily booked. Best for non-urgent jobs.',
              style: TextStyle(
                fontSize: 12,
                color: sem.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PP6 + PP7: themed contact rows + phone privacy
  Widget _buildContactCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Contact'),
            const SizedBox(height: 12),
            // PP7: only show phone if provider opted in
            if (provider.showPhoneToOwners)
              _contactRow(Icons.phone, 'Call', provider.phone)
            else
              _contactRow(
                Icons.lock_outline,
                'Call',
                'Hidden by provider — message instead',
              ),
            const Divider(height: 16),
            _contactRow(Icons.email, 'Email', provider.email),
            const Divider(height: 16),
            if (provider.showPhoneToOwners)
              _contactRow(Icons.chat, 'WhatsApp', provider.phone)
            else
              _contactRow(
                Icons.chat_bubble_outline,
                'WhatsApp',
                'Hidden by provider — message instead',
              ),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Builder(builder: (ctx) {
      final sem = SemanticColors.of(ctx);
      return Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: sem.textSecondary),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: sem.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: sem.textTertiary,
            ),
            onPressed: () {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('$label tapped · Sprint 1 will open dialer'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      );
    });
  }

  String _serviceLabel(String id) {
    const map = {
      'standard': 'Standard cleaning',
      'deep': 'Deep cleaning',
      'window': 'Window cleaning',
      'move-in': 'Move-in cleaning',
      'move-out': 'Move-out cleaning',
    };
    return map[id] ?? id;
  }
}
