// lib/screens/provider_inbox_screen.dart
// Provider-side job inbox. Subscribes to BookingStore so it sees owner-side
// changes in real time. Tabs + earnings hero + accept/decline quick actions.
//
// Round 10 polish (PI1-PI6):
//   PI1 TabBar uses AppColors.primary for label + indicator
//   PI2 Search field themed (sem.surface bg, sem.textSecondary icon)
//   PI3 Earnings summary uses AppTheme.primaryGradient
//   PI4 AppColors.success / AppColors.error for accept/decline snackbars
//   PI5 Notification dot uses AppColors.error
//   PI6 _EarningsStat highlight uses sem.textPrimary + primary text color

import 'package:flutter/material.dart';
import '../main.dart';
import '../models/demo_data.dart';
import '../services/booking_store.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer.dart';
import '../widgets/coach_mark.dart';
import '../widgets/empty_state.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/status_chip.dart';
import 'about_screen.dart';
import 'earnings_history_screen.dart';
import 'chat_list_screen.dart';
import 'notifications_screen.dart';
import 'provider_edit_profile_screen.dart';
import 'provider_job_detail_screen.dart';
import 'provider_profile_screen.dart';
import 'provider_schedule_screen.dart';
import 'provider_stats_screen.dart';

class ProviderInboxScreen extends StatefulWidget {
  const ProviderInboxScreen({super.key, this.provider, this.showShell = true});
  final DemoProvider? provider;
  final bool showShell;

  @override
  State<ProviderInboxScreen> createState() => _ProviderInboxScreenState();
}

class _ProviderInboxScreenState extends State<ProviderInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _navTab = 'inbox';
  FilterResult _filter = FilterResult.empty;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DemoBooking> _filterBookings(List<DemoBooking> source, _InboxTab tab) {
    var out = source;
    if (tab == _InboxTab.newRequests) {
      out = out.where((b) => b.status == BookingStatus.pending).toList();
    } else if (tab == _InboxTab.active) {
      out = out
          .where((b) =>
              b.status == BookingStatus.accepted ||
              b.status == BookingStatus.inProgress)
          .toList();
    } else if (tab == _InboxTab.completed) {
      out = out.where((b) => b.status == BookingStatus.completed).toList();
    }
    out = applyFilter(out, _filter);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      out = out
          .where((b) =>
              b.property.toLowerCase().contains(q) ||
              b.serviceType.toLowerCase().contains(q))
          .toList();
    }
    return out;
  }

  // PI4: themed success snackbar
  void _accept(DemoBooking b, BookingStore store) {
    Haptics.medium();
    final result = store.acceptPending(b.id);
    if (result.accepted) {
      final acceptedBooking = store.byId(b.id) ?? b;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accepted ${b.property}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _openDetail(acceptedBooking),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // PI4: themed error snackbar
  void _decline(DemoBooking b, BookingStore store) {
    Haptics.heavy();
    final ok = store.declineBooking(b.id);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Declined ${b.property}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDetail(DemoBooking b) {
    final current = AppProviders.of(context).bookingStore.byId(b.id) ?? b;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderJobDetailScreen(
          booking: current,
          provider: widget.provider,
        ),
      ),
    );
  }

  Future<void> _onDrawerNav(String id) async {
    switch (id) {
      case 'inbox':
        setState(() => _navTab = 'inbox');
        break;
      case 'schedule':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProviderScheduleScreen(
            providerName: widget.provider?.name ?? 'Provider A',
            bookings: AppProviders.of(context).bookingStore.bookings,
          ),
        ));
        break;
      case 'earnings':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EarningsHistoryScreen(
            providerName: widget.provider?.name ?? 'Provider A',
            bookings: AppProviders.of(context).bookingStore.bookings,
          ),
        ));
        break;
      case 'profile':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProviderProfileScreen(
            provider: widget.provider ?? DemoProvider.seeded().first,
          ),
        ));
        break;
      case 'messages':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ChatListScreen()));
        break;
      case 'stats':
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProviderStatsScreen()));
        break;
      case 'about':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AboutScreen()));
        break;
      case 'edit_profile':
        final current =
            AppProviders.of(context).providerStore.currentProvider ??
                DemoProvider.seeded().first;
        final updated = await Navigator.of(context).push<DemoProvider>(
          MaterialPageRoute(
              builder: (_) => ProviderEditProfileScreen(provider: current)),
        );
        if (updated != null) {
          setState(() {});
        }
        break;
      case 'notifications':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const NotificationsScreen(role: 'Provider'),
        ));
        break;
    }
  }

  void _openFilter() async {
    Haptics.light();
    final all = AppProviders.of(context).bookingStore.bookings;
    final properties = all.map((b) => b.property).toSet().toList()..sort();
    final result = await showModalBottomSheet<FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FilterSheet(initial: _filter, properties: properties),
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppProviders.of(context).bookingStore;
    return AnimatedBuilder(
      animation: store,
      builder: (ctx, _) {
        if (!widget.showShell) {
          return _buildContent(ctx, store);
        }
        return Scaffold(
          drawer: AppDrawer(role: 'Provider', onNavigate: _onDrawerNav),
          appBar: _buildAppBar(ctx),
          body: CoachMarkOverlay(
            setId: 'provider_inbox_v1',
            marks: const [
              CoachMark(
                id: 'earnings',
                icon: Icons.account_balance_wallet,
                title: 'Your earnings at a glance',
                body:
                    "See this week's earnings, upcoming jobs, and incoming requests — all in one card.",
                accent: AppColors.primary,
                alignment: CoachMarkAlignment.topLeft,
              ),
              CoachMark(
                id: 'tabs',
                icon: Icons.tab,
                title: '4 quick tabs',
                body:
                    'Inbox / Schedule / Earnings / Profile. Tap a tab to navigate.',
                accent: AppColors.primary,
                alignment: CoachMarkAlignment.bottomCenter,
              ),
              CoachMark(
                id: 'accept',
                icon: Icons.check_circle,
                title: 'Accept in one tap',
                body:
                    'New job requests show here. Tap Accept (green) to confirm, or Decline (red) to pass.',
                accent: AppColors.primary,
                alignment: CoachMarkAlignment.topRight,
              ),
            ],
            child: _buildContent(ctx, store),
          ),
          bottomNavigationBar: AppBottomNav(
            activeId: _navTab,
            onChange: (id) {
              Haptics.selection();
              setState(() => _navTab = id);
              if (id == 'inbox') setState(() {});
              if (id == 'earnings') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EarningsHistoryScreen(
                    providerName: widget.provider?.name ?? 'Provider A',
                    bookings: store.bookings,
                  ),
                ));
              }
              if (id == 'profile') {
                final current =
                    AppProviders.of(context).providerStore.currentProvider ??
                        DemoProvider.seeded().first;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProviderEditProfileScreen(provider: current),
                ));
              }
            },
            tabs: const [
              NavTab(id: 'inbox', icon: Icons.inbox, label: 'Inbox'),
              NavTab(
                  id: 'schedule',
                  icon: Icons.calendar_today,
                  label: 'Schedule'),
              NavTab(id: 'earnings', icon: Icons.payments, label: 'Earnings'),
              NavTab(id: 'profile', icon: Icons.person, label: 'Profile'),
            ],
          ),
        );
      },
    );
  }

  // PI1: themed TabBar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Provider Inbox'),
      actions: [
        Builder(builder: (ctx) {
          final isDark2 = AppProviders.of(ctx).isDark;
          return IconButton(
            icon: Icon(
                isDark2 ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => AppProviders.of(ctx).onToggleTheme(),
            tooltip: isDark2 ? 'Switch to light mode' : 'Switch to dark mode',
          );
        }),
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              // PI5: themed notification dot
              const Positioned(
                top: -2,
                right: -2,
                child: _NotificationDot(),
              ),
            ],
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const NotificationsScreen(role: 'Provider')),
          ),
          tooltip: 'Notifications',
        ),
        IconButton(
          icon: const Icon(Icons.tune),
          onPressed: _openFilter,
          tooltip: 'Filter & sort',
        ),
        const SizedBox(width: 8),
      ],
      bottom: TabBar(
        controller: _tab,
        isScrollable: false,
        labelColor: AppColors.primary,
        unselectedLabelColor: SemanticColors.of(context).textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(
              text:
                  'New (${_filterBookings(storeForCount(context), _InboxTab.newRequests).length})'),
          Tab(
              text:
                  'Active (${_filterBookings(storeForCount(context), _InboxTab.active).length})'),
          Tab(
              text:
                  'Done (${_filterBookings(storeForCount(context), _InboxTab.completed).length})'),
          const Tab(text: 'All'),
        ],
      ),
    );
  }

  List<DemoBooking> storeForCount(BuildContext context) =>
      AppProviders.of(context).bookingStore.bookings;

  Widget _buildContent(BuildContext context, BookingStore store) {
    final sem = SemanticColors.of(context);
    return Column(
      children: [
        _buildEarningsSummary(context, store),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          // PI2: themed search field
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by property or service...',
              hintStyle: TextStyle(fontSize: 13, color: sem.textTertiary),
              prefixIcon:
                  Icon(Icons.search, size: 20, color: sem.textSecondary),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon:
                          Icon(Icons.close, size: 18, color: sem.textSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
              filled: true,
              fillColor: sem.surface,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildList(context, store, _InboxTab.newRequests),
              _buildList(context, store, _InboxTab.active),
              _buildList(context, store, _InboxTab.completed),
              _buildList(context, store, _InboxTab.all),
            ],
          ),
        ),
      ],
    );
  }

  // PI3: themed earnings summary
  Widget _buildEarningsSummary(BuildContext context, BookingStore store) {
    final all = store.bookings.where(
        (b) => b.providerName == (widget.provider?.name ?? 'Provider A'));
    final completed =
        all.where((b) => b.status == BookingStatus.completed).length;
    final upcoming = all
        .where((b) =>
            b.status == BookingStatus.accepted ||
            b.status == BookingStatus.inProgress)
        .length;
    final newReq = all.where((b) => b.status == BookingStatus.pending).length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.work_outline,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.provider?.name ?? 'Provider A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Cleaning Service Provider',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Online',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _EarningsStat(
                    label: 'This week',
                    value: 'RM 540',
                    sub: '$completed done'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _EarningsStat(
                    label: 'Upcoming', value: '$upcoming', sub: 'jobs'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _EarningsStat(
                  label: 'New',
                  value: '$newReq',
                  sub: 'requests',
                  highlight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, BookingStore store, _InboxTab tab) {
    final items = _filterBookings(store.bookings, tab);
    if (items.isEmpty) {
      return EmptyState(
        icon: tab == _InboxTab.newRequests
            ? Icons.inbox
            : tab == _InboxTab.completed
                ? Icons.task_alt
                : Icons.work_outline,
        title: _emptyTitle(tab),
        subtitle: _emptySubtitle(tab),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final b = items[i];
        return _ProviderJobCard(
          booking: b,
          onTap: () => _openDetail(b),
          onAccept: () => _accept(b, store),
          onDecline: () => _decline(b, store),
        );
      },
    );
  }

  String _emptyTitle(_InboxTab tab) {
    switch (tab) {
      case _InboxTab.newRequests:
        return 'No new requests';
      case _InboxTab.active:
        return 'No active jobs';
      case _InboxTab.completed:
        return 'No completed jobs yet';
      case _InboxTab.all:
        return 'No jobs at all';
    }
  }

  String _emptySubtitle(_InboxTab tab) {
    switch (tab) {
      case _InboxTab.newRequests:
        return "We'll ping you when an owner routes a request to you.";
      case _InboxTab.active:
        return 'Accept a request or wait for one to be assigned.';
      case _InboxTab.completed:
        return 'Completed jobs will appear here for your records.';
      case _InboxTab.all:
        return 'Pull to refresh or check your notifications.';
    }
  }
}

enum _InboxTab { newRequests, active, completed, all }

class _NotificationDot extends StatelessWidget {
  const _NotificationDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

// PI6: themed highlight state
class _EarningsStat extends StatelessWidget {
  const _EarningsStat(
      {required this.label,
      required this.value,
      required this.sub,
      this.highlight = false});
  final String label;
  final String value;
  final String sub;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? Colors.white : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: highlight ? sem.textSecondary : Colors.white70,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.primary : Colors.white,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              color: highlight ? sem.textSecondary : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderJobCard extends StatelessWidget {
  const _ProviderJobCard({
    required this.booking,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
  });
  final DemoBooking booking;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final canRespond = booking.status == BookingStatus.pending;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: booking.status.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.cleaning_services,
                      size: 18,
                      color: booking.status.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.property,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: sem.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${booking.serviceType}  ·  ${_formatTime(booking.scheduledStart)}',
                          style:
                              TextStyle(fontSize: 12, color: sem.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: booking.status),
                ],
              ),
              if (booking.specialInstructions != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sem.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notes, size: 14, color: sem.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.specialInstructions!,
                          style: TextStyle(
                              fontSize: 12,
                              color: sem.textPrimary,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (canRespond) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDecline,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Accept'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
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

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
