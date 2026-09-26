// lib/screens/owner_spend_screen.dart
// Owner's spend analytics: total spent, this month, by provider, recent records.
//
// Round 10 polish (OS1-OS6):
//   OS1 Theme colors (sem.* + AppColors.*) instead of hardcoded hex
//   OS2 Hero uses AppTheme.accentGradient (orange — distinct from earnings emerald)
//   OS3 intl.DateFormat for spend tile date (was hand-rolled month list)
//   OS4 _monthBar uses theme tokens (sem.surfaceAlt background, sem.textPrimary text)
//   OS5 By-provider bars use AppColors.warning (consistent with earnings stats grid)
//   OS6 Delta pill with semantic color (success/error) instead of red/green hex

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';

class OwnerSpendScreen extends StatelessWidget {
  const OwnerSpendScreen({super.key, required this.bookings});
  final List<DemoBooking> bookings;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final summary = spendFor(bookings);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: sem.textSecondary),
            onPressed: () => _showFilterSheet(context),
            tooltip: 'Filter by month',
          ),
          IconButton(
            icon: Icon(Icons.file_download_outlined, color: sem.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export PDF · Sprint 1 feature'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Export statement',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: summary.jobsFunded == 0
          ? const EmptyState(
              icon: Icons.payments_outlined,
              title: 'No spending yet',
              subtitle:
                  'Funded jobs will appear here once providers mark them complete.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHero(context, summary),
                const SizedBox(height: 16),
                _buildMonthOverMonth(context, summary),
                const SizedBox(height: 16),
                _buildByProvider(context, summary),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Spending history'),
                const SizedBox(height: 8),
                ...summary.records.map((r) => _SpendTile(record: r)),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildHero(BuildContext context, SpendSummary s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // OS2: orange accent gradient (distinct from earnings' emerald)
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withOpacity(0.3),
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
                  Icons.account_balance,
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
                      'Total spent',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Across all properties · all time',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedCounter(
            value: s.totalSpent,
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
                '${s.jobsFunded} jobs  ·  avg RM ${s.avgPerJob.toStringAsFixed(0)}/job',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthOverMonth(BuildContext context, SpendSummary s) {
    final sem = SemanticColors.of(context);
    final maxV = s.thisMonth > s.lastMonth ? s.thisMonth : s.lastMonth;
    final thisWidth = maxV == 0 ? 0.0 : s.thisMonth / maxV;
    final lastWidth = maxV == 0 ? 0.0 : s.lastMonth / maxV;
    final delta = s.lastMonth == 0 ? 0.0 : (s.thisMonth - s.lastMonth) / s.lastMonth;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Month over month'),
            const SizedBox(height: 16),
            _monthBar('This month', s.thisMonth, thisWidth, AppColors.warning, sem),
            const SizedBox(height: 12),
            _monthBar(
              'Last month',
              s.lastMonth,
              lastWidth,
              sem.textTertiary,
              sem,
            ),
            const SizedBox(height: 12),
            _deltaPill(delta, sem),
          ],
        ),
      ),
    );
  }

  // OS6: semantic success/error pill
  Widget _deltaPill(double delta, SemanticColors sem) {
    final hasChange = delta.abs() > 0.001;
    final isUp = delta > 0;
    final color = !hasChange
        ? sem.textSecondary
        : isUp
            ? AppColors.error
            : AppColors.success;
    final bg = !hasChange
        ? sem.surfaceAlt
        : isUp
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFDCFCE7);
    final icon = !hasChange
        ? Icons.remove
        : isUp
            ? Icons.arrow_upward
            : Icons.arrow_downward;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              !hasChange
                  ? 'No change from last month.'
                  : '${(delta.abs() * 100).toStringAsFixed(0)}% ${isUp ? 'increase' : 'decrease'} from last month',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // OS4: themed _monthBar
  Widget _monthBar(
    String label,
    double value,
    double widthFactor,
    Color color,
    SemanticColors sem,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: sem.textPrimary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widthFactor.clamp(0, 1),
              minHeight: 14,
              backgroundColor: sem.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            'RM ${value.toStringAsFixed(0)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sem.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // OS5: themed provider bars
  Widget _buildByProvider(BuildContext context, SpendSummary s) {
    if (s.byProvider.isEmpty) return const SizedBox.shrink();
    final sem = SemanticColors.of(context);
    final maxV = s.byProvider.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Top providers', subtitle: 'By total spend'),
            const SizedBox(height: 12),
            ...s.byProvider.map((e) {
              final width = maxV == 0 ? 0.0 : e.value / maxV;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: sem.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: width.clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: sem.surfaceAlt,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Text(
                        'RM ${e.value.toStringAsFixed(0)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sem.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final sem = SemanticColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: sem.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sem.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Filter by month',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: sem.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ...['All time', 'Last 30 days', 'Last 90 days', 'This year'].map(
                (l) => ListTile(
                  leading: Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: sem.textSecondary,
                  ),
                  title: Text(l, style: TextStyle(color: sem.textPrimary)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Filter: $l'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpendTile extends StatelessWidget {
  const _SpendTile({required this.record});
  final SpendRecord record;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.cleaning_services,
            color: AppColors.warning,
            size: 18,
          ),
        ),
        title: Text(
          record.serviceLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sem.textPrimary,
          ),
        ),
        subtitle: Text(
          '${record.property}  ·  ${record.providerName}',
          style: TextStyle(fontSize: 11, color: sem.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'RM ${record.cost.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
            // OS3: intl date
            Text(
              DateFormat('d MMM').format(record.date),
              style: TextStyle(fontSize: 10, color: sem.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
