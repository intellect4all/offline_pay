// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initiate_transfer_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$InitiateTransferBody extends InitiateTransferBody {
  @override
  final String receiverAccountNumber;
  @override
  final int amountKobo;
  @override
  final String reference;
  @override
  final String pin;

  factory _$InitiateTransferBody(
          [void Function(InitiateTransferBodyBuilder)? updates]) =>
      (InitiateTransferBodyBuilder()..update(updates))._build();

  _$InitiateTransferBody._(
      {required this.receiverAccountNumber,
      required this.amountKobo,
      required this.reference,
      required this.pin})
      : super._();
  @override
  InitiateTransferBody rebuild(
          void Function(InitiateTransferBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  InitiateTransferBodyBuilder toBuilder() =>
      InitiateTransferBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is InitiateTransferBody &&
        receiverAccountNumber == other.receiverAccountNumber &&
        amountKobo == other.amountKobo &&
        reference == other.reference &&
        pin == other.pin;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, receiverAccountNumber.hashCode);
    _$hash = $jc(_$hash, amountKobo.hashCode);
    _$hash = $jc(_$hash, reference.hashCode);
    _$hash = $jc(_$hash, pin.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'InitiateTransferBody')
          ..add('receiverAccountNumber', receiverAccountNumber)
          ..add('amountKobo', amountKobo)
          ..add('reference', reference)
          ..add('pin', pin))
        .toString();
  }
}

class InitiateTransferBodyBuilder
    implements Builder<InitiateTransferBody, InitiateTransferBodyBuilder> {
  _$InitiateTransferBody? _$v;

  String? _receiverAccountNumber;
  String? get receiverAccountNumber => _$this._receiverAccountNumber;
  set receiverAccountNumber(String? receiverAccountNumber) =>
      _$this._receiverAccountNumber = receiverAccountNumber;

  int? _amountKobo;
  int? get amountKobo => _$this._amountKobo;
  set amountKobo(int? amountKobo) => _$this._amountKobo = amountKobo;

  String? _reference;
  String? get reference => _$this._reference;
  set reference(String? reference) => _$this._reference = reference;

  String? _pin;
  String? get pin => _$this._pin;
  set pin(String? pin) => _$this._pin = pin;

  InitiateTransferBodyBuilder() {
    InitiateTransferBody._defaults(this);
  }

  InitiateTransferBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _receiverAccountNumber = $v.receiverAccountNumber;
      _amountKobo = $v.amountKobo;
      _reference = $v.reference;
      _pin = $v.pin;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(InitiateTransferBody other) {
    _$v = other as _$InitiateTransferBody;
  }

  @override
  void update(void Function(InitiateTransferBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  InitiateTransferBody build() => _build();

  _$InitiateTransferBody _build() {
    final _$result = _$v ??
        _$InitiateTransferBody._(
          receiverAccountNumber: BuiltValueNullFieldError.checkNotNull(
              receiverAccountNumber,
              r'InitiateTransferBody',
              'receiverAccountNumber'),
          amountKobo: BuiltValueNullFieldError.checkNotNull(
              amountKobo, r'InitiateTransferBody', 'amountKobo'),
          reference: BuiltValueNullFieldError.checkNotNull(
              reference, r'InitiateTransferBody', 'reference'),
          pin: BuiltValueNullFieldError.checkNotNull(
              pin, r'InitiateTransferBody', 'pin'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
