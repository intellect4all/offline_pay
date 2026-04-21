import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../util/haptics.dart';

class PinDotsField extends StatefulWidget {
  final int length;
  final bool enabled;
  final bool autofocus;
  final void Function(String) onChanged;
  final VoidCallback? onSubmit;

  const PinDotsField({
    super.key,
    this.length = 6,
    this.enabled = true,
    this.autofocus = true,
    required this.onChanged,
    this.onSubmit,
  });

  @override
  State<PinDotsField> createState() => _PinDotsFieldState();
}

class _PinDotsFieldState extends State<PinDotsField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _lastLen = 0;

  void _handleChange(String v) {
    if (v.length > _lastLen) Haptics.selection();
    _lastLen = v.length;
    widget.onChanged(v);
    if (v.length >= widget.length && widget.onSubmit != null) {
      widget.onSubmit!();
    }
    setState(() {});
  }

  void clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < widget.length; i++)
                _PinBox(
                  filled: i < _controller.text.length,
                  active: i == _controller.text.length && widget.enabled,
                  scheme: scheme,
                ),
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: widget.length,
                obscureText: true,
                showCursor: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                onChanged: _handleChange,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinBox extends StatelessWidget {
  final bool filled;
  final bool active;
  final ColorScheme scheme;
  const _PinBox({
    required this.filled,
    required this.active,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 44,
      height: 52,
      decoration: BoxDecoration(
        color: filled ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
          width: active ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: filled
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: scheme.onPrimaryContainer,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
