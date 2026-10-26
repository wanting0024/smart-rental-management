import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../features/availability/domain/provider_availability.dart';
import '../services/provider_store.dart';
import '../theme/app_theme.dart';

/// Accepts digits or a pasted 24-hour time and inserts the colon automatically.
class _TimeDigitsFormatter extends TextInputFormatter {
  const _TimeDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    // Let backspace pass the separator so the hour can still be edited.
    if (oldValue.selection.isCollapsed &&
        oldValue.selection.baseOffset == 3 &&
        newValue.selection.baseOffset == 2 &&
        oldValue.text.replaceFirst(':', '') == raw) {
      return newValue;
    }

    final separator = raw.indexOf(':');
    final oneDigitHour =
        separator == 1 && raw.substring(0, separator).contains(RegExp(r'^\d$'));
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (oneDigitHour) digits = '0$digits';
    if (digits.length > 4) digits = digits.substring(0, 4);
    final formatted = digits.length > 2
        ? '${digits.substring(0, 2)}:${digits.substring(2)}'
        : digits;

    final rawCaret = newValue.selection.extentOffset.clamp(0, raw.length);
    var digitsBeforeCaret =
        raw.substring(0, rawCaret).replaceAll(RegExp(r'\D'), '').length;
    if (oneDigitHour && rawCaret > separator) digitsBeforeCaret++;
    digitsBeforeCaret = digitsBeforeCaret.clamp(0, digits.length);
    final formattedCaret = (digitsBeforeCaret +
            (digits.length > 2 && digitsBeforeCaret > 2 ? 1 : 0))
        .clamp(0, formatted.length);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formattedCaret),
    );
  }
}

/// Local editor for the provider's declared weekly hours and date exceptions.
class ProviderAvailabilityScreen extends StatelessWidget {
  const ProviderAvailabilityScreen({
    super.key,
    required this.store,
    required this.providerId,
  });

  final ProviderStore store;
  final String providerId;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _time(int minute) => '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  int? _parseTime(String value, {bool allowEndOfDay = false}) {
    final match = RegExp(r'^(\d{1,2}):([0-5]\d)$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 && !(allowEndOfDay && hour == 24 && minute == 0)) {
      return null;
    }
    return hour * 60 + minute;
  }

  Future<void> _editSlot(
    BuildContext context,
    int weekday,
    List<AvailabilitySlot> slots, {
    int? index,
  }) async {
    final existing = index == null ? null : slots[index];
    final initialStart =
        existing == null ? '09:00' : _time(existing.startMinute);
    final initialEnd = existing == null ? '12:00' : _time(existing.endMinute);
    var startInput = initialStart;
    var endInput = initialEnd;
    final formKey = GlobalKey<FormState>();
    String? slotError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final sem = SemanticColors.of(sheetContext);
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        index == null
                            ? 'Add working slot'
                            : 'Edit working slot',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: sem.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_days[weekday - 1]} · Enter both times in 24-hour format.',
                        style:
                            TextStyle(color: sem.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: const Key('slot-start-time'),
                              initialValue: initialStart,
                              onChanged: (value) => startInput = value,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [_TimeDigitsFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Start time',
                                hintText: '08:00',
                                prefixIcon: Icon(Icons.schedule_outlined),
                              ),
                              validator: (value) =>
                                  _parseTime(value ?? '') == null
                                      ? 'Use HH:MM'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: const Key('slot-end-time'),
                              initialValue: initialEnd,
                              onChanged: (value) => endInput = value,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [_TimeDigitsFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'End time',
                                hintText: '18:00',
                                prefixIcon: Icon(Icons.schedule_outlined),
                              ),
                              validator: (value) => _parseTime(value ?? '',
                                          allowEndOfDay: true) ==
                                      null
                                  ? 'Use HH:MM'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      if (slotError != null) ...[
                        const SizedBox(height: 10),
                        Text(slotError!,
                            style: TextStyle(
                                color: Theme.of(sheetContext).colorScheme.error,
                                fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Each slot must be at least 2 hours. Slots on the same day cannot overlap.',
                        style:
                            TextStyle(color: sem.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            final start = _parseTime(startInput)!;
                            final end =
                                _parseTime(endInput, allowEndOfDay: true)!;
                            if (end - start < AvailabilitySlot.minimumMinutes) {
                              setSheetState(() => slotError =
                                  'Working slots must be at least 2 hours long.');
                              return;
                            }
                            final next = List<AvailabilitySlot>.of(slots);
                            final newSlot = AvailabilitySlot(start, end);
                            if (index == null) {
                              next.add(newSlot);
                            } else {
                              next[index] = newSlot;
                            }
                            try {
                              store.setWeeklySlots(providerId, weekday, next);
                              Navigator.of(sheetContext).pop();
                            } on ArgumentError {
                              setSheetState(() => slotError =
                                  'This slot overlaps another working slot.');
                            }
                          },
                          child: const Text('Save working slot'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _blockDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    store.setUnavailableDate(providerId, date, true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final provider = store.byId(providerId);
          if (provider == null) {
            return const Scaffold(
              body: Center(child: Text('Provider profile unavailable.')),
            );
          }
          final schedule = provider.availabilitySchedule;
          final blocked = schedule.unavailableDates.toList()..sort();
          final activeDays = List.generate(7, (index) => index + 1)
              .where(
                  (day) => (schedule.weeklySlots[day] ?? const []).isNotEmpty)
              .length;
          final sem = SemanticColors.of(context);
          return Scaffold(
            appBar: AppBar(title: const Text('My availability')),
            backgroundColor: sem.background,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _overview(context, activeDays, blocked.length),
                const SizedBox(height: 24),
                _sectionTitle('Weekly working slots', sem),
                const SizedBox(height: 5),
                _supportingText(
                  'Set the hours when you can take a complete cleaning request.',
                  sem,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: sem.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: sem.border),
                  ),
                  child: Column(
                    children: [
                      for (var day = 1; day <= 7; day++) ...[
                        if (day > 1)
                          Divider(height: 1, indent: 16, color: sem.border),
                        _dayTile(
                          context,
                          day,
                          schedule.weeklySlots[day] ?? const [],
                          sem,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _sectionTitle('Unavailable dates', sem),
                const SizedBox(height: 5),
                _supportingText(
                  'A blocked date overrides your regular weekly hours.',
                  sem,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sem.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: sem.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (blocked.isEmpty)
                        Row(
                          children: [
                            Icon(Icons.event_available_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('No dates blocked',
                                  style: TextStyle(color: sem.textSecondary)),
                            ),
                          ],
                        ),
                      for (final key in blocked)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.event_busy_outlined,
                              color: Theme.of(context).colorScheme.primary),
                          title: Text(DateFormat('EEE, d MMM yyyy')
                              .format(DateTime.parse(key))),
                          trailing: IconButton(
                            tooltip: 'Remove unavailable date',
                            icon: const Icon(Icons.close),
                            onPressed: () => store.setUnavailableDate(
                                providerId, DateTime.parse(key), false),
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _blockDate(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add unavailable date'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _supportingText(
                  'Local demo: availability resets when the app restarts.',
                  sem,
                ),
              ],
            ),
          );
        },
      );

  Widget _overview(BuildContext context, int activeDays, int blockedDates) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.calendar_month_outlined,
                color: Colors.white, size: 26),
            const SizedBox(height: 14),
            const Text(
              'Plan your working week',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your declared hours help owners find you for suitable requests.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _overviewPill('$activeDays active days'),
                _overviewPill('$blockedDates blocked dates'),
              ],
            ),
          ],
        ),
      );

  Widget _overviewPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );

  Widget _sectionTitle(String title, SemanticColors sem) => Text(
        title,
        style: TextStyle(
          color: sem.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _supportingText(String text, SemanticColors sem) => Text(
        text,
        style: TextStyle(color: sem.textSecondary, fontSize: 13, height: 1.4),
      );

  Widget _dayTile(BuildContext context, int day, List<AvailabilitySlot> slots,
      SemanticColors sem) {
    final active = slots.isNotEmpty;
    final summary = active
        ? slots
            .map(
                (slot) => '${_time(slot.startMinute)}–${_time(slot.endMinute)}')
            .join(', ')
        : 'Unavailable';
    return ExpansionTile(
      key: PageStorageKey('availability-day-$day'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? sem.primarySurface : sem.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _days[day - 1].substring(0, 3),
          style: TextStyle(
            color: active
                ? Theme.of(context).colorScheme.primary
                : sem.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(_days[day - 1],
          style:
              TextStyle(color: sem.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: sem.textSecondary, fontSize: 12)),
      children: [
        for (var index = 0; index < slots.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.access_time,
                color: Theme.of(context).colorScheme.primary),
            title: Text(
                '${_time(slots[index].startMinute)}–${_time(slots[index].endMinute)}'),
            subtitle: const Text('Tap to edit this slot'),
            onTap: () => _editSlot(context, day, slots, index: index),
            trailing: IconButton(
              tooltip: 'Remove slot',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                final next = List<AvailabilitySlot>.of(slots)..removeAt(index);
                store.setWeeklySlots(providerId, day, next);
              },
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _editSlot(context, day, slots),
            icon: const Icon(Icons.add),
            label: const Text('Add working slot'),
          ),
        ),
      ],
    );
  }
}
