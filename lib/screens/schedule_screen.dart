// lib/screens/schedule_screen.dart
// Owner-side schedule view. Week timeline + legend + list-of-today fallback.
//
// Round 10 polish (SC1-SC5):
//   SC1 Theme colors (sem.* + AppColors.*) for dividers and icon
//   SC2 Legend pill style improved (sem.surfaceAlt bg, sem.textPrimary text)
//   SC3 "Today's bookings" header uses sem tokens
//   SC4 Container background uses sem.surfaceAlt
//   SC5 App bar "Jump to today" button gets themed icon

import 'package:flutter/material.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/booking_card.dart';
import '../widgets/calendar_week_view.dart';
import '../widgets/empty_state.dart';
import 'booking_detail_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen(
      {super.key, required this.bookings, this.embedded = false});
  final List<DemoBooking> bookings;

  /// When true, skip the inner Scaffold/AppBar so the parent (e.g. owner shell)
  /// can own the AppBar and avoid a duplicate title.
  final bool embedded;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = mondayOf(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final body = Column(
      children: [
        _buildLegend(sem),
        Divider(height: 1, thickness: 1, color: sem.border),
        Expanded(
          child: CalendarWeekView(
            weekStart: _weekStart,
            bookings: widget.bookings,
            onTapBooking: _openDetail,
            onChangeWeek: (w) => setState(() => _weekStart = w),
            today: {DateTime.now()},
          ),
        ),
        Divider(height: 1, thickness: 1, color: sem.border),
        _buildTodayList(sem),
      ],
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            // SC5: themed icon
            icon: Icon(Icons.today, color: sem.textSecondary),
            onPressed: () =>
                setState(() => _weekStart = mondayOf(DateTime.now())),
            tooltip: 'Jump to this week',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }

  // SC2: themed legend
  Widget _buildLegend(SemanticColors sem) {
    final items = [
      BookingStatus.pending,
      BookingStatus.accepted,
      BookingStatus.inProgress,
      BookingStatus.completed,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 5,
        runSpacing: 6,
        children: [
          for (final s in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: s.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: s.color.withOpacity(0.30),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: sem.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // SC3 + SC4: themed today list
  Widget _buildTodayList(SemanticColors sem) {
    final now = DateTime.now();
    final todayBookings = widget.bookings
        .where((b) =>
            b.scheduledStart.year == now.year &&
            b.scheduledStart.month == now.month &&
            b.scheduledStart.day == now.day)
        .toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return Container(
      color: sem.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                "Today's bookings  ·  ${todayBookings.length}",
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
            child: todayBookings.isEmpty
                ? const EmptyState(
                    icon: Icons.event_available,
                    title: 'No bookings today',
                    subtitle:
                        'A quiet day. Use the form to schedule a cleaning.',
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: todayBookings.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) {
                      final b = todayBookings[i];
                      return SizedBox(
                        width: 280,
                        child: BookingCard(
                          booking: b,
                          onTap: () => _openDetail(b),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetail(DemoBooking b) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)),
    );
  }
}
