import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/service_locator.dart';
import '../presentation/cubits/session/session_cubit.dart';
import '../repositories/auth_repository.dart';
import '../util/time_format.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<UserSession> _sessions = const <UserSession>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  AuthRepository get _repo => sl<AuthRepository>();
  String? get _accessToken =>
      context.read<SessionCubit>().state.session?.accessToken;

  Future<void> _load() async {
    final token = _accessToken;
    if (token == null) {
      setState(() {
        _error = 'Not signed in';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.listSessions(token);
      if (!mounted) return;
      setState(() {
        _sessions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load sessions: $e';
        _loading = false;
      });
    }
  }

  Future<void> _revoke(UserSession s) async {
    final token = _accessToken;
    if (token == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke session?'),
        content: Text(
          'The device "${s.deviceId ?? s.id}" will be signed out the next '
          'time it refreshes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await _repo.revokeSession(s.id, token);
      messenger.showSnackBar(
        const SnackBar(content: Text('Session revoked')),
      );
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Revoke failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeAllOthers() async {
    final token = _accessToken;
    if (token == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out all other devices?'),
        content: const Text(
          'This will revoke every session except this one. Other devices '
          'will be signed out the next time they refresh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out others'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final n = await _repo.revokeAllOtherSessions(token);
      messenger.showSnackBar(
        SnackBar(content: Text('Revoked $n other session(s)')),
      );
      await _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Revoke failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOther = _sessions.any((s) => !s.isCurrent);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active sessions'),
        centerTitle: false,
        actions: [
          PopupMenuButton<_SessionsAction>(
            enabled: !_loading && !_busy,
            onSelected: (a) {
              switch (a) {
                case _SessionsAction.refresh:
                  _load();
                  break;
                case _SessionsAction.signOutOthers:
                  _revokeAllOthers();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _SessionsAction.refresh,
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _SessionsAction.signOutOthers,
                enabled: hasOther,
                child: const ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign out others'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Builder(builder: (_) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(child: Text(_error!)),
              ],
            );
          }
          if (_sessions.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                _EmptyState(),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _SessionTile(
              session: _sessions[i],
              busy: _busy,
              onRevoke: () => _revoke(_sessions[i]),
            ),
          );
        }),
      ),
    );
  }
}

enum _SessionsAction { refresh, signOutOthers }

class _SessionTile extends StatelessWidget {
  final UserSession session;
  final bool busy;
  final VoidCallback onRevoke;
  const _SessionTile({
    required this.session,
    required this.busy,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ua = session.userAgent.isEmpty
        ? 'Unknown client'
        : _shortUserAgent(session.userAgent);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: session.isCurrent
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: session.isCurrent
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            child: Icon(
              session.isCurrent ? Icons.smartphone : Icons.devices,
              color: session.isCurrent
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.deviceId ?? _short(session.id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (session.isCurrent)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'This device',
                          style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ua,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: session.isCurrent
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    'Signed in ${shortRelative(session.createdAt)}',
                    if (session.ip.isNotEmpty) session.ip,
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: session.isCurrent
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!session.isCurrent)
            TextButton(
              onPressed: busy ? null : onRevoke,
              child: const Text('Revoke'),
            ),
        ],
      ),
    );
  }

  static String _short(String s) {
    if (s.length <= 12) return s;
    return '${s.substring(0, 6)}…${s.substring(s.length - 4)}';
  }

  static String _shortUserAgent(String ua) {
    final idx = ua.indexOf(' ');
    if (idx < 0 || idx > 40) return ua.length > 40 ? '${ua.substring(0, 40)}…' : ua;
    return ua.substring(0, idx);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            Icon(Icons.devices_other,
                size: 64, color: scheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No active sessions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Sign in on another device and it will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
