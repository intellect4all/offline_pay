import 'dart:async';
import 'dart:convert' show base64;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/di/service_locator.dart';
import '../nfc/nfc_receive_transport.dart';
import '../presentation/cubits/app/app_cubit.dart';
import '../presentation/cubits/app/app_state.dart';
import '../services/payment_verifier.dart';
import '../services/qr_receiver.dart';
import '../services/receive_coordinator.dart';
import '../util/haptics.dart';
import '../util/money.dart';
import '../widgets/animated_check.dart';
import '../widgets/app_bar_hero_icon.dart';
import '../widgets/pulse_ring.dart';
import 'receive_nfc.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});
  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

enum _ReceiveStep { showingInvoice, scanningPayment }

class _ReceiveScreenState extends State<ReceiveScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  QrReceiver? _receiver;
  StreamSubscription<VerifiedPayment>? _completedSub;
  StreamSubscription<VerifyException>? _failuresSub;

  final TextEditingController _amountCtrl = TextEditingController();
  bool _issuing = false;

  _ReceiveStep _step = _ReceiveStep.showingInvoice;

  VerifiedPayment? _lastSuccess;
  String? _lastError;
  int _framesSeen = 0;
  int? _totalFrames;

  NfcReceiveTransport? _nfc;
  StreamSubscription<Uint8List>? _nfcSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    unawaited(_completedSub?.cancel());
    unawaited(_failuresSub?.cancel());
    unawaited(_receiver?.dispose());
    unawaited(_nfcSub?.cancel());
    unawaited(_nfc?.stop());
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    if (state == AppLifecycleState.resumed) {
      if (_step == _ReceiveStep.scanningPayment) {
        unawaited(c.start());
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(c.stop());
    }
  }

  Future<void> _startScanner() async {
    _controller ??= MobileScannerController();
    try {
      await _controller!.start();
    } catch (_) {
    }
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    unawaited(() async {
      try {
        await c.stop();
      } catch (_) {}
      await c.dispose();
    }());
  }

  int? _amountKobo() {
    final txt = _amountCtrl.text.trim();
    if (txt.isEmpty) return 0;
    final naira = double.tryParse(txt);
    if (naira == null || naira < 0) return null;
    return (naira * 100).round();
  }

  Future<void> _issueInvoice(AppCubit cubit) async {
    if (_issuing) return;
    final state = cubit.state;
    final userId = state.userId;
    final card = state.displayCard;
    if (userId == null || card == null) {
      setState(() => _lastError =
          'Missing identity — sign in and fetch your display card');
      return;
    }
    final amount = _amountKobo();
    if (amount == null) {
      setState(() => _lastError = 'Invalid amount');
      return;
    }
    setState(() {
      _step = _ReceiveStep.showingInvoice;
      _issuing = true;
      _lastError = null;
    });
    try {
      final active = await sl<ReceiveCoordinator>().issue(
        receiverUserId: userId,
        displayCard: card,
        amountKobo: amount,
        realmKey: cubit.activeRealmKey,
        realmKeyVersion: cubit.activeRealmKeyVersion,
      );
      cubit.setActiveRequest(active);
    } catch (e) {
      setState(() => _lastError = 'Failed to issue invoice: $e');
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  void _ensureReceiver(AppCubit cubit) {
    if (_receiver != null) return;
    final selfUserId = cubit.state.userId;
    if (selfUserId == null) return;
    _receiver = QrReceiver(
      verifier: sl<PaymentVerifier>(),
      selfUserId: selfUserId,
    );
    _completedSub = _receiver!.completed.listen(_onVerified);
    _failuresSub = _receiver!.failures.listen(_onFailure);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AppCubit>();
    final state = cubit.state;
    _ensureReceiver(cubit);
    final nfcAvailable = NfcReceiveTransport.isAvailable;
    final selected = state.preferredChannel;
    _syncNfcLifecycle(cubit);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset',
            onPressed: _reset,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: Hero(
                tag: 'hero-receive',
                child: AppBarHeroIcon(icon: Icons.qr_code_scanner),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<PaymentChannel>(
                segments: [
                  const ButtonSegment(
                    value: PaymentChannel.qr,
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('Scan QR'),
                  ),
                  ButtonSegment(
                    value: PaymentChannel.nfc,
                    icon: const Icon(Icons.nfc),
                    label: const Text('Tap'),
                    enabled: nfcAvailable,
                  ),
                ],
                selected: {selected},
                onSelectionChanged: (s) {
                  cubit.setPreferredChannel(s.first);
                  _reset();
                },
              ),
            ),
            Expanded(
              child: _body(cubit, state, selected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppCubit cubit, AppUiState state, PaymentChannel selected) {
    if (_lastSuccess != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _SuccessView(
          verified: _lastSuccess!,
          onDone: () => Navigator.of(context).maybePop(),
          onScanAnother: _reset,
        ),
      );
    }
    if (selected == PaymentChannel.nfc) {
      return Column(
        children: [
          const _NfcIdleView(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _StatusView(
                framesSeen: _framesSeen,
                totalFrames: _totalFrames,
                error: _lastError,
              ),
            ),
          ),
        ],
      );
    }
    final active = state.activeRequest;
    if (active == null) {
      return _InvoiceComposer(
        amountCtrl: _amountCtrl,
        busy: _issuing,
        error: _lastError,
        hasDisplayCard: state.displayCard != null,
        onShow: () => _issueInvoice(cubit),
      );
    }
    final onCancel = () {
      cubit.clearActiveRequest();
      _reset();
    };
    switch (_step) {
      case _ReceiveStep.showingInvoice:
        return _InvoiceShowView(
          active: active,
          onCancel: onCancel,
          onScanPayment: () {
            setState(() => _step = _ReceiveStep.scanningPayment);
            unawaited(_startScanner());
          },
        );
      case _ReceiveStep.scanningPayment:
        final c = _controller;
        if (c == null) {
          unawaited(_startScanner().then((_) {
            if (mounted) setState(() {});
          }));
          return const Center(child: CircularProgressIndicator());
        }
        return _PaymentScanView(
          active: active,
          controller: c,
          framesSeen: _framesSeen,
          totalFrames: _totalFrames,
          error: _lastError,
          onBack: () {
            _disposeController();
            setState(() => _step = _ReceiveStep.showingInvoice);
          },
          onCancel: () {
            _disposeController();
            onCancel();
          },
          onDetect: (capture) {
            final r = _receiver;
            if (r == null) return;
            r.ingest(capture);
            setState(() {
              _framesSeen = r.framesReceived;
              _totalFrames = r.totalFrames;
            });
          },
        );
    }
  }

  void _onVerified(VerifiedPayment v) {
    if (!mounted) return;
    Haptics.success();
    final cubit = context.read<AppCubit>();
    cubit.clearActiveRequest();
    unawaited(cubit.refreshLocal());
    setState(() {
      _lastSuccess = v;
      _lastError = null;
    });
  }

  void _onFailure(VerifyException err) {
    if (!mounted) return;
    Haptics.error();
    debugPrint('verify failed: ${err.reason.name}: ${err.detail}');
    setState(() {
      _lastError = _humanize(err);
    });
    _receiver?.reset();
  }

  String _humanize(VerifyException err) {
    switch (err.reason) {
      case VerifyFailure.signature:
        return 'Signature invalid — possible tampering';
      case VerifyFailure.sequence:
        return 'Duplicate or replayed payment';
      case VerifyFailure.expired:
        return 'Ceiling token expired';
      case VerifyFailure.insufficient:
        return 'Remaining ceiling negative';
      case VerifyFailure.ceilingMissing:
        return 'Missing ceiling token; ask payer to refresh';
      case VerifyFailure.decrypt:
        return 'Decrypt failed — different realm key';
      case VerifyFailure.reassemble:
        return 'Frame reassembly failed — keep scanning';
      case VerifyFailure.selfPay:
        return 'Self-pay rejected';
      case VerifyFailure.unknownKeyVersion:
        return 'Unknown realm key version — update required';
      case VerifyFailure.noActiveRequest:
        return 'No active invoice — issue one before the payer scans';
      case VerifyFailure.requestMismatch:
        return 'Payment does not match the shown invoice';
      case VerifyFailure.amountMismatch:
        return 'Paid amount differs from the invoice';
    }
  }

  void _reset() {
    _receiver?.reset();
    _disposeController();
    setState(() {
      _lastSuccess = null;
      _lastError = null;
      _framesSeen = 0;
      _totalFrames = null;
      _step = _ReceiveStep.showingInvoice;
    });
  }

  void _syncNfcLifecycle(AppCubit cubit) {
    final wantNfc = cubit.state.preferredChannel == PaymentChannel.nfc &&
        NfcReceiveTransport.isAvailable;
    if (wantNfc && _nfc == null) {
      final n = NfcReceiveTransport();
      _nfc = n;
      _nfcSub = n.envelopes.listen((wire) => _handleSealedWire(cubit, wire));
      n.start().catchError((Object e) {
        if (!mounted) return;
        setState(() => _lastError = 'NFC unavailable: $e');
      });
    } else if (!wantNfc && _nfc != null) {
      final n = _nfc;
      final s = _nfcSub;
      _nfc = null;
      _nfcSub = null;
      unawaited(s?.cancel());
      unawaited(n?.stop());
    }
  }

  Future<void> _handleSealedWire(AppCubit cubit, Uint8List wire) async {
    final result = await handleNfcSealedWire(cubit, wire);
    if (!mounted) return;
    setState(() {
      _lastSuccess = result.success;
      _lastError = result.error;
    });
  }
}

class _ScannerFrame extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  const _ScannerFrame({required this.controller, required this.onDetect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: MobileScanner(
                controller: controller,
                onDetect: onDetect,
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _ScannerCornersPainter(color: scheme.primary),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerCornersPainter extends CustomPainter {
  final Color color;
  _ScannerCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const inset = 20.0;
    const armLen = 28.0;
    canvas.drawLine(
      const Offset(inset, inset + armLen),
      const Offset(inset, inset),
      paint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + armLen, inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset - armLen, inset),
      Offset(size.width - inset, inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + armLen),
      paint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset - armLen),
      Offset(inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + armLen, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - armLen),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset - armLen, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerCornersPainter old) =>
      old.color != color;
}

class _NfcIdleView extends StatelessWidget {
  const _NfcIdleView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PulseRing(
              size: 72,
              color: scheme.primary,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nfc,
                  size: 36,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Hold the payer's phone against this device",
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

class _StatusView extends StatelessWidget {
  final int framesSeen;
  final int? totalFrames;
  final String? error;
  const _StatusView({
    required this.framesSeen,
    required this.totalFrames,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = totalFrames == null || totalFrames == 0
        ? null
        : (framesSeen / totalFrames!).clamp(0.0, 1.0);
    final headline = error ??
        (framesSeen == 0
            ? "Point at a payer's animated QR…"
            : 'Reading frames…');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          headline,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: error != null ? scheme.error : null,
              ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        if (totalFrames != null) ...[
          const SizedBox(height: 6),
          Text(
            '$framesSeen / $totalFrames frames',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VerifiedPayment verified;
  final VoidCallback onDone;
  final VoidCallback onScanAnother;
  const _SuccessView({
    required this.verified,
    required this.onDone,
    required this.onScanAnother,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const AnimatedCheck(size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Queued for settlement',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatNaira(verified.amountKobo),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _KeyRow(label: 'From', value: verified.payerId),
        _KeyRow(label: 'Sequence', value: '${verified.sequenceNumber}'),
        _KeyRow(
          label: 'Ceiling',
          value: _short(verified.ceilingTokenId),
        ),
        _KeyRow(
          label: 'Transaction',
          value: _short(verified.transactionId),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                onPressed: onDone,
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Done'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: onScanAnother,
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Scan another'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _short(String s) {
    if (s.length <= 16) return s;
    return '${s.substring(0, 8)}…${s.substring(s.length - 6)}';
  }
}

class _KeyRow extends StatelessWidget {
  final String label;
  final String value;
  const _KeyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
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
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceComposer extends StatelessWidget {
  final TextEditingController amountCtrl;
  final bool busy;
  final String? error;
  final bool hasDisplayCard;
  final VoidCallback onShow;

  const _InvoiceComposer({
    required this.amountCtrl,
    required this.busy,
    required this.error,
    required this.hasDisplayCard,
    required this.onShow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invoice the payer',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            hasDisplayCard
                ? "Enter the amount you're collecting. Leave 0 to let the "
                    'payer enter it themselves.'
                : 'Your identity card is missing — sign in again to fetch it.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: amountCtrl,
            enabled: hasDisplayCard && !busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (₦)',
              hintText: '0.00',
              prefixText: '₦  ',
              border: const OutlineInputBorder(),
              errorText: error,
            ),
            autofocus: true,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_2),
            onPressed: hasDisplayCard && !busy ? onShow : null,
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Show invoice'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceShowView extends StatefulWidget {
  final ActiveRequest active;
  final VoidCallback onScanPayment;
  final VoidCallback onCancel;

  const _InvoiceShowView({
    required this.active,
    required this.onScanPayment,
    required this.onCancel,
  });

  @override
  State<_InvoiceShowView> createState() => _InvoiceShowViewState();
}

class _InvoiceShowViewState extends State<_InvoiceShowView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  int _frameIdx = 0;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _frameIdx++);
          _tick.forward(from: 0);
        }
      });
    if (widget.active.qrFrames.length > 1) {
      _tick.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _InvoiceShowView old) {
    super.didUpdateWidget(old);
    if (old.active.sessionNonce != widget.active.sessionNonce) {
      _frameIdx = 0;
      if (widget.active.qrFrames.length > 1 && !_tick.isAnimating) {
        _tick.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.active.qrFrames;
    final scheme = Theme.of(context).colorScheme;
    final frame = frames.isEmpty
        ? Uint8List(0)
        : frames[_frameIdx % frames.length];
    final qrData = base64.encode(frame);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.active.amountKobo == 0
                ? 'Payer will enter the amount'
                : 'Asking for ${formatNaira(widget.active.amountKobo)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Step 1 of 2 — show this invoice to the payer',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    gapless: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: widget.onScanPayment,
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Scan payment'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.close),
            onPressed: widget.onCancel,
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentScanView extends StatelessWidget {
  final ActiveRequest active;
  final MobileScannerController controller;
  final int framesSeen;
  final int? totalFrames;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final void Function(BarcodeCapture) onDetect;

  const _PaymentScanView({
    required this.active,
    required this.controller,
    required this.framesSeen,
    required this.totalFrames,
    required this.error,
    required this.onBack,
    required this.onCancel,
    required this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            active.amountKobo == 0
                ? "Scanning payer's QR"
                : 'Collecting ${formatNaira(active.amountKobo)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Step 2 of 2 — scan the payer’s QR',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          _ScannerFrame(
            controller: controller,
            onDetect: onDetect,
          ),
          const SizedBox(height: 12),
          _StatusView(
            framesSeen: framesSeen,
            totalFrames: totalFrames,
            error: error,
          ),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Back to invoice'),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
            label: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
