import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app.dart' show TabIndex;
import '../presentation/cubits/app/app_cubit.dart';
import '../presentation/cubits/app/app_state.dart';
import '../presentation/cubits/session/session_cubit.dart';
import '../services/local_queue.dart';
import '../util/haptics.dart';
import '../util/money.dart';
import '../widgets/animated_balance.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/press_scale.dart';
import 'receive_screen.dart';
import 'send_money/send_money_screen.dart';
import 'send_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  bool _showMini = false;

  static const double _miniThreshold = 180;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scroll.offset > _miniThreshold;
    if (show != _showMini) setState(() => _showMini = show);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppCubit>().state;
    final session = context.watch<SessionCubit>().state;
    final appCubit = context.read<AppCubit>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: appCubit.refreshAll,
                child: ListView(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    FadeSlideIn(
                      duration: const Duration(milliseconds: 320),
                      child:
                          _Greeting(session: session, online: state.online),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: _HeroBalance(state: state),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 140),
                      child: _QuickActions(state: state),
                    ),
                    const SizedBox(height: 28),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 220),
                      child: _RecentActivity(activity: state.activity),
                    ),
                  ],
                ),
              ),
              _MiniBalanceBar(
                state: state,
                session: session,
                visible: _showMini,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBalanceBar extends StatelessWidget {
  final AppUiState state;
  final SessionUiState session;
  final bool visible;
  const _MiniBalanceBar({
    required this.state,
    required this.session,
    required this.visible,
  });

  String get _initials {
    final phone = session.session?.userId ?? session.profile?.phone ?? '';
    if (phone.length < 2) return '?';
    return phone.substring(phone.length - 2);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          offset: visible ? Offset.zero : const Offset(0, -1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: visible ? 1 : 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      _initials,
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Main balance',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        if (state.hasRemoteBalances)
                          AnimatedBalance(
                            amountKobo: state.mainBalanceKobo,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          )
                        else
                          Container(
                            height: 16,
                            width: 120,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final SessionUiState session;
  final bool online;
  const _Greeting({required this.session, required this.online});

  String get _accountNumber => session.profile?.accountNumber ?? '';

  String get _initials {
    final phone = session.session?.userId ?? session.profile?.phone ?? '';
    if (phone.length < 2) return '?';
    return phone.substring(phone.length - 2);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            _initials,
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi 👋',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_accountNumber.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _accountNumber),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        content: Text('Account number copied'),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _accountNumber,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy, size: 14),
                    ],
                  ),
                )
              else
                Text(
                  'Welcome',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
            ],
          ),
        ),
        _ConnectivityPill(online: online),
      ],
    );
  }
}

class _ConnectivityPill extends StatelessWidget {
  final bool online;
  const _ConnectivityPill({required this.online});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = online ? scheme.secondaryContainer : scheme.errorContainer;
    final fg = online ? scheme.onSecondaryContainer : scheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(online ? Icons.cloud_done : Icons.cloud_off,
              size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            online ? 'online' : 'offline',
            style: TextStyle(
                color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _HeroBalance extends StatelessWidget {
  final AppUiState state;
  const _HeroBalance({required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final offline = state.offlineRemainingKobo;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Main balance',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (state.hasRemoteBalances)
            AnimatedBalance(
              amountKobo: state.mainBalanceKobo,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            )
          else
            Container(
              height: 44,
              margin: const EdgeInsets.only(right: 64),
              decoration: BoxDecoration(
                color: scheme.onPrimary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BalanceChip(
                icon: Icons.offline_bolt,
                label: 'Offline',
                value: formatNaira(offline),
                foreground: scheme.onPrimary,
              ),
              if (state.lienBalanceKobo > 0)
                _BalanceChip(
                  icon: Icons.lock_outline,
                  label: 'Held',
                  value: formatNaira(state.lienBalanceKobo),
                  foreground: scheme.onPrimary,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color foreground;
  const _BalanceChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final AppUiState state;
  const _QuickActions({required this.state});

  void _go(BuildContext context, Widget Function() build) {
    Haptics.tap();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => build()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionTile(
          heroTag: 'hero-send-money',
          icon: Icons.north_east,
          label: 'Send',
          onTap: () => _go(context, () => const SendMoneyScreen()),
        ),
        _ActionTile(
          heroTag: 'hero-offline-pay',
          icon: Icons.qr_code_2,
          label: 'Offline pay',
          onTap: () => _go(context, () => const SendScreen()),
        ),
        _ActionTile(
          heroTag: 'hero-receive',
          icon: Icons.qr_code_scanner,
          label: 'Receive',
          onTap: () => _go(context, () => const ReceiveScreen()),
        ),
        _ActionTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Wallet',
          onTap: () {
            Haptics.tap();
            context.read<AppCubit>().setTab(TabIndex.wallet);
          },
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Object? heroTag;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget circle = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: scheme.primary),
    );
    if (heroTag != null) {
      circle = Hero(tag: heroTag!, child: circle);
    }
    return Expanded(
      child: PressScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              circle,
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  final List<LocalTxn> activity;
  const _RecentActivity({required this.activity});

  @override
  Widget build(BuildContext context) {
    final preview = activity.take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (activity.isNotEmpty)
              TextButton(
                onPressed: () =>
                    context.read<AppCubit>().setTab(TabIndex.activity),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (preview.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No activity yet. Send or receive to get started.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...preview.map((t) => _ActivityTile(txn: t)),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final LocalTxn txn;
  const _ActivityTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sent = txn.direction == TxnDirection.sent;
    final icon = sent ? Icons.arrow_upward : Icons.arrow_downward;
    final sign = sent ? '-' : '+';
    final color = sent ? scheme.error : scheme.primary;
    final counterId = sent ? txn.payeeId : txn.payerId;
    final counterName = txn.counterDisplayName;
    final hasName = counterName != null && counterName.trim().isNotEmpty;
    final label = hasName ? counterName : _truncate(counterId);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        sent ? 'To $label' : 'From $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        txnStateLabel(txn.state),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Text(
        '$sign${formatNaira(txn.amountKobo)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  static String _truncate(String s, {int max = 18}) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }
}
