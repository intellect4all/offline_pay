// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_public_keys_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$BankPublicKeysBody extends BankPublicKeysBody {
  @override
  final BuiltList<String>? keyIds;

  factory _$BankPublicKeysBody(
          [void Function(BankPublicKeysBodyBuilder)? updates]) =>
      (BankPublicKeysBodyBuilder()..update(updates))._build();

  _$BankPublicKeysBody._({this.keyIds}) : super._();
  @override
  BankPublicKeysBody rebuild(
          void Function(BankPublicKeysBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  BankPublicKeysBodyBuilder toBuilder() =>
      BankPublicKeysBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BankPublicKeysBody && keyIds == other.keyIds;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, keyIds.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'BankPublicKeysBody')
          ..add('keyIds', keyIds))
        .toString();
  }
}

class BankPublicKeysBodyBuilder
    implements Builder<BankPublicKeysBody, BankPublicKeysBodyBuilder> {
  _$BankPublicKeysBody? _$v;

  ListBuilder<String>? _keyIds;
  ListBuilder<String> get keyIds => _$this._keyIds ??= ListBuilder<String>();
  set keyIds(ListBuilder<String>? keyIds) => _$this._keyIds = keyIds;

  BankPublicKeysBodyBuilder() {
    BankPublicKeysBody._defaults(this);
  }

  BankPublicKeysBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _keyIds = $v.keyIds?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BankPublicKeysBody other) {
    _$v = other as _$BankPublicKeysBody;
  }

  @override
  void update(void Function(BankPublicKeysBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BankPublicKeysBody build() => _build();

  _$BankPublicKeysBody _build() {
    _$BankPublicKeysBody _$result;
    try {
      _$result = _$v ??
          _$BankPublicKeysBody._(
            keyIds: _keyIds?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'keyIds';
        _keyIds?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'BankPublicKeysBody', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
