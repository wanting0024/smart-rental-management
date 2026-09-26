// lib/screens/booking_detail_screen.dart
// Booking detail with FSM-driven status, vertical lifecycle stepper, before/after
// image placeholders, and primary/secondary action groups that follow the same
// transition rules as the FYP BookingStatusX.canTransitionTo.
//
// Round 11 polish (BD1-BD5): touch-up — replace hardcoded colors with theme
// tokens and use intl.DateFormat for date labels (consistency with rest of app).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/demo_data.dart';
import '../services/booking_store.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/cancellation_reason_sheet.dart';
import '../widgets/rating_input.dart';
import '../widgets/status_chip.dart';
import 'chat_screen.dart';
import 'reschedule_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.booking});
  final DemoBooking booking;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late DemoBooking _booking;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  void _openMessage() {
    final session = UserSessionAccess.of(context);
    final me = session.displayName.isEmpty ? 'Oh Wan Ting' : session.displayName;
    final other = _booking.providerName ?? 'Provider A';
    final store = AppProviders.of(context).messageStore;
    final convoId = store.findOrCreate(
      participantA: me,
      participantB: other,
      bookingId: _booking.id,
      property: _booking.property,
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(conversationId: convoId, counterpart: other),
    ));
  }

  Future<void> _showCancelSheet() async {
    Haptics.heavy();
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CancellationReasonSheet(bookingId: _booking.id),
    );
    if (result != null && mounted) {
      final store = AppProviders.of(context).bookingStore;
      store.updateStatus(_booking.id, DemoBookingStatus.cancelled);
      Haptics.heavy();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Booking cancelled'),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () {
                // Round 14 fix: use copyWith to preserve all fields
                // (reason text, proof paths, lifecycle timestamps, etc.)
                final prev = _booking.copyWith(
                  status: DemoBookingStatus.scheduled,
                  cancelledAt: null,
                );
                store.update(prev);
              },
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  String _fmtDate(DateTime d) => DateFormat('MMM d, y').format(d);
  String _fmtTime(DateTime d) => DateFormat('HH:mm').format(d);

  String _fmtRange(DateTime s, DateTime e) =>
      '${_fmtDate(s)}   ${_fmtTime(s)} – ${_fmtTime(e)}';

  String _durationLabel() {
    final mins = _booking.scheduledEnd.difference(_booking.scheduledStart).inMinutes;
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Scaffold(
      backgroundColor: sem.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  switch (value) {
                    case 'reschedule':
                      final updated = await Navigator.of(context).push<DemoBooking>(
                        MaterialPageRoute(builder: (_) => RescheduleScreen(booking: _booking)),
                      );
                      if (updated != null && mounted) {
                        setState(() => _booking = updated);
                        Navigator.of(context).pop(updated);
                      }
                      break;
                    case 'cancel':
                      await _showCancelSheet();
                      break;
                    case 'share':
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Share link copied (demo)'), behavior: SnackBarBehavior.floating),
                      );
                      break;
                    case 'message':
                      _openMessage();
                      break;
                    case 'report':
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report submitted - Sprint 1 will email the team'), behavior: SnackBarBehavior.floating),
                      );
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'reschedule', child: Row(children: [Icon(Icons.schedule, size: 16), SizedBox(width: 8), Text('Reschedule')])),
                  PopupMenuItem(value: 'message', child: Row(children: [Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.primary), SizedBox(width: 8), Text('Message', style: TextStyle(color: AppColors.primary))])),
                  PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share, size: 16), SizedBox(width: 8), Text('Share with tenant')])),
                  PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel_outlined, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Cancel booking', style: TextStyle(color: AppColors.error))])),
                  PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.report_outlined, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Report issue', style: TextStyle(color: AppColors.error))])),
                ],
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: _HeroSection(booking: _booking, fmtRange: _fmtRange),
          ),
          SliverList(
            delegate: SliverChildListDelegate.fixed([
              const SizedBox(height: 16),
              _InfoChipRow(booking: _booking, durationLabel: _durationLabel()),
              const SizedBox(height: 16),
              _ScheduleCard(booking: _booking, fmtRange: _fmtRange),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'Service lifecycle'),
              const SizedBox(height: 8),
              _LifecycleStepper(booking: _booking),
              const SizedBox(height: 16),
              const _SectionHeader(title: 'Proof of completion'),
              const SizedBox(height: 8),
              _ProofOfCompletionRow(status: _booking.status),
              if (_booking.status == DemoBookingStatus.completed) ...[
                const SizedBox(height: 16),
                const _SectionHeader(title: 'Your rating'),
                const SizedBox(height: 8),
                _OwnerRatingCard(booking: _booking, onChanged: (r, c) {
                  AppProviders.of(context).bookingStore.rateCompleted(
                    _booking.id,
                    rating: r,
                    comment: c,
                  );
                  setState(() {
                    _booking = _booking.copyWith(
                      ownerRating: r,
                      ownerRatingComment: c,
                    );
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Rating submitted'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              const _SectionHeader(title: 'Available actions'),
              const SizedBox(height: 8),
              _AvailableActions(booking: _booking),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Hero section inside the SliverAppBar
// ====================================================================

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.booking,
    required this.fmtRange,
  });
  final DemoBooking booking;
  final String Function(DateTime, DateTime) fmtRange;

  static const _gradientTop = AppColors.primary;
  static const _gradientBottom = AppColors.primaryLight;

  @override
  Widget build(BuildContext context) {
    return FlexibleSpaceBar(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientTop, _gradientBottom],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.id.toUpperCase(),
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.property,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.serviceType,
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fmtRange(booking.scheduledStart, booking.scheduledEnd),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================

class _InfoChipRow extends StatelessWidget {
  const _InfoChipRow({required this.booking, required this.durationLabel});
  final DemoBooking booking;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _InfoChip(
              icon: Icons.tag,
              label: 'Booking',
              value: booking.id.toUpperCase(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _InfoChip(
              icon: Icons.schedule,
              label: 'Duration',
              value: durationLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: sem.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sem.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: sem.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: sem.textTertiary, letterSpacing: 0.5),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sem.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Schedule card (date/time + provider + special instructions)
// ====================================================================

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.booking, required this.fmtRange});
  final DemoBooking booking;
  final String Function(DateTime, DateTime) fmtRange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.event,
                label: 'Date & time',
                value: fmtRange(booking.scheduledStart, booking.scheduledEnd),
              ),
              const Divider(height: 24),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Provider',
                value: booking.providerName ?? 'Awaiting provider assignment',
                valueColor: booking.providerName == null
                    ? SemanticColors.lightTokens.textTertiary
                    : SemanticColors.lightTokens.textPrimary,
                valueItalic: booking.providerName == null,
              ),
              if (booking.specialInstructions != null) ...[
                const Divider(height: 24),
                _SpecialInstructionsBlock(text: booking.specialInstructions!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueItalic = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueItalic;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: sem.textTertiary, letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? sem.textPrimary,
                  fontStyle: valueItalic ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpecialInstructionsBlock extends StatelessWidget {
  const _SpecialInstructionsBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                'Special instructions',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.4)),
        ],
      ),
    );
  }
}

// ====================================================================
// Section header
// ====================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 1.0,
          ),
        ),
      );
}

// ====================================================================
// Vertical lifecycle stepper
// ====================================================================

class _LifecycleStepper extends StatelessWidget {
  const _LifecycleStepper({required this.booking});
  final DemoBooking booking;

  static const _steps = <(String, DemoBookingStatus, IconData)>[
    ('Requested', DemoBookingStatus.requested, Icons.assignment_outlined),
    ('Accepted', DemoBookingStatus.accepted, Icons.thumb_up_alt_outlined),
    ('Scheduled', DemoBookingStatus.scheduled, Icons.event_outlined),
    ('In Progress', DemoBookingStatus.inProgress, Icons.play_circle_outline),
    ('Completed', DemoBookingStatus.completed, Icons.check_circle_outline),
  ];

  int _indexOf(DemoBookingStatus s) {
    for (var i = 0; i < _steps.length; i++) {
      if (_steps[i].$2 == s) return i;
    }
    return 3;
  }

  _StepState _stepState(int i, int currentIdx, bool isDelayed) {
    if (i < currentIdx) return _StepState.completed;
    if (i == currentIdx) {
      if (isDelayed) return _StepState.delayed;
      return _StepState.active;
    }
    return _StepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _indexOf(booking.status);
    final isTerminal = booking.status == DemoBookingStatus.cancelled ||
        booking.status == DemoBookingStatus.completed;
    final isDelayed = booking.status == DemoBookingStatus.delayed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              for (var i = 0; i < _steps.length; i++) ...[
                _StepRow(
                  icon: _steps[i].$3,
                  label: _steps[i].$1,
                  state: _stepState(i, currentIdx, isDelayed),
                ),
                if (i < _steps.length - 1)
                  _StepConnector(
                    reached: i < currentIdx,
                    interrupted: isDelayed && i == currentIdx,
                  ),
              ],
              if (isTerminal || isDelayed) _TerminalBanner(status: booking.status),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StepState { pending, active, completed, delayed }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.icon, required this.label, required this.state});
  final IconData icon;
  final String label;
  final _StepState state;

  Color get _color {
    switch (state) {
      case _StepState.completed: return const Color(0xFF10B981);
      case _StepState.active: return const Color(0xFF2E7D32);
      case _StepState.delayed: return const Color(0xFFEF4444);
      case _StepState.pending: return const Color(0xFFD1D5DB);
    }
  }

  String get _subtitle {
    switch (state) {
      case _StepState.completed: return 'Completed';
      case _StepState.active: return 'Current';
      case _StepState.delayed: return 'Delayed';
      case _StepState.pending: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _color.withOpacity(state == _StepState.pending ? 0.15 : 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: _color, width: 2),
          ),
          child: state == _StepState.completed
              ? Icon(Icons.check, size: 18, color: _color)
              : Icon(icon, size: 16, color: _color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: state == _StepState.active ? FontWeight.w700 : FontWeight.w600,
                  color: state == _StepState.pending ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: _color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (state == _StepState.active)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.reached, required this.interrupted});
  final bool reached;
  final bool interrupted;

  @override
  Widget build(BuildContext context) {
    final color = interrupted
        ? const Color(0xFFFCA5A5)
        : (reached ? const Color(0xFF10B981) : const Color(0xFFE5E7EB));
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: Container(
        width: 2,
        height: 18,
        color: color,
      ),
    );
  }
}

class _TerminalBanner extends StatelessWidget {
  const _TerminalBanner({required this.status});
  final DemoBookingStatus status;

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == DemoBookingStatus.cancelled;
    final color = isCancelled ? const Color(0xFF991B1B) : const Color(0xFF047857);
    final bg = isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5);
    final icon = isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline;
    final text = isCancelled
        ? 'This booking was cancelled. Lifecycle ended at the Scheduled step.'
        : 'Cleaning completed. You can review the proof of completion below.';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Proof of completion row (before / after with dashed border)
// ====================================================================

class _ProofOfCompletionRow extends StatelessWidget {
  const _ProofOfCompletionRow({required this.status});
  final DemoBookingStatus status;

  @override
  Widget build(BuildContext context) {
    final completed = status == DemoBookingStatus.completed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _ProofCard(
              label: 'Before',
              caption: 'Pre-cleaning photo',
              icon: Icons.image_outlined,
              hasImage: completed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ProofCard(
              label: 'After',
              caption: completed ? 'Photo uploaded' : 'Awaiting upload',
              icon: completed ? Icons.check_circle_outline : Icons.image_outlined,
              hasImage: completed,
              highlight: completed,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofCard extends StatelessWidget {
  const _ProofCard({
    required this.label,
    required this.caption,
    required this.icon,
    required this.hasImage,
    this.highlight = false,
  });
  final String label;
  final String caption;
  final IconData icon;
  final bool hasImage;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? const Color(0xFF10B981) : const Color(0xFF9CA3AF);
    final borderColor = highlight ? const Color(0xFF10B981) : const Color(0xFFD1D5DB);
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: hasImage ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: hasImage ? 1.5 : 1.2, style: BorderStyle.solid),
      ),
      child: hasImage
          ? Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: highlight
                              ? [const Color(0xFFA7F3D0), const Color(0xFFD1FAE5)]
                              : [const Color(0xFFE0E7FF), const Color(0xFFF3F4F6)],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 18, left: 18,
                            child: Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), shape: BoxShape.circle)),
                          ),
                          Positioned(
                            bottom: 20, right: 16,
                            child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), shape: BoxShape.circle)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 10, bottom: 8,
                  child: _ProofLabel(label: label, caption: caption, color: color),
                ),
              ],
            )
          : CustomPaint(
              painter: _DashedBorderPainter(color: borderColor),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28, color: color),
                  const SizedBox(height: 6),
                  _ProofLabel(label: label, caption: caption, color: color),
                ],
              ),
            ),
    );
  }
}

class _ProofLabel extends StatelessWidget {
  const _ProofLabel({required this.label, required this.caption, required this.color});
  final String label;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
        Text(
          caption,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path();
    double x = 0;
    while (x < size.width) {
      path.moveTo(x, 0);
      path.lineTo(x + dashWidth, 0);
      x += dashWidth + dashSpace;
    }
    double y = 0;
    while (y < size.height) {
      path.moveTo(size.width, y);
      path.lineTo(size.width, y + dashWidth);
      y += dashWidth + dashSpace;
    }
    x = 0;
    while (x < size.width) {
      path.moveTo(x, size.height);
      path.lineTo(x + dashWidth, size.height);
      x += dashWidth + dashSpace;
    }
    y = 0;
    while (y < size.height) {
      path.moveTo(0, y);
      path.lineTo(0, y + dashWidth);
      y += dashWidth + dashSpace;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}

// ====================================================================
// Available actions (primary / secondary grouping)
// ====================================================================

class _AvailableActions extends StatelessWidget {
  const _AvailableActions({required this.booking});
  final DemoBooking booking;

  @override
  Widget build(BuildContext context) {
    final primary = _primaryAction();
    final secondary = _secondaryActions();
    if (primary == null && secondary.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          color: const Color(0xFFF3F4F6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: const [
                Icon(Icons.lock_outline, size: 18, color: Color(0xFF6B7280)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This booking is in a terminal state. No further actions allowed.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (primary != null) ...[
                FilledButton.icon(
                  onPressed: () => _showSnack(context, '${primary.$1} (FSM action)'),
                  icon: Icon(primary.$2, size: 18),
                  label: Text(primary.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary.$3,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (secondary.isNotEmpty) const SizedBox(height: 10),
              ],
              for (var i = 0; i < secondary.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _secondaryButton(context, secondary[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(BuildContext context, (String, IconData, Color) a) {
    return OutlinedButton.icon(
      onPressed: () => _showSnack(context, '${a.$1} (FSM action)'),
      icon: Icon(a.$2, size: 18),
      label: Text(a.$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: a.$3,
        side: BorderSide(color: a.$3.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  (String, IconData, Color)? _primaryAction() {
    switch (booking.status) {
      case DemoBookingStatus.requested:
        return ('Accept booking', Icons.check_circle, const Color(0xFF2E7D32));
      case DemoBookingStatus.accepted:
        return ('Confirm schedule', Icons.event_available, const Color(0xFF2E7D32));
      case DemoBookingStatus.scheduled:
        return ('Start job', Icons.play_arrow, const Color(0xFFF59E0B));
      case DemoBookingStatus.rescheduled:
        return ('Confirm new time', Icons.event_repeat, const Color(0xFF8E24AA));
      case DemoBookingStatus.inProgress:
        return ('Mark complete', Icons.task_alt, const Color(0xFF10B981));
      case DemoBookingStatus.delayed:
        return ('Resume job', Icons.play_arrow, const Color(0xFF2E7D32));
      case DemoBookingStatus.completed:
      case DemoBookingStatus.rejected:
      case DemoBookingStatus.cancelled:
        return null;
    }
  }

  List<(String, IconData, Color)> _secondaryActions() {
    final out = <(String, IconData, Color)>[];
    if (booking.status == DemoBookingStatus.scheduled) {
      out.add(('Mark delayed', Icons.schedule, const Color(0xFFEF4444)));
    }
    if (booking.status == DemoBookingStatus.inProgress) {
      out.add(('Mark delayed', Icons.schedule, const Color(0xFFEF4444)));
    }
    if (booking.status != DemoBookingStatus.completed &&
        booking.status != DemoBookingStatus.cancelled) {
      out.add(('Cancel booking', Icons.close, const Color(0xFFEF4444)));
    }
    return out;
  }

  void _showSnack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Card shown on the booking detail when status is completed. Lets the
/// owner submit or update their 1-5 star rating (Section 2.4.8) along with
/// an optional comment.
class _OwnerRatingCard extends StatefulWidget {
  const _OwnerRatingCard({required this.booking, required this.onChanged});
  final DemoBooking booking;
  final void Function(int rating, String? comment) onChanged;

  @override
  State<_OwnerRatingCard> createState() => _OwnerRatingCardState();
}

class _OwnerRatingCardState extends State<_OwnerRatingCard> {
  late int _rating;
  late TextEditingController _comment;

  @override
  void initState() {
    super.initState();
    _rating = widget.booking.ownerRating ?? 0;
    _comment = TextEditingController(
      text: widget.booking.ownerRatingComment ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _OwnerRatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.booking.ownerRating != null &&
        widget.booking.ownerRating != _rating) {
      _rating = widget.booking.ownerRating!;
    }
    if (widget.booking.ownerRatingComment != null &&
        widget.booking.ownerRatingComment != _comment.text) {
      _comment.text = widget.booking.ownerRatingComment!;
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alreadyRated = widget.booking.ownerRating != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alreadyRated
                    ? 'Your rating is recorded'
                    : 'How was the cleaning?',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (alreadyRated)
                RatingDisplay(
                  rating: widget.booking.ownerRating!,
                  comment: widget.booking.ownerRatingComment,
                )
              else
                RatingInput(
                  initialRating: _rating,
                  initialComment: _comment.text,
                  onSubmit: (r, c) => widget.onChanged(r, c),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
