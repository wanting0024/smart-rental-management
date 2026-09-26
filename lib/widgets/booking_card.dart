// lib/widgets/booking_card.dart
// Compact booking row used in lists. Shows recurring badge when applicable.

import 'package:flutter/material.dart';
import '../models/demo_data.dart';
import 'status_chip.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.onTap});
  final DemoBooking booking;
  final VoidCallback onTap;

  String _fmtDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _timeRange(DateTime s, DateTime e) =>
      '${_fmtTime(s)} - ${_fmtTime(e)}';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.property,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (booking.isMultiDay)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _MultiDayBadge(days: booking.totalDays),
                    ),
                  if (booking.isRecurring)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _RecurringBadge(pattern: booking.recurrencePattern!),
                    ),
                  StatusChip(status: booking.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                booking.serviceType,
                style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Text(
                    _fmtDate(booking.scheduledStart),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _timeRange(booking.scheduledStart, booking.scheduledEnd),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (booking.providerName != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking.providerName!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringBadge extends StatelessWidget {
  const _RecurringBadge({required this.pattern});
  final RecurrencePattern pattern;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF80CBC4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, size: 10, color: Color(0xFF00796B)),
          const SizedBox(width: 3),
          Text(
            pattern.shortLabel,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF00796B), letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

class _MultiDayBadge extends StatelessWidget {
  const _MultiDayBadge({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFA5B4FC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_view_week, size: 10, color: Color(0xFF4338CA)),
          const SizedBox(width: 3),
          Text(
            '$days days',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF4338CA), letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
