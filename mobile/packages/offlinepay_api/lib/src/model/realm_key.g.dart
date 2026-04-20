// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realm_key.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RealmKey extends RealmKey {
  @override
  final int version;
  @override
  final String key;
  @override
  final DateTime activeFrom;
  @override
  final DateTime? retiredAt;

  factory _$RealmKey([void Function(RealmKeyBuilder)? updates]) =>
      (RealmKeyBuilder()..update(updates))._build();

  _$RealmKey._(
      {required this.version,
      required this.key,
      required this.activeFrom,
      this.retiredAt})
      : super._();
  @override
  RealmKey rebuild(void Function(RealmKeyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RealmKeyBuilder toBuilder() => RealmKeyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RealmKey &&
        version == other.version &&
        key == other.key &&
        activeFrom == other.activeFrom &&
        retiredAt == other.retiredAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, key.hashCode);
    _$hash = $jc(_$hash, activeFrom.hashCode);
    _$hash = $jc(_$hash, retiredAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RealmKey')
          ..add('version', version)
          ..add('key', key)
          ..add('activeFrom', activeFrom)
          ..add('retiredAt', retiredAt))
        .toString();
  }
}

class RealmKeyBuilder implements Builder<RealmKey, RealmKeyBuilder> {
  _$RealmKey? _$v;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  String? _key;
  String? get key => _$this._key;
  set key(String? key) => _$this._key = key;

  DateTime? _activeFrom;
  DateTime? get activeFrom => _$this._activeFrom;
  set activeFrom(DateTime? activeFrom) => _$this._activeFrom = activeFrom;

  DateTime? _retiredAt;
  DateTime? get retiredAt => _$this._retiredAt;
  set retiredAt(DateTime? retiredAt) => _$this._retiredAt = retiredAt;

  RealmKeyBuilder() {
    RealmKey._defaults(this);
  }

  RealmKeyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _version = $v.version;
      _key = $v.key;
      _activeFrom = $v.activeFrom;
      _retiredAt = $v.retiredAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RealmKey other) {
    _$v = other as _$RealmKey;
  }

  @override
  void update(void Function(RealmKeyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RealmKey build() => _build();

  _$RealmKey _build() {
    final _$result = _$v ??
        _$RealmKey._(
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'RealmKey', 'version'),
          key: BuiltValueNullFieldError.checkNotNull(key, r'RealmKey', 'key'),
          activeFrom: BuiltValueNullFieldError.checkNotNull(
              activeFrom, r'RealmKey', 'activeFrom'),
          retiredAt: retiredAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
