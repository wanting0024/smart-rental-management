// lib/screens/provider_schedule_screen.dart
// Provider's own schedule view. Mirrors owner schedule but filtered to
// this provider's bookings, with action availability hints.
//
// Round 11 polish (PS1-PS6):
//   PS1 Theme colors (sem.* + AppColors.*) throughout
//   PS2 Stat tiles use AppColors.primary / secondary / statusCompleted
//   PS3 Dividers use sem.border
//   PS4 Today's list uses sem.surfaceAlt bg
//   PS5 App bar "Block out time" icon uses sem.textSecondary
//   PS6 "Today" icon + label use AppColors.primary + sem.textPrimary

import 'package:flutter/material.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/booking_card.dart';
import '../widgets/calendar_week_view.dart';
import '../widgets/empty_state.dart';
import 'booking_detail_screen.dart';

class ProviderScheduleScreen extends StatefulWidget {
  const ProviderScheduleScreen({super.key, required this.providerName, required this.bookings});
  final String providerName;
  final List<DemoBooking> bookings;

  @override
  State<ProviderScheduleScreen> createState() => _ProviderScheduleScreenState();
}

class _ProviderScheduleScreenState extends State<ProviderScheduleScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = mondayOf(DateTime.now());
  }

  List<DemoBooking> get _myBookings => widget.bookings
      .where((b) => b.providerName == widget.providerName)
      .toList();

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final mine = _myBookings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My schedule'),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: sem.textSecondary),
            tooltip: 'Block out time',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Block out time · Sprint 1 feature'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildStats(mine, sem),
          Divider(height: 1, thickness: 1, color: sem.border),
          Expanded(
            child: CalendarWeekView(
              weekStart: _weekStart,
              bookings: mine,
              onTapBooking: (b) => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)),
              ),
              onChangeWeek: (w) => setState(() => _weekStart = w),
              today: {DateTime.now()},
            ),
          ),
          Divider(height: 1, thickness: 1, color: sem.border),
          _buildTodayList(mine, sem),
        ],
      ),
    );
  }

  // PS2: themed stat tiles
  Widget _buildStats(List<DemoBooking> mine, SemanticColors sem) {
    final thisWeek = mine.where((b) {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      return b.scheduledStart.isAfter(startOfWeek) && b.scheduledStart.isBefore(endOfWeek);
    }).length;
    final upcoming = mine.where((b) =>
        b.status == DemoBookingStatus.scheduled ||
        b.status == DemoBookingStatus.accepted ||
        b.status == DemoBookingStatus.requested ||
        b.status == DemoBookingStatus.inProgress).length;
    final hoursThisWeek = mine.where((b) {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      return b.scheduledStart.isAfter(startOfWeek) && b.scheduledStart.isBefore(endOfWeek);
    }).fold<double>(0, (s, b) => s + b.scheduledEnd.difference(b.scheduledStart).inMinutes / 60.0);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _stat('This week', '$thisWeek', AppColors.primary, sem),
          const SizedBox(width: 8),
          _stat('Hours booked', hoursThisWeek.toStringAsFixed(1), AppColors.secondary, sem),
          const SizedBox(width: 8),
          _stat('Upcoming', '$upcoming', AppColors.statusCompleted, sem),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color, SemanticColors sem) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: sem.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PS4 + PS6: themed today list
  Widget _buildTodayList(List<DemoBooking> mine, SemanticColors sem) {
    final now = DateTime.now();
    final today = mine.where((b) =>
        b.scheduledStart.year == now.year &&
        b.scheduledStart.month == now.month &&
        b.scheduledStart.day == now.day).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return Container(
      color: sem.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                "Today's jobs  ·  ${today.length}",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: sem.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: today.isEmpty
                ? const EmptyState(
                    icon: Icons.beach_access,
                    title: 'No jobs today',
                    subtitle: 'Enjoy the break!',
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: today.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) {
                      final b = today[i];
                      return SizedBox(
                        width: 280,
                        child: BookingCard(
                          booking: b,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BookingDetailScreen(booking: b),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
