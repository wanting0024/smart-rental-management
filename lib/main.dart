// lib/main.dart
// Sprint 0 demo entry. Provides shared:
//   - AppProviders (theme + booking store + provider store)
//   - UserSessionAccess (login + onboarding state + providerId)
//
// Default route: Login -> Onboarding (first run) -> Owner Home.

import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/owner_home_screen.dart';
import 'screens/provider_inbox_screen.dart';
import 'services/booking_store.dart';
import 'services/message_store.dart';
import 'services/provider_store.dart';
import 'services/review_store.dart';
import 'services/user_session.dart';
import 'theme/app_theme.dart';

void main() => runApp(const RentalAppDemo());

class RentalAppDemo extends StatefulWidget {
  const RentalAppDemo({super.key});

  @override
  State<RentalAppDemo> createState() => _RentalAppDemoState();
}

class _RentalAppDemoState extends State<RentalAppDemo> {
  ThemeMode _themeMode = ThemeMode.light;
  final BookingStore _bookingStore = BookingStore();
  final ProviderStore _providerStore = ProviderStore();
  final ReviewStore _reviewStore = ReviewStore();
  final MessageStore _messageStore = MessageStore();
  final UserSession _userSession = UserSession();

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      themeMode: _themeMode,
      onToggleTheme: _toggleTheme,
      bookingStore: _bookingStore,
      providerStore: _providerStore,
      reviewStore: _reviewStore,
      messageStore: _messageStore,
      child: UserSessionAccess(
        session: _userSession,
        child: MaterialApp(
          title: 'Smart Rental Manager',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeMode,
          debugShowCheckedModeBanner: false,
          home: const _RootRouter(),
        ),
      ),
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  @override
  Widget build(BuildContext context) {
    final session = UserSessionAccess.of(context);
    return AnimatedBuilder(
      animation: session,
      builder: (ctx, _) {
        if (!session.isLoggedIn) return const LoginScreen();
        if (!session.hasSeenOnboarding) return const OnboardingScreen();
        // If provider, route to Provider Inbox. Otherwise Owner Home.
        return session.role == UserRole.provider
            ? const _ProviderEntry()
            : const OwnerHomeScreen();
      },
    );
  }
}

class _ProviderEntry extends StatefulWidget {
  const _ProviderEntry();
  @override
  State<_ProviderEntry> createState() => _ProviderEntryState();
}

class _ProviderEntryState extends State<_ProviderEntry> {
  @override
  void initState() {
    super.initState();
    // After first frame, sync providerId from session → store
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = UserSessionAccess.of(context);
      final store = AppProviders.of(context).providerStore;
      if (session.providerId != null) {
        store.setCurrentProviderId(session.providerId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Default to Provider A for demo
    return const ProviderInboxScreen(provider: null);
  }
}

/// Top-level providers: theme + booking store + provider store.
class AppProviders extends InheritedWidget {
  const AppProviders({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.bookingStore,
    required this.providerStore,
    required this.reviewStore,
    required this.messageStore,
    required super.child,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final BookingStore bookingStore;
  final ProviderStore providerStore;
  final ReviewStore reviewStore;
  final MessageStore messageStore;

  static AppProviders of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppProviders>();
    assert(result != null, 'No AppProviders found in context');
    return result!;
  }

  bool get isDark => themeMode == ThemeMode.dark;

  @override
  bool updateShouldNotify(AppProviders oldWidget) =>
      oldWidget.themeMode != themeMode;
}

/// Backwards-compat shim. Old code used `RentalTheme.of(context)`.
class RentalTheme {
  RentalTheme._();
  static AppProviders of(BuildContext context) => AppProviders.of(context);
  static bool get isDark => false; // not used standalone
  static VoidCallback get onToggle => () {}; // not used standalone
}
