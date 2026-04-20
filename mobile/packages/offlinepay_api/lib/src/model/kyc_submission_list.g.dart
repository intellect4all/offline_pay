// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kyc_submission_list.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$KYCSubmissionList extends KYCSubmissionList {
  @override
  final BuiltList<KYCSubmission> items;

  factory _$KYCSubmissionList(
          [void Function(KYCSubmissionListBuilder)? updates]) =>
      (KYCSubmissionListBuilder()..update(updates))._build();

  _$KYCSubmissionList._({required this.items}) : super._();
  @override
  KYCSubmissionList rebuild(void Function(KYCSubmissionListBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  KYCSubmissionListBuilder toBuilder() =>
      KYCSubmissionListBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is KYCSubmissionList && items == other.items;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'KYCSubmissionList')
          ..add('items', items))
        .toString();
  }
}

class KYCSubmissionListBuilder
    implements Builder<KYCSubmissionList, KYCSubmissionListBuilder> {
  _$KYCSubmissionList? _$v;

  ListBuilder<KYCSubmission>? _items;
  ListBuilder<KYCSubmission> get items =>
      _$this._items ??= ListBuilder<KYCSubmission>();
  set items(ListBuilder<KYCSubmission>? items) => _$this._items = items;

  KYCSubmissionListBuilder() {
    KYCSubmissionList._defaults(this);
  }

  KYCSubmissionListBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(KYCSubmissionList other) {
    _$v = other as _$KYCSubmissionList;
  }

  @override
  void update(void Function(KYCSubmissionListBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  KYCSubmissionList build() => _build();

  _$KYCSubmissionList _build() {
    _$KYCSubmissionList _$result;
    try {
      _$result = _$v ??
          _$KYCSubmissionList._(
            items: items.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'KYCSubmissionList', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
