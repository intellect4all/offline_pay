// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revoke_all_others_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RevokeAllOthersResponse extends RevokeAllOthersResponse {
  @override
  final int revoked;

  factory _$RevokeAllOthersResponse(
          [void Function(RevokeAllOthersResponseBuilder)? updates]) =>
      (RevokeAllOthersResponseBuilder()..update(updates))._build();

  _$RevokeAllOthersResponse._({required this.revoked}) : super._();
  @override
  RevokeAllOthersResponse rebuild(
          void Function(RevokeAllOthersResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RevokeAllOthersResponseBuilder toBuilder() =>
      RevokeAllOthersResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RevokeAllOthersResponse && revoked == other.revoked;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, revoked.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RevokeAllOthersResponse')
          ..add('revoked', revoked))
        .toString();
  }
}

class RevokeAllOthersResponseBuilder
    implements
        Builder<RevokeAllOthersResponse, RevokeAllOthersResponseBuilder> {
  _$RevokeAllOthersResponse? _$v;

  int? _revoked;
  int? get revoked => _$this._revoked;
  set revoked(int? revoked) => _$this._revoked = revoked;

  RevokeAllOthersResponseBuilder() {
    RevokeAllOthersResponse._defaults(this);
  }

  RevokeAllOthersResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _revoked = $v.revoked;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RevokeAllOthersResponse other) {
    _$v = other as _$RevokeAllOthersResponse;
  }

  @override
  void update(void Function(RevokeAllOthersResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RevokeAllOthersResponse build() => _build();

  _$RevokeAllOthersResponse _build() {
    final _$result = _$v ??
        _$RevokeAllOthersResponse._(
          revoked: BuiltValueNullFieldError.checkNotNull(
              revoked, r'RevokeAllOthersResponse', 'revoked'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
