// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_public_keys_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$BankPublicKeysResponse extends BankPublicKeysResponse {
  @override
  final BuiltList<BankPublicKey> keys;

  factory _$BankPublicKeysResponse(
          [void Function(BankPublicKeysResponseBuilder)? updates]) =>
      (BankPublicKeysResponseBuilder()..update(updates))._build();

  _$BankPublicKeysResponse._({required this.keys}) : super._();
  @override
  BankPublicKeysResponse rebuild(
          void Function(BankPublicKeysResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  BankPublicKeysResponseBuilder toBuilder() =>
      BankPublicKeysResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BankPublicKeysResponse && keys == other.keys;
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
    return (newBuiltValueToStringHelper(r'BankPublicKeysResponse')
          ..add('keys', keys))
        .toString();
  }
}

class BankPublicKeysResponseBuilder
    implements Builder<BankPublicKeysResponse, BankPublicKeysResponseBuilder> {
  _$BankPublicKeysResponse? _$v;

  ListBuilder<BankPublicKey>? _keys;
  ListBuilder<BankPublicKey> get keys =>
      _$this._keys ??= ListBuilder<BankPublicKey>();
  set keys(ListBuilder<BankPublicKey>? keys) => _$this._keys = keys;

  BankPublicKeysResponseBuilder() {
    BankPublicKeysResponse._defaults(this);
  }

  BankPublicKeysResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _keys = $v.keys.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BankPublicKeysResponse other) {
    _$v = other as _$BankPublicKeysResponse;
  }

  @override
  void update(void Function(BankPublicKeysResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BankPublicKeysResponse build() => _build();

  _$BankPublicKeysResponse _build() {
    _$BankPublicKeysResponse _$result;
    try {
      _$result = _$v ??
          _$BankPublicKeysResponse._(
            keys: keys.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'keys';
        keys.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'BankPublicKeysResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
