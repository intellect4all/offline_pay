import 'package:flutter/material.dart';

class AuthShell extends StatelessWidget {
  final List<Widget> children;

  final Widget? footer;

  final List<Widget>? appBarActions;

  final String? appBarTitle;

  final bool showAppBar;

  const AuthShell({
    super.key,
    required this.children,
    this.footer,
    this.appBarActions,
    this.appBarTitle,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: appBarTitle == null ? null : Text(appBarTitle!),
              centerTitle: false,
              actions: appBarActions,
            )
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, constraints) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                          maxWidth: 520,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              ...children,
                              const Spacer(),
                              if (footer != null) ...[
                                const SizedBox(height: 16),
                                footer!,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthHero extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final bool compact;

  const AuthHero({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: compact ? 56 : 72,
            height: compact ? 56 : 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compact ? 28 : 36,
              color: scheme.onPrimaryContainer,
            ),
          ),
          SizedBox(height: compact ? 12 : 20),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.bolt, color: scheme.onPrimary, size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          'offline_pay',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
        ),
      ],
    );
  }
}

class AuthInlineMessage extends StatelessWidget {
  final String message;
  final bool isError;
  const AuthInlineMessage({
    super.key,
    required this.message,
    this.isError = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isError ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = isError ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fg, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
