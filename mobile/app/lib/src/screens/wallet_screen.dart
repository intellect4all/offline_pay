import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/service_locator.dart';
import '../presentation/cubits/app/app_cubit.dart';
import '../presentation/cubits/app/app_state.dart';
import '../presentation/cubits/session/session_cubit.dart';
import '../repositories/wallet_repository.dart';
import '../util/haptics.dart';
import '../util/money.dart';
import '../util/time_format.dart';
import '../widgets/animated_balance.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/skeleton.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<AppCubit>();
      if (cubit.state.online && !cubit.state.hasRemoteBalances && !_busy) {
        unawaited(cubit.refreshAll());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppCubit>().state;
    final ceiling = state.activeCeiling;
    final refreshing = state.refreshing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh balances',
            onPressed: state.online && !_busy && !refreshing
                ? _pullBalances
                : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _pullBalances,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                FadeSlideIn(
                  child: _MainBalanceCard(
                    state: state,
                    onTopUp: _busy ? null : _showTopUpSheet,
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: _AccountsGrid(state: state),
                ),
                const SizedBox(height: 24),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: _OfflineSection(
                    state: state,
                    ceiling: ceiling,
                    busy: _busy,
                    online: state.online,
                    onFund: _showFundSheet,
                    onRefresh: _showRefreshSheet,
                    onMoveToMain: _confirmMoveToMain,
                  ),
                ),
                if (!state.online) ...[
                  const SizedBox(height: 12),
                  _OfflineHintTile(),
                ],
              ],
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pullBalances() async {
    final cubit = context.read<AppCubit>();
    await _runGuarded(cubit.refreshAll);
  }

  void _showFundSheet() {
    _promptAmount(
      title: 'Fund offline wallet',
      description:
          'Move money from your main wallet to the offline ceiling. Funds '
          'are held as lien and can be spent without internet up to the '
          'ceiling amount.',
      confirmLabel: 'Fund offline',
      icon: Icons.offline_bolt,
      onConfirm: _fundOffline,
    );
  }

  void _showRefreshSheet() {
    _promptAmount(
      title: 'Refresh ceiling',
      description:
          'Issue a new ceiling token with the amount below. The old ceiling '
          'is revoked; in-flight offline payments under it remain valid.',
      confirmLabel: 'Refresh',
      icon: Icons.autorenew,
      onConfirm: _refreshCeiling,
    );
  }

  void _showTopUpSheet() {
    _promptAmount(
      title: 'Add money',
      description: 'Dev-only: credit the main wallet without a real transfer.',
      confirmLabel: 'Credit wallet',
      icon: Icons.add_card,
      onConfirm: _topUp,
    );
  }

  void _confirmMoveToMain() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Move offline balance back',
              style: Theme.of(sheetCtx).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Revokes the active ceiling and releases the held funds back '
              'to your main wallet. Pending offline payments must settle '
              'first, or the server will reject the move.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.north_east),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Move to main'),
              ),
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                _moveToMain();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _promptAmount({
    required String title,
    required String description,
    required String confirmLabel,
    required IconData icon,
    required Future<void> Function(String amountNaira) onConfirm,
  }) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(sheetCtx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(sheetCtx).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (naira)',
                prefixText: '₦ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: Icon(icon),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(confirmLabel),
              ),
              onPressed: () {
                final v = controller.text;
                Navigator.of(sheetCtx).pop();
                onConfirm(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _topUp(String input) async {
    final kobo = parseNairaToKobo(input);
    if (kobo == null || kobo <= 0) return _toast('Enter a positive amount.');
    final token = _token();
    if (token == null) return _toast('Session expired. Please sign in again.');
    final cubit = context.read<AppCubit>();
    final repo = sl<WalletRepository>();
    await _runGuarded(() async {
      try {
        await repo.topUp(amountKobo: kobo, accessToken: token);
        _toast('Added ${formatNaira(kobo)}');
        await cubit.refreshRemote();
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        if (status == 404) {
          _toast('Top-up not available on this server.');
        } else if (status == 400) {
          _toast('Amount too large (max ₦100,000).');
        } else {
          rethrow;
        }
      }
    });
  }

  Future<void> _fundOffline(String input) async {
    final kobo = parseNairaToKobo(input);
    if (kobo == null || kobo <= 0) return _toast('Enter a positive amount.');
    final token = _token();
    if (token == null) return _toast('Session expired. Please sign in again.');
    final cubit = context.read<AppCubit>();
    final repo = sl<WalletRepository>();
    await _runGuarded(() async {
      final pub = await _payerPublicKey(cubit.state);
      final snap = await repo.fundOffline(
        amountKobo: kobo,
        ttlSeconds: 24 * 3600,
        payerPublicKey: pub,
        accessToken: token,
      );
      await _applyCeilingAndRefreshBalances(cubit, snap);
      _toast('Funded ${formatNaira(kobo)} offline.');
    });
  }

  Future<void> _moveToMain() async {
    final token = _token();
    if (token == null) return _toast('Session expired. Please sign in again.');
    final cubit = context.read<AppCubit>();
    final repo = sl<WalletRepository>();
    await _runGuarded(() async {
      await repo.moveToMain(token);
      cubit.clearActiveCeiling();
      await cubit.refreshRemote();
      _toast('Offline balance moved back to main.');
    });
  }

  Future<void> _refreshCeiling(String input) async {
    final kobo = parseNairaToKobo(input);
    if (kobo == null || kobo <= 0) return _toast('Enter a positive amount.');
    final token = _token();
    if (token == null) return _toast('Session expired. Please sign in again.');
    final cubit = context.read<AppCubit>();
    final repo = sl<WalletRepository>();
    await _runGuarded(() async {
      final pub = await _payerPublicKey(cubit.state);
      final snap = await repo.refreshCeiling(
        newAmountKobo: kobo,
        ttlSeconds: 24 * 3600,
        payerPublicKey: pub,
        accessToken: token,
      );
      await _applyCeilingAndRefreshBalances(cubit, snap);
      _toast('Ceiling refreshed to ${formatNaira(kobo)}.');
    });
  }

  Future<void> _applyCeilingAndRefreshBalances(
    AppCubit cubit,
    CeilingSnapshot ct,
  ) async {
    final snap = cubit.state;
    cubit.applyFundOffline(
      ceiling: ActiveCeiling(
        id: ct.id,
        ceilingKobo: ct.ceilingAmountKobo,
        sequenceStart: ct.sequenceStart,
        issuedAt: ct.issuedAt.toUtc(),
        expiresAt: ct.expiresAt.toUtc(),
        bankKeyId: ct.bankKeyId,
        payerPublicKey: ct.payerPublicKey,
        bankSignature: ct.bankSignature,
        ceilingTokenBlob: ct.ceilingTokenBlob,
      ),
      newMainBalanceKobo: snap.mainBalanceKobo,
      newOfflineBalanceKobo: snap.offlineBalanceKobo,
      newLienBalanceKobo: snap.lienBalanceKobo,
    );
    await cubit.refreshRemote();
  }

  String? _token() =>
      context.read<SessionCubit>().state.session?.accessToken;

  Future<Uint8List> _payerPublicKey(AppUiState state) async {
    final existing = state.activeCeiling?.payerPublicKey;
    if (existing != null && existing.isNotEmpty) return existing;
    final pub = await context.read<AppCubit>().keystore.publicKey();
    if (pub == null || pub.isEmpty) {
      throw StateError('keystore has no keypair; cannot fund offline wallet');
    }
    return pub;
  }

  Future<void> _runGuarded(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
      Haptics.success();
    } on DioException catch (e) {
      Haptics.error();
      _handleHttpError(e);
    } catch (e) {
      Haptics.error();
      _toast('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleHttpError(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    String? code;
    String message = e.message ?? 'request failed';
    if (data is Map) {
      final c = data['code'];
      final m = data['message'];
      if (c is String) code = c;
      if (m is String) message = m;
    }
    switch (status) {
      case 409:
        if (message.toLowerCase().contains('unsettled')) {
          _toast('Cannot move — unsettled offline claims remain.');
        } else if (code == 'already_exists' ||
            message.toLowerCase().contains('already')) {
          _toast('An active ceiling already exists. Refresh it instead.');
        } else {
          _toast('Preconditions not met: $message');
        }
        break;
      case 402:
      case 422:
        _toast('Insufficient funds in main wallet.');
        break;
      default:
        _toast('Server error ($status): $message');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }
}

class _MainBalanceCard extends StatelessWidget {
  final AppUiState state;
  final VoidCallback? onTopUp;
  const _MainBalanceCard({required this.state, required this.onTopUp});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Main balance',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (kDebugMode && onTopUp != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimary,
                    backgroundColor:
                        scheme.onPrimary.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add money'),
                  onPressed: onTopUp,
                ),
            ],
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
            _HeroShimmer(scheme: scheme),
        ],
      ),
    );
  }
}

class _HeroShimmer extends StatelessWidget {
  final ColorScheme scheme;
  const _HeroShimmer({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.onPrimary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _AccountsGrid extends StatelessWidget {
  final AppUiState state;
  const _AccountsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final loading = !state.hasRemoteBalances;
    final rows = <_AccountTile>[
      _AccountTile(
        label: 'Offline available',
        value: state.offlineRemainingKobo,
        icon: Icons.offline_bolt,
        hint: state.activeCeiling == null ? 'No ceiling' : null,
        loading: loading,
      ),
      _AccountTile(
        label: 'Held (lien)',
        value: state.lienBalanceKobo,
        icon: Icons.lock_outline,
        loading: loading,
      ),
      _AccountTile(
        label: 'Receiving pending',
        value: state.receivingPendingKobo,
        icon: Icons.schedule,
        loading: loading,
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: rows,
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final String? hint;
  final bool loading;
  const _AccountTile({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = value == 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (loading)
            const Skeleton(width: 88, height: 18)
          else
            Text(
              formatNaira(value),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: muted ? scheme.onSurfaceVariant : null,
                  ),
            ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineSection extends StatelessWidget {
  final AppUiState state;
  final ActiveCeiling? ceiling;
  final bool busy;
  final bool online;
  final VoidCallback onFund;
  final VoidCallback onRefresh;
  final VoidCallback onMoveToMain;
  const _OfflineSection({
    required this.state,
    required this.ceiling,
    required this.busy,
    required this.online,
    required this.onFund,
    required this.onRefresh,
    required this.onMoveToMain,
  });

  @override
  Widget build(BuildContext context) {
    final recovering = state.recoveringCeiling;
    if (recovering != null) {
      return _RecoveringCeilingCard(recovering: recovering);
    }
    if (ceiling == null) return _NoCeiling(online: online, onFund: onFund);
    return _ActiveCeilingCard(
      ceiling: ceiling!,
      remaining: state.offlineRemainingKobo,
      online: online,
      busy: busy,
      onRefresh: onRefresh,
      onMoveToMain: onMoveToMain,
    );
  }
}

class _RecoveringCeilingCard extends StatelessWidget {
  final RecoveringCeiling recovering;
  const _RecoveringCeilingCard({required this.recovering});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final release = recovering.releaseAfter.toLocal();
    final shortId = recovering.id.length > 8
        ? '…${recovering.id.substring(recovering.id.length - 8)}'
        : recovering.id;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top, color: scheme.tertiary),
              const SizedBox(width: 8),
              Text(
                'Recovery in progress',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'quarantined',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatNaira(recovering.quarantinedKobo),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Returns to main wallet by '
            '${_RecoveringCeilingCard._releaseDateFmt(release)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Any offline payments you already made can still settle during '
            'this window.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'ID: $shortId',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _releaseDateFmt(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }
}

class _NoCeiling extends StatelessWidget {
  final bool online;
  final VoidCallback onFund;
  const _NoCeiling({required this.online, required this.onFund});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.offline_bolt, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Offline payments',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Move money into the offline wallet to pay without internet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.arrow_downward),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Set up offline wallet'),
            ),
            onPressed: online ? onFund : null,
          ),
        ],
      ),
    );
  }
}

class _ActiveCeilingCard extends StatelessWidget {
  final ActiveCeiling ceiling;
  final int remaining;
  final bool online;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onMoveToMain;
  const _ActiveCeilingCard({
    required this.ceiling,
    required this.remaining,
    required this.online,
    required this.busy,
    required this.onRefresh,
    required this.onMoveToMain,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expiryLabel = untilOrAgo(ceiling.expiresAt);
    final expired = ceiling.expiresAt.isBefore(DateTime.now());
    final shortId = ceiling.id.length > 8
        ? '…${ceiling.id.substring(ceiling.id.length - 8)}'
        : ceiling.id;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.offline_bolt, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Active ceiling',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: expired
                      ? scheme.errorContainer
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  expired ? 'expired' : 'active',
                  style: TextStyle(
                    color: expired
                        ? scheme.onErrorContainer
                        : scheme.onPrimaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _KeyRow(label: 'Remaining', value: formatNaira(remaining)),
          _KeyRow(
              label: 'Ceiling',
              value: formatNaira(ceiling.ceilingKobo),
              muted: true),
          _KeyRow(label: 'Expires', value: expiryLabel, muted: true),
          _KeyRow(label: 'ID', value: shortId, muted: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.autorenew),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Refresh'),
                  ),
                  onPressed: (online && !busy) ? onRefresh : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.north_east),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Move back'),
                  ),
                  onPressed: (online && !busy) ? onMoveToMain : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  const _KeyRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                    color: muted ? scheme.onSurfaceVariant : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineHintTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are offline. Fund, refresh, and move-back require internet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
