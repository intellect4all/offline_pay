import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/service_locator.dart';
import '../presentation/cubits/app/app_cubit.dart';
import '../presentation/cubits/app/app_state.dart';
import '../presentation/cubits/session/session_cubit.dart';
import '../repositories/wallet_repository.dart';
import '../services/claim_submitter.dart';
import '../services/device_registrar.dart';
import '../services/gossip_pool.dart';
import '../services/local_queue.dart';
import 'sessions_screen.dart';
import 'set_pin_screen.dart';
import 'tiers_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _deviceId;
  int? _realmVersion;
  int _bankKeyCount = 0;
  int _queuedCount = 0;
  int _pendingCount = 0;
  int _settledCount = 0;
  int _rejectedCount = 0;
  int _gossipPending = 0;
  int _gossipUploaded = 0;
  int _gossipMaxCarry = gossipMaxCarry;
  bool _reregistering = false;
  bool _syncing = false;
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cubit = context.read<AppCubit>();
    GossipPool? gossipPool;
    try {
      gossipPool = sl<GossipPool>();
    } catch (_) {}

    final results = await Future.wait<Object?>([
      cubit.keystore.deviceId(),
      cubit.keystore.realmKey(),
      cubit.keystore.readBankKeys(),
      cubit.queue.countByState(TxnState.queued),
      cubit.queue.countByState(TxnState.pending),
      cubit.queue.countByState(TxnState.settled),
      cubit.queue.countByState(TxnState.rejected),
      if (gossipPool != null) gossipPool.stats(),
    ]);
    if (!mounted) return;

    final deviceId = results[0] as String?;
    final realm = results[1] as (int, Uint8List)?;
    final bankKeys = results[2] as List<dynamic>;
    final queued = results[3] as int;
    final pending = results[4] as int;
    final settled = results[5] as int;
    final rejected = results[6] as int;
    final gossipStats =
        gossipPool != null ? results[7] as Map<String, dynamic> : null;

    setState(() {
      _deviceId = deviceId;
      _realmVersion = realm?.$1;
      _bankKeyCount = bankKeys.length;
      _queuedCount = queued;
      _pendingCount = pending;
      _settledCount = settled;
      _rejectedCount = rejected;
      _gossipPending = (gossipStats?['carryPending'] as int?) ?? 0;
      _gossipUploaded = (gossipStats?['uploaded'] as int?) ?? 0;
      _gossipMaxCarry = (gossipStats?['maxCarry'] as int?) ?? gossipMaxCarry;
    });
  }

  Future<void> _syncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final submitter = sl<ClaimSubmitter>();
    setState(() => _syncing = true);
    try {
      final report = await submitter.drainOnce();
      await _load();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(report.toString())));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _reregister() async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionCubit>();
    final registrar = sl<DeviceRegistrar>();
    final userId = session.state.session?.userId;
    if (userId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in first to re-register')),
      );
      return;
    }
    setState(() => _reregistering = true);
    try {
      await registrar.ensureRegistered(userId: userId, force: true);
      await _load();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Device re-registered')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Re-register failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _reregistering = false);
    }
  }

  Future<void> _recoverOfflineFunds() async {
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionCubit>();
    final token = session.state.session?.accessToken;
    if (token == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in first to recover offline funds')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Recover offline funds?'),
        content: const Text(
          "Use this only if your offline wallet token was lost and you can't "
          'send offline payments. The lien stays locked for a few days so any '
          "offline payments you've already made can still settle. After that, "
          'the remaining amount returns to your main wallet automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Start recovery'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _recovering = true);
    try {
      final out = await sl<WalletRepository>().recoverOfflineCeiling(token);
      if (!mounted) return;
      await context.read<AppCubit>().beginCeilingRecovery(
            ceilingId: out.ceilingId,
            quarantinedKobo: out.quarantinedKobo,
            releaseAfter: out.releaseAfter,
          );
      await _load();
      if (!mounted) return;
      final releaseLocal = out.releaseAfter.toLocal();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            'Recovery started. '
            '${_formatNaira(out.quarantinedKobo)} will return to your main '
            'wallet by ${_formatShortDate(releaseLocal)}.',
          ),
        ),
      );
    } on RecoverOfflineRejected catch (e) {
      if (!mounted) return;
      final String msg;
      if (e.isUnsettledClaims) {
        msg = 'A payment you made is still being settled. Try again in a '
            'few minutes.';
      } else if (e.isNoActiveCeiling) {
        msg = "You don't have an active offline wallet to recover.";
      } else if (e.statusCode == 409) {
        msg = 'Recovery is already in progress.';
        unawaited(context.read<AppCubit>().reconcileCeilingStatus());
      } else {
        msg = 'Recovery failed: ${e.message}';
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't reach the server. Your recovery was not started. Try "
            'again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  String _recoverTileSubtitle(AppUiState state) {
    final recovering = state.recoveringCeiling;
    if (recovering != null) {
      final release = _formatShortDate(recovering.releaseAfter.toLocal());
      return 'Recovery in progress — ${_formatNaira(recovering.quarantinedKobo)} '
          'returns by $release';
    }
    if (_recovering) {
      return 'Starting recovery…';
    }
    if (state.activeCeiling == null) {
      return 'No active offline wallet to recover';
    }
    return 'Use if the offline wallet token was lost on this device';
  }

  VoidCallback? _recoverTileOnTap(AppUiState state) {
    if (_recovering) return null;
    if (state.recoveringCeiling != null) return null;
    if (state.activeCeiling == null) return null;
    return _recoverOfflineFunds;
  }

  static String _formatNaira(int kobo) =>
      '₦${(kobo / 100).toStringAsFixed(2)}';

  static String _formatShortDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$d/$m ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "We'll keep your device registered so signing back in is quick. "
          'Offline funds stay protected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SessionCubit>().logout();
  }

  Future<void> _confirmWipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Wipe local data?'),
        content: const Text(
          'Removes all on-device keys, queued transactions, and gossip '
          'blobs. Only use this when debugging — it is destructive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Wipe'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cubit = context.read<AppCubit>();
    await cubit.keystore.wipe();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local data wiped')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppCubit>().state;
    final session = context.watch<SessionCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _ProfileCard(session: session, online: state.online),
            const SizedBox(height: 20),
            const _SectionHeader('Security'),
            _Group(children: [
              _Tile(
                icon: Icons.verified_user_outlined,
                title: 'KYC & transaction limits',
                subtitle: 'View your tier and upgrade with BVN or NIN',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TiersScreen(),
                  ),
                ),
              ),
              const _TileDivider(),
              _Tile(
                icon: Icons.password,
                title: 'Transaction PIN',
                subtitle: 'Required before sending money',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SetPinScreen(),
                  ),
                ),
              ),
              const _TileDivider(),
              _Tile(
                icon: Icons.devices,
                title: 'Active sessions',
                subtitle: 'Review and revoke sessions on other devices',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SessionsScreen(),
                  ),
                ),
              ),
              const _TileDivider(),
              _Tile(
                icon: Icons.sync,
                title: 'Rotate device',
                subtitle: 'Move offline_pay to a new device',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Rotate device: requires online'),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _SectionHeader(
              'Offline health',
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
                onPressed: _load,
                visualDensity: VisualDensity.compact,
              ),
            ),
            _Group(children: [
              _HealthTile(
                icon: Icons.vpn_key,
                label: 'Realm key',
                value: _realmVersion == null
                    ? 'Missing'
                    : 'v$_realmVersion',
                ok: _realmVersion != null,
              ),
              const _TileDivider(),
              _HealthTile(
                icon: Icons.account_balance,
                label: 'Bank keys',
                value: _bankKeyCount == 0 ? 'Missing' : '$_bankKeyCount',
                ok: _bankKeyCount > 0,
              ),
              const _TileDivider(),
              _HealthTile(
                icon: Icons.hub_outlined,
                label: 'Gossip carry',
                value: '$_gossipPending / $_gossipMaxCarry '
                    '(uploaded $_gossipUploaded)',
                ok: true,
              ),
              const _TileDivider(),
              _QueueTile(
                queued: _queuedCount,
                pending: _pendingCount,
                settled: _settledCount,
                rejected: _rejectedCount,
                syncing: _syncing,
                onSync: _syncing ? null : _syncNow,
              ),
            ]),
            const SizedBox(height: 20),
            const _SectionHeader('Device'),
            _Group(children: [
              _HealthTile(
                icon: Icons.fingerprint,
                label: 'Device ID',
                value: _deviceId == null
                    ? 'Not registered'
                    : _truncate(_deviceId!),
                ok: _deviceId != null,
              ),
              const _TileDivider(),
              _Tile(
                icon: Icons.refresh,
                title: 'Re-register device',
                subtitle: session.deviceReady
                    ? 'Re-attest with the server'
                    : 'Device is not fully registered',
                trailing: _reregistering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _reregistering ? null : _reregister,
              ),
              const _TileDivider(),
              _Tile(
                icon: Icons.restore,
                title: 'Recover offline funds',
                subtitle: _recoverTileSubtitle(state),
                trailing: _recovering
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _recoverTileOnTap(state),
              ),
              const _TileDivider(),
              const _HealthTile(
                icon: Icons.shield_outlined,
                label: 'Attestation',
                value: 'Pending — Play Integrity / DeviceCheck TBD',
                ok: false,
              ),
            ]),
            const SizedBox(height: 28),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.logout),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Sign out'),
              ),
              onPressed: _confirmSignOut,
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Wipe local data (debug)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                onPressed: _confirmWipe,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _truncate(String id, {int head = 6, int tail = 6}) {
    if (id.length <= head + tail + 1) return id;
    return '${id.substring(0, head)}…${id.substring(id.length - tail)}';
  }
}

class _ProfileCard extends StatelessWidget {
  final SessionUiState session;
  final bool online;
  const _ProfileCard({required this.session, required this.online});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profile = session.profile;
    final accountNumber = profile?.accountNumber ?? '';
    final phone = profile?.phone ?? session.session?.userId ?? '';
    final initials =
        phone.length >= 2 ? phone.substring(phone.length - 2) : '👤';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              initials,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phone.isEmpty ? 'Signed in' : phone,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (accountNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: accountNumber),
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
                          accountNumber,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.copy,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ],
                if (profile?.kycTier != null) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TiersScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'KYC ${profile!.kycTier}',
                            style: TextStyle(
                              color: scheme.onSecondaryContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 12,
                            color: scheme.onSecondaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ConnectivityDot(online: online),
        ],
      ),
    );
  }
}

class _ConnectivityDot extends StatelessWidget {
  final bool online;
  const _ConnectivityDot({required this.online});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: online ? 'Online' : 'Offline',
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: online ? Colors.green : scheme.outlineVariant,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 2),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _SectionHeader(this.label, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(icon, color: scheme.primary, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      trailing: trailing ??
          (onTap == null
              ? null
              : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)),
    );
  }
}

class _HealthTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  const _HealthTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(
          icon,
          color: ok ? scheme.primary : scheme.outline,
          size: 18,
        ),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        value,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      trailing: Icon(
        ok ? Icons.check_circle : Icons.pending_outlined,
        color: ok ? Colors.green : scheme.outline,
        size: 18,
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final int queued;
  final int pending;
  final int settled;
  final int rejected;
  final bool syncing;
  final VoidCallback? onSync;
  const _QueueTile({
    required this.queued,
    required this.pending,
    required this.settled,
    required this.rejected,
    required this.syncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(Icons.queue, color: scheme.primary, size: 18),
      ),
      title: const Text(
        'Claim queue',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _QueuePill(
                label: 'Queued', value: queued, color: scheme.outlineVariant),
            _QueuePill(
                label: 'Pending',
                value: pending,
                color: scheme.tertiaryContainer),
            _QueuePill(
                label: 'Settled',
                value: settled,
                color: scheme.primaryContainer),
            _QueuePill(
                label: 'Rejected',
                value: rejected,
                color: scheme.errorContainer),
          ],
        ),
      ),
      trailing: syncing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: onSync,
              child: const Text('Sync'),
            ),
    );
  }
}

class _QueuePill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _QueuePill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
