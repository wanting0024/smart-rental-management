// lib/screens/onboarding_screen.dart
// First-launch onboarding. 3 pages, paginated, skip-able.
// On completion, marks session.hasSeenOnboarding and the root router
// advances to the home screen.
//
// Round 12 polish (ON1-ON4): touch-up — explicit theme colors + animated
// background tint that follows the current page's accent.

import 'package:flutter/material.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctl = PageController();
  int _idx = 0;

  static const _pages = <_OnbPageData>[
    _OnbPageData(
      icon: Icons.apartment,
      title: 'Manage your properties',
      body: 'Schedule cleanings, view status across your portfolio, and keep tenants happy with on-time service.',
      accent: AppColors.primary,
    ),
    _OnbPageData(
      icon: Icons.person_search,
      title: 'Match the right provider',
      body: 'We rank candidates with multi-criteria analysis — availability, distance, rating, workload. Top match gets routed in seconds.',
      accent: AppColors.secondary,
    ),
    _OnbPageData(
      icon: Icons.verified,
      title: 'Approve with proof',
      body: 'Every job ends with before-and-after photos. You stay in control until you sign off.',
      accent: AppColors.warning,
    ),
  ];

  void _skip() => UserSessionAccess.of(context).markOnboardingSeen();

  void _next() {
    if (_idx < _pages.length - 1) {
      _ctl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      UserSessionAccess.of(context).markOnboardingSeen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _idx == _pages.length - 1;
    final sem = SemanticColors.of(context);
    final accent = _pages[_idx].accent;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        // ON1: subtle accent-tinted background that animates with the page
        color: accent.withOpacity(isLast ? 0.0 : 0.04),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: sem.textSecondary,
                  ),
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctl,
                  onPageChanged: (i) => setState(() => _idx = i),
                  itemCount: _pages.length,
                  itemBuilder: (ctx, i) => _OnbPage(data: _pages[i]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _idx ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _idx ? _pages[_idx].accent : sem.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(isLast ? 'Get started' : 'Next'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnbPageData {
  const _OnbPageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
}

class _OnbPage extends StatelessWidget {
  const _OnbPage({required this.data});
  final _OnbPageData data;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ON2: ring around icon for extra polish
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: data.accent.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: data.accent.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(data.icon, size: 64, color: data.accent),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            // ON3: explicit theme color for title
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: sem.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: sem.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
