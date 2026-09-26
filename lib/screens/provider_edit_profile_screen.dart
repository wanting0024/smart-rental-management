// lib/screens/provider_edit_profile_screen.dart
// Provider profile editor. Reads from + writes to ProviderStore.
//
// Round 7 polish:
//   1. Form validation (name, phone, email, rate, working hours)
//   2. Section grouping (Profile / Contact / Services / Schedule / Rate / Privacy)
//   3. Sticky save button in bottomNavigationBar
//   4. Unsaved changes guard via PopScope + confirm dialog
//   5. Bigger avatar (120x120) with photo/color toggle
//   6. Helper text + char counter + bio limit (200)
//   7. Bonus: Privacy toggle for phone visibility to owners

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../models/demo_data.dart';
import '../services/provider_store.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'provider_profile_screen.dart';

class ProviderEditProfileScreen extends StatefulWidget {
  const ProviderEditProfileScreen({super.key, required this.provider});
  final DemoProvider provider;

  @override
  State<ProviderEditProfileScreen> createState() => _ProviderEditProfileScreenState();
}

class _ProviderEditProfileScreenState extends State<ProviderEditProfileScreen> {
  // Controllers ------------------------------------------------------------
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _rateCtrl;
  late TimeOfDay _workStart;
  late TimeOfDay _workEnd;
  late List<String> _services;
  late int _avatarColorIndex;
  late bool _showPhoneToOwners;
  XFile? _avatarImage;
  bool _saving = false;

  // Snapshot of initial values to detect dirty state.
  late final DemoProvider _initial;

  // Constants ----------------------------------------------------------------
  static const _bioMaxLength = 200;
  static const _allServices = <Map<String, String>>[
    {'id': 'standard', 'label': 'Standard cleaning'},
    {'id': 'deep',     'label': 'Deep cleaning'},
    {'id': 'window',   'label': 'Window cleaning'},
    {'id': 'move-in',  'label': 'Move-in cleaning'},
    {'id': 'move-out', 'label': 'Move-out cleaning'},
  ];
  static const _avatarColors = <Color>[
    Color(0xFF2E7D32), // emerald (brand)
    Color(0xFF26A69A), // teal (brand)
    Color(0xFF6366F1), // indigo
    Color(0xFFFB8C00), // orange
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // purple
  ];

  // Lifecycle ---------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _initial = widget.provider;
    final p = widget.provider;
    _nameCtrl = TextEditingController(text: p.name);
    _phoneCtrl = TextEditingController(text: p.phone);
    _emailCtrl = TextEditingController(text: p.email);
    _bioCtrl = TextEditingController(text: p.bio);
    _rateCtrl = TextEditingController(text: p.hourlyRate.toStringAsFixed(0));
    _workStart = p.workingHoursStart;
    _workEnd = p.workingHoursEnd;
    _services = List.of(p.serviceTypes);
    _avatarColorIndex = p.avatarColorIndex;
    _showPhoneToOwners = p.showPhoneToOwners;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  // Dirty-state detection ---------------------------------------------------
  bool get _isDirty {
    if (_nameCtrl.text.trim() != _initial.name) return true;
    if (_phoneCtrl.text.trim() != _initial.phone) return true;
    if (_emailCtrl.text.trim() != _initial.email) return true;
    if (_bioCtrl.text.trim() != _initial.bio) return true;
    final rate = double.tryParse(_rateCtrl.text);
    if (rate != null && rate != _initial.hourlyRate) return true;
    if (_workStart != _initial.workingHoursStart) return true;
    if (_workEnd != _initial.workingHoursEnd) return true;
    if (_services.length != _initial.serviceTypes.length ||
        !_services.asMap().entries.every(
            (e) => e.value == _initial.serviceTypes[e.key])) return true;
    if (_avatarColorIndex != _initial.avatarColorIndex) return true;
    if (_avatarImage != null) return true;
    if (_showPhoneToOwners != _initial.showPhoneToOwners) return true;
    return false;
  }

  // Validators --------------------------------------------------------------
  String? _validateName(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Display name is required';
    if (t.length < 2) return 'At least 2 characters';
    if (t.length > 60) return 'Too long (max 60)';
    return null;
  }

  String? _validatePhone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Phone is required';
    // Loose Malaysian phone format: +60 12-345 6789 / 012-345 6789 / +60123456789
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 9 || digits.length > 13) {
      return 'Enter a valid phone (e.g. +60 12-345 6789)';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _validateRate(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Hourly rate is required';
    final n = double.tryParse(t);
    if (n == null) return 'Enter a number';
    if (n <= 0) return 'Must be greater than 0';
    if (n > 1000) return 'Too high (max RM 1000/hr)';
    return null;
  }

  String? _validateBio(String? v) {
    final t = v ?? '';
    if (t.length > _bioMaxLength) return 'Max $_bioMaxLength characters';
    return null;
  }

  // Actions -----------------------------------------------------------------
  Future<void> _pickAvatar() async {
    Haptics.light();
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;
      setState(() => _avatarImage = image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _clearAvatarImage() {
    Haptics.light();
    setState(() => _avatarImage = null);
  }

  Future<void> _pickTime({required bool isStart}) async {
    Haptics.light();
    final initial = isStart ? _workStart : _workEnd;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _workStart = picked;
        if (!_isEndAfterStart()) {
          // Bump end to be at least 1 hour after the new start.
          _workEnd = TimeOfDay(
            hour: (picked.hour + 1) % 24,
            minute: picked.minute,
          );
        }
      } else {
        if (!_isEndAfterStart(customEnd: picked)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        _workEnd = picked;
      }
    });
  }

  bool _isEndAfterStart({TimeOfDay? customStart, TimeOfDay? customEnd}) {
    final s = customStart ?? _workStart;
    final e = customEnd ?? _workEnd;
    final sMin = s.hour * 60 + s.minute;
    final eMin = e.hour * 60 + e.minute;
    return eMin > sMin;
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Leave anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors above'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one service'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_isEndAfterStart()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Working hours: end must be after start'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Haptics.medium();
    setState(() => _saving = true);
    final updated = widget.provider.copyWith(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      hourlyRate: double.tryParse(_rateCtrl.text) ?? widget.provider.hourlyRate,
      workingHoursStart: _workStart,
      workingHoursEnd: _workEnd,
      serviceTypes: _services,
      avatarColorIndex: _avatarColorIndex,
      showPhoneToOwners: _showPhoneToOwners,
    );
    AppProviders.of(context).providerStore.update(updated);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _initial = updated; // reset dirty baseline
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Profile updated'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProviderProfileScreen(provider: updated)),
              );
            },
          ),
        ),
      );
      Navigator.of(context).pop();
    });
  }

  // Build -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit profile'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              _buildAvatarSection(sem),
              const SizedBox(height: 28),

              _sectionHeader('Profile', sem),
              const SizedBox(height: 12),
              _validatedField(
                label: 'Display name',
                controller: _nameCtrl,
                hint: 'How owners see you',
                icon: Icons.person_outline,
                sem: sem,
                validator: _validateName,
                maxLength: 60,
                inputFormatters: [LengthLimitingTextInputFormatter(60)],
              ),
              const SizedBox(height: 12),
              _bioField(sem),

              const SizedBox(height: 28),
              _sectionHeader('Contact', sem),
              const SizedBox(height: 12),
              _validatedField(
                label: 'Phone',
                controller: _phoneCtrl,
                hint: '+60 12-345 6789',
                icon: Icons.phone_outlined,
                sem: sem,
                validator: _validatePhone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _validatedField(
                label: 'Email',
                controller: _emailCtrl,
                hint: 'you@example.com',
                icon: Icons.email_outlined,
                sem: sem,
                validator: _validateEmail,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 28),
              _sectionHeader('Services you offer', sem),
              const SizedBox(height: 4),
              Text(
                'Tap to add or remove. Pick at least one.',
                style: TextStyle(fontSize: 12, color: sem.textSecondary),
              ),
              const SizedBox(height: 12),
              _buildServicesChips(sem),

              const SizedBox(height: 28),
              _sectionHeader('Schedule', sem),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildTimePicker('Start', _workStart,
                      () => _pickTime(isStart: true), sem)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimePicker('End', _workEnd,
                      () => _pickTime(isStart: false), sem)),
                ],
              ),

              const SizedBox(height: 28),
              _sectionHeader('Rate', sem),
              const SizedBox(height: 12),
              _validatedField(
                label: 'Hourly rate',
                controller: _rateCtrl,
                hint: '80',
                icon: Icons.payments_outlined,
                sem: sem,
                validator: _validateRate,
                keyboardType: TextInputType.number,
                suffix: 'RM/hr',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),

              const SizedBox(height: 28),
              _sectionHeader('Privacy', sem),
              const SizedBox(height: 4),
              _buildPrivacyToggle(sem),

              const SizedBox(height: 28),
              _sectionHeader('Avatar color', sem),
              const SizedBox(height: 4),
              Text(
                'Fallback if you do not upload a photo.',
                style: TextStyle(fontSize: 12, color: sem.textSecondary),
              ),
              const SizedBox(height: 12),
              _buildColorPicker(),

              const SizedBox(height: 28),
              _sectionHeader('Verification', sem),
              const SizedBox(height: 12),
              _buildVerificationCard(sem),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: sem.surface,
              border: Border(
                top: BorderSide(color: sem.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _saving ? 'Saving...' : 'Save profile',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _isDirty && !_saving
                      ? AppColors.primary
                      : const Color(0xFF9CA3AF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Section header ----------------------------------------------------------
  Widget _sectionHeader(String title, SemanticColors sem) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: sem.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }

  // Avatar section ----------------------------------------------------------
  Widget _buildAvatarSection(SemanticColors sem) {
    final color = _avatarColors[_avatarColorIndex % _avatarColors.length];
    final hasImage = _avatarImage != null;
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    image: hasImage
                        ? DecorationImage(
                            image: kIsWeb
                                ? NetworkImage(_avatarImage!.path)
                                    as ImageProvider
                                : FileImage(File(_avatarImage!.path)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? null
                      : Center(
                          child: Text(
                            widget.provider.name.isNotEmpty
                                ? widget.provider.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
              if (hasImage)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: const Color(0xFFEF4444),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _clearAvatarImage,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickAvatar,
            icon: Icon(hasImage ? Icons.swap_horiz : Icons.upload_outlined,
                size: 18),
            label: Text(hasImage ? 'Change photo' : 'Upload photo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  // Validated text field -----------------------------------------------------
  Widget _validatedField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required SemanticColors sem,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    String? suffix,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixText: suffix,
        counterText: '', // hide default counter (we add our own for bio)
      ),
    );
  }

  // Bio with character counter ----------------------------------------------
  Widget _bioField(SemanticColors sem) {
    return TextFormField(
      controller: _bioCtrl,
      validator: _validateBio,
      maxLines: 4,
      maxLength: _bioMaxLength,
      decoration: const InputDecoration(
        labelText: 'Bio',
        hintText: 'Tell owners about your service...',
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 56),
          child: Icon(Icons.description_outlined, size: 20),
        ),
        alignLabelWithHint: true,
      ),
      buildCounter: (context,
              {required currentLength,
              required isFocused,
              maxLength}) {
        return Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Text(
            '$currentLength / $maxLength',
            style: TextStyle(
              fontSize: 11,
              color: currentLength > (maxLength ?? 0) * 0.9
                  ? const Color(0xFFEF4444)
                  : sem.textTertiary,
            ),
          ),
        );
      },
    );
  }

  // Services chips ----------------------------------------------------------
  Widget _buildServicesChips(SemanticColors sem) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allServices.map((s) {
        final id = s['id']!;
        final label = s['label']!;
        final selected = _services.contains(id);
        return FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (v) {
            Haptics.light();
            setState(() {
              if (v) {
                if (!_services.contains(id)) _services.add(id);
              } else {
                _services.remove(id);
              }
            });
          },
          selectedColor: AppColors.primarySurface,
          checkmarkColor: AppColors.primary,
        );
      }).toList(),
    );
  }

  // Time picker field -------------------------------------------------------
  Widget _buildTimePicker(
      String label, TimeOfDay value, VoidCallback onTap, SemanticColors sem) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: sem.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sem.border),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 18, color: sem.textSecondary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: sem.textSecondary)),
                Text(
                  value.format(context),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Color picker ------------------------------------------------------------
  Widget _buildColorPicker() {
    return Row(
      children: List.generate(_avatarColors.length, (i) {
        final color = _avatarColors[i];
        final selected = _avatarColorIndex == i;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() => _avatarColorIndex = i);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        );
      }),
    );
  }

  // Privacy toggle ----------------------------------------------------------
  Widget _buildPrivacyToggle(SemanticColors sem) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: sem.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sem.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 20, color: Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Show phone to owners',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  _showPhoneToOwners
                      ? 'Owners see your phone and can call you.'
                      : 'Phone hidden. Owners can only contact via in-app chat.',
                  style: TextStyle(fontSize: 12, color: sem.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _showPhoneToOwners,
            onChanged: (v) {
              Haptics.light();
              setState(() => _showPhoneToOwners = v);
            },
          ),
        ],
      ),
    );
  }

  // Verification card -------------------------------------------------------
  Widget _buildVerificationCard(SemanticColors sem) {
    final p = widget.provider;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.isVerified
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.isVerified
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            p.isVerified ? Icons.verified : Icons.error_outline,
            color: p.isVerified
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.isVerified
                  ? 'Verified provider. Owners see a verified badge on your profile.'
                  : 'Not verified yet. Contact support to start verification.',
              style: TextStyle(
                fontSize: 12,
                color: p.isVerified
                    ? const Color(0xFF065F46)
                    : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
