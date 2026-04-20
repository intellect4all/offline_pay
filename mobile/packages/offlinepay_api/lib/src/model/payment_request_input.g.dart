// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_request_input.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PaymentRequestInput extends PaymentRequestInput {
  @override
  final String receiverId;
  @override
  final DisplayCardInput receiverDisplayCard;
  @override
  final int amountKobo;
  @override
  final String sessionNonce;
  @override
  final DateTime issuedAt;
  @override
  final DateTime expiresAt;
  @override
  final String receiverDevicePubkey;
  @override
  final String receiverSignature;

  factory _$PaymentRequestInput(
          [void Function(PaymentRequestInputBuilder)? updates]) =>
      (PaymentRequestInputBuilder()..update(updates))._build();

  _$PaymentRequestInput._(
      {required this.receiverId,
      required this.receiverDisplayCard,
      required this.amountKobo,
      required this.sessionNonce,
      required this.issuedAt,
      required this.expiresAt,
      required this.receiverDevicePubkey,
      required this.receiverSignature})
      : super._();
  @override
  PaymentRequestInput rebuild(
          void Function(PaymentRequestInputBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PaymentRequestInputBuilder toBuilder() =>
      PaymentRequestInputBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PaymentRequestInput &&
        receiverId == other.receiverId &&
        receiverDisplayCard == other.receiverDisplayCard &&
        amountKobo == other.amountKobo &&
        sessionNonce == other.sessionNonce &&
        issuedAt == other.issuedAt &&
        expiresAt == other.expiresAt &&
        receiverDevicePubkey == other.receiverDevicePubkey &&
        receiverSignature == other.receiverSignature;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, receiverId.hashCode);
    _$hash = $jc(_$hash, receiverDisplayCard.hashCode);
    _$hash = $jc(_$hash, amountKobo.hashCode);
    _$hash = $jc(_$hash, sessionNonce.hashCode);
    _$hash = $jc(_$hash, issuedAt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, receiverDevicePubkey.hashCode);
    _$hash = $jc(_$hash, receiverSignature.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PaymentRequestInput')
          ..add('receiverId', receiverId)
          ..add('receiverDisplayCard', receiverDisplayCard)
          ..add('amountKobo', amountKobo)
          ..add('sessionNonce', sessionNonce)
          ..add('issuedAt', issuedAt)
          ..add('expiresAt', expiresAt)
          ..add('receiverDevicePubkey', receiverDevicePubkey)
          ..add('receiverSignature', receiverSignature))
        .toString();
  }
}

class PaymentRequestInputBuilder
    implements Builder<PaymentRequestInput, PaymentRequestInputBuilder> {
  _$PaymentRequestInput? _$v;

  String? _receiverId;
  String? get receiverId => _$this._receiverId;
  set receiverId(String? receiverId) => _$this._receiverId = receiverId;

  DisplayCardInputBuilder? _receiverDisplayCard;
  DisplayCardInputBuilder get receiverDisplayCard =>
      _$this._receiverDisplayCard ??= DisplayCardInputBuilder();
  set receiverDisplayCard(DisplayCardInputBuilder? receiverDisplayCard) =>
      _$this._receiverDisplayCard = receiverDisplayCard;

  int? _amountKobo;
  int? get amountKobo => _$this._amountKobo;
  set amountKobo(int? amountKobo) => _$this._amountKobo = amountKobo;

  String? _sessionNonce;
  String? get sessionNonce => _$this._sessionNonce;
  set sessionNonce(String? sessionNonce) => _$this._sessionNonce = sessionNonce;

  DateTime? _issuedAt;
  DateTime? get issuedAt => _$this._issuedAt;
  set issuedAt(DateTime? issuedAt) => _$this._issuedAt = issuedAt;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  String? _receiverDevicePubkey;
  String? get receiverDevicePubkey => _$this._receiverDevicePubkey;
  set receiverDevicePubkey(String? receiverDevicePubkey) =>
      _$this._receiverDevicePubkey = receiverDevicePubkey;

  String? _receiverSignature;
  String? get receiverSignature => _$this._receiverSignature;
  set receiverSignature(String? receiverSignature) =>
      _$this._receiverSignature = receiverSignature;

  PaymentRequestInputBuilder() {
    PaymentRequestInput._defaults(this);
  }

  PaymentRequestInputBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _receiverId = $v.receiverId;
      _receiverDisplayCard = $v.receiverDisplayCard.toBuilder();
      _amountKobo = $v.amountKobo;
      _sessionNonce = $v.sessionNonce;
      _issuedAt = $v.issuedAt;
      _expiresAt = $v.expiresAt;
      _receiverDevicePubkey = $v.receiverDevicePubkey;
      _receiverSignature = $v.receiverSignature;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PaymentRequestInput other) {
    _$v = other as _$PaymentRequestInput;
  }

  @override
  void update(void Function(PaymentRequestInputBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PaymentRequestInput build() => _build();

  _$PaymentRequestInput _build() {
    _$PaymentRequestInput _$result;
    try {
      _$result = _$v ??
          _$PaymentRequestInput._(
            receiverId: BuiltValueNullFieldError.checkNotNull(
                receiverId, r'PaymentRequestInput', 'receiverId'),
            receiverDisplayCard: receiverDisplayCard.build(),
            amountKobo: BuiltValueNullFieldError.checkNotNull(
                amountKobo, r'PaymentRequestInput', 'amountKobo'),
            sessionNonce: BuiltValueNullFieldError.checkNotNull(
                sessionNonce, r'PaymentRequestInput', 'sessionNonce'),
            issuedAt: BuiltValueNullFieldError.checkNotNull(
                issuedAt, r'PaymentRequestInput', 'issuedAt'),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
                expiresAt, r'PaymentRequestInput', 'expiresAt'),
            receiverDevicePubkey: BuiltValueNullFieldError.checkNotNull(
                receiverDevicePubkey,
                r'PaymentRequestInput',
                'receiverDevicePubkey'),
            receiverSignature: BuiltValueNullFieldError.checkNotNull(
                receiverSignature, r'PaymentRequestInput', 'receiverSignature'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'receiverDisplayCard';
        receiverDisplayCard.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'PaymentRequestInput', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
