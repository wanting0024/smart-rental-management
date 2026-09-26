// lib/screens/property_list_screen.dart
// Owner's property portfolio. Each card shows the unit, size, recent
// booking count, and a quick "schedule" CTA. Tapping a card opens detail.
//
// Round 10 polish (PL1-PL5):
//   PL1 Theme colors (sem.* + AppColors.*) throughout
//   PL2 Summary header uses AppTheme.primaryGradient
//   PL3 Mini stat tiles use AppColors.warning / success / secondary
//   PL4 intl for time formatting ("14:00" via DateFormat)
//   PL5 Active-cleaning banner uses theme warning token

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import 'property_detail_screen.dart';

class PropertyListScreen extends StatelessWidget {
  const PropertyListScreen(
      {super.key, required this.bookings, this.embedded = false});
  final List<DemoBooking> bookings;

  /// When true, skip the inner Scaffold/AppBar so the parent (e.g. owner shell)
  /// can own the AppBar and avoid a duplicate title.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final properties = DemoProperty.all;
    final body = Column(
      children: [
        _buildSummaryHeader(properties.length),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: properties.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => _PropertyCard(
              property: properties[i],
              bookings: _bookingsFor(properties[i], bookings),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PropertyDetailScreen(
                      property: properties[i],
                      bookings: _bookingsFor(properties[i], bookings),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My properties'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add property',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add property form · Sprint 1 feature'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }

  List<DemoBooking> _bookingsFor(DemoProperty p, List<DemoBooking> all) {
    return all.where((b) => b.property == p.display).toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
  }

  // PL2: themed summary header
  Widget _buildSummaryHeader(int count) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.apartment, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Portfolio',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$count properties',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Across 2 towers · 8,710 sqft total',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard(
      {required this.property, required this.bookings, required this.onTap});
  final DemoProperty property;
  final List<DemoBooking> bookings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final upcoming = bookings
        .where((b) =>
            b.status == BookingStatus.accepted ||
            b.status == BookingStatus.pending ||
            b.status == BookingStatus.inProgress)
        .length;
    final done =
        bookings.where((b) => b.status == BookingStatus.completed).length;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.apartment,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.display,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: sem.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${property.bedrooms} bedrooms  ·  ${property.sizeSqft} sqft',
                          style: TextStyle(
                            fontSize: 12,
                            color: sem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: sem.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // PL3: themed mini stats
              Row(
                children: [
                  _miniStat('Upcoming', '$upcoming', AppColors.warning, sem),
                  const SizedBox(width: 8),
                  _miniStat('Done', '$done', AppColors.statusCompleted, sem),
                  const SizedBox(width: 8),
                  _miniStat(
                      'Total', '${bookings.length}', AppColors.secondary, sem),
                ],
              ),
              if (bookings.isEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: sem.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No bookings yet. Schedule a cleaning to get started.',
                        style:
                            TextStyle(fontSize: 12, color: sem.textSecondary),
                      ),
                    ),
                  ],
                ),
              ] else if (bookings.first.status == BookingStatus.inProgress) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // PL5: themed active-cleaning banner
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cleaning in progress · ends ${_formatTime(bookings.first.scheduledEnd)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w500,
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

  Widget _miniStat(
    String label,
    String value,
    Color color,
    SemanticColors sem,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: sem.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PL4: intl time format
  String _formatTime(DateTime d) => DateFormat('HH:mm').format(d);
}
