// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer_list.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$TransferList extends TransferList {
  @override
  final BuiltList<Transfer> items;
  @override
  final int limit;
  @override
  final int offset;

  factory _$TransferList([void Function(TransferListBuilder)? updates]) =>
      (TransferListBuilder()..update(updates))._build();

  _$TransferList._(
      {required this.items, required this.limit, required this.offset})
      : super._();
  @override
  TransferList rebuild(void Function(TransferListBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TransferListBuilder toBuilder() => TransferListBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TransferList &&
        items == other.items &&
        limit == other.limit &&
        offset == other.offset;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, limit.hashCode);
    _$hash = $jc(_$hash, offset.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'TransferList')
          ..add('items', items)
          ..add('limit', limit)
          ..add('offset', offset))
        .toString();
  }
}

class TransferListBuilder
    implements Builder<TransferList, TransferListBuilder> {
  _$TransferList? _$v;

  ListBuilder<Transfer>? _items;
  ListBuilder<Transfer> get items => _$this._items ??= ListBuilder<Transfer>();
  set items(ListBuilder<Transfer>? items) => _$this._items = items;

  int? _limit;
  int? get limit => _$this._limit;
  set limit(int? limit) => _$this._limit = limit;

  int? _offset;
  int? get offset => _$this._offset;
  set offset(int? offset) => _$this._offset = offset;

  TransferListBuilder() {
    TransferList._defaults(this);
  }

  TransferListBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _limit = $v.limit;
      _offset = $v.offset;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(TransferList other) {
    _$v = other as _$TransferList;
  }

  @override
  void update(void Function(TransferListBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TransferList build() => _build();

  _$TransferList _build() {
    _$TransferList _$result;
    try {
      _$result = _$v ??
          _$TransferList._(
            items: items.build(),
            limit: BuiltValueNullFieldError.checkNotNull(
                limit, r'TransferList', 'limit'),
            offset: BuiltValueNullFieldError.checkNotNull(
                offset, r'TransferList', 'offset'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'TransferList', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
