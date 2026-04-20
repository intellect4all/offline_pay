// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recover_offline_ceiling_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RecoverOfflineCeilingResponse extends RecoverOfflineCeilingResponse {
  @override
  final String ceilingId;
  @override
  final int quarantinedKobo;
  @override
  final DateTime releaseAfter;

  factory _$RecoverOfflineCeilingResponse(
          [void Function(RecoverOfflineCeilingResponseBuilder)? updates]) =>
      (RecoverOfflineCeilingResponseBuilder()..update(updates))._build();

  _$RecoverOfflineCeilingResponse._(
      {required this.ceilingId,
      required this.quarantinedKobo,
      required this.releaseAfter})
      : super._();
  @override
  RecoverOfflineCeilingResponse rebuild(
          void Function(RecoverOfflineCeilingResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RecoverOfflineCeilingResponseBuilder toBuilder() =>
      RecoverOfflineCeilingResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RecoverOfflineCeilingResponse &&
        ceilingId == other.ceilingId &&
        quarantinedKobo == other.quarantinedKobo &&
        releaseAfter == other.releaseAfter;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, ceilingId.hashCode);
    _$hash = $jc(_$hash, quarantinedKobo.hashCode);
    _$hash = $jc(_$hash, releaseAfter.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RecoverOfflineCeilingResponse')
          ..add('ceilingId', ceilingId)
          ..add('quarantinedKobo', quarantinedKobo)
          ..add('releaseAfter', releaseAfter))
        .toString();
  }
}

class RecoverOfflineCeilingResponseBuilder
    implements
        Builder<RecoverOfflineCeilingResponse,
            RecoverOfflineCeilingResponseBuilder> {
  _$RecoverOfflineCeilingResponse? _$v;

  String? _ceilingId;
  String? get ceilingId => _$this._ceilingId;
  set ceilingId(String? ceilingId) => _$this._ceilingId = ceilingId;

  int? _quarantinedKobo;
  int? get quarantinedKobo => _$this._quarantinedKobo;
  set quarantinedKobo(int? quarantinedKobo) =>
      _$this._quarantinedKobo = quarantinedKobo;

  DateTime? _releaseAfter;
  DateTime? get releaseAfter => _$this._releaseAfter;
  set releaseAfter(DateTime? releaseAfter) =>
      _$this._releaseAfter = releaseAfter;

  RecoverOfflineCeilingResponseBuilder() {
    RecoverOfflineCeilingResponse._defaults(this);
  }

  RecoverOfflineCeilingResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _ceilingId = $v.ceilingId;
      _quarantinedKobo = $v.quarantinedKobo;
      _releaseAfter = $v.releaseAfter;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RecoverOfflineCeilingResponse other) {
    _$v = other as _$RecoverOfflineCeilingResponse;
  }

  @override
  void update(void Function(RecoverOfflineCeilingResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RecoverOfflineCeilingResponse build() => _build();

  _$RecoverOfflineCeilingResponse _build() {
    final _$result = _$v ??
        _$RecoverOfflineCeilingResponse._(
          ceilingId: BuiltValueNullFieldError.checkNotNull(
              ceilingId, r'RecoverOfflineCeilingResponse', 'ceilingId'),
          quarantinedKobo: BuiltValueNullFieldError.checkNotNull(
              quarantinedKobo,
              r'RecoverOfflineCeilingResponse',
              'quarantinedKobo'),
          releaseAfter: BuiltValueNullFieldError.checkNotNull(
              releaseAfter, r'RecoverOfflineCeilingResponse', 'releaseAfter'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
