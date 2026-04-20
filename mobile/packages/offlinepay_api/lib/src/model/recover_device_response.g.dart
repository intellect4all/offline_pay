// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recover_device_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RecoverDeviceResponse extends RecoverDeviceResponse {
  @override
  final String newDeviceId;
  @override
  final DateTime recoveredAt;
  @override
  final int realmKeyVersion;

  factory _$RecoverDeviceResponse(
          [void Function(RecoverDeviceResponseBuilder)? updates]) =>
      (RecoverDeviceResponseBuilder()..update(updates))._build();

  _$RecoverDeviceResponse._(
      {required this.newDeviceId,
      required this.recoveredAt,
      required this.realmKeyVersion})
      : super._();
  @override
  RecoverDeviceResponse rebuild(
          void Function(RecoverDeviceResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RecoverDeviceResponseBuilder toBuilder() =>
      RecoverDeviceResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RecoverDeviceResponse &&
        newDeviceId == other.newDeviceId &&
        recoveredAt == other.recoveredAt &&
        realmKeyVersion == other.realmKeyVersion;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, newDeviceId.hashCode);
    _$hash = $jc(_$hash, recoveredAt.hashCode);
    _$hash = $jc(_$hash, realmKeyVersion.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RecoverDeviceResponse')
          ..add('newDeviceId', newDeviceId)
          ..add('recoveredAt', recoveredAt)
          ..add('realmKeyVersion', realmKeyVersion))
        .toString();
  }
}

class RecoverDeviceResponseBuilder
    implements Builder<RecoverDeviceResponse, RecoverDeviceResponseBuilder> {
  _$RecoverDeviceResponse? _$v;

  String? _newDeviceId;
  String? get newDeviceId => _$this._newDeviceId;
  set newDeviceId(String? newDeviceId) => _$this._newDeviceId = newDeviceId;

  DateTime? _recoveredAt;
  DateTime? get recoveredAt => _$this._recoveredAt;
  set recoveredAt(DateTime? recoveredAt) => _$this._recoveredAt = recoveredAt;

  int? _realmKeyVersion;
  int? get realmKeyVersion => _$this._realmKeyVersion;
  set realmKeyVersion(int? realmKeyVersion) =>
      _$this._realmKeyVersion = realmKeyVersion;

  RecoverDeviceResponseBuilder() {
    RecoverDeviceResponse._defaults(this);
  }

  RecoverDeviceResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _newDeviceId = $v.newDeviceId;
      _recoveredAt = $v.recoveredAt;
      _realmKeyVersion = $v.realmKeyVersion;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RecoverDeviceResponse other) {
    _$v = other as _$RecoverDeviceResponse;
  }

  @override
  void update(void Function(RecoverDeviceResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RecoverDeviceResponse build() => _build();

  _$RecoverDeviceResponse _build() {
    final _$result = _$v ??
        _$RecoverDeviceResponse._(
          newDeviceId: BuiltValueNullFieldError.checkNotNull(
              newDeviceId, r'RecoverDeviceResponse', 'newDeviceId'),
          recoveredAt: BuiltValueNullFieldError.checkNotNull(
              recoveredAt, r'RecoverDeviceResponse', 'recoveredAt'),
          realmKeyVersion: BuiltValueNullFieldError.checkNotNull(
              realmKeyVersion, r'RecoverDeviceResponse', 'realmKeyVersion'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
