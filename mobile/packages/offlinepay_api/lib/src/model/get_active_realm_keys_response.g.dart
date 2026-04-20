// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_active_realm_keys_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetActiveRealmKeysResponse extends GetActiveRealmKeysResponse {
  @override
  final BuiltList<RealmKey> keys;

  factory _$GetActiveRealmKeysResponse(
          [void Function(GetActiveRealmKeysResponseBuilder)? updates]) =>
      (GetActiveRealmKeysResponseBuilder()..update(updates))._build();

  _$GetActiveRealmKeysResponse._({required this.keys}) : super._();
  @override
  GetActiveRealmKeysResponse rebuild(
          void Function(GetActiveRealmKeysResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GetActiveRealmKeysResponseBuilder toBuilder() =>
      GetActiveRealmKeysResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetActiveRealmKeysResponse && keys == other.keys;
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
    return (newBuiltValueToStringHelper(r'GetActiveRealmKeysResponse')
          ..add('keys', keys))
        .toString();
  }
}

class GetActiveRealmKeysResponseBuilder
    implements
        Builder<GetActiveRealmKeysResponse, GetActiveRealmKeysResponseBuilder> {
  _$GetActiveRealmKeysResponse? _$v;

  ListBuilder<RealmKey>? _keys;
  ListBuilder<RealmKey> get keys => _$this._keys ??= ListBuilder<RealmKey>();
  set keys(ListBuilder<RealmKey>? keys) => _$this._keys = keys;

  GetActiveRealmKeysResponseBuilder() {
    GetActiveRealmKeysResponse._defaults(this);
  }

  GetActiveRealmKeysResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _keys = $v.keys.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetActiveRealmKeysResponse other) {
    _$v = other as _$GetActiveRealmKeysResponse;
  }

  @override
  void update(void Function(GetActiveRealmKeysResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetActiveRealmKeysResponse build() => _build();

  _$GetActiveRealmKeysResponse _build() {
    _$GetActiveRealmKeysResponse _$result;
    try {
      _$result = _$v ??
          _$GetActiveRealmKeysResponse._(
            keys: keys.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'keys';
        keys.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'GetActiveRealmKeysResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
