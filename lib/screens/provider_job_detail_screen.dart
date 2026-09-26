// lib/screens/provider_job_detail_screen.dart
// Provider-side active job screen. Mirror of BookingDetail but with
// provider-centric actions: check-in, start, finish, upload before/after.
//
// Round 13 polish (PJ1-PJ2):
//   PJ1 Modal bottom sheet background now uses sem.surface (dark mode aware).
//        All other Colors.white are inside green/orange hero+button contexts
//        and intentionally stay white (on top of colored backgrounds).
//   PJ2 Theme.of(context).colorScheme.surface replaced with sem.surface.

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/reject_reason_sheet.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';

class ProviderJobDetailScreen extends StatefulWidget {
  const ProviderJobDetailScreen({
    super.key,
    required this.booking,
    this.provider,
    this.onUpdate,
  });

  final DemoBooking booking;
  final DemoProvider? provider;
  final void Function(DemoBooking updated)? onUpdate;

  @override
  State<ProviderJobDetailScreen> createState() =>
      _ProviderJobDetailScreenState();
}

class _ProviderJobDetailScreenState extends State<ProviderJobDetailScreen> {
  late DemoBooking _booking;
  bool _hasBefore = false;
  bool _hasAfter = false;
  XFile? _beforeImage;
  XFile? _afterImage;
  late final TextEditingController _completionRemarksController;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _hasBefore = _booking.beforeImagePath != null;
    _hasAfter = _booking.afterImagePath != null;
    _completionRemarksController = TextEditingController(
      text: _booking.completionRemarks,
    );
  }

  @override
  void dispose() {
    _completionRemarksController.dispose();
    super.dispose();
  }

  _TransitionOutcome _transition(BookingStatus next, {String? reason}) {
    final store = AppProviders.of(context).bookingStore;
    bool succeeded;
    String failureMessage = 'This status change is not permitted.';

    if (next == BookingStatus.accepted) {
      final result = store.acceptPending(_booking.id);
      succeeded = result.accepted;
      failureMessage = result.message;
    } else if (next == BookingStatus.declined) {
      succeeded = store.declineBooking(_booking.id, reason: reason);
    } else {
      if (next == BookingStatus.completed) {
        store.update(
          _booking.copyWith(
            completionRemarks: _completionRemarksController.text.trim(),
          ),
        );
      }
      succeeded = store.updateStatus(_booking.id, next);
    }

    final latest = store.byId(_booking.id);
    if (succeeded && latest != null) {
      setState(() => _booking = latest);
      widget.onUpdate?.call(latest);
      return _TransitionOutcome(
        succeeded: true,
        message: 'Status updated to ${latest.status.label}',
      );
    }
    return _TransitionOutcome(succeeded: false, message: failureMessage);
  }

  void _showActionSheet() {
    final actions = _availableActions();
    if (actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('This job is in a terminal state - no further actions.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      // PJ1: themed surface so dark mode renders a dark sheet
      backgroundColor: SemanticColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update job status',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pick the next state. This notifies the owner.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              ...actions.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _actionTile(ctx, a),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, _StatusAction a) {
    return InkWell(
      onTap: () {
        Navigator.of(ctx).pop();
        // Declining a Pending request may include an optional reason.
        if (a.next == BookingStatus.declined) {
          RejectReasonSheet.show(
            context,
            onSubmit: (reason) {
              final outcome = _transition(a.next, reason: reason);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    outcome.succeeded
                        ? reason == null
                            ? 'Booking declined (no reason given)'
                            : 'Booking declined: "$reason"'
                        : outcome.message,
                  ),
                  backgroundColor:
                      outcome.succeeded ? a.next.color : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          );
          return;
        }
        if (a.next == BookingStatus.completed &&
            (!_hasBefore ||
                !_hasAfter ||
                _completionRemarksController.text.trim().isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Add before-and-after photos and completion remarks first.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        final outcome = _transition(a.next);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(outcome.message),
            backgroundColor: outcome.succeeded ? a.next.color : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: a.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: a.color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: a.color, borderRadius: BorderRadius.circular(8)),
              child: Icon(a.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  /// Available next states from the authoritative six-state lifecycle.
  List<_StatusAction> _availableActions() {
    switch (_booking.status) {
      case BookingStatus.pending:
        return [
          _StatusAction('Accept job', 'Owner will be notified',
              BookingStatus.accepted, Icons.check, const Color(0xFF10B981)),
          _StatusAction('Decline request', 'Owner can choose another provider',
              BookingStatus.declined, Icons.close, const Color(0xFFEF4444)),
        ];
      case BookingStatus.accepted:
        return [
          _StatusAction(
              'Start job',
              'Changes status to In Progress',
              BookingStatus.inProgress,
              Icons.play_arrow,
              const Color(0xFFF59E0B)),
        ];
      case BookingStatus.inProgress:
        return [
          _StatusAction(
              'Mark complete',
              'Requires photos and completion remarks',
              BookingStatus.completed,
              Icons.task_alt,
              const Color(0xFF10B981)),
        ];
      case BookingStatus.completed:
      case BookingStatus.declined:
      case BookingStatus.cancelled:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _booking.status.color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_booking.property.split(',').first,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              titlePadding:
                  const EdgeInsets.only(left: 56, bottom: 16, right: 16),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _booking.status.color,
                      _booking.status.color.withOpacity(0.7)
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _booking.id.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4),
                              ),
                            ),
                            const Spacer(),
                            StatusChip(status: _booking.status),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'JOB TIMELINE',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRange(),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildServiceCard(),
                  const SizedBox(height: 16),
                  _buildLocationCard(),
                  const SizedBox(height: 16),
                  _buildProofCard(),
                  const SizedBox(height: 16),
                  _buildNotesCard(),
                  const SizedBox(height: 16),
                  _buildChecklistCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _availableActions().isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showActionSheet,
              backgroundColor: _booking.status.color,
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              label: const Text('Update status',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
    );
  }

  Widget _buildServiceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Service', subtitle: 'What was ordered'),
            const SizedBox(height: 12),
            _infoRow(Icons.cleaning_services, 'Type', _booking.serviceType),
            const Divider(height: 24),
            _infoRow(Icons.timer_outlined, 'Duration',
                '${_booking.scheduledEnd.difference(_booking.scheduledStart).inMinutes} min'),
            const Divider(height: 24),
            _infoRow(Icons.payments_outlined, 'Estimated payout',
                'RM ${(_estimatePayout()).toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Location', subtitle: 'Where to go'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8F4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: const Center(
                      child:
                          Icon(Icons.map, size: 32, color: Color(0xFF2E7D32))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _booking.property,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '2.0 km from your location  -  ~8 min drive',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Opening maps - Sprint 1 will integrate Google Maps'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.directions, size: 14),
                            label: const Text('Directions'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Calling owner - Sprint 1 will integrate phone dialer'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.phone, size: 14),
                            label: const Text('Call owner'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              textStyle: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Completion evidence',
              subtitle: 'Both photos and remarks are required',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _photoSlot('Before', _hasBefore)),
                const SizedBox(width: 12),
                Expanded(child: _photoSlot('After', _hasAfter)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _completionRemarksController,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Completion remarks',
                hintText: 'Summarise the completed cleaning work',
                prefixIcon: Icon(Icons.notes),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              _hasBefore &&
                      _hasAfter &&
                      _completionRemarksController.text.trim().isNotEmpty
                  ? 'Completion evidence is ready to submit.'
                  : 'Add both photos and completion remarks before finishing.',
              style: TextStyle(
                fontSize: 12,
                color: (_hasBefore &&
                        _hasAfter &&
                        _completionRemarksController.text.trim().isNotEmpty)
                    ? const Color(0xFF065F46)
                    : const Color(0xFF92400E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoSlot(String label, bool uploaded) {
    final isBefore = label == 'Before';
    final image = isBefore ? _beforeImage : _afterImage;
    return InkWell(
      onTap: () => _handlePhotoTap(isBefore),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: uploaded ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: uploaded ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
            width: uploaded ? 1.5 : 1,
          ),
        ),
        child: uploaded && image != null
            ? _buildPhotoPreview(image, isBefore)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo,
                      size: 28, color: Color(0xFF6B7280)),
                  const SizedBox(height: 6),
                  Text(
                    'Add $label',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to choose photo',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPhotoPreview(XFile image, bool isBefore) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: kIsWeb
              ? Image.network(
                  image.path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPhotoFallback(isBefore),
                )
              : Image.file(
                  File(image.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPhotoFallback(isBefore),
                ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    size: 10, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isBefore ? 'Before photo' : 'After photo',
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => _handlePhotoTap(isBefore),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoFallback(bool isBefore) {
    return Container(
      color: const Color(0xFFECFDF5),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 24, color: Color(0xFF10B981)),
          const SizedBox(height: 4),
          Text(
            isBefore ? 'Before photo' : 'After photo',
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF065F46),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePhotoTap(bool isBefore) async {
    Haptics.light();
    final hasImage = isBefore ? _hasBefore : _hasAfter;
    if (hasImage) {
      final updated = _booking.copyWith(
        clearBeforeImagePath: isBefore,
        clearAfterImagePath: !isBefore,
      );
      AppProviders.of(context).bookingStore.update(updated);
      setState(() {
        _booking = updated;
        if (isBefore) {
          _hasBefore = false;
          _beforeImage = null;
        } else {
          _hasAfter = false;
          _afterImage = null;
        }
      });
      widget.onUpdate?.call(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isBefore ? 'Before' : 'After'} photo removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final source = await _chooseSource();
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (image == null) return;
      // F2: store the path on the booking. On mobile/desktop, the
      // image_picker gives us a temp file path; on web, it gives us a
      // blob URL. Both work with Image.file / Image.network downstream.
      final storedPath = image.path;
      final updated = _booking.copyWith(
        beforeImagePath: isBefore ? storedPath : _booking.beforeImagePath,
        afterImagePath: !isBefore ? storedPath : _booking.afterImagePath,
      );
      AppProviders.of(context).bookingStore.update(updated);
      setState(() {
        _booking = updated;
        if (isBefore) {
          _beforeImage = image;
          _hasBefore = true;
        } else {
          _afterImage = image;
          _hasAfter = true;
        }
      });
      // Persist the path on the booking so the Owner side can show it later.
      widget.onUpdate?.call(updated);
      Haptics.medium();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('${isBefore ? 'Before' : 'After'} photo uploaded'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<ImageSource?> _chooseSource() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      // PJ2: themed surface
      backgroundColor: SemanticColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Color(0xFF2E7D32)),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    if (_booking.specialInstructions == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Owner notes'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote,
                      size: 16, color: Color(0xFF9A3412)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _booking.specialInstructions!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF7C2D12), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistCard() {
    final confirmed = _booking.status == BookingStatus.accepted ||
        _booking.status == BookingStatus.inProgress ||
        _booking.status == BookingStatus.completed;
    final checks = [
      ('Arrive on time', confirmed),
      ('Confirm scope with owner', confirmed),
      ('Before photo captured', _hasBefore),
      ('After photo captured', _hasAfter),
      (
        'Completion remarks added',
        _completionRemarksController.text.trim().isNotEmpty,
      ),
      ('Job complete', _booking.status == BookingStatus.completed),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Job checklist'),
            const SizedBox(height: 12),
            ...checks.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        c.$2
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: c.$2
                            ? const Color(0xFF10B981)
                            : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.$1,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.$2
                                ? const Color(0xFF111827)
                                : const Color(0xFF6B7280),
                            fontWeight:
                                c.$2 ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827)),
        ),
      ],
    );
  }

  String _formatRange() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final s = _booking.scheduledStart;
    final e = _booking.scheduledEnd;
    final fmt = (DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '${s.day} ${months[s.month - 1]}  ${fmt(s)} - ${fmt(e)}';
  }

  double _estimatePayout() {
    final minutes =
        _booking.scheduledEnd.difference(_booking.scheduledStart).inMinutes;
    final hours = minutes / 60.0;
    return 80 * hours; // base rate RM 80/h
  }
}

class _StatusAction {
  const _StatusAction(
      this.label, this.subtitle, this.next, this.icon, this.color);
  final String label;
  final String subtitle;
  final BookingStatus next;
  final IconData icon;
  final Color color;
}

class _TransitionOutcome {
  const _TransitionOutcome({
    required this.succeeded,
    required this.message,
  });

  final bool succeeded;
  final String message;
}
