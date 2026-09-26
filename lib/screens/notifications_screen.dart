// lib/screens/notifications_screen.dart
// Activity feed: shows recent events (booking state changes, new requests,
// payment confirmations, etc). Shared between Owner and Provider roles.
//
// Round 11 polish (NS1-NS6):
//   NS1 Theme colors throughout (sem.* + AppColors.*)
//   NS2 Filter chip uses AppColors.primary for active state
//   NS3 Unread tile bg uses sem.primarySurface / primarySurfaceDark
//   NS4 Unread dot uses AppColors.primary
//   NS5 Notification icons use semantic color tokens (statusInProgress, statusCompleted, etc.)
//   NS6 Time-ago uses sem.textTertiary

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.color,
    this.read = false,
    this.actionable = false,
  });
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final Color color;
  final bool read;
  final bool actionable;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.role = 'Owner'});
  final String role; // 'Owner' or 'Provider'

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<NotificationItem> _items;
  String _filter = 'all'; // all, unread, action

  @override
  void initState() {
    super.initState();
    _items = _seed();
  }

  List<NotificationItem> _seed() {
    final now = DateTime.now();
    if (widget.role == 'Owner') {
      return [
        NotificationItem(
          id: 'n1',
          icon: Icons.notifications_active,
          title: 'New request awaiting your review',
          subtitle: 'Unit C-21 · Routine cleaning · 18 Jul 09:00',
          timestamp: now.subtract(const Duration(minutes: 12)),
          color: AppColors.statusRequested,
          read: false,
          actionable: true,
        ),
        NotificationItem(
          id: 'n2',
          icon: Icons.check_circle,
          title: 'Booking completed',
          subtitle: 'Unit D-03 · Move-in cleaning by Provider C',
          timestamp: now.subtract(const Duration(hours: 2)),
          color: AppColors.statusCompleted,
          read: false,
        ),
        NotificationItem(
          id: 'n3',
          icon: Icons.play_circle,
          title: 'Cleaning started',
          subtitle: 'Provider A started Unit A-12 at 10:00',
          timestamp: now.subtract(const Duration(hours: 3)),
          color: AppColors.statusInProgress,
          read: true,
        ),
        NotificationItem(
          id: 'n4',
          icon: Icons.event_available,
          title: 'Provider confirmed schedule',
          subtitle: 'Provider B confirmed Unit B-08 for 16 Jul 14:00',
          timestamp: now.subtract(const Duration(hours: 5)),
          color: AppColors.statusScheduled,
          read: true,
        ),
        NotificationItem(
          id: 'n5',
          icon: Icons.star,
          title: 'New review from tenant',
          subtitle: 'Unit A-12 rated 4.8 stars after last cleaning',
          timestamp: now.subtract(const Duration(days: 1)),
          color: AppColors.warning,
          read: true,
        ),
        NotificationItem(
          id: 'n6',
          icon: Icons.payment,
          title: 'Payment processed',
          subtitle: 'RM 240 to Provider A for b-001',
          timestamp: now.subtract(const Duration(days: 1, hours: 4)),
          color: AppColors.success,
          read: true,
        ),
        NotificationItem(
          id: 'n7',
          icon: Icons.warning,
          title: 'Provider running late',
          subtitle: 'Provider C delayed on Unit D-03 by 15 min',
          timestamp: now.subtract(const Duration(days: 2)),
          color: AppColors.statusDelayed,
          read: true,
        ),
      ];
    } else {
      // Provider notifications
      return [
        NotificationItem(
          id: 'n1',
          icon: Icons.notifications_active,
          title: 'New job request from Oh Wan Ting',
          subtitle: 'Unit C-21 · Routine cleaning · 18 Jul 09:00',
          timestamp: now.subtract(const Duration(minutes: 12)),
          color: AppColors.primary,
          read: false,
          actionable: true,
        ),
        NotificationItem(
          id: 'n2',
          icon: Icons.attach_money,
          title: 'Earnings paid out',
          subtitle: 'RM 240 deposited to your account',
          timestamp: now.subtract(const Duration(hours: 6)),
          color: AppColors.success,
          read: false,
        ),
        NotificationItem(
          id: 'n3',
          icon: Icons.star,
          title: 'You got a 5-star review',
          subtitle: '"Excellent work, very thorough." · Unit A-12',
          timestamp: now.subtract(const Duration(days: 1)),
          color: AppColors.warning,
          read: true,
        ),
        NotificationItem(
          id: 'n4',
          icon: Icons.cancel,
          title: 'Booking cancelled by owner',
          subtitle: 'Unit E-15 · 19 Jul 10:00 · refunded in full',
          timestamp: now.subtract(const Duration(days: 2)),
          color: AppColors.error,
          read: true,
        ),
      ];
    }
  }

  List<NotificationItem> get _filtered {
    switch (_filter) {
      case 'unread':
        return _items.where((n) => !n.read).toList();
      case 'action':
        return _items.where((n) => n.actionable).toList();
      default:
        return _items;
    }
  }

  void _markAllRead() {
    setState(() {
      _items = _items
          .map((n) => NotificationItem(
                id: n.id,
                icon: n.icon,
                title: n.title,
                subtitle: n.subtitle,
                timestamp: n.timestamp,
                color: n.color,
                read: true,
                actionable: n.actionable,
              ))
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleTap(NotificationItem n) {
    setState(() {
      _items = _items.map((x) {
        if (x.id != n.id) return x;
        return NotificationItem(
          id: x.id,
          icon: x.icon,
          title: x.title,
          subtitle: x.subtitle,
          timestamp: x.timestamp,
          color: x.color,
          read: true,
          actionable: x.actionable,
        );
      }).toList();
    });
    if (n.actionable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening: ${n.title}'),
          backgroundColor: n.color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final unreadCount = _items.where((n) => !n.read).length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: sem.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _filterChip('all', 'All', _items.length, sem),
                const SizedBox(width: 8),
                _filterChip('unread', 'Unread', unreadCount, sem),
                const SizedBox(width: 8),
                _filterChip(
                  'action',
                  'Needs action',
                  _items.where((n) => n.actionable).length,
                  sem,
                ),
              ],
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications',
              subtitle: 'You are all caught up.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 64,
                color: sem.border,
              ),
              itemBuilder: (ctx, i) => _NotificationTile(
                item: _filtered[i],
                isDark: isDark,
                onTap: () => _handleTap(_filtered[i]),
              ),
            ),
    );
  }

  // NS2: themed filter chip
  Widget _filterChip(String id, String label, int count, SemanticColors sem) {
    final active = _filter == id;
    return InkWell(
      onTap: () => setState(() => _filter = id),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : sem.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : sem.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withOpacity(0.2)
                    : sem.borderStrong,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : sem.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });
  final NotificationItem item;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    // NS3: themed unread background (primary surface in both modes)
    final unreadBg = isDark
        ? AppColors.primarySurfaceDark
        : AppColors.primarySurface.withOpacity(0.6);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.read ? sem.surface : unreadBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.read
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: sem.textPrimary,
                          ),
                        ),
                      ),
                      // NS4: themed unread dot
                      if (!item.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: sem.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeAgo(item.timestamp),
                    // NS6: themed time-ago
                    style: TextStyle(fontSize: 11, color: sem.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
