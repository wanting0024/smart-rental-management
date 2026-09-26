// lib/widgets/cancellation_reason_sheet.dart
// Bottom sheet that requires the user to pick a reason before cancelling.
// Returns the chosen reason via Navigator.pop. If the user dismisses
// without picking, returns null.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CancellationReason {
  const CancellationReason({required this.id, required this.label, required this.icon, required this.color});
  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

const kCancellationReasons = <CancellationReason>[
  CancellationReason(id: 'changed_mind',    label: 'Changed my mind',         icon: Icons.replay,         color: Color(0xFF6B7280)),
  CancellationReason(id: 'scheduling',     label: 'Scheduling conflict',     icon: Icons.event_busy,     color: Color(0xFFFB8C00)),
  CancellationReason(id: 'price',          label: 'Price too high',          icon: Icons.payments,       color: Color(0xFFEF4444)),
  CancellationReason(id: 'bad_service',    label: 'Provider not responsive', icon: Icons.support_agent,  color: Color(0xFFEF4444)),
  CancellationReason(id: 'no_longer_need', label: 'No longer needed',        icon: Icons.check_circle,   color: Color(0xFF2E7D32)),
  CancellationReason(id: 'other',          label: 'Other (tell us more)',    icon: Icons.edit_note,      color: Color(0xFF26A69A)),
];

class CancellationReasonSheet extends StatefulWidget {
  const CancellationReasonSheet({super.key, required this.bookingId, this.allowComment = true});
  final String bookingId;
  final bool allowComment;

  @override
  State<CancellationReasonSheet> createState() => _CancellationReasonSheetState();
}

class _CancellationReasonSheetState extends State<CancellationReasonSheet> {
  String? _selectedId;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_selectedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a reason'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop(<String, String>{
      'reason_id': _selectedId!,
      'comment': _commentCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFEF4444)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cancel this booking?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: sem.textPrimary)),
                          Text('Booking ${widget.bookingId.toUpperCase()}', style: TextStyle(fontSize: 12, color: sem.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('WHY ARE YOU CANCELLING?', style: TextStyle(fontSize: 11, color: sem.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                const SizedBox(height: 10),
                ...kCancellationReasons.map((r) => _reasonTile(r, sem)),
                if (widget.allowComment) ...[
                  const SizedBox(height: 16),
                  Text('Anything else? (optional)', style: TextStyle(fontSize: 11, color: sem.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: 'Help us improve...',
                      filled: true,
                      fillColor: sem.surfaceAlt,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: sem.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: sem.border),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Keep booking'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _confirm,
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Cancel booking'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reasonTile(CancellationReason r, SemanticColors sem) {
    final selected = _selectedId == r.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedId = r.id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? r.color.withOpacity(0.1) : sem.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? r.color : sem.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: r.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(r.icon, size: 16, color: r.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: sem.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 18, color: r.color),
            ],
          ),
        ),
      ),
    );
  }
}
