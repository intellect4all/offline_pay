import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/cubits/app/app_cubit.dart';
import '../services/local_queue.dart';
import '../util/money.dart';
import '../util/time_format.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AppCubit>();
    final items = context.select<AppCubit, List<LocalTxn>>(
      (c) => c.state.activity,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: cubit.refreshAll,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  _EmptyState(),
                ],
              )
            : _GroupedList(items: items),
      ),
    );
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
            Icon(Icons.receipt_long_outlined,
                size: 64, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Your sent, received, and offline transactions will show up here.',
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

class _GroupedList extends StatelessWidget {
  final List<LocalTxn> items;
  const _GroupedList({required this.items});

  List<_Section> _group(List<LocalTxn> rows) {
    final now = DateTime.now();
    final sections = <String, List<LocalTxn>>{};
    final order = <String>[];
    for (final r in rows) {
      final key = dayGroup(r.createdAt, now: now);
      final list = sections.putIfAbsent(key, () {
        order.add(key);
        return <LocalTxn>[];
      });
      list.add(r);
    }
    return [
      for (final k in order) _Section(label: k, rows: sections[k]!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _group(items);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        for (final section in sections) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                section.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          SliverList.separated(
            itemCount: section.rows.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
            ),
            itemBuilder: (_, i) => _Row(txn: section.rows[i]),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _Section {
  final String label;
  final List<LocalTxn> rows;
  const _Section({required this.label, required this.rows});
}

class _Row extends StatelessWidget {
  final LocalTxn txn;
  const _Row({required this.txn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sent = txn.direction == TxnDirection.sent;
    final icon = sent ? Icons.arrow_upward : Icons.arrow_downward;
    final sign = sent ? '-' : '+';
    final amountColor = sent ? scheme.error : scheme.primary;
    final counterId = sent ? txn.payeeId : txn.payerId;
    final counterName = txn.counterDisplayName;
    final hasName = counterName != null && counterName.trim().isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(icon, color: amountColor, size: 20),
      ),
      title: Text(
        hasName ? counterName : _truncate(counterId),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          _StateChip(state: txn.state),
          const SizedBox(width: 8),
          Text(
            shortRelative(txn.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sign${formatNaira(txn.amountKobo)}',
            style: TextStyle(color: amountColor, fontWeight: FontWeight.w600),
          ),
          if (txn.state == TxnState.partiallySettled &&
              txn.settledAmountKobo != null &&
              txn.settledAmountKobo != txn.amountKobo)
            Text(
              'settled ${formatNaira(txn.settledAmountKobo!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      onTap: () => _showDetails(context, txn),
    );
  }

  void _showDetails(BuildContext context, LocalTxn t) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.direction == TxnDirection.sent ? 'Sent' : 'Received',
              style: Theme.of(sheetCtx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _Detail(label: 'Amount', value: formatNaira(t.amountKobo)),
            if (t.settledAmountKobo != null)
              _Detail(
                label: 'Settled',
                value: formatNaira(t.settledAmountKobo!),
              ),
            _Detail(label: 'State', value: txnStateLabel(t.state)),
            if (t.counterDisplayName != null &&
                t.counterDisplayName!.trim().isNotEmpty)
              _Detail(
                label: t.direction == TxnDirection.sent ? 'To' : 'From',
                value: t.counterDisplayName!,
              ),
            _Detail(
                label: t.direction == TxnDirection.sent ? 'Account' : 'Account',
                value: t.direction == TxnDirection.sent ? t.payeeId : t.payerId),
            _Detail(label: 'Sequence', value: '${t.sequenceNumber}'),
            _Detail(
                label: 'Created', value: t.createdAt.toLocal().toString()),
            if (t.rejectionReason != null)
              _Detail(label: 'Reason', value: t.rejectionReason!),
          ],
        ),
      ),
    );
  }

  static String _truncate(String s, {int max = 28}) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}…';
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  const _Detail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final TxnState state;
  const _StateChip({required this.state});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (state) {
      TxnState.queued =>
        (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      TxnState.submitted =>
        (scheme.secondaryContainer, scheme.onSecondaryContainer),
      TxnState.pending =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      TxnState.settled =>
        (scheme.primaryContainer, scheme.onPrimaryContainer),
      TxnState.partiallySettled =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      TxnState.rejected => (scheme.errorContainer, scheme.onErrorContainer),
      TxnState.expired => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        txnStateLabel(state),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
