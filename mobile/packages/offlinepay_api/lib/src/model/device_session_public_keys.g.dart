// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_session_public_keys.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeviceSessionPublicKeys extends DeviceSessionPublicKeys {
  @override
  final BuiltList<DeviceSessionPublicKey> keys;

  factory _$DeviceSessionPublicKeys(
          [void Function(DeviceSessionPublicKeysBuilder)? updates]) =>
      (DeviceSessionPublicKeysBuilder()..update(updates))._build();

  _$DeviceSessionPublicKeys._({required this.keys}) : super._();
  @override
  DeviceSessionPublicKeys rebuild(
          void Function(DeviceSessionPublicKeysBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeviceSessionPublicKeysBuilder toBuilder() =>
      DeviceSessionPublicKeysBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceSessionPublicKeys && keys == other.keys;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, keys.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceSessionPublicKeys')
          ..add('keys', keys))
        .toString();
  }
}

class DeviceSessionPublicKeysBuilder
    implements
        Builder<DeviceSessionPublicKeys, DeviceSessionPublicKeysBuilder> {
  _$DeviceSessionPublicKeys? _$v;

  ListBuilder<DeviceSessionPublicKey>? _keys;
  ListBuilder<DeviceSessionPublicKey> get keys =>
      _$this._keys ??= ListBuilder<DeviceSessionPublicKey>();
  set keys(ListBuilder<DeviceSessionPublicKey>? keys) => _$this._keys = keys;

  DeviceSessionPublicKeysBuilder() {
    DeviceSessionPublicKeys._defaults(this);
  }

  DeviceSessionPublicKeysBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _keys = $v.keys.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceSessionPublicKeys other) {
    _$v = other as _$DeviceSessionPublicKeys;
  }

  @override
  void update(void Function(DeviceSessionPublicKeysBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceSessionPublicKeys build() => _build();

  _$DeviceSessionPublicKeys _build() {
    _$DeviceSessionPublicKeys _$result;
    try {
      _$result = _$v ??
          _$DeviceSessionPublicKeys._(
            keys: keys.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'keys';
        keys.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'DeviceSessionPublicKeys', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
