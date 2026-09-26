// lib/screens/reschedule_screen.dart
// Pick a new date + time for an existing booking. Reuses the new-booking
// form's date+time pickers for consistency.
//
// F1b: requires a non-empty reason before allowing reschedule (audit trail).
// F1c: enforces kMaxRescheduleCount — once reached, the reschedule button
// is disabled and the user is told to cancel and re-create.
//
// Round 13 polish (RS1): documentation header added. Code already uses
// 13 SemanticColors + 3 AppColors tokens (Round 6). No code change.

import 'package:flutter/material.dart';
import '../main.dart';
import '../models/demo_data.dart';
import '../services/booking_store.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';

class RescheduleScreen extends StatefulWidget {
  const RescheduleScreen({super.key, required this.booking});
  final DemoBooking booking;

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  late DateTime _date;
  late TimeOfDay _time;
  final TextEditingController _reason = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.booking.scheduledStart;
    _time = TimeOfDay(
      hour: widget.booking.scheduledStart.hour,
      minute: widget.booking.scheduledStart.minute,
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Please provide a reason (required)');
      return;
    }
    if (widget.booking.rescheduleCount >= kMaxRescheduleCount) {
      setState(() => _error =
          'Reschedule limit reached (${kMaxRescheduleCount} of $kMaxRescheduleCount). '
          'Please cancel this booking and create a new one.');
      return;
    }
    final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    if (start.isBefore(DateTime.now())) {
      setState(() => _error = 'Pick a time in the future');
      return;
    }
    final duration =
        widget.booking.scheduledEnd.difference(widget.booking.scheduledStart);
    final end = start.add(duration);
    final store = AppProviders.of(context).bookingStore;
    store.rescheduleBooking(
      id: widget.booking.id,
      newStart: start,
      newEnd: end,
      reason: reason,
    );
    final updated = store.byId(widget.booking.id);
    Haptics.medium();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rescheduled to ${_formatDateTime(start)}'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final start = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final limitReached =
        widget.booking.rescheduleCount >= kMaxRescheduleCount;
    final canSubmit = !limitReached && _reason.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reschedule'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Booking summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sem.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sem.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.booking.property,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: sem.textPrimary)),
                const SizedBox(height: 4),
                Text(widget.booking.serviceType,
                    style: TextStyle(fontSize: 12, color: sem.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Currently: ${_formatDateTime(widget.booking.scheduledStart)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (widget.booking.rescheduleCount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.history, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        'Rescheduled ${widget.booking.rescheduleCount} / $kMaxRescheduleCount times',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (limitReached)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reschedule limit reached ($kMaxRescheduleCount of $kMaxRescheduleCount). Cancel this booking and create a new one to change the time again.',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          Text('NEW DATE & TIME',
              style: TextStyle(
                  fontSize: 11,
                  color: sem.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _picker(
                      context, 'Date', _formatDate(_date), Icons.calendar_today, _pickDate, limitReached)),
              const SizedBox(width: 12),
              Expanded(
                  child: _picker(
                      context, 'Time', _time.format(context), Icons.schedule, _pickTime, limitReached)),
            ],
          ),

          const SizedBox(height: 20),
          Text('REASON (REQUIRED)',
              style: TextStyle(
                  fontSize: 11,
                  color: sem.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            enabled: !limitReached,
            maxLines: 2,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'e.g. Tenant moved in late, need to shift the cleaning',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFEF4444))),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New time: ${_formatDateTime(start)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: const Icon(Icons.check),
            label: Text(limitReached
                ? 'Reschedule unavailable'
                : 'Confirm reschedule'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: limitReached
                  ? const Color(0xFFD1D5DB)
                  : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _picker(
    BuildContext ctx,
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
    bool disabled,
  ) {
    final sem = SemanticColors.of(ctx);
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: disabled ? null : () { Haptics.light(); onTap(); },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sem.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sem.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: sem.textSecondary),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 11, color: sem.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sem.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    return '${_formatDate(d)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
