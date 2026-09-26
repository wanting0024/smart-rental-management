// lib/screens/provider_browse_screen.dart
// Provider Browse screen. Providers must pass all mandatory eligibility checks
// before they are ranked by distance, rating, and current workload.
//
// Round 9 polish (PB1-PB6):
//   PB1 Sort selector (Score / Distance / Rating / Price) — default Score
//   PB2 Service-type filter chip row (All / Standard / Deep / Window / etc.)
//   PB3 Theme colors throughout (sem.* + AppColors.*)
//   PB4 Empty state when filtered list is empty
//   PB5 Better header with legend chip showing MCDA weights
//   PB6 SectionHeader widget for consistency

import 'package:flutter/material.dart';
import '../features/matching/domain/provider_matching.dart';
import '../main.dart';
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
  String _serviceType = 'standard';

  @override
  Widget build(BuildContext context) {
    final providers = AppProviders.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        providers.providerStore,
        providers.bookingStore,
      ]),
      builder: (context, _) => _buildContent(context, providers),
    );
  }

  Widget _buildContent(BuildContext context, AppProviders providers) {
    final sem = SemanticColors.of(context);
    final requestedStart = DateTime(2026, 7, 20, 10);
    final request = ProviderMatchRequest(
      serviceType: _serviceType,
      requestedStart: requestedStart,
      requestedEnd: requestedStart.add(const Duration(hours: 2)),
      rentalWindowStart: DateTime(2026, 7, 20, 8),
      rentalWindowEnd: DateTime(2026, 7, 20, 18),
    );
    final result = providers.providerStore.matchProviders(
      request: request,
      bookings: providers.bookingStore.bookings,
    );
    final sorted = [...result.rankedProviders];
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
                          'Unit A-12 · Mon 20 Jul 10:00–12:00 · '
                          '${_serviceLabel(_serviceType)}',
                          style:
                              TextStyle(fontSize: 11, color: sem.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Eligibility first · service · full interval · rental window · no conflict',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ranking · distance 1/3 · rating 1/3 · current workload 1/3',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Requested service',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: sem.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildServiceTypeFilter(sem),
        const SizedBox(height: 12),
        _buildSortBar(sem, sorted.length),
        if (result.excludedProviders.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.filter_alt_outlined,
                  size: 14, color: sem.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${result.excludedProviders.length} provider${result.excludedProviders.length == 1 ? '' : 's'} '
                  'excluded by mandatory checks before scoring.',
                  style: TextStyle(fontSize: 11, color: sem.textSecondary),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const EmptyState(
            icon: Icons.person_search_outlined,
            title: 'No eligible provider',
            subtitle:
                'No provider passed every mandatory check for this request.',
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
    final entries = <(String, String)>[
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

  String _serviceLabel(String serviceId) {
    for (final service in ServiceTypeOption.all) {
      if (service.id == serviceId) return service.label;
    }
    return serviceId;
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
