// lib/widgets/calendar_week_view.dart
// Week timeline: 7-day strip header + time-grid body with booking blocks.
// Each booking renders as a colored block positioned by its start/end time.

import 'package:flutter/material.dart';
import '../models/demo_data.dart';

class CalendarWeekView extends StatelessWidget {
  const CalendarWeekView({
    super.key,
    required this.weekStart,
    required this.bookings,
    required this.onTapBooking,
    this.onChangeWeek,
    this.today = const {},
  });

  /// Monday of the displayed week.
  final DateTime weekStart;

  /// All bookings; we filter to those falling inside the week.
  final List<DemoBooking> bookings;

  /// Fires when a booking block is tapped.
  final void Function(DemoBooking) onTapBooking;

  /// Optional: fires when user taps prev/next/today.
  final void Function(DateTime newWeekStart)? onChangeWeek;

  /// Set of DateTimes (year, month, day) to highlight as today.
  /// Pass `{DateTime.now()}` to highlight current day.
  final Set<DateTime> today;

  static const double _hourHeight = 56;
  static const double _timeColumnWidth = 48;
  static const int _startHour = 7; // 07:00
  static const int _endHour = 21; // 21:00
  static const int _hourCount = _endHour - _startHour;

  List<DateTime> get _days {
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  List<DemoBooking> _bookingsForDay(DateTime day) {
    return bookings.where((b) {
      return b.scheduledStart.year == day.year &&
          b.scheduledStart.month == day.month &&
          b.scheduledStart.day == day.day;
    }).toList();
  }

  bool _isToday(DateTime day) {
    return today.any((t) => t.year == day.year && t.month == day.month && t.day == day.day);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(context),
        const SizedBox(height: 8),
        _buildDayHeader(),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        Expanded(child: _buildGrid(context)),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final first = _days.first;
    final last = _days.last;
    final monthLabel = _monthName(first.month);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChangeWeek?.call(weekStart.subtract(const Duration(days: 7))),
            tooltip: 'Previous week',
          ),
          Expanded(
            child: Center(
              child: Text(
                '$monthLabel ${first.day} - ${_monthName(last.month)} ${last.day}, ${last.year}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChangeWeek?.call(weekStart.add(const Duration(days: 7))),
            tooltip: 'Next week',
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: _timeColumnWidth),
          ..._days.asMap().entries.map((e) {
            final day = e.value;
            final isToday = _isToday(day);
            return Expanded(
              child: Column(
                children: [
                  Text(
                    weekdays[e.key],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isToday ? const Color(0xFF2E7D32) : const Color(0xFF6B7280),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? const Color(0xFF2E7D32) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isToday ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        height: _hourHeight * _hourCount,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hour labels
            SizedBox(
              width: _timeColumnWidth,
              child: Column(
                children: List.generate(_hourCount, (i) {
                  final hour = _startHour + i;
                  return SizedBox(
                    height: _hourHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6, top: 2),
                      child: Text(
                        _formatHour(hour),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // 7 day columns
            ..._days.map((day) => Expanded(
                  child: _buildDayColumn(day),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDayColumn(DateTime day) {
    final dayBookings = _bookingsForDay(day);
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: Stack(
        children: [
          // Hour grid lines
          Column(
            children: List.generate(_hourCount, (i) {
              return Container(
                height: _hourHeight,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: const Color(0xFFF3F4F6), width: i == _hourCount - 1 ? 0 : 1),
                  ),
                ),
              );
            }),
          ),
          // Booking blocks
          ...dayBookings.map((b) => _buildBookingBlock(b)),
        ],
      ),
    );
  }

  Widget _buildBookingBlock(DemoBooking b) {
    final startHour = b.scheduledStart.hour + b.scheduledStart.minute / 60.0;
    final endHour = b.scheduledEnd.hour + b.scheduledEnd.minute / 60.0;
    final clampedStart = startHour.clamp(_startHour.toDouble(), _endHour.toDouble());
    final clampedEnd = endHour.clamp(_startHour.toDouble(), _endHour.toDouble());
    final top = (clampedStart - _startHour) * _hourHeight;
    final height = ((clampedEnd - clampedStart) * _hourHeight).clamp(24.0, double.infinity);
    final color = b.status.color;
    // Strip down the property name so it fits the narrow cell:
    //   "Unit C-21, Menara Suria" -> "C-21"
    final unitMatch = RegExp(r'Unit\s+([A-Z]-\d{2})').firstMatch(b.property);
    final shortLabel = unitMatch?.group(1) ?? b.property.split(',').first;
    return Positioned(
      top: top,
      left: 3,
      right: 3,
      child: GestureDetector(
        onTap: () => onTapBooking(b),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shortLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                b.serviceType,
                style: const TextStyle(fontSize: 9, color: Color(0xFF374151)),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHour(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  String _monthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }
}

/// Returns the Monday of the week containing [date] (00:00 local).
DateTime mondayOf(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}
