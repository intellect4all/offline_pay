// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sealed_box_pubkey_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SealedBoxPubkeyResponse extends SealedBoxPubkeyResponse {
  @override
  final String publicKey;
  @override
  final String keyId;
  @override
  final DateTime activeFrom;

  factory _$SealedBoxPubkeyResponse(
          [void Function(SealedBoxPubkeyResponseBuilder)? updates]) =>
      (SealedBoxPubkeyResponseBuilder()..update(updates))._build();

  _$SealedBoxPubkeyResponse._(
      {required this.publicKey, required this.keyId, required this.activeFrom})
      : super._();
  @override
  SealedBoxPubkeyResponse rebuild(
          void Function(SealedBoxPubkeyResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SealedBoxPubkeyResponseBuilder toBuilder() =>
      SealedBoxPubkeyResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SealedBoxPubkeyResponse &&
        publicKey == other.publicKey &&
        keyId == other.keyId &&
        activeFrom == other.activeFrom;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, publicKey.hashCode);
    _$hash = $jc(_$hash, keyId.hashCode);
    _$hash = $jc(_$hash, activeFrom.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SealedBoxPubkeyResponse')
          ..add('publicKey', publicKey)
          ..add('keyId', keyId)
          ..add('activeFrom', activeFrom))
        .toString();
  }
}

class SealedBoxPubkeyResponseBuilder
    implements
        Builder<SealedBoxPubkeyResponse, SealedBoxPubkeyResponseBuilder> {
  _$SealedBoxPubkeyResponse? _$v;

  String? _publicKey;
  String? get publicKey => _$this._publicKey;
  set publicKey(String? publicKey) => _$this._publicKey = publicKey;

  String? _keyId;
  String? get keyId => _$this._keyId;
  set keyId(String? keyId) => _$this._keyId = keyId;

  DateTime? _activeFrom;
  DateTime? get activeFrom => _$this._activeFrom;
  set activeFrom(DateTime? activeFrom) => _$this._activeFrom = activeFrom;

  SealedBoxPubkeyResponseBuilder() {
    SealedBoxPubkeyResponse._defaults(this);
  }

  SealedBoxPubkeyResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _publicKey = $v.publicKey;
      _keyId = $v.keyId;
      _activeFrom = $v.activeFrom;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SealedBoxPubkeyResponse other) {
    _$v = other as _$SealedBoxPubkeyResponse;
  }

  @override
  void update(void Function(SealedBoxPubkeyResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SealedBoxPubkeyResponse build() => _build();

  _$SealedBoxPubkeyResponse _build() {
    final _$result = _$v ??
        _$SealedBoxPubkeyResponse._(
          publicKey: BuiltValueNullFieldError.checkNotNull(
              publicKey, r'SealedBoxPubkeyResponse', 'publicKey'),
          keyId: BuiltValueNullFieldError.checkNotNull(
              keyId, r'SealedBoxPubkeyResponse', 'keyId'),
          activeFrom: BuiltValueNullFieldError.checkNotNull(
              activeFrom, r'SealedBoxPubkeyResponse', 'activeFrom'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
