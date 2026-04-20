// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gossip_blob_input.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GossipBlobInput extends GossipBlobInput {
  @override
  final String transactionHash;
  @override
  final String encryptedBlob;
  @override
  final String bankSignature;
  @override
  final String ceilingTokenHash;
  @override
  final int hopCount;
  @override
  final int blobSize;

  factory _$GossipBlobInput([void Function(GossipBlobInputBuilder)? updates]) =>
      (GossipBlobInputBuilder()..update(updates))._build();

  _$GossipBlobInput._(
      {required this.transactionHash,
      required this.encryptedBlob,
      required this.bankSignature,
      required this.ceilingTokenHash,
      required this.hopCount,
      required this.blobSize})
      : super._();
  @override
  GossipBlobInput rebuild(void Function(GossipBlobInputBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GossipBlobInputBuilder toBuilder() => GossipBlobInputBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GossipBlobInput &&
        transactionHash == other.transactionHash &&
        encryptedBlob == other.encryptedBlob &&
        bankSignature == other.bankSignature &&
        ceilingTokenHash == other.ceilingTokenHash &&
        hopCount == other.hopCount &&
        blobSize == other.blobSize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, transactionHash.hashCode);
    _$hash = $jc(_$hash, encryptedBlob.hashCode);
    _$hash = $jc(_$hash, bankSignature.hashCode);
    _$hash = $jc(_$hash, ceilingTokenHash.hashCode);
    _$hash = $jc(_$hash, hopCount.hashCode);
    _$hash = $jc(_$hash, blobSize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GossipBlobInput')
          ..add('transactionHash', transactionHash)
          ..add('encryptedBlob', encryptedBlob)
          ..add('bankSignature', bankSignature)
          ..add('ceilingTokenHash', ceilingTokenHash)
          ..add('hopCount', hopCount)
          ..add('blobSize', blobSize))
        .toString();
  }
}

class GossipBlobInputBuilder
    implements Builder<GossipBlobInput, GossipBlobInputBuilder> {
  _$GossipBlobInput? _$v;

  String? _transactionHash;
  String? get transactionHash => _$this._transactionHash;
  set transactionHash(String? transactionHash) =>
      _$this._transactionHash = transactionHash;

  String? _encryptedBlob;
  String? get encryptedBlob => _$this._encryptedBlob;
  set encryptedBlob(String? encryptedBlob) =>
      _$this._encryptedBlob = encryptedBlob;

  String? _bankSignature;
  String? get bankSignature => _$this._bankSignature;
  set bankSignature(String? bankSignature) =>
      _$this._bankSignature = bankSignature;

  String? _ceilingTokenHash;
  String? get ceilingTokenHash => _$this._ceilingTokenHash;
  set ceilingTokenHash(String? ceilingTokenHash) =>
      _$this._ceilingTokenHash = ceilingTokenHash;

  int? _hopCount;
  int? get hopCount => _$this._hopCount;
  set hopCount(int? hopCount) => _$this._hopCount = hopCount;

  int? _blobSize;
  int? get blobSize => _$this._blobSize;
  set blobSize(int? blobSize) => _$this._blobSize = blobSize;

  GossipBlobInputBuilder() {
    GossipBlobInput._defaults(this);
  }

  GossipBlobInputBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _transactionHash = $v.transactionHash;
      _encryptedBlob = $v.encryptedBlob;
      _bankSignature = $v.bankSignature;
      _ceilingTokenHash = $v.ceilingTokenHash;
      _hopCount = $v.hopCount;
      _blobSize = $v.blobSize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GossipBlobInput other) {
    _$v = other as _$GossipBlobInput;
  }

  @override
  void update(void Function(GossipBlobInputBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GossipBlobInput build() => _build();

  _$GossipBlobInput _build() {
    final _$result = _$v ??
        _$GossipBlobInput._(
          transactionHash: BuiltValueNullFieldError.checkNotNull(
              transactionHash, r'GossipBlobInput', 'transactionHash'),
          encryptedBlob: BuiltValueNullFieldError.checkNotNull(
              encryptedBlob, r'GossipBlobInput', 'encryptedBlob'),
          bankSignature: BuiltValueNullFieldError.checkNotNull(
              bankSignature, r'GossipBlobInput', 'bankSignature'),
          ceilingTokenHash: BuiltValueNullFieldError.checkNotNull(
              ceilingTokenHash, r'GossipBlobInput', 'ceilingTokenHash'),
          hopCount: BuiltValueNullFieldError.checkNotNull(
              hopCount, r'GossipBlobInput', 'hopCount'),
          blobSize: BuiltValueNullFieldError.checkNotNull(
              blobSize, r'GossipBlobInput', 'blobSize'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
