// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_realm_key_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetRealmKeyResponse extends GetRealmKeyResponse {
  @override
  final int version;
  @override
  final String key;
  @override
  final DateTime activeFrom;
  @override
  final DateTime expiresAt;

  factory _$GetRealmKeyResponse(
          [void Function(GetRealmKeyResponseBuilder)? updates]) =>
      (GetRealmKeyResponseBuilder()..update(updates))._build();

  _$GetRealmKeyResponse._(
      {required this.version,
      required this.key,
      required this.activeFrom,
      required this.expiresAt})
      : super._();
  @override
  GetRealmKeyResponse rebuild(
          void Function(GetRealmKeyResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GetRealmKeyResponseBuilder toBuilder() =>
      GetRealmKeyResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetRealmKeyResponse &&
        version == other.version &&
        key == other.key &&
        activeFrom == other.activeFrom &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, key.hashCode);
    _$hash = $jc(_$hash, activeFrom.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GetRealmKeyResponse')
          ..add('version', version)
          ..add('key', key)
          ..add('activeFrom', activeFrom)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class GetRealmKeyResponseBuilder
    implements Builder<GetRealmKeyResponse, GetRealmKeyResponseBuilder> {
  _$GetRealmKeyResponse? _$v;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  String? _key;
  String? get key => _$this._key;
  set key(String? key) => _$this._key = key;

  DateTime? _activeFrom;
  DateTime? get activeFrom => _$this._activeFrom;
  set activeFrom(DateTime? activeFrom) => _$this._activeFrom = activeFrom;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  GetRealmKeyResponseBuilder() {
    GetRealmKeyResponse._defaults(this);
  }

  GetRealmKeyResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _version = $v.version;
      _key = $v.key;
      _activeFrom = $v.activeFrom;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetRealmKeyResponse other) {
    _$v = other as _$GetRealmKeyResponse;
  }

  @override
  void update(void Function(GetRealmKeyResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetRealmKeyResponse build() => _build();

  _$GetRealmKeyResponse _build() {
    final _$result = _$v ??
        _$GetRealmKeyResponse._(
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'GetRealmKeyResponse', 'version'),
          key: BuiltValueNullFieldError.checkNotNull(
              key, r'GetRealmKeyResponse', 'key'),
          activeFrom: BuiltValueNullFieldError.checkNotNull(
              activeFrom, r'GetRealmKeyResponse', 'activeFrom'),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt, r'GetRealmKeyResponse', 'expiresAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
