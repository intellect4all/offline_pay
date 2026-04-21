import 'dart:async';
import 'dart:convert' show base64;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app.dart' show TabIndex;
import '../core/di/service_locator.dart';
import '../nfc/nfc_send_transport.dart';
import '../presentation/cubits/app/app_cubit.dart';
import '../presentation/cubits/app/app_state.dart';
import '../services/gossip_pool.dart';
import '../services/local_queue.dart';
import '../util/haptics.dart';
import '../util/money.dart';
import '../util/txn_id.dart';
import '../widgets/app_bar_hero_icon.dart';
import '../widgets/pulse_ring.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});
  @override
  State<SendScreen> createState() => _SendScreenState();
}

enum _SendMode { compose, scanning, confirming, showing, tapping }

class _SendScreenState extends State<SendScreen> with WidgetsBindingObserver {
  final _amountCtrl = TextEditingController();
  int? _kobo;
  _SendMode _mode = _SendMode.compose;
  List<Uint8List> _encodedFrames = const [];
  int _frameIdx = 0;
  Timer? _timer;
  NfcSendTransport? _nfc;

  MobileScannerController? _scanner;
  Reassembler _prReassembler = Reassembler();
  int _scanFramesSeen = 0;
  int? _scanTotalFrames;
  String? _scanError;

  PaymentRequest? _scannedRequest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountCtrl.dispose();
    _timer?.cancel();
    _disposeScanner();
    unawaited(_nfc?.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = _scanner;
    if (s == null) return;
    if (state == AppLifecycleState.resumed) {
      if (_mode == _SendMode.scanning) {
        unawaited(s.start());
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(s.stop());
    }
  }

  void _disposeScanner() {
    final s = _scanner;
    _scanner = null;
    if (s == null) return;
    unawaited(() async {
      try {
        await s.stop();
      } catch (_) {}
      await s.dispose();
    }());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppCubit>().state;
    final ceiling = state.activeCeiling;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline pay'),
        centerTitle: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: Hero(
                tag: 'hero-offline-pay',
                child: AppBarHeroIcon(icon: Icons.qr_code_2),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _bodyForMode(state, ceiling)),
    );
  }

  Widget _bodyForMode(AppUiState state, ActiveCeiling? ceiling) {
    if (ceiling == null) return _NoCeilingView(online: state.online);
    switch (_mode) {
      case _SendMode.showing:
        return _QrDisplay(
          frames: _encodedFrames,
          frameIdx: _frameIdx,
          onDone: _stopQr,
        );
      case _SendMode.tapping:
        return _TappingView(
          apduCount: _nfc?.stagedResponses.length ?? 0,
          onCancel: _stopTap,
        );
      case _SendMode.scanning:
        return _InvoiceScanView(
          controller: _scanner!,
          framesSeen: _scanFramesSeen,
          totalFrames: _scanTotalFrames,
          error: _scanError,
          onDetect: _onScanFrames,
          onCancel: _cancelScan,
        );
      case _SendMode.confirming:
        return _InvoiceConfirmView(
          request: _scannedRequest!,
          remainingKobo: state.offlineRemainingKobo,
          amountCtrl: _amountCtrl,
          onAmountChanged: (v) => setState(() => _kobo = parseNairaToKobo(v)),
          onCancel: _cancelScan,
          onAuthorize: () => _authorizeFromRequest(state, ceiling),
        );
      case _SendMode.compose:
        return _ComposeView(
          remaining: state.offlineRemainingKobo,
          onScanInvoice: _startScan,
        );
    }
  }

  void _startScan() {
    _scanner ??= MobileScannerController();
    _prReassembler = Reassembler();
    unawaited(_scanner!.start());
    setState(() {
      _mode = _SendMode.scanning;
      _scanError = null;
      _scanFramesSeen = 0;
      _scanTotalFrames = null;
    });
  }

  void _cancelScan() {
    _prReassembler = Reassembler();
    _disposeScanner();
    setState(() {
      _mode = _SendMode.compose;
      _scannedRequest = null;
      _scanError = null;
    });
  }

  Future<void> _onScanFrames(BarcodeCapture capture) async {
    final cubit = context.read<AppCubit>();
    var accepted = 0;
    for (final bc in capture.barcodes) {
      final raw = _decodeBase64(bc.rawValue) ?? bc.rawBytes;
      if (raw == null) continue;
      try {
        _prReassembler.accept(decodeFrame(Uint8List.fromList(raw)));
        accepted++;
      } on QrFrameException {
        continue;
      }
    }
    if (accepted > 0) setState(() => _scanFramesSeen += accepted);
    if (!_prReassembler.complete()) return;

    try {
      final wire = reassembleRequestWire(_prReassembler);
      if (wire == null) {
        setState(() => _scanError = 'Scanned QR was not a payment request');
        return;
      }
      final opened = await openRequestFromWire(
        wire,
        (v) => cubit.realmKeyForVersion(v),
      );
      final ok = await verifyRequest(
        opened.request.payload.receiverDevicePubkey,
        opened.request.payload,
        opened.request.receiverSignature,
      );
      if (!ok) {
        setState(() => _scanError = 'Receiver signature invalid');
        return;
      }
      if (opened.request.payload.expiresAt.isBefore(DateTime.now().toUtc())) {
        setState(() => _scanError = 'Invoice expired — ask the merchant to re-issue');
        return;
      }
      _disposeScanner();
      setState(() {
        _scannedRequest = opened.request;
        _scanError = null;
        _mode = _SendMode.confirming;
        if (opened.request.payload.amount != unboundAmount) {
          _kobo = opened.request.payload.amount;
          _amountCtrl.text = (opened.request.payload.amount / 100)
              .toStringAsFixed(2);
        } else {
          _kobo = null;
          _amountCtrl.clear();
        }
      });
    } catch (e) {
      setState(() => _scanError = 'Failed to read invoice: $e');
    }
  }

  Future<void> _authorizeFromRequest(
    AppUiState state,
    ActiveCeiling ceiling,
  ) async {
    final pr = _scannedRequest;
    if (pr == null) {
      print("pr == null in _authorizeFromRequest");
      return;
    }
    final userId = state.userId;
    if (userId == null) {
      print("user == null in _authorizeFromRequest");
      return;
    }
    if (pr.payload.receiverId == userId) {
      Haptics.error();
      _showError('Self-pay is not allowed.');
      return;
    }
    final prAmount = pr.payload.amount;
    final kobo = prAmount == unboundAmount ? _kobo : prAmount;
    if (kobo == null || kobo <= 0) {
      _showError('Enter an amount');
      return;
    }
    final remaining = state.offlineRemainingKobo;
    if (kobo > remaining) {
      _showError('Exceeds offline remaining (${formatNaira(remaining)}).');
      return;
    }
    await _mintAndShow(
      userId: userId,
      ceiling: ceiling,
      request: pr,
      kobo: kobo,
    );
  }

  Future<void> _mintAndShow({
    required String userId,
    required ActiveCeiling ceiling,
    required PaymentRequest request,
    required int kobo,
  }) async {
    final cubit = context.read<AppCubit>();
    final keyPair = await cubit.keystore.loadKeyPair();
    final remaining = cubit.state.offlineRemainingKobo - kobo;
    final seq = await cubit.queue.nextSequenceNumber(
      ceiling.id,
      ceiling.sequenceStart,
    );
    final nonce = request.payload.sessionNonce;
    final hash = await hashRequest(request);

    final payload = PaymentPayload(
      payerId: userId,
      payeeId: request.payload.receiverId,
      amount: kobo,
      sequenceNumber: seq,
      remainingCeiling: remaining,
      timestamp: DateTime.now().toUtc(),
      ceilingTokenId: ceiling.id,
      sessionNonce: nonce,
      requestHash: hash,
    );
    final sig = await signPayment(keyPair, payload);
    final token = PaymentToken(payload: payload, payerSignature: sig);

    final paymentBytes = canonicalize(token.toJson());
    final transactionId = await deriveTransactionId(paymentBytes);

    final blobs = await _drawGossipBlobs(userId);

    final envelope = GossipEnvelope(
      paymentToken: token,
      ceiling: EnvelopeCeiling(
        id: ceiling.id,
        payload: CeilingTokenPayload(
          payerId: userId,
          ceilingAmount: ceiling.ceilingKobo,
          issuedAt: ceiling.issuedAt,
          expiresAt: ceiling.expiresAt,
          sequenceStart: ceiling.sequenceStart,
          payerPublicKey: ceiling.payerPublicKey,
          bankKeyId: ceiling.bankKeyId,
        ),
        bankSignature: ceiling.bankSignature,
      ),
      blobs: blobs,
      payerDisplayCard: cubit.state.displayCard,
    );
    final sealed = await sealEnvelopeToWire(
      envelope: envelope,
      realmKey: cubit.activeRealmKey,
      keyVersion: cubit.activeRealmKeyVersion,
    );

    final requestBytes = canonicalize(request.toJson());

    final txn = LocalTxn(
      id: transactionId,
      direction: TxnDirection.sent,
      payerId: userId,
      payeeId: request.payload.receiverId,
      amountKobo: kobo,
      sequenceNumber: seq,
      ceilingTokenId: ceiling.id,
      state: TxnState.queued,
      createdAt: DateTime.now().toUtc(),
      submittedAt: null,
      settledAt: null,
      rejectionReason: null,
      paymentTokenBlob: base64.encode(paymentBytes),
      ceilingTokenBlob: ceiling.ceilingTokenBlob,
      requestBlob: base64.encode(requestBytes),
      counterDisplayName:
          request.payload.receiverDisplayCard.payload.displayName,
    );
    await cubit.queue.enqueueSent(txn);
    await _sealOwnBlobForPool(
      userId: userId,
      ceiling: ceiling,
      token: token,
      request: request,
    );
    await cubit.refreshLocal();
    if (!mounted) return;

    Haptics.success();
    if (cubit.state.preferredChannel == PaymentChannel.nfc &&
        NfcSendTransport.isAvailable) {
      await _startNfc(sealed.wireBytes);
    } else {
      _startQr(sealed.wireBytes);
    }
  }

  static const int _gossipPiggybackBudgetBytes = 1500;
  static const int _gossipDrawCount = 5;

  Future<void> _sealOwnBlobForPool({
    required String userId,
    required ActiveCeiling ceiling,
    required PaymentToken token,
    required PaymentRequest request,
  }) async {
    final cubit = context.read<AppCubit>();
    try {
      final serverPubkey = await cubit.keystore.readSealedBoxPubkey();
      if (serverPubkey == null || serverPubkey.isEmpty) {
        debugPrint(
            'gossip.sealOwnBlob: skipped — no cached server sealed-box pubkey');
        return;
      }
      final GossipPool pool;
      try {
        pool = sl<GossipPool>();
      } catch (e) {
        debugPrint('gossip.sealOwnBlob: skipped — GossipPool not registered: $e');
        return;
      }
      final inner = GossipInnerPayload(
        ceiling: CeilingTokenWire(
          id: ceiling.id,
          payload: CeilingTokenPayload(
            payerId: userId,
            ceilingAmount: ceiling.ceilingKobo,
            issuedAt: ceiling.issuedAt,
            expiresAt: ceiling.expiresAt,
            sequenceStart: ceiling.sequenceStart,
            payerPublicKey: ceiling.payerPublicKey,
            bankKeyId: ceiling.bankKeyId,
          ),
          bankSignature: ceiling.bankSignature,
        ),
        payment: token,
        request: request,
        senderUserId: request.payload.receiverId,
      );
      final sealed = await sealGossipBlobs([inner], serverPubkey);
      if (sealed.isEmpty) {
        debugPrint('gossip.sealOwnBlob: sealGossipBlobs returned empty');
        return;
      }
      await pool.ingest(
        sealed.first,
        selfUserId: userId,
        originUserId: userId,
        payerId: userId,
        sequenceNumber: token.payload.sequenceNumber,
      );
      debugPrint('gossip.sealOwnBlob: ingested seq=${token.payload.sequenceNumber} '
          'ceiling=${ceiling.id} receiver=${request.payload.receiverId} '
          'blob_size=${sealed.first.blobSize}');
    } catch (e, st) {
      debugPrint('gossip.sealOwnBlob failed: $e\n$st');
    }
  }

  Future<List<GossipBlob>> _drawGossipBlobs(String selfUserId) async {
    final GossipPool pool;
    try {
      pool = sl<GossipPool>();
    } catch (_) {
      return const [];
    }
    try {
      final drawn = await pool.draw(
        n: _gossipDrawCount,
        selfUserId: selfUserId,
      );
      if (drawn.isEmpty) return const [];
      final kept = <GossipBlob>[];
      var used = 0;
      for (final b in drawn) {
        if (used + b.blobSize > _gossipPiggybackBudgetBytes) continue;
        kept.add(b);
        used += b.blobSize;
      }
      return kept;
    } catch (e, st) {
      debugPrint('gossip.draw failed: $e\n$st');
      return const [];
    }
  }

  void _startQr(Uint8List sealedWire) {
    final qr = QrSendTransport();
    qr.start(sealedWire, chunkSize: 256);
    setState(() {
      _encodedFrames = qr.encodedFrames;
      _frameIdx = 0;
      _mode = _SendMode.showing;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      print('Advancing QR frame: idx=$_frameIdx');
      print('Current frame size: ${_encodedFrames.isEmpty ? 0 : _encodedFrames[_frameIdx % _encodedFrames.length].length} bytes');
      print("Current frame preview (base64, first 50 chars): ${_encodedFrames.isEmpty ? '' : base64.encode(_encodedFrames[_frameIdx % _encodedFrames.length]).substring(0, 50)}");
      print("Total frames: ${_encodedFrames.length}");

      setState(() => _frameIdx++);

    });
  }

  Future<void> _startNfc(Uint8List sealedWire) async {
    final nfc = NfcSendTransport();
    try {
      await nfc.start(sealedWire);
    } catch (e) {
      if (!mounted) return;
      _showError('Tap unavailable: $e — falling back to QR.');
      _startQr(sealedWire);
      return;
    }
    if (!mounted) return;
    setState(() {
      _nfc = nfc;
      _mode = _SendMode.tapping;
    });
  }

  void _stopQr() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _mode = _SendMode.compose;
      _encodedFrames = const [];
      _frameIdx = 0;
      _scannedRequest = null;
      _amountCtrl.clear();
      _kobo = null;
    });
  }

  Future<void> _stopTap() async {
    final n = _nfc;
    _nfc = null;
    if (n != null) await n.stop();
    if (!mounted) return;
    setState(() {
      _mode = _SendMode.compose;
      _scannedRequest = null;
      _amountCtrl.clear();
      _kobo = null;
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static Uint8List? _decodeBase64(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return Uint8List.fromList(base64.decode(s));
    } catch (_) {
      return null;
    }
  }
}

class _NoCeilingView extends StatelessWidget {
  final bool online;
  const _NoCeilingView({required this.online});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.offline_bolt,
              size: 48,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No offline wallet yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Move money into the offline wallet to pay without internet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Text('Go to Wallet'),
            ),
            onPressed: !online
                ? null
                : () {
                    context.read<AppCubit>().setTab(TabIndex.wallet);
                    Navigator.of(context).maybePop();
                  },
          ),
          if (!online) ...[
            const SizedBox(height: 8),
            Text(
              'Funding requires internet.',
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

class _OfflineRemainingChip extends StatelessWidget {
  final int remaining;
  const _OfflineRemainingChip({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.offline_bolt, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline available',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                ),
                Text(
                  formatNaira(remaining),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelToggle extends StatelessWidget {
  final PaymentChannel selected;
  final bool nfcAvailable;
  final ValueChanged<PaymentChannel> onChanged;
  const _ChannelToggle({
    required this.selected,
    required this.nfcAvailable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PaymentChannel>(
      segments: [
        const ButtonSegment(
          value: PaymentChannel.qr,
          icon: Icon(Icons.qr_code_2),
          label: Text('QR'),
        ),
        ButtonSegment(
          value: PaymentChannel.nfc,
          icon: const Icon(Icons.nfc),
          label: const Text('Tap'),
          enabled: nfcAvailable,
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _HeroAmountField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _HeroAmountField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '₦',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: onChanged,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            decoration: const InputDecoration(
              hintText: '0.00',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _QrDisplay extends StatelessWidget {
  final List<Uint8List> frames;
  final int frameIdx;
  final VoidCallback onDone;
  const _QrDisplay({
    required this.frames,
    required this.frameIdx,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final frame = frames.isEmpty
        ? Uint8List(0)
        : frames[frameIdx % frames.length];
    final qrData = base64.encode(frame);
    final frameCount = frames.isEmpty ? 1 : frames.length;
    final progress = (frameIdx % frameCount + 1) / frameCount;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text(
            'Ask the merchant to scan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Frame ${(frameIdx % frameCount) + 1} / $frameCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDone,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TappingView extends StatelessWidget {
  final int apduCount;
  final VoidCallback onCancel;
  const _TappingView({required this.apduCount, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PulseRing(
            size: 128,
            color: scheme.primary,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.nfc,
                  size: 72, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Hold near the merchant',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '$apduCount APDU chunk${apduCount == 1 ? '' : 's'} staged',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: onCancel,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              child: Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeView extends StatelessWidget {
  final int remaining;
  final VoidCallback onScanInvoice;
  const _ComposeView({required this.remaining, required this.onScanInvoice});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OfflineRemainingChip(remaining: remaining),
          const Spacer(),
          Icon(
            Icons.qr_code_scanner,
            size: 96,
            color: scheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Scan the merchant’s invoice',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Every payment starts from a receiver-issued invoice. Ask the '
            'merchant to show their receive QR.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const Spacer(flex: 2),
          FilledButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: onScanInvoice,
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Scan invoice'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceScanView extends StatelessWidget {
  final MobileScannerController controller;
  final int framesSeen;
  final int? totalFrames;
  final String? error;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onCancel;

  const _InvoiceScanView({
    required this.controller,
    required this.framesSeen,
    required this.totalFrames,
    required this.error,
    required this.onDetect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress =
        totalFrames == null || totalFrames == 0 ? null : framesSeen / totalFrames!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: MobileScanner(
                controller: controller,
                onDetect: onDetect,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            error ??
                (framesSeen == 0
                    ? 'Point at the merchant’s invoice QR…'
                    : 'Reading frames…'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: error != null ? scheme.error : null,
                ),
          ),
          const SizedBox(height: 8),
          if (progress != null)
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back),
            onPressed: onCancel,
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

class _InvoiceConfirmView extends StatelessWidget {
  final PaymentRequest request;
  final int remainingKobo;
  final TextEditingController amountCtrl;
  final void Function(String) onAmountChanged;
  final VoidCallback onCancel;
  final VoidCallback onAuthorize;

  const _InvoiceConfirmView({
    required this.request,
    required this.remainingKobo,
    required this.amountCtrl,
    required this.onAmountChanged,
    required this.onCancel,
    required this.onAuthorize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = request.payload.receiverDisplayCard.payload;
    final unbound = request.payload.amount == unboundAmount;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _OfflineRemainingChip(remaining: remainingKobo),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are paying',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Account ${card.accountNumber}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onPrimaryContainer
                                        .withValues(alpha: 0.8),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (unbound) ...[
                    Text(
                      'Amount',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    _HeroAmountField(
                      controller: amountCtrl,
                      onChanged: onAmountChanged,
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Amount',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            formatNaira(request.payload.amount),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    onPressed: onAuthorize,
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(unbound ? 'Authorize and show QR' : 'Pay'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: onCancel,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Cancel'),
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
