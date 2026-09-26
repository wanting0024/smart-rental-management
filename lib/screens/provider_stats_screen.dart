// lib/screens/provider_stats_screen.dart
// Provider performance dashboard: acceptance rate, response time, completion
// rate, weekly trend (last 4 weeks + delta vs previous 4), ratings
// distribution, job breakdown. All computed from demo data.
//
// Round 8 polish (P1-P7):
//   P1 Hero 4-metric (Acceptance / Completion / Response / Repeat)
//   P2 Week-over-week trend pill (↑/↓% with color)
//   P3 Empty state when 0 bookings
//   P4 SectionHeader widget instead of all-caps text
//   P5 Theme-aware text colors (sem.textPrimary vs hardcoded #111827)
//   P6 Taller bar chart (140px) with delta indicator
//   P7 Pull-to-refresh with simulated delay + haptics

import 'package:flutter/material.dart';
import '../main.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';

class ProviderStatsScreen extends StatelessWidget {
  const ProviderStatsScreen({super.key, this.providerName = 'Provider A'});
  final String providerName;

  @override
  Widget build(BuildContext context) {
    final bookingStore = AppProviders.of(context).bookingStore;
    final reviewStore = AppProviders.of(context).reviewStore;
    final sem = SemanticColors.of(context);

    // ---- P3: Empty state (computed before AnimatedBuilder for fast bail-out) ----
    final allForProvider = bookingStore.bookings
        .where((b) => b.providerName == providerName)
        .toList();
    if (allForProvider.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('My stats')),
        body: const EmptyState(
          icon: Icons.insights_outlined,
          title: 'No stats yet',
          subtitle: 'Complete a few jobs to unlock your performance dashboard.',
        ),
      );
    }

    // ---- Round 14 fix: listen to both stores so data refreshes ----
    return AnimatedBuilder(
      animation: Listenable.merge([bookingStore, reviewStore]),
      builder: (ctx, _) => _buildBody(
        ctx: ctx,
        allForProvider: allForProvider,
        sem: sem,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext ctx,
    required List<DemoBooking> allForProvider,
    required SemanticColors sem,
  }) {
    final reviewStore = AppProviders.of(ctx).reviewStore;
    final total = allForProvider.length;
    final accepted = allForProvider
        .where(
          (b) =>
              b.status == BookingStatus.accepted ||
              b.status == BookingStatus.inProgress ||
              b.status == BookingStatus.completed,
        )
        .length;
    final completed =
        allForProvider.where((b) => b.status == BookingStatus.completed).length;
    final cancelled = allForProvider
        .where(
          (b) =>
              b.status == BookingStatus.cancelled ||
              b.status == BookingStatus.declined,
        )
        .length;
    final acceptanceRate = total == 0 ? 0.0 : accepted / total;
    final completionRate = accepted == 0 ? 0.0 : completed / accepted;

    // Mock values (Sprint 2 will compute from real timestamp data)
    const avgResponseMin = 12;
    const repeatRate = 0.78;

    // ---- Weekly trend: 8 weeks total so we can show "vs previous 4" delta ----
    final now = DateTime.now();
    final weeklyData = List.generate(8, (w) {
      final weekStart = now.subtract(Duration(days: (7 - w) * 7 + 6));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final weekJobs = allForProvider.where((b) {
        return b.scheduledStart
                .isAfter(weekStart.subtract(const Duration(days: 1))) &&
            b.scheduledStart.isBefore(weekEnd);
      }).length;
      return _WeekPoint(
        label: 'W${8 - w}',
        jobs: weekJobs,
        isCurrentPeriod: w >= 4, // last 4 weeks = current period
      );
    });
    final currentPeriodJobs = weeklyData
        .where((w) => w.isCurrentPeriod)
        .fold<int>(0, (a, w) => a + w.jobs);
    final previousPeriodJobs = weeklyData
        .where((w) => !w.isCurrentPeriod)
        .fold<int>(0, (a, w) => a + w.jobs);
    final trendDelta = _computeDelta(currentPeriodJobs, previousPeriodJobs);
    final visibleWeeks =
        weeklyData.skip(4).toList(); // show only current 4 weeks
    final maxWeekJobs =
        visibleWeeks.map((w) => w.jobs).fold<int>(0, (m, v) => v > m ? v : m);

    // ---- Rating distribution ----
    final ratingDist = reviewStore.distributionFor(providerName);
    final totalReviews = ratingDist.values.fold<int>(0, (a, b) => a + b);
    final avgRating = reviewStore.averageFor(providerName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share report',
            onPressed: () {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Share report — Sprint 2 will PDF this'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // P7: Pull-to-refresh
      body: RefreshIndicator(
        onRefresh: () async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          Haptics.light();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // P1 + P2: Hero with 4 metrics + trend pill
            _buildHeroCard(
              acceptanceRate,
              completionRate,
              avgResponseMin,
              repeatRate,
              trendDelta,
              sem,
            ),
            const SizedBox(height: 16),
            // P4: SectionHeader widget
            const SectionHeader(
              title: 'Weekly trend',
              subtitle: 'Last 4 weeks vs previous 4',
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Jobs completed (last 4 weeks)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: sem.textPrimary,
                            ),
                          ),
                        ),
                        // P2: Trend pill
                        _TrendPill(delta: trendDelta),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // P6: Taller bar chart
                    SizedBox(
                      height: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: visibleWeeks.map((w) {
                          final h = maxWeekJobs == 0
                              ? 0.0
                              : (w.jobs / maxWeekJobs) * 100;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${w.jobs}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: h + 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    w.label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // P4: SectionHeader
            SectionHeader(
              title: 'Rating breakdown',
              subtitle:
                  'From $totalReviews review${totalReviews == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Column(
                      children: [
                        // P5: Theme-aware
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: sem.textPrimary,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < avgRating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 12,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalReviews review${totalReviews == 1 ? '' : 's'}',
                          style:
                              TextStyle(fontSize: 11, color: sem.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [5, 4, 3, 2, 1].map((star) {
                          final count = ratingDist[star] ?? 0;
                          final pct =
                              totalReviews == 0 ? 0.0 : count / totalReviews;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  child: Text(
                                    '$star',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.star,
                                    size: 9, color: AppColors.warning),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      minHeight: 5,
                                      backgroundColor: sem.border,
                                      valueColor: const AlwaysStoppedAnimation(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // P4: SectionHeader
            const SectionHeader(
              title: 'Job breakdown',
              subtitle: 'All time',
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _statRow('Total bookings', '$total', Icons.list_alt, sem),
                  _statRow(
                    'Accepted',
                    '$accepted',
                    Icons.check_circle_outline,
                    sem,
                    color: AppColors.primary,
                  ),
                  _statRow(
                    'Completed',
                    '$completed',
                    Icons.task_alt,
                    sem,
                    color: AppColors.statusCompleted,
                  ),
                  _statRow(
                    'Cancelled',
                    '$cancelled',
                    Icons.cancel_outlined,
                    sem,
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Returns +0.18 for 18% increase, -0.05 for 5% decrease.
  /// Edge case: if previous is 0, returns 1.0 when current > 0, else 0.0.
  double _computeDelta(int current, int previous) {
    if (previous == 0) return current > 0 ? 1.0 : 0.0;
    return (current - previous) / previous;
  }

  Widget _buildHeroCard(
    double acc,
    double comp,
    int respMin,
    double rep,
    double trendDelta,
    SemanticColors sem,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.insights, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Last 30 days',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // P2: Trend pill in hero too
              _HeroTrendPill(delta: trendDelta),
            ],
          ),
          const SizedBox(height: 16),
          // P1: 4 metrics
          Row(
            children: [
              Expanded(
                  child: _heroStat('Acceptance',
                      '${(acc * 100).toStringAsFixed(0)}%', 'rate')),
              const SizedBox(width: 6),
              Expanded(
                  child: _heroStat('Completion',
                      '${(comp * 100).toStringAsFixed(0)}%', 'rate')),
              const SizedBox(width: 6),
              Expanded(child: _heroStat('Response', '${respMin}m', 'avg')),
              const SizedBox(width: 6),
              Expanded(
                  child: _heroStat(
                      'Repeat', '${(rep * 100).toStringAsFixed(0)}%', 'rate')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _statRow(
    String label,
    String value,
    IconData icon,
    SemanticColors sem, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (color ?? AppColors.primary).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color ?? AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: sem.textPrimary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: sem.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekPoint {
  const _WeekPoint({
    required this.label,
    required this.jobs,
    this.isCurrentPeriod = false,
  });
  final String label;
  final int jobs;
  final bool isCurrentPeriod;
}

/// Compact trend indicator pill (white background for hero card overlay).
class _HeroTrendPill extends StatelessWidget {
  const _HeroTrendPill({required this.delta});
  final double delta;

  @override
  Widget build(BuildContext context) {
    if (delta == 0) {
      return const Text('', style: TextStyle(fontSize: 12));
    }
    final isUp = delta > 0;
    final color = isUp ? Colors.greenAccent : Colors.redAccent;
    final icon = isUp ? Icons.trending_up : Icons.trending_down;
    final pct = (delta.abs() * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Larger trend pill (used on white card surfaces).
class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.delta});
  final double delta;

  @override
  Widget build(BuildContext context) {
    if (delta == 0) {
      return Text(
        'No change',
        style: TextStyle(
          fontSize: 11,
          color: SemanticColors.of(context).textTertiary,
        ),
      );
    }
    final isUp = delta > 0;
    final color = isUp ? AppColors.success : AppColors.error;
    final icon = isUp ? Icons.trending_up : Icons.trending_down;
    final pct = (delta.abs() * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
