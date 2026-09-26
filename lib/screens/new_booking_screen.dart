// lib/screens/new_booking_screen.dart
// Owner creates a new cleaning request. Multi-field form with validation.
// On submit, creates a DemoBooking with status Pending and returns it.
//
// Round 9 polish (NB1-NB8):
//   NB1 Theme colors (AppColors.primary + sem.*) instead of hardcoded hex
//   NB2 Sticky submit button in bottomNavigationBar (always visible)
//   NB3 PopScope unsaved-changes guard (warn before back/close)
//   NB4 Switch.adaptive for Auto-match and Recurring toggles
//   NB5 intl.DateFormat for date display (consistency with rest of app)
//   NB6 Quick picks chips themed (primary surface + primary border)
//   NB7 SectionHeader widget throughout (typography consistency)
//   NB8 Multi-day / Recurring section cards themed (sem.* + primary tint)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/section_header.dart';

class NewBookingScreen extends StatefulWidget {
  const NewBookingScreen({super.key, this.onSubmit});
  final void Function(DemoBooking booking)? onSubmit;

  @override
  State<NewBookingScreen> createState() => _NewBookingScreenState();
}

class _NewBookingScreenState extends State<NewBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  DemoProperty? _selectedProperty;
  ServiceTypeOption? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _instructionsCtrl = TextEditingController();
  bool _autoMatch = true;
  bool _isRecurring = false;
  RecurrencePattern _recurrence = RecurrencePattern.weekly;
  int _totalDays = 1;

  // Track whether any form field has been touched — used by PopScope guard.
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _instructionsCtrl.addListener(_onAnyChange);
  }

  @override
  void dispose() {
    _instructionsCtrl.dispose();
    super.dispose();
  }

  void _onAnyChange() {
    // Mark dirty if user has entered anything substantial.
    final dirty = _selectedProperty != null ||
        _selectedService != null ||
        _selectedDate != null ||
        _selectedTime != null ||
        _instructionsCtrl.text.trim().isNotEmpty ||
        _isRecurring ||
        _totalDays > 1;
    if (dirty != _hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = dirty);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Theme.of(ctx).brightness,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _onAnyChange();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Theme.of(ctx).brightness,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _onAnyChange();
      });
    }
  }

  /// PopScope guard: ask user to confirm discarding in-progress form.
  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this request?'),
        content: const Text(
          'You have unsaved selections. Going back will clear them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProperty == null) {
      _showError('Please select a property');
      return;
    }
    if (_selectedService == null) {
      _showError('Please select a service type');
      return;
    }
    if (_selectedDate == null) {
      _showError('Please pick a date');
      return;
    }
    if (_selectedTime == null) {
      _showError('Please pick a time');
      return;
    }

    final start = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final end = start.add(Duration(hours: _selectedService!.durationHours));

    final booking = DemoBooking(
      id: 'b-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      property: _selectedProperty!.display,
      serviceType: _selectedService!.label,
      providerName: null, // auto-match
      scheduledStart: start,
      scheduledEnd: end,
      status: BookingStatus.pending,
      specialInstructions: _instructionsCtrl.text.trim().isEmpty
          ? null
          : _instructionsCtrl.text.trim(),
      isRecurring: _isRecurring,
      recurrencePattern: _isRecurring ? _recurrence : null,
      totalDays: _totalDays,
    );

    widget.onSubmit?.call(booking);
    Navigator.of(context).pop(booking);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _confirmDiscard();
        if (allow && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New cleaning request'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _confirmDiscard() && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            tooltip: 'Cancel',
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildPropertyCard(sem),
              const SizedBox(height: 20),
              const SectionHeader(
                title: 'Service type',
                subtitle: 'Pick one · duration and base price will follow',
              ),
              const SizedBox(height: 12),
              _buildServiceGrid(sem),
              const SizedBox(height: 20),
              const SectionHeader(
                title: 'When',
                subtitle: 'Schedule a 2-hour window for the cleaning team',
              ),
              const SizedBox(height: 8),
              _buildQuickPicks(sem),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildDateField(sem)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimeField(sem)),
                ],
              ),
              const SizedBox(height: 20),
              _buildMultiDaySection(sem),
              const SizedBox(height: 20),
              _buildRecurringSection(sem),
              const SizedBox(height: 20),
              const SectionHeader(
                title: 'Special instructions',
                subtitle: 'Optional · tell the team anything they should know',
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Notes',
                hint:
                    'e.g. "Focus on kitchen and both bathrooms. Tenant move-in tomorrow 9 AM."',
                controller: _instructionsCtrl,
                maxLines: 4,
                minLines: 3,
                maxLength: 300,
              ),
              const SizedBox(height: 20),
              _buildAutoMatchCard(sem),
              const SizedBox(height: 20),
              _buildSummaryCard(sem),
            ],
          ),
        ),
        // NB2: sticky submit button
        bottomNavigationBar: _StickySubmitBar(
          enabled: _selectedProperty != null &&
              _selectedService != null &&
              _selectedDate != null &&
              _selectedTime != null,
          onSubmit: _submit,
          sem: sem,
        ),
      ),
    );
  }

  // ============== Sub-widgets ==============

  Widget _buildPropertyCard(SemanticColors sem) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.apartment, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Property',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sem.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DemoProperty>(
            value: _selectedProperty,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
            decoration: InputDecoration(
              filled: true,
              fillColor: sem.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: sem.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: sem.border),
              ),
            ),
            hint: Text('Select a property',
                style: TextStyle(color: sem.textTertiary)),
            items: DemoProperty.all.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p.display,
                    style: TextStyle(fontSize: 14, color: sem.textPrimary)),
              );
            }).toList(),
            onChanged: (v) {
              setState(() => _selectedProperty = v);
              _onAnyChange();
            },
            validator: (v) => v == null ? 'Required' : null,
          ),
          if (_selectedProperty != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_selectedProperty!.bedrooms} bedrooms  ·  ${_selectedProperty!.sizeSqft} sqft',
              style: TextStyle(fontSize: 12, color: sem.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceGrid(SemanticColors sem) {
    return Column(
      children: [
        ...ServiceTypeOption.all.map((s) {
          final selected = _selectedService?.id == s.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() => _selectedService = s);
                _onAnyChange();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primarySurface : sem.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.primary : sem.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              selected ? AppColors.primary : sem.textTertiary,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: sem.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.durationHours} hours  ·  from RM ${s.priceFrom.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 12, color: sem.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDateField(SemanticColors sem) {
    final dateText = _selectedDate == null
        ? null
        : DateFormat('d MMM y').format(_selectedDate!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sem.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: sem.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sem.border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: sem.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateText ?? 'Pick a date',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          dateText == null ? sem.textTertiary : sem.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(SemanticColors sem) {
    final timeText =
        _selectedTime == null ? null : _selectedTime!.format(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: sem.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickTime,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: sem.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sem.border),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: sem.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeText ?? 'Pick a time',
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          timeText == null ? sem.textTertiary : sem.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoMatchCard(SemanticColors sem) {
    return InkWell(
      onTap: () {
        setState(() => _autoMatch = !_autoMatch);
        _onAnyChange();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-match provider',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sem.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "We'll rank providers and route to the best match",
                    style: TextStyle(fontSize: 12, color: sem.textSecondary),
                  ),
                ],
              ),
            ),
            // NB4: Switch.adaptive
            Switch.adaptive(
              value: _autoMatch,
              onChanged: (v) {
                setState(() => _autoMatch = v);
                _onAnyChange();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(SemanticColors sem) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sem.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sem.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: sem.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow(sem, 'Property', _selectedProperty?.display ?? '-'),
          _summaryRow(sem, 'Service', _selectedService?.label ?? '-'),
          _summaryRow(sem, 'When', _formatWhen()),
          _summaryRow(sem, 'Auto-match', _autoMatch ? 'Yes' : 'No'),
          if (_isRecurring) _summaryRow(sem, 'Repeats', _recurrence.label),
          if (_totalDays > 1) _summaryRow(sem, 'Duration', '$_totalDays days'),
          if (_selectedService != null) ...[
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated cost',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sem.textPrimary,
                  ),
                ),
                Text(
                  'RM ${_selectedService!.priceFrom.toStringAsFixed(0)}+',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(SemanticColors sem, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: sem.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: sem.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWhen() {
    if (_selectedDate == null || _selectedTime == null) return '-';
    final d = _selectedDate!;
    final dateStr = DateFormat('d MMM y').format(d);
    return '$dateStr, ${_selectedTime!.format(context)}';
  }

  // ====================================================================
  // Smart time picker — quick-pick chips
  // ====================================================================

  Widget _buildQuickPicks(SemanticColors sem) {
    final suggestions = _computeQuickPicks();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK PICKS',
          style: TextStyle(
            fontSize: 11,
            color: sem.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: suggestions.map((s) => _quickPickChip(s, sem)).toList(),
        ),
      ],
    );
  }

  Widget _quickPickChip(_QuickPick s, SemanticColors sem) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = s.date;
          _selectedTime = s.time;
        });
        _onAnyChange();
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              s.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_QuickPick> _computeQuickPicks() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final today = DateTime(now.year, now.month, now.day);
    int daysUntilMon = (DateTime.monday - now.weekday) % 7;
    if (daysUntilMon == 0) daysUntilMon = 7;
    final nextMonday = today.add(Duration(days: daysUntilMon));
    int daysUntilSat = (DateTime.saturday - now.weekday) % 7;
    if (daysUntilSat == 0) daysUntilSat = 7;
    final nextSaturday = today.add(Duration(days: daysUntilSat));
    return [
      _QuickPick('Tomorrow 10am', Icons.wb_sunny_outlined, tomorrow,
          const TimeOfDay(hour: 10, minute: 0)),
      _QuickPick('Tomorrow 2pm', Icons.wb_sunny_outlined, tomorrow,
          const TimeOfDay(hour: 14, minute: 0)),
      _QuickPick('Mon 10am', Icons.calendar_today, nextMonday,
          const TimeOfDay(hour: 10, minute: 0)),
      _QuickPick('Sat 9am', Icons.weekend_outlined, nextSaturday,
          const TimeOfDay(hour: 9, minute: 0)),
    ];
  }

  // ====================================================================
  // Recurring section
  // ====================================================================

  Widget _buildRecurringSection(SemanticColors sem) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isRecurring ? AppColors.primarySurface : sem.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRecurring ? AppColors.primary : sem.border,
          width: _isRecurring ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isRecurring ? AppColors.primary : sem.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.repeat,
                  size: 18,
                  color: _isRecurring ? Colors.white : sem.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Repeat',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sem.textPrimary,
                      ),
                    ),
                    Text(
                      'Auto-schedule next occurrence when this one completes',
                      style: TextStyle(fontSize: 11, color: sem.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isRecurring,
                onChanged: (v) {
                  setState(() => _isRecurring = v);
                  _onAnyChange();
                },
              ),
            ],
          ),
          if (_isRecurring) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: RecurrencePattern.values.map((p) {
                final selected = _recurrence == p;
                return InkWell(
                  onTap: () => setState(() => _recurrence = p),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.primaryBorder,
                      ),
                    ),
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.primaryDark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMultiDaySection(SemanticColors sem) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _totalDays > 1 ? AppColors.secondarySurface : sem.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _totalDays > 1 ? AppColors.secondary : sem.border,
          width: _totalDays > 1 ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _totalDays > 1 ? AppColors.secondary : sem.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_view_week,
                  size: 18,
                  color: _totalDays > 1 ? Colors.white : sem.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multi-day booking',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sem.textPrimary,
                      ),
                    ),
                    Text(
                      'For deep cleans that span 2-3 days',
                      style: TextStyle(fontSize: 11, color: sem.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                _totalDays == 1 ? '1 day' : '$_totalDays days',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _totalDays > 1
                      ? AppColors.secondaryDark
                      : sem.textSecondary,
                ),
              ),
            ],
          ),
          if (_totalDays > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sem.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.secondaryBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available,
                      size: 16, color: AppColors.secondaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking runs from start date for $_totalDays days',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sem.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _multiDayChip(1, sem),
              const SizedBox(width: 6),
              _multiDayChip(2, sem),
              const SizedBox(width: 6),
              _multiDayChip(3, sem),
            ],
          ),
        ],
      ),
    );
  }

  Widget _multiDayChip(int days, SemanticColors sem) {
    final selected = _totalDays == days;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _totalDays = days;
            _onAnyChange();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondary : sem.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.secondary : sem.border,
            ),
          ),
          child: Center(
            child: Text(
              days == 1 ? '1 day' : '$days days',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : sem.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickySubmitBar extends StatelessWidget {
  const _StickySubmitBar({
    required this.enabled,
    required this.onSubmit,
    required this.sem,
  });
  final bool enabled;
  final VoidCallback onSubmit;
  final SemanticColors sem;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: sem.surface,
          border: Border(top: BorderSide(color: sem.border)),
          boxShadow: [
            BoxShadow(
              color: sem.shadow,
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    enabled ? 'Ready to submit' : 'Fill in the required fields',
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? AppColors.success : sem.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: enabled ? onSubmit : null,
                icon: const Icon(Icons.send),
                label: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPick {
  const _QuickPick(this.label, this.icon, this.date, this.time);
  final String label;
  final IconData icon;
  final DateTime date;
  final TimeOfDay time;
}
