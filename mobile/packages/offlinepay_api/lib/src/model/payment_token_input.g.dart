// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_token_input.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PaymentTokenInput extends PaymentTokenInput {
  @override
  final String payerId;
  @override
  final String payeeId;
  @override
  final int amountKobo;
  @override
  final int sequenceNumber;
  @override
  final int remainingCeilingKobo;
  @override
  final DateTime timestamp;
  @override
  final String ceilingTokenId;
  @override
  final String payerSignature;
  @override
  final String sessionNonce;
  @override
  final String requestHash;

  factory _$PaymentTokenInput(
          [void Function(PaymentTokenInputBuilder)? updates]) =>
      (PaymentTokenInputBuilder()..update(updates))._build();

  _$PaymentTokenInput._(
      {required this.payerId,
      required this.payeeId,
      required this.amountKobo,
      required this.sequenceNumber,
      required this.remainingCeilingKobo,
      required this.timestamp,
      required this.ceilingTokenId,
      required this.payerSignature,
      required this.sessionNonce,
      required this.requestHash})
      : super._();
  @override
  PaymentTokenInput rebuild(void Function(PaymentTokenInputBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PaymentTokenInputBuilder toBuilder() =>
      PaymentTokenInputBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PaymentTokenInput &&
        payerId == other.payerId &&
        payeeId == other.payeeId &&
        amountKobo == other.amountKobo &&
        sequenceNumber == other.sequenceNumber &&
        remainingCeilingKobo == other.remainingCeilingKobo &&
        timestamp == other.timestamp &&
        ceilingTokenId == other.ceilingTokenId &&
        payerSignature == other.payerSignature &&
        sessionNonce == other.sessionNonce &&
        requestHash == other.requestHash;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, payerId.hashCode);
    _$hash = $jc(_$hash, payeeId.hashCode);
    _$hash = $jc(_$hash, amountKobo.hashCode);
    _$hash = $jc(_$hash, sequenceNumber.hashCode);
    _$hash = $jc(_$hash, remainingCeilingKobo.hashCode);
    _$hash = $jc(_$hash, timestamp.hashCode);
    _$hash = $jc(_$hash, ceilingTokenId.hashCode);
    _$hash = $jc(_$hash, payerSignature.hashCode);
    _$hash = $jc(_$hash, sessionNonce.hashCode);
    _$hash = $jc(_$hash, requestHash.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PaymentTokenInput')
          ..add('payerId', payerId)
          ..add('payeeId', payeeId)
          ..add('amountKobo', amountKobo)
          ..add('sequenceNumber', sequenceNumber)
          ..add('remainingCeilingKobo', remainingCeilingKobo)
          ..add('timestamp', timestamp)
          ..add('ceilingTokenId', ceilingTokenId)
          ..add('payerSignature', payerSignature)
          ..add('sessionNonce', sessionNonce)
          ..add('requestHash', requestHash))
        .toString();
  }
}

class PaymentTokenInputBuilder
    implements Builder<PaymentTokenInput, PaymentTokenInputBuilder> {
  _$PaymentTokenInput? _$v;

  String? _payerId;
  String? get payerId => _$this._payerId;
  set payerId(String? payerId) => _$this._payerId = payerId;

  String? _payeeId;
  String? get payeeId => _$this._payeeId;
  set payeeId(String? payeeId) => _$this._payeeId = payeeId;

  int? _amountKobo;
  int? get amountKobo => _$this._amountKobo;
  set amountKobo(int? amountKobo) => _$this._amountKobo = amountKobo;

  int? _sequenceNumber;
  int? get sequenceNumber => _$this._sequenceNumber;
  set sequenceNumber(int? sequenceNumber) =>
      _$this._sequenceNumber = sequenceNumber;

  int? _remainingCeilingKobo;
  int? get remainingCeilingKobo => _$this._remainingCeilingKobo;
  set remainingCeilingKobo(int? remainingCeilingKobo) =>
      _$this._remainingCeilingKobo = remainingCeilingKobo;

  DateTime? _timestamp;
  DateTime? get timestamp => _$this._timestamp;
  set timestamp(DateTime? timestamp) => _$this._timestamp = timestamp;

  String? _ceilingTokenId;
  String? get ceilingTokenId => _$this._ceilingTokenId;
  set ceilingTokenId(String? ceilingTokenId) =>
      _$this._ceilingTokenId = ceilingTokenId;

  String? _payerSignature;
  String? get payerSignature => _$this._payerSignature;
  set payerSignature(String? payerSignature) =>
      _$this._payerSignature = payerSignature;

  String? _sessionNonce;
  String? get sessionNonce => _$this._sessionNonce;
  set sessionNonce(String? sessionNonce) => _$this._sessionNonce = sessionNonce;

  String? _requestHash;
  String? get requestHash => _$this._requestHash;
  set requestHash(String? requestHash) => _$this._requestHash = requestHash;

  PaymentTokenInputBuilder() {
    PaymentTokenInput._defaults(this);
  }

  PaymentTokenInputBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _payerId = $v.payerId;
      _payeeId = $v.payeeId;
      _amountKobo = $v.amountKobo;
      _sequenceNumber = $v.sequenceNumber;
      _remainingCeilingKobo = $v.remainingCeilingKobo;
      _timestamp = $v.timestamp;
      _ceilingTokenId = $v.ceilingTokenId;
      _payerSignature = $v.payerSignature;
      _sessionNonce = $v.sessionNonce;
      _requestHash = $v.requestHash;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PaymentTokenInput other) {
    _$v = other as _$PaymentTokenInput;
  }

  @override
  void update(void Function(PaymentTokenInputBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PaymentTokenInput build() => _build();

  _$PaymentTokenInput _build() {
    final _$result = _$v ??
        _$PaymentTokenInput._(
          payerId: BuiltValueNullFieldError.checkNotNull(
              payerId, r'PaymentTokenInput', 'payerId'),
          payeeId: BuiltValueNullFieldError.checkNotNull(
              payeeId, r'PaymentTokenInput', 'payeeId'),
          amountKobo: BuiltValueNullFieldError.checkNotNull(
              amountKobo, r'PaymentTokenInput', 'amountKobo'),
          sequenceNumber: BuiltValueNullFieldError.checkNotNull(
              sequenceNumber, r'PaymentTokenInput', 'sequenceNumber'),
          remainingCeilingKobo: BuiltValueNullFieldError.checkNotNull(
              remainingCeilingKobo,
              r'PaymentTokenInput',
              'remainingCeilingKobo'),
          timestamp: BuiltValueNullFieldError.checkNotNull(
              timestamp, r'PaymentTokenInput', 'timestamp'),
          ceilingTokenId: BuiltValueNullFieldError.checkNotNull(
              ceilingTokenId, r'PaymentTokenInput', 'ceilingTokenId'),
          payerSignature: BuiltValueNullFieldError.checkNotNull(
              payerSignature, r'PaymentTokenInput', 'payerSignature'),
          sessionNonce: BuiltValueNullFieldError.checkNotNull(
              sessionNonce, r'PaymentTokenInput', 'sessionNonce'),
          requestHash: BuiltValueNullFieldError.checkNotNull(
              requestHash, r'PaymentTokenInput', 'requestHash'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
