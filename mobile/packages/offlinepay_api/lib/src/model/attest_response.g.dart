// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attest_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttestResponse extends AttestResponse {
  @override
  final bool valid;
  @override
  final String deviceJwt;
  @override
  final DateTime expiresAt;
  @override
  final String? failureReason;

  factory _$AttestResponse([void Function(AttestResponseBuilder)? updates]) =>
      (AttestResponseBuilder()..update(updates))._build();

  _$AttestResponse._(
      {required this.valid,
      required this.deviceJwt,
      required this.expiresAt,
      this.failureReason})
      : super._();
  @override
  AttestResponse rebuild(void Function(AttestResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AttestResponseBuilder toBuilder() => AttestResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttestResponse &&
        valid == other.valid &&
        deviceJwt == other.deviceJwt &&
        expiresAt == other.expiresAt &&
        failureReason == other.failureReason;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, valid.hashCode);
    _$hash = $jc(_$hash, deviceJwt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, failureReason.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttestResponse')
          ..add('valid', valid)
          ..add('deviceJwt', deviceJwt)
          ..add('expiresAt', expiresAt)
          ..add('failureReason', failureReason))
        .toString();
  }
}

class AttestResponseBuilder
    implements Builder<AttestResponse, AttestResponseBuilder> {
  _$AttestResponse? _$v;

  bool? _valid;
  bool? get valid => _$this._valid;
  set valid(bool? valid) => _$this._valid = valid;

  String? _deviceJwt;
  String? get deviceJwt => _$this._deviceJwt;
  set deviceJwt(String? deviceJwt) => _$this._deviceJwt = deviceJwt;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  String? _failureReason;
  String? get failureReason => _$this._failureReason;
  set failureReason(String? failureReason) =>
      _$this._failureReason = failureReason;

  AttestResponseBuilder() {
    AttestResponse._defaults(this);
  }

  AttestResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _valid = $v.valid;
      _deviceJwt = $v.deviceJwt;
      _expiresAt = $v.expiresAt;
      _failureReason = $v.failureReason;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttestResponse other) {
    _$v = other as _$AttestResponse;
  }

  @override
  void update(void Function(AttestResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttestResponse build() => _build();

  _$AttestResponse _build() {
    final _$result = _$v ??
        _$AttestResponse._(
          valid: BuiltValueNullFieldError.checkNotNull(
              valid, r'AttestResponse', 'valid'),
          deviceJwt: BuiltValueNullFieldError.checkNotNull(
              deviceJwt, r'AttestResponse', 'deviceJwt'),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt, r'AttestResponse', 'expiresAt'),
          failureReason: failureReason,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
