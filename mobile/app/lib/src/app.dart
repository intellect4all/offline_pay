import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/service_locator.dart';
import 'presentation/cubits/app/app_cubit.dart';
import 'presentation/cubits/kyc/kyc_cubit.dart';
import 'presentation/cubits/send_money/send_money_cubit.dart';
import 'presentation/cubits/session/session_cubit.dart';
import 'screens/activity_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/unlock_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/wallet_screen.dart';
import 'services/connectivity.dart';
import 'services/install_sentinel.dart';
import 'services/push_notifications_service.dart';
import 'services/sync.dart';
import 'theme.dart';

const _bffUrl = String.fromEnvironment(
  'BFF_URL',
  defaultValue: 'http://localhost:8082',
);

class OfflinePayApp extends StatefulWidget {
  const OfflinePayApp({super.key});

  @override
  State<OfflinePayApp> createState() => _OfflinePayAppState();
}

class _OfflinePayAppState extends State<OfflinePayApp> {
  late Future<void> _boot;

  @override
  void initState() {
    super.initState();
    _boot = _bootstrap();
  }

  void _retry() {
    final next = _bootstrap();
    setState(() {
      _boot = next;
    });
  }

  // Keep this synchronous / local-only. Anything that might hit the
  // network or a slow platform channel runs from _RootGate after first
  // paint so the splash can't hang on a dead BFF.
  Future<void> _bootstrap() async {
    final bffBase = Uri.parse(_bffUrl);
    developer.log('booting with BFF at $bffBase', name: 'app');
    await InstallSentinel.ensure();
    await setupServiceLocator(bffBase: bffBase);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _boot,
      builder: (context, snap) {
        if (snap.hasError) {
          return MaterialApp(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            home: _BootFailureScreen(
              error: snap.error!,
              onRetry: _retry,
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return MaterialApp(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            home: const _BootScreen(),
          );
        }
        return MultiBlocProvider(
          providers: [
            BlocProvider<AppCubit>.value(value: sl<AppCubit>()),
            BlocProvider<SessionCubit>.value(value: sl<SessionCubit>()),
            BlocProvider<SendMoneyCubit>.value(value: sl<SendMoneyCubit>()),
            BlocProvider<KycCubit>.value(value: sl<KycCubit>()),
          ],
          child: MaterialApp(
            title: 'offline_pay',
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            scaffoldMessengerKey: scaffoldMessengerKey,
            home: const _RootGate(),
          ),
        );
      },
    );
  }
}

class _BootScreen extends StatefulWidget {
  const _BootScreen();
  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1 - 0.04 * t,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(
                            alpha: 0.25 - 0.15 * t,
                          ),
                          blurRadius: 24 + 8 * t,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.bolt,
                      size: 36,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'offline_pay',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _deferredStart());
  }

  Future<void> _deferredStart() async {
    unawaited(
      sl<ConnectivityService>().start().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          developer.log(
            'connectivity.start() timed out',
            name: 'app',
          );
        },
      ),
    );
    try {
      await sl<SessionCubit>().bootstrap();
    } catch (e, st) {
      developer.log('sessionCubit.bootstrap threw',
          error: e, stackTrace: st, name: 'app');
    }
    try {
      await sl<AppCubit>().bootstrap();
    } catch (e, st) {
      developer.log('appCubit.bootstrap threw',
          error: e, stackTrace: st, name: 'app');
    }
    sl<SyncService>().start();
    try {
      final push = sl<PushNotificationsService>();
      await push.init(
        onNotificationTap: _onNotificationTap,
        onForegroundMessage: _onForegroundMessage,
      );
      await push.handleInitialMessageIfAny();
    } catch (e, st) {
      developer.log('push init threw',
          error: e, stackTrace: st, name: 'app');
    }
    if (mounted) setState(() => _ready = true);
  }

  void _onNotificationTap(Map<String, String> data) {
    final type = data['type'] ?? '';
    if (type.startsWith('transfer_') || type.startsWith('offline_payment_')) {
      sl<AppCubit>().setTab(TabIndex.activity);
    }
  }

  void _onForegroundMessage(Map<String, String> data) {
    final type = data['type'] ?? '';
    if (type.startsWith('offline_payment_') || type.startsWith('transfer_')) {
      unawaited(sl<AppCubit>().refreshRemoteAndActivity());
      unawaited(sl<SyncService>().runOnce());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _BootScreen();
    // Route on `gate`, not `signedIn`: a cached token must reach the
    // wallet even when the access JWT has expired and we can't refresh.
    final gate = context.select<SessionCubit, AuthGate>((c) => c.state.gate);
    final signedIn =
        context.select<SessionCubit, bool>((c) => c.state.signedIn);
    if (gate == AuthGate.unlocked) {
      return const _HomeShell();
    }
    if (gate == AuthGate.locked) {
      return const UnlockScreen();
    }
    if (signedIn && gate == AuthGate.expired) {
      return const _HomeShell();
    }
    return const LoginScreen();
  }
}

class _BootFailureScreen extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _BootFailureScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                'offline_pay could not start',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell();

  static const _tabs = <_Tab>[
    _Tab('Home', Icons.home_outlined, Icons.home),
    _Tab('Wallet', Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet),
    _Tab('Activity', Icons.receipt_long_outlined, Icons.receipt_long),
    _Tab('Settings', Icons.settings_outlined, Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AppCubit>();
    final currentTab = context.select<AppCubit, int>((c) => c.state.currentTab);
    const screens = <Widget>[
      HomeScreen(),
      WalletScreen(),
      ActivityScreen(),
      SettingsScreen(),
    ];
    final clamped = currentTab.clamp(0, screens.length - 1);
    return Scaffold(
      body: IndexedStack(index: clamped, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: clamped,
        onDestinationSelected: cubit.setTab,
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: _BounceIcon(
                icon: _tabs[i].icon,
                active: false,
                triggered: clamped == i,
              ),
              selectedIcon: _BounceIcon(
                icon: _tabs[i].iconSelected,
                active: true,
                triggered: clamped == i,
              ),
              label: _tabs[i].label,
            ),
        ],
      ),
    );
  }
}

class _BounceIcon extends StatefulWidget {
  final IconData icon;
  final bool active;
  final bool triggered;
  const _BounceIcon({
    required this.icon,
    required this.active,
    required this.triggered,
  });

  @override
  State<_BounceIcon> createState() => _BounceIconState();
}

class _BounceIconState extends State<_BounceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    if (widget.triggered) _c.value = 1;
  }

  @override
  void didUpdateWidget(covariant _BounceIcon old) {
    super.didUpdateWidget(old);
    if (widget.triggered && !old.triggered) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        final scale = 1 + 0.18 * math.sin(t * math.pi);
        return Transform.scale(scale: scale, child: child);
      },
      child: Icon(widget.icon),
    );
  }
}

class TabIndex {
  static const home = 0;
  static const wallet = 1;
  static const activity = 2;
  static const settings = 3;
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData iconSelected;
  const _Tab(this.label, this.icon, this.iconSelected);
}

