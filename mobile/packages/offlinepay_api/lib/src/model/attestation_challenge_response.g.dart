// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attestation_challenge_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AttestationChallengeResponse extends AttestationChallengeResponse {
  @override
  final String nonce;
  @override
  final DateTime expiresAt;

  factory _$AttestationChallengeResponse(
          [void Function(AttestationChallengeResponseBuilder)? updates]) =>
      (AttestationChallengeResponseBuilder()..update(updates))._build();

  _$AttestationChallengeResponse._(
      {required this.nonce, required this.expiresAt})
      : super._();
  @override
  AttestationChallengeResponse rebuild(
          void Function(AttestationChallengeResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AttestationChallengeResponseBuilder toBuilder() =>
      AttestationChallengeResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AttestationChallengeResponse &&
        nonce == other.nonce &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, nonce.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AttestationChallengeResponse')
          ..add('nonce', nonce)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class AttestationChallengeResponseBuilder
    implements
        Builder<AttestationChallengeResponse,
            AttestationChallengeResponseBuilder> {
  _$AttestationChallengeResponse? _$v;

  String? _nonce;
  String? get nonce => _$this._nonce;
  set nonce(String? nonce) => _$this._nonce = nonce;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  AttestationChallengeResponseBuilder() {
    AttestationChallengeResponse._defaults(this);
  }

  AttestationChallengeResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _nonce = $v.nonce;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AttestationChallengeResponse other) {
    _$v = other as _$AttestationChallengeResponse;
  }

  @override
  void update(void Function(AttestationChallengeResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AttestationChallengeResponse build() => _build();

  _$AttestationChallengeResponse _build() {
    final _$result = _$v ??
        _$AttestationChallengeResponse._(
          nonce: BuiltValueNullFieldError.checkNotNull(
              nonce, r'AttestationChallengeResponse', 'nonce'),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt, r'AttestationChallengeResponse', 'expiresAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
