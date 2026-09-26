// lib/screens/property_detail_screen.dart
// Single property's page: unit info, upcoming + past bookings,
// quick actions (schedule cleaning, view history).
//
// Round 10 polish (PD1-PD5):
//   PD1 Theme colors (sem.* + AppColors.*) throughout
//   PD2 Header uses AppTheme.primaryGradient (instead of hardcoded hex)
//   PD3 intl.DateFormat for date display
//   PD4 Sticky "Schedule new cleaning" button in bottomNavigationBar
//   PD5 AppColors.success for success snackbar

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/booking_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
import 'booking_detail_screen.dart';
import 'new_booking_screen.dart';

class PropertyDetailScreen extends StatelessWidget {
  const PropertyDetailScreen({super.key, required this.property, required this.bookings});
  final DemoProperty property;
  final List<DemoBooking> bookings;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final upcoming = bookings.where((b) =>
        b.status == DemoBookingStatus.requested ||
        b.status == DemoBookingStatus.accepted ||
        b.status == DemoBookingStatus.scheduled ||
        b.status == DemoBookingStatus.inProgress ||
        b.status == DemoBookingStatus.delayed).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    final past = bookings.where((b) =>
        b.status == DemoBookingStatus.completed ||
        b.status == DemoBookingStatus.cancelled).toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));

    return Scaffold(
      appBar: AppBar(
        title: Text(property.display),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: sem.textSecondary),
            tooltip: 'Edit property',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit property · Sprint 1 feature'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          const SectionHeader(
            title: 'Upcoming bookings',
            subtitle: 'Scheduled, requested, or in progress',
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            const EmptyState(
              icon: Icons.event_available,
              title: 'No upcoming cleanings',
              subtitle: 'Use the button below to schedule a cleaning.',
            )
          else
            ...upcoming.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookingCard(
                    booking: b,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookingDetailScreen(booking: b),
                      ),
                    ),
                  ),
                )),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Booking history'),
          const SizedBox(height: 8),
          if (past.isEmpty)
            const EmptyState(
              icon: Icons.history,
              title: 'No past bookings',
              subtitle: 'Completed or cancelled jobs will appear here.',
            )
          else
            ...past.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: b.status.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.history,
                          size: 18,
                          color: b.status.color,
                        ),
                      ),
                      // PD3: intl date format
                      title: Text(
                        b.serviceType,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: sem.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('d MMM y').format(b.scheduledStart),
                        style: TextStyle(
                          fontSize: 12,
                          color: sem.textSecondary,
                        ),
                      ),
                      trailing: StatusChip(status: b.status),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookingDetailScreen(booking: b),
                        ),
                      ),
                    ),
                  ),
                )),
          const SizedBox(height: 24),
        ],
      ),
      // PD4: sticky CTA
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: sem.surface,
            border: Border(top: BorderSide(color: sem.border)),
          ),
          child: FilledButton.icon(
            onPressed: () async {
              final created = await Navigator.of(context).push<DemoBooking>(
                MaterialPageRoute(builder: (_) => const NewBookingScreen()),
              );
              if (created != null && context.mounted) {
                // PD5: themed success color
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Request submitted for ${created.property}'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Schedule new cleaning'),
          ),
        ),
      ),
    );
  }

  // PD2: themed gradient
  Widget _buildHeader() {
    return Container(
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
                width: 48,
                height: 48,
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
                    Text(
                      property.display,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${property.tower}  ·  ${property.bedrooms} bedrooms  ·  ${property.sizeSqft} sqft',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statBlock('Total bookings', '${bookings.length}'),
              const SizedBox(width: 8),
              _statBlock(
                'Last cleaned',
                bookings.isEmpty
                    ? '-'
                    : DateFormat('d MMM y').format(bookings.first.scheduledStart),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBlock(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
