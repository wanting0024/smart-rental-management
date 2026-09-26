// lib/screens/about_screen.dart
// App info, version, FAQ, contact support. Standard "About" page.
//
// Round 11 polish (AB1-AB3):
//   AB1 Theme colors (sem.* + AppColors.*) for FAQ text
//   AB2 ListTile trailing icon uses sem.textTertiary
//   AB3 Subtitle text uses sem.textSecondary

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _expandedFAQs = <int>{};

  static const _faqs = [
    {
      'q': 'How does the MCDA matching work?',
      'a': 'We score each provider using a weighted formula: Availability (0.35), Distance (0.20), Rating (0.25), Workload (0.20). The provider with the highest score gets routed the job.',
    },
    {
      'q': 'Can I cancel a booking after accepting?',
      'a': 'Yes, but you\'ll be asked to pick a reason. Frequent cancellations affect your reliability score.',
    },
    {
      'q': 'When does a recurring booking stop?',
      'a': 'Recurring bookings continue until you cancel or pause them. You can pause via the booking detail page.',
    },
    {
      'q': 'How are payouts calculated?',
      'a': 'Hourly rate × duration, minus a 15% platform fee. Payouts are processed weekly to your registered bank account.',
    },
    {
      'q': 'Can I change my service area?',
      'a': 'Yes — go to Profile > Edit profile > Working hours. Your service radius is auto-computed from your listed address.',
    },
    {
      'q': 'How do I dispute a review?',
      'a': 'Open the review in your reviews page and tap "Report". Our team will review within 48 hours.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About & help')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App brand card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.apartment, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Smart Rental',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Owner & Cleaning Service Provider',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'v0.1.0 · Sprint 0',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick links
          Card(
            child: Column(
              children: [
                _tile(context, Icons.help_outline, 'Help center', 'Browse articles and guides', null),
                _divider(sem),
                _tile(context, Icons.chat_bubble_outline, 'Contact support', 'We respond within 24h', null),
                _divider(sem),
                _tile(context, Icons.description_outlined, 'Terms of service', null, null),
                _divider(sem),
                _tile(context, Icons.privacy_tip_outlined, 'Privacy policy', null, null),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'FREQUENTLY ASKED',
            style: TextStyle(fontSize: 11, color: sem.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          ..._faqs.asMap().entries.map((e) => _buildFAQ(e.key, e.value, sem)),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Smart Rental Manager · Made with 💚 for property managers',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: sem.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String title, String? subtitle, VoidCallback? onTap) {
    final sem = SemanticColors.of(ctx);
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
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
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: sem.textSecondary),
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 12,
        color: sem.textTertiary,
      ),
      onTap: onTap ?? () {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('$title - Sprint 1 will add this'), behavior: SnackBarBehavior.floating),
        );
      },
    );
  }

  Widget _divider(SemanticColors sem) => Divider(height: 1, color: sem.border, indent: 60);

  Widget _buildFAQ(int idx, Map<String, String> faq, SemanticColors sem) {
    final isOpen = _expandedFAQs.contains(idx);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: sem.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sem.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isOpen) {
                _expandedFAQs.remove(idx);
              } else {
                _expandedFAQs.add(idx);
              }
            }),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      faq['q']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sem.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    isOpen ? Icons.expand_less : Icons.expand_more,
                    color: sem.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                faq['a']!,
                style: TextStyle(fontSize: 13, color: sem.textSecondary, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
