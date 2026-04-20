// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gossip_upload_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GossipUploadBody extends GossipUploadBody {
  @override
  final BuiltList<GossipBlobInput> blobs;

  factory _$GossipUploadBody(
          [void Function(GossipUploadBodyBuilder)? updates]) =>
      (GossipUploadBodyBuilder()..update(updates))._build();

  _$GossipUploadBody._({required this.blobs}) : super._();
  @override
  GossipUploadBody rebuild(void Function(GossipUploadBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GossipUploadBodyBuilder toBuilder() =>
      GossipUploadBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GossipUploadBody && blobs == other.blobs;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, blobs.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GossipUploadBody')
          ..add('blobs', blobs))
        .toString();
  }
}

class GossipUploadBodyBuilder
    implements Builder<GossipUploadBody, GossipUploadBodyBuilder> {
  _$GossipUploadBody? _$v;

  ListBuilder<GossipBlobInput>? _blobs;
  ListBuilder<GossipBlobInput> get blobs =>
      _$this._blobs ??= ListBuilder<GossipBlobInput>();
  set blobs(ListBuilder<GossipBlobInput>? blobs) => _$this._blobs = blobs;

  GossipUploadBodyBuilder() {
    GossipUploadBody._defaults(this);
  }

  GossipUploadBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _blobs = $v.blobs.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GossipUploadBody other) {
    _$v = other as _$GossipUploadBody;
  }

  @override
  void update(void Function(GossipUploadBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GossipUploadBody build() => _build();

  _$GossipUploadBody _build() {
    _$GossipUploadBody _$result;
    try {
      _$result = _$v ??
          _$GossipUploadBody._(
            blobs: blobs.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'blobs';
        blobs.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'GossipUploadBody', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
