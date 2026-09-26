// lib/screens/provider_browse_screen.dart
// Provider Browse screen. Mirrors the tutor example table
// (Provider A full match, Provider B full match, Provider C partial match).
// Scores are precomputed using the same availability/distance/rating/workload
// weights documented in ADR-0003 in the FYP project.
//
// Round 9 polish (PB1-PB6):
//   PB1 Sort selector (Score / Distance / Rating / Price) — default Score
//   PB2 Service-type filter chip row (All / Standard / Deep / Window / etc.)
//   PB3 Theme colors throughout (sem.* + AppColors.*)
//   PB4 Empty state when filtered list is empty
//   PB5 Better header with legend chip showing MCDA weights
//   PB6 SectionHeader widget for consistency

import 'package:flutter/material.dart';
import '../models/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/provider_card.dart';

/// Sort mode for the provider list.
enum _ProviderSort {
  score('Best match'),
  distance('Nearest'),
  rating('Top rated'),
  price('Lowest price');

  const _ProviderSort(this.label);
  final String label;
}

class ProviderBrowseScreen extends StatefulWidget {
  const ProviderBrowseScreen({super.key, this.onViewProfile, this.onAssign});
  final void Function(DemoProvider)? onViewProfile;
  final void Function(DemoProvider)? onAssign;

  @override
  State<ProviderBrowseScreen> createState() => _ProviderBrowseScreenState();
}

class _ProviderBrowseScreenState extends State<ProviderBrowseScreen> {
  _ProviderSort _sort = _ProviderSort.score;
  String? _serviceType; // null = all

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final providers = DemoProvider.ranked();

    // Apply service-type filter, then sort.
    final filtered = (_serviceType == null
            ? providers.toList()
            : providers.where((p) => p.serviceTypes.contains(_serviceType)).toList())
        .cast<DemoProvider>();

    final sorted = [...filtered];
    switch (_sort) {
      case _ProviderSort.score:
        sorted.sort((a, b) => b.score.compareTo(a.score));
        break;
      case _ProviderSort.distance:
        sorted.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case _ProviderSort.rating:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _ProviderSort.price:
        sorted.sort((a, b) => a.hourlyRate.compareTo(b.hourlyRate));
        break;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // PB5: Better header with MCDA legend chip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommended for your request',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: sem.textPrimary,
                          ),
                        ),
                        Text(
                          'Unit A-12 · Mon 14 Jul 10:00–12:00 · standard cleaning',
                          style: TextStyle(fontSize: 11, color: sem.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 12, color: AppColors.primaryDark),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'MCDA · availability 0.35 · distance 0.20 · rating 0.25 · workload 0.20',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // PB2: Service-type filter chip row
        _buildServiceTypeFilter(sem),
        const SizedBox(height: 12),
        // PB1: Sort selector
        _buildSortBar(sem, sorted.length),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const EmptyState(
            icon: Icons.person_search_outlined,
            title: 'No providers match',
            subtitle: 'Try a different service type or sort option.',
          )
        else
          for (var i = 0; i < sorted.length; i++) ...[
            ProviderCard(
              provider: sorted[i],
              rank: i + 1,
              onViewProfile: () => _handleViewProfile(context, sorted[i]),
              onAssign: () => _handleAssign(context, sorted[i]),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildServiceTypeFilter(SemanticColors sem) {
    // Build the chip list: "All" + each ServiceTypeOption label.
    final entries = <(String?, String)>[
      (null, 'All'),
      for (final s in ServiceTypeOption.all) (s.id, s.label),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final (value, label) = entries[i];
          final selected = _serviceType == value;
          return InkWell(
            onTap: () => setState(() => _serviceType = value),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : sem.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppColors.primary : sem.border,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : sem.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortBar(SemanticColors sem, int resultCount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$resultCount provider${resultCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sem.textPrimary,
            ),
          ),
        ),
        PopupMenuButton<_ProviderSort>(
          initialValue: _sort,
          onSelected: (v) => setState(() => _sort = v),
          position: PopupMenuPosition.under,
          itemBuilder: (ctx) => _ProviderSort.values
              .map((s) => PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        if (_sort == s)
                          const Icon(Icons.check, size: 16)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text(s.label),
                      ],
                    ),
                  ))
              .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sem.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sem.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort, size: 14, color: sem.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _sort.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sem.textPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_drop_down, size: 16, color: sem.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleViewProfile(BuildContext context, DemoProvider p) {
    if (widget.onViewProfile != null) {
      widget.onViewProfile!(p);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('View ${p.name} profile'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleAssign(BuildContext context, DemoProvider p) {
    if (widget.onAssign != null) {
      widget.onAssign!(p);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${p.name} assigned (demo)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
