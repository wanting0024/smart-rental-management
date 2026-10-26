import 'package:flutter/material.dart';
import '../services/backend/safe_diagnostics.dart';
import 'package:flutter/services.dart';

import '../services/backend/connected_failure_message.dart';
import '../models/demo_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/unsaved_changes_guard.dart';
import '../widgets/bedroom_count_field.dart';

/// Values collected for a real Owner property. Saving is delegated to the
/// connected workspace so this form never writes local preview data.
class ConnectedPropertyInput {
  const ConnectedPropertyInput({
    required this.unitName,
    required this.buildingName,
    required this.address,
    required this.bedrooms,
    required this.sizeSqft,
    required this.cleaningWindowStart,
    required this.cleaningWindowEnd,
  });

  final String unitName;
  final String buildingName;
  final String address;
  final int bedrooms;
  final int sizeSqft;
  final String cleaningWindowStart;
  final String cleaningWindowEnd;
}

class ConnectedPropertyFormScreen extends StatefulWidget {
  const ConnectedPropertyFormScreen({
    super.key,
    required this.onSave,
    this.initial,
    this.canSave,
  });

  final Future<void> Function(ConnectedPropertyInput input) onSave;
  final DemoProperty? initial;
  final bool Function()? canSave;

  @override
  State<ConnectedPropertyFormScreen> createState() =>
      _ConnectedPropertyFormScreenState();
}

class _ConnectedPropertyFormScreenState
    extends State<ConnectedPropertyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _unit = TextEditingController();
  final _building = TextEditingController();
  final _address = TextEditingController();
  final _bedrooms = TextEditingController();
  final _size = TextEditingController();
  TimeOfDay? _start;
  TimeOfDay? _end;
  bool _saving = false;
  bool _needsVerification = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    if (value == null) return;
    _unit.text = value.unit;
    _building.text = value.tower;
    _address.text = value.address;
    _bedrooms.text = '${value.bedrooms}';
    _size.text = '${value.sizeSqft}';
    _start = value.cleaningWindowStart;
    _end = value.cleaningWindowEnd;
  }

  @override
  void dispose() {
    _unit.dispose();
    _building.dispose();
    _address.dispose();
    _bedrooms.dispose();
    _size.dispose();
    super.dispose();
  }

  Future<TimeOfDay?> _pickTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime:
          (start ? _start : _end) ?? TimeOfDay(hour: start ? 8 : 18, minute: 0),
      helpText: start ? 'Cleaning window starts' : 'Cleaning window ends',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || selected == null) return null;
    setState(() {
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
      _error = null;
    });
    return selected;
  }

  int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  String _databaseTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (widget.canSave?.call() == false) {
      setState(() =>
          _error = 'Your session changed. Close this form and sign in again.');
      return;
    }
    if (_saving || _needsVerification || !_formKey.currentState!.validate())
      return;
    if (_start == null || _end == null) return;
    if (_minutes(_end!) <= _minutes(_start!)) {
      setState(() => _error = 'The end time must be after the start time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(ConnectedPropertyInput(
        unitName: _unit.text.trim(),
        buildingName: _building.text.trim(),
        address: _address.text.trim(),
        bedrooms: int.parse(_bedrooms.text),
        sizeSqft: int.parse(_size.text),
        cleaningWindowStart: _databaseTime(_start!),
        cleaningWindowEnd: _databaseTime(_end!),
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      SafeDiagnostics.app.record(SafeOperation.propertySave, error);
      if (mounted) {
        setState(() {
          final rejected = error is PostgrestException &&
              const {'22023', '23514', '23505', '42501'}.contains(error.code);
          _needsVerification = !rejected;
          _error = error is PostgrestException && error.code == '40001'
              ? 'This property was changed elsewhere. Close this form and reload before editing.'
              : rejected
                  ? 'Could not save. Check the details, duplicate unit name and cleaning window. Confirmed bookings must remain within the window.'
                  : ConnectedFailureMessage.isConnectionFailure(error)
                      ? 'Connection lost while saving. Your entries are kept. Check My properties before adding this unit again.'
                      : 'We could not confirm whether this unit was saved. Your entries are kept. Check My properties before adding it again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    String? hint,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        controller: controller,
        enabled: !_saving,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        inputFormatters:
            numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
        textCapitalization:
            numeric ? TextCapitalization.none : TextCapitalization.words,
        decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: helper,
            helperMaxLines: 3,
            floatingLabelBehavior: hint == null
                ? FloatingLabelBehavior.auto
                : FloatingLabelBehavior.always),
        validator: (value) {
          if (value == null || value.trim().isEmpty)
            return '$label is required';
          if (numeric && (int.tryParse(value) ?? 0) <= 0) {
            return 'Enter a positive number';
          }
          return null;
        },
      ),
    );
  }

  Widget _timeField(bool start) => FormField<TimeOfDay>(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        key: ValueKey(start ? 'window-start' : 'window-end'),
        initialValue: start ? _start : _end,
        validator: (_) {
          final value = start ? _start : _end;
          if (value == null)
            return start ? 'Select a start time' : 'Select an end time';
          if (!start && _start != null && _minutes(value) <= _minutes(_start!))
            return 'End must be after start';
          return null;
        },
        builder: (field) {
          final value = start ? _start : _end;
          return Semantics(
              button: true,
              child: InkWell(
                onTap: _saving
                    ? null
                    : () async {
                        final selected = await _pickTime(start: start);
                        if (selected != null && mounted)
                          field.didChange(selected);
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: start ? 'Available from *' : 'Available until *',
                    errorText: field.errorText,
                    suffixIcon: const Icon(Icons.schedule),
                    enabled: !_saving,
                  ),
                  child: Text(
                      value == null ? 'Select time' : _databaseTime(value)),
                ),
              ));
        },
      );

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
        dirty: () =>
            _unit.text != (widget.initial?.unit ?? '') ||
            _building.text != (widget.initial?.tower ?? '') ||
            _address.text != (widget.initial?.address ?? '') ||
            _bedrooms.text !=
                (widget.initial == null ? '' : '${widget.initial!.bedrooms}') ||
            _size.text !=
                (widget.initial == null ? '' : '${widget.initial!.sizeSqft}') ||
            _start != widget.initial?.cleaningWindowStart ||
            _end != widget.initial?.cleaningWindowEnd,
        busy: () => _saving,
        child: Scaffold(
          appBar: AppBar(
              title: Text(widget.initial == null
                  ? 'Add rental unit'
                  : 'Edit rental unit')),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Property details',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('This rental unit will be saved to your account.'),
                  const SizedBox(height: 20),
                  _textField('Unit name', _unit,
                      hint: 'e.g. A-12-03',
                      helper: 'The unit or apartment number.'),
                  _textField('Building or tower', _building,
                      hint: 'e.g. Menara Suria',
                      helper:
                          'The building name, including the tower or block if needed.'),
                  _textField('Property address', _address,
                      hint: 'e.g. 12 Jalan Example, Kuala Lumpur',
                      helper:
                          'The address the provider needs to find this property.'),
                  BedroomCountField(controller: _bedrooms, enabled: !_saving),
                  const SizedBox(height: 14),
                  _textField('Size (sqft)', _size,
                      numeric: true,
                      hint: 'e.g. 980',
                      helper: 'Floor area in square feet (sqft).'),
                  const SizedBox(height: 8),
                  const Text('Permissible cleaning window',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                      'Cleaning bookings must fit within this time range.'),
                  const Text(
                      'Both times are required · 24-hour format (HH:mm) · Malaysia time'),
                  const SizedBox(height: 12),
                  _timeField(true),
                  const SizedBox(height: 16),
                  _timeField(false),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error!,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _needsVerification
                    ? FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Check My properties'),
                      )
                    : FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving
                            ? 'Saving…'
                            : widget.initial == null
                                ? 'Add property'
                                : 'Save changes'),
                      ),
              ),
            ),
          ),
        ));
  }
}
