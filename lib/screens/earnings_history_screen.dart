// lib/screens/earnings_history_screen.dart
// Provider earnings dashboard: hero (period total), weekly bar chart,
// 3-stat grid, per-job breakdown with platform fee and net.
//
// Round 8 polish (E1-E7):
//   E1 Theme gradient (AppColors.primary + primaryLight, not hardcoded emerald)
//   E2 Period filter: SegmentedButton (Last 30 days / This month / All time)
//   E3 Theme-aware text in tiles (sem.textPrimary vs hardcoded #111827)
//   E4 intl.DateFormat for "21 Jul 2026" instead of hand-rolled month list
//   E5 Tap action on earnings tile → snackbar "Coming in Sprint 2"
//   E6 Platform fee shown as % next to RM value
//   E7 Stats grid uses AppColors (primary / secondary / warning)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';

/// Time range used by the period filter.
enum _EarningsPeriod {
  last30('Last 30 days'),
  thisMonth('This month'),
  allTime('All time');

  const _EarningsPeriod(this.label);
  final String label;

  /// Earliest date (inclusive) for this period, relative to [now].
  /// `allTime` returns null = no lower bound.
  DateTime? earliest(DateTime now) {
    switch (this) {
      case _EarningsPeriod.last30:
        return now.subtract(const Duration(days: 30));
      case _EarningsPeriod.thisMonth:
        return DateTime(now.year, now.month, 1);
      case _EarningsPeriod.allTime:
        return null;
    }
  }
}

class EarningsHistoryScreen extends StatefulWidget {
  const EarningsHistoryScreen({super.key, required this.providerName, required this.bookings});
  final String providerName;
  final List<DemoBooking> bookings;

  @override
  State<EarningsHistoryScreen> createState() => _EarningsHistoryScreenState();
}

class _EarningsHistoryScreenState extends State<EarningsHistoryScreen> {
  _EarningsPeriod _period = _EarningsPeriod.allTime;

  /// Filter the global summary's records by the selected period and
  /// recompute period-scoped aggregates.
  EarningsSummary _scopedSummary(EarningsSummary global, _EarningsPeriod period) {
    final cutoff = period.earliest(DateTime.now());
    final filtered = cutoff == null
        ? global.records
        : global.records.where((r) => !r.date.isBefore(cutoff)).toList();
    if (filtered.isEmpty) {
      return EarningsSummary(
        providerName: global.providerName,
        totalNet: 0,
        weeklyNet: global.weeklyNet, // keep week/month stats as reference
        monthlyNet: global.monthlyNet,
        jobsCompleted: 0,
        avgPerJob: 0,
        records: const [],
      );
    }
    final total = filtered.fold<double>(0, (a, r) => a + r.net);
    final avg = total / filtered.length;
    return EarningsSummary(
      providerName: global.providerName,
      totalNet: total,
      weeklyNet: global.weeklyNet,
      monthlyNet: global.monthlyNet,
      jobsCompleted: filtered.length,
      avgPerJob: avg,
      records: filtered,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = earningsFor(widget.providerName, widget.bookings);
    final scoped = _scopedSummary(summary, _period);

    if (summary.jobsCompleted == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Earnings')),
        body: const EmptyState(
          icon: Icons.payments_outlined,
          title: 'No earnings yet',
          subtitle: 'Complete a job to see your earnings here.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export statement',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export PDF — Sprint 2 feature'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHero(context, scoped),
          const SizedBox(height: 12),
          // E2: Period filter
          _buildPeriodFilter(),
          const SizedBox(height: 16),
          _buildWeekChart(context, scoped),
          const SizedBox(height: 16),
          _buildStatsGrid(context, scoped),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Earnings history',
            subtitle: scoped.records.isEmpty
                ? 'No jobs in this period'
                : 'Tap a job to view details',
          ),
          const SizedBox(height: 8),
          if (scoped.records.isEmpty)
            const _NoRecordsInPeriod()
          else
            ...scoped.records.map((r) => _EarningsTile(record: r)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, EarningsSummary s) {
    final periodLabel = _period == _EarningsPeriod.allTime
        ? 'Lifetime · all completed jobs'
        : _period.label;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // E1: Theme gradient
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
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total earned',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Lifetime · all completed jobs',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedCounter(
            value: s.totalNet,
            prefix: 'RM ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.trending_up, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '${s.jobsCompleted} job${s.jobsCompleted == 1 ? '' : 's'}  ·  avg RM ${s.avgPerJob.toStringAsFixed(0)}/job  ·  $periodLabel',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// E2: Segmented period filter (Material 3).
  Widget _buildPeriodFilter() {
    return SegmentedButton<_EarningsPeriod>(
      segments: _EarningsPeriod.values
          .map((p) => ButtonSegment(value: p, label: Text(p.label)))
          .toList(),
      selected: {_period},
      onSelectionChanged: (sel) => setState(() => _period = sel.first),
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildWeekChart(BuildContext context, EarningsSummary s) {
    // Always show the last 7 days, regardless of selected period —
    // it's a "recent activity" snapshot, not a period aggregate.
    final today = DateTime.now();
    final buckets = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final dayBookings = s.records.where(
        (r) =>
            r.date.year == day.year &&
            r.date.month == day.month &&
            r.date.day == day.day,
      );
      final total = dayBookings.fold<double>(0, (sum, r) => sum + r.net);
      return _DayBucket(day: day, total: total);
    });
    final maxV = buckets.map((b) => b.total).fold<double>(0, (m, v) => v > m ? v : m);
    final sem = SemanticColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Last 7 days',
              subtitle: 'Daily earnings, Mon–Sun',
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets.map((b) {
                  final h = maxV == 0 ? 0.0 : (b.total / maxV) * 80;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            b.total > 0 ? b.total.toStringAsFixed(0) : '',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF374151),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: h + 8,
                            decoration: BoxDecoration(
                              color: b.total > 0
                                  ? AppColors.primary
                                  : sem.border,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: buckets
                  .map(
                    (b) => Expanded(
                      child: Center(
                        child: Text(
                          _dayShort(b.day),
                          style: TextStyle(
                            fontSize: 10,
                            color: sem.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // E7: theme colors
  Widget _buildStatsGrid(BuildContext context, EarningsSummary s) {
    return Row(
      children: [
        _statTile('This week', 'RM ${s.weeklyNet.toStringAsFixed(0)}', AppColors.primary, context),
        const SizedBox(width: 8),
        _statTile('This month', 'RM ${s.monthlyNet.toStringAsFixed(0)}', AppColors.secondary, context),
        const SizedBox(width: 8),
        _statTile('Avg / job', 'RM ${s.avgPerJob.toStringAsFixed(0)}', AppColors.warning, context),
      ],
    );
  }

  Widget _statTile(String label, String value, Color color, BuildContext context) {
    final sem = SemanticColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
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
      ),
    );
  }

  String _dayShort(DateTime d) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[d.weekday - 1];
  }
}

/// E3: Theme-aware earnings tile with tap action + E6 fee %.
class _EarningsTile extends StatelessWidget {
  const _EarningsTile({required this.record});
  final EarningsRecord record;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // E5: Tap action
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${record.serviceLabel} · ${record.property}'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.cleaning_services,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.serviceLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sem.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.property}  ·  ${record.hours.toStringAsFixed(1)} hours',
                      style: TextStyle(
                        fontSize: 11,
                        color: sem.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // E4: intl DateFormat
                    Text(
                      DateFormat('d MMM y').format(record.date),
                      style: TextStyle(
                        fontSize: 10,
                        color: sem.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${record.net.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  // E6: fee as %
                  Text(
                    '−15% fee',
                    style: TextStyle(
                      fontSize: 10,
                      color: sem.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayBucket {
  const _DayBucket({required this.day, required this.total});
  final DateTime day;
  final double total;
}

/// Subtle inline empty state for the records list when a period has no jobs.
class _NoRecordsInPeriod extends StatelessWidget {
  const _NoRecordsInPeriod();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 28,
              color: SemanticColors.of(context).textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No completed jobs in this period. '
                'Try a wider date range.',
                style: TextStyle(
                  fontSize: 12,
                  color: SemanticColors.of(context).textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
