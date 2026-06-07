import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/app_providers.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/active_trades/active_trades_screen.dart';
import 'features/wallet/wallet_screen.dart';
import 'features/history/history_screen.dart';
import 'features/history/trade_detail_screen.dart';
import 'features/ai_chat/ai_chat_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/trade_entry/trade_entry_screen.dart';

// ── Auth-aware router notifier ────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authStateProvider);

    // Still resolving auth state — stay on splash
    if (authAsync.isLoading) {
      return state.uri.path == '/splash' ? null : '/splash';
    }

    final isLoggedIn = authAsync.valueOrNull != null;
    final path = state.uri.path;
    final isAuthRoute = path == '/login' ||
        path == '/register' ||
        path == '/splash';

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/';
    return null;
  }
}

// ── Router provider ───────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
          path: '/splash', builder: (ctx, st) => const SplashScreen()),
      GoRoute(
          path: '/login', builder: (ctx, st) => const LoginScreen()),
      GoRoute(
          path: '/register', builder: (ctx, st) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (ctx, st) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/active',
            builder: (ctx, st) => const ActiveTradesScreen(),
          ),
          GoRoute(
            path: '/wallet',
            builder: (ctx, st) => const WalletScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (ctx, st) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/ai',
            builder: (ctx, st) => const AiChatScreen(),
          ),
        ],
      ),
      // Full-screen routes (no bottom nav)
      GoRoute(
        path: '/settings',
        builder: (ctx, st) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/trade/new',
        builder: (ctx, st) => const TradeEntryScreen(),
      ),
      GoRoute(
        path: '/history/:id',
        builder: (ctx, st) =>
            TradeDetailScreen(tradeId: st.pathParameters['id']!),
      ),
    ],
  );
});

// ── Shell scaffold with bottom nav ────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  static const _tabs = [
    (path: '/', icon: Icons.dashboard_outlined, label: 'Dashboard'),
    (path: '/active', icon: Icons.trending_up, label: 'Trades'),
    (
      path: '/wallet',
      icon: Icons.account_balance_wallet_outlined,
      label: 'Wallet'
    ),
    (path: '/history', icon: Icons.history, label: 'History'),
    (path: '/ai', icon: Icons.auto_awesome_outlined, label: 'AI'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final idx = _tabs.indexWhere((t) => t.path == location);
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex(context),
        onTap: (i) => context.go(_tabs[i].path),
        items: _tabs
            .map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
      floatingActionButton: GoRouterState.of(context).uri.path == '/'
          ? FloatingActionButton(
              onPressed: () => context.push('/trade/new'),
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

