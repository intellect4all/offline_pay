// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attest_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttestBody extends AttestBody {
  @override
  final String attestationBlob;
  @override
  final String nonce;

  factory _$AttestBody([void Function(AttestBodyBuilder)? updates]) =>
      (AttestBodyBuilder()..update(updates))._build();

  _$AttestBody._({required this.attestationBlob, required this.nonce})
      : super._();
  @override
  AttestBody rebuild(void Function(AttestBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AttestBodyBuilder toBuilder() => AttestBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttestBody &&
        attestationBlob == other.attestationBlob &&
        nonce == other.nonce;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, attestationBlob.hashCode);
    _$hash = $jc(_$hash, nonce.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttestBody')
          ..add('attestationBlob', attestationBlob)
          ..add('nonce', nonce))
        .toString();
  }
}

class AttestBodyBuilder implements Builder<AttestBody, AttestBodyBuilder> {
  _$AttestBody? _$v;

  String? _attestationBlob;
  String? get attestationBlob => _$this._attestationBlob;
  set attestationBlob(String? attestationBlob) =>
      _$this._attestationBlob = attestationBlob;

  String? _nonce;
  String? get nonce => _$this._nonce;
  set nonce(String? nonce) => _$this._nonce = nonce;

  AttestBodyBuilder() {
    AttestBody._defaults(this);
  }

  AttestBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _attestationBlob = $v.attestationBlob;
      _nonce = $v.nonce;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttestBody other) {
    _$v = other as _$AttestBody;
  }

  @override
  void update(void Function(AttestBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttestBody build() => _build();

  _$AttestBody _build() {
    final _$result = _$v ??
        _$AttestBody._(
          attestationBlob: BuiltValueNullFieldError.checkNotNull(
              attestationBlob, r'AttestBody', 'attestationBlob'),
          nonce: BuiltValueNullFieldError.checkNotNull(
              nonce, r'AttestBody', 'nonce'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
