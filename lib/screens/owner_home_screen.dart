// lib/screens/owner_home_screen.dart
// Owner-side shell. Subscribes to BookingStore for real-time updates
// from the provider side. Tabs: Dashboard / Schedule / Properties / Browse / Spend.
//
// Round 9 polish (OH1-OH7):
//   OH1 Theme colors (AppColors.primary + sem.*) instead of hardcoded hex
//   OH2 Dynamic user name from UserSession (no hardcoded "Oh Wan Ting")
//   OH3 Time-based greeting (Good morning / afternoon / evening)
//   OH4 _SummaryHeader uses AppTheme.primaryGradient
//   OH5 Search field uses theme tokens
//   OH6 Filter chip dot uses AppColors.primary
//   OH7 _OwnerProfileScreen: section headers use SectionHeader, theme tiles

import 'package:flutter/material.dart';
import '../main.dart';
import '../models/demo_data.dart';
import '../services/booking_store.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer.dart';
import '../widgets/booking_card.dart';
import '../widgets/coach_mark.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/section_header.dart';
import 'about_screen.dart';
import 'booking_detail_screen.dart';
import 'chat_list_screen.dart';
import 'new_booking_screen.dart';
import 'notifications_screen.dart';
import 'owner_spend_screen.dart';
import 'property_list_screen.dart';
import 'provider_browse_screen.dart';
import 'provider_inbox_screen.dart';
import 'provider_profile_screen.dart';
import 'schedule_screen.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  String _tab = 'home';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  FilterResult _filter = FilterResult.empty;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _switchTab(String id) {
    Haptics.selection();
    setState(() => _tab = id);
  }

  void _onDrawerNav(String routeId) {
    switch (routeId) {
      case 'home': _switchTab('home'); break;
      case 'schedule': _switchTab('schedule'); break;
      case 'properties': _switchTab('properties'); break;
      case 'browse': _switchTab('browse'); break;
      case 'notifications':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const NotificationsScreen(role: 'Owner'),
        ));
        break;
      case 'profile':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _OwnerProfileScreen(onOpenBookings: () => _switchTab('home')),
        ));
        break;
      case 'messages':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen()));
        break;
      case 'spend':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OwnerSpendScreen(bookings: AppProviders.of(context).bookingStore.bookings),
        ));
        break;
      case 'about':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
        break;
      case 'switch-role':
        _openProviderView();
        break;
    }
  }

  void _openNewBooking() async {
    Haptics.light();
    final created = await Navigator.of(context).push<DemoBooking>(
      MaterialPageRoute(builder: (_) => NewBookingScreen()),
    );
    if (created != null && mounted) {
      AppProviders.of(context).bookingStore.add(
        property: created.property,
        serviceType: created.serviceType,
        scheduledStart: created.scheduledStart,
        scheduledEnd: created.scheduledEnd,
        providerName: created.providerName,
        specialInstructions: created.specialInstructions,
      );
      Haptics.medium();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request submitted for ${created.property}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _switchTab('schedule'),
          ),
        ),
      );
    }
  }

  void _openProviderView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderInboxScreen(
          provider: DemoProvider.ranked().first,
        ),
      ),
    );
  }

  void _openFilter() async {
    Haptics.light();
    final store = AppProviders.of(context).bookingStore;
    final all = store.bookings;
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
        final body = _buildBody(ctx, store);
        final withCoach = _tab == 'home'
            ? CoachMarkOverlay(
                setId: 'owner_home_v1',
                marks: const [
                  CoachMark(
                    id: 'hero',
                    icon: Icons.dashboard,
                    title: 'Your dashboard',
                    body: 'At-a-glance stats: total bookings, in-progress, scheduled, and done.',
                    accent: AppColors.primary,
                    alignment: CoachMarkAlignment.topLeft,
                  ),
                  CoachMark(
                    id: 'tabs',
                    icon: Icons.tab,
                    title: '5 quick tabs',
                    body: 'Home / Schedule / Properties / Browse / Spend. Switch anytime.',
                    accent: AppColors.primary,
                    alignment: CoachMarkAlignment.bottomCenter,
                  ),
                  CoachMark(
                    id: 'fab',
                    icon: Icons.add_circle,
                    title: 'New request',
                    body: 'The big + button creates a new cleaning request.',
                    accent: AppColors.primary,
                    alignment: CoachMarkAlignment.bottomRight,
                  ),
                ],
                child: body,
              )
            : body;
        return Scaffold(
          drawer: AppDrawer(role: 'Owner', onNavigate: _onDrawerNav),
          appBar: _buildAppBar(ctx),
          body: withCoach,
          floatingActionButton: _tab == 'home'
              ? FloatingActionButton.extended(
                  heroTag: 'new-request',
                  onPressed: _openNewBooking,
                  icon: const Icon(Icons.add),
                  label: const Text('New request'),
                )
              : null,
          bottomNavigationBar: AppBottomNav(
            activeId: _tab,
            onChange: _switchTab,
            tabs: const [
              NavTab(id: 'home', icon: Icons.dashboard, label: 'Home'),
              NavTab(id: 'schedule', icon: Icons.calendar_today, label: 'Schedule'),
              NavTab(id: 'properties', icon: Icons.apartment, label: 'Properties'),
              NavTab(id: 'browse', icon: Icons.person_search, label: 'Browse'),
              NavTab(id: 'spend', icon: Icons.payments, label: 'Spend'),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    String title;
    switch (_tab) {
      case 'home': title = 'Owner Dashboard'; break;
      case 'schedule': title = 'Schedule'; break;
      case 'properties': title = 'My properties'; break;
      case 'browse': title = 'Browse providers'; break;
      case 'spend': title = 'Spending'; break;
      default: title = 'Owner';
    }
    final isDark = AppProviders.of(context).isDark;
    return AppBar(
      title: Text(title),
      actions: [
        IconButton(
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          onPressed: () => AppProviders.of(context).onToggleTheme(),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
        ),
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen(role: 'Owner')),
          ),
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(BuildContext context, BookingStore store) {
    switch (_tab) {
      case 'home': return _buildHomeTab(context, store);
      case 'schedule': return _embeddedSchedule(store);
      case 'properties': return PropertyListScreen(bookings: store.bookings, embedded: true);
      case 'browse': return _embeddedBrowse();
      case 'spend': return OwnerSpendScreen(bookings: store.bookings);
      default: return _buildHomeTab(context, store);
    }
  }

  Widget _embeddedSchedule(BookingStore store) {
    return ScheduleScreen(bookings: store.bookings, embedded: true);
  }

  Widget _embeddedBrowse() {
    final sem = SemanticColors.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: sem.surfaceAlt,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-matched providers',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sem.textPrimary,
                      ),
                    ),
                    Text(
                      'Ranked by MCDA · ADR-0001',
                      style: TextStyle(fontSize: 11, color: sem.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ProviderBrowseScreen(
            onViewProfile: (p) => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProviderProfileScreen(provider: p)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeTab(BuildContext context, BookingStore store) {
    final sem = SemanticColors.of(context);
    final allBookings = store.bookings;
    final filtered = applyFilter(
      allBookings.where((b) =>
        _searchQuery.isEmpty ||
        b.property.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        b.serviceType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (b.providerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
        b.status.label.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList(),
      _filter,
    );
    return RefreshIndicator(
      onRefresh: () async {
        Haptics.light();
        await Future.delayed(const Duration(milliseconds: 600));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refreshed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryHeader(bookings: allBookings),
          const SizedBox(height: 16),
          // OH5: search + filter with theme tokens
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search bookings...',
                    hintStyle: TextStyle(fontSize: 13, color: sem.textTertiary),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 6),
                      child: Icon(Icons.search, size: 18, color: sem.textSecondary),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close, size: 16, color: sem.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: sem.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
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
              const SizedBox(width: 8),
              // OH6: theme-tinted filter button
              Material(
                color: sem.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: sem.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _openFilter,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.tune, size: 20, color: sem.textSecondary),
                        if (_filter.statusFilter != null || _filter.propertyFilter != null)
                          const Positioned(
                            top: -2,
                            right: -2,
                            child: _FilterDot(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  _searchQuery.isEmpty
                      ? '${filtered.length} booking${filtered.length == 1 ? '' : 's'}'
                      : '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: sem.textPrimary,
                  ),
                ),
              ),
              if (_searchQuery.isEmpty)
                TextButton.icon(
                  onPressed: () => _switchTab('browse'),
                  icon: const Icon(Icons.person_search, size: 18),
                  label: const Text('Browse'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: sem.textTertiary),
                  const SizedBox(height: 8),
                  Text('No matches', style: TextStyle(fontSize: 14, color: sem.textSecondary)),
                ],
              ),
            )
          else
            ...filtered.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookingCard(
                    booking: b,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)),
                    ),
                  ),
                )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Small filled dot used to indicate an active filter is set.
class _FilterDot extends StatelessWidget {
  const _FilterDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ====================================================================
// Gradient hero summary header
// ====================================================================

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.bookings});
  final List<DemoBooking> bookings;

  @override
  Widget build(BuildContext context) {
    // OH2: dynamic user name
    final session = UserSessionAccess.of(context);
    final name = session.displayName.isEmpty ? 'Owner' : session.displayName;
    // OH3: greeting is local to widget (parent already builds greeting string)
    final greeting = _greetingFor(DateTime.now().hour);
    final total = bookings.length;
    final inProgress = bookings.where((b) => b.status == DemoBookingStatus.inProgress).length;
    final scheduled = bookings.where((b) => b.status == DemoBookingStatus.scheduled).length;
    final completed = bookings.where((b) => b.status == DemoBookingStatus.completed).length;
    final requested = bookings.where((b) => b.status == DemoBookingStatus.requested).length;
    return Container(
      decoration: BoxDecoration(
        // OH4: use AppTheme gradient
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
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: const Icon(Icons.apartment, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Owner Module',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _StatCard(label: 'Total', value: '$total'),
                const SizedBox(width: 6),
                _StatCard(
                  label: 'Active',
                  value: '$inProgress',
                  color: AppColors.statusInProgress,
                ),
                const SizedBox(width: 6),
                _StatCard(
                  label: 'Sched.',
                  value: '$scheduled',
                  color: AppColors.statusScheduled,
                ),
                const SizedBox(width: 6),
                _StatCard(
                  label: 'Done',
                  value: '$completed',
                  color: AppColors.statusCompleted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (requested > 0)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_active, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '$requested new request${requested == 1 ? '' : 's'} awaiting your review',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _greetingFor(int h) {
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color ?? Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Owner Profile mini-screen (drawer destination)
// ====================================================================

class _OwnerProfileScreen extends StatelessWidget {
  const _OwnerProfileScreen({required this.onOpenBookings});
  final VoidCallback onOpenBookings;

  @override
  Widget build(BuildContext context) {
    // OH2: dynamic name
    final session = UserSessionAccess.of(context);
    final name = session.displayName.isEmpty ? 'Owner' : session.displayName;
    final initials = _initialsOf(name);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Owner · 5 properties',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Account'),
          _tile(context, Icons.person_outline, 'Edit profile', 'Name, email, phone'),
          _tile(context, Icons.lock_outline, 'Change password', 'Last changed 30 days ago'),
          _tile(context, Icons.verified_user_outlined, 'Verification', 'NRIC verified'),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Preferences'),
          _tile(context, Icons.notifications_outlined, 'Notifications', 'Push, email, SMS'),
          _tile(context, Icons.language, 'Language', 'English (Malaysia)'),
          _tile(context, Icons.dark_mode_outlined, 'Appearance', 'Light mode'),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Properties'),
          _tile(
            context,
            Icons.apartment,
            'Manage properties',
            '5 properties managed',
            onTap: onOpenBookings,
          ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'About'),
          _tile(context, Icons.info_outline, 'App version', 'v0.1.0 · Sprint 0'),
          _tile(context, Icons.description_outlined, 'Terms of service', null),
          _tile(context, Icons.privacy_tip_outlined, 'Privacy policy', null),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'O';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _tile(
    BuildContext ctx,
    IconData icon,
    String title,
    String? subtitle, {
    VoidCallback? onTap,
  }) {
    final sem = SemanticColors.of(ctx);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: sem.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(fontSize: 12, color: sem.textSecondary))
            : null,
        trailing: Icon(Icons.arrow_forward_ios, size: 12, color: sem.textTertiary),
        onTap: onTap ?? () {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('$title · Sprint 1 feature'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}
