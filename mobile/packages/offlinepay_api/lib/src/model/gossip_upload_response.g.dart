// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gossip_upload_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GossipUploadResponse extends GossipUploadResponse {
  @override
  final int accepted;
  @override
  final int duplicates;
  @override
  final int invalid;

  factory _$GossipUploadResponse(
          [void Function(GossipUploadResponseBuilder)? updates]) =>
      (GossipUploadResponseBuilder()..update(updates))._build();

  _$GossipUploadResponse._(
      {required this.accepted, required this.duplicates, required this.invalid})
      : super._();
  @override
  GossipUploadResponse rebuild(
          void Function(GossipUploadResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GossipUploadResponseBuilder toBuilder() =>
      GossipUploadResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GossipUploadResponse &&
        accepted == other.accepted &&
        duplicates == other.duplicates &&
        invalid == other.invalid;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, accepted.hashCode);
    _$hash = $jc(_$hash, duplicates.hashCode);
    _$hash = $jc(_$hash, invalid.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GossipUploadResponse')
          ..add('accepted', accepted)
          ..add('duplicates', duplicates)
          ..add('invalid', invalid))
        .toString();
  }
}

class GossipUploadResponseBuilder
    implements Builder<GossipUploadResponse, GossipUploadResponseBuilder> {
  _$GossipUploadResponse? _$v;

  int? _accepted;
  int? get accepted => _$this._accepted;
  set accepted(int? accepted) => _$this._accepted = accepted;

  int? _duplicates;
  int? get duplicates => _$this._duplicates;
  set duplicates(int? duplicates) => _$this._duplicates = duplicates;

  int? _invalid;
  int? get invalid => _$this._invalid;
  set invalid(int? invalid) => _$this._invalid = invalid;

  GossipUploadResponseBuilder() {
    GossipUploadResponse._defaults(this);
  }

  GossipUploadResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _accepted = $v.accepted;
      _duplicates = $v.duplicates;
      _invalid = $v.invalid;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GossipUploadResponse other) {
    _$v = other as _$GossipUploadResponse;
  }

  @override
  void update(void Function(GossipUploadResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GossipUploadResponse build() => _build();

  _$GossipUploadResponse _build() {
    final _$result = _$v ??
        _$GossipUploadResponse._(
          accepted: BuiltValueNullFieldError.checkNotNull(
              accepted, r'GossipUploadResponse', 'accepted'),
          duplicates: BuiltValueNullFieldError.checkNotNull(
              duplicates, r'GossipUploadResponse', 'duplicates'),
          invalid: BuiltValueNullFieldError.checkNotNull(
              invalid, r'GossipUploadResponse', 'invalid'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
