// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kyc_submit_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const KYCSubmitBodyIdTypeEnum _$kYCSubmitBodyIdTypeEnum_NIN =
    const KYCSubmitBodyIdTypeEnum._('NIN');
const KYCSubmitBodyIdTypeEnum _$kYCSubmitBodyIdTypeEnum_BVN =
    const KYCSubmitBodyIdTypeEnum._('BVN');

KYCSubmitBodyIdTypeEnum _$kYCSubmitBodyIdTypeEnumValueOf(String name) {
  switch (name) {
    case 'NIN':
      return _$kYCSubmitBodyIdTypeEnum_NIN;
    case 'BVN':
      return _$kYCSubmitBodyIdTypeEnum_BVN;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<KYCSubmitBodyIdTypeEnum> _$kYCSubmitBodyIdTypeEnumValues =
    BuiltSet<KYCSubmitBodyIdTypeEnum>(const <KYCSubmitBodyIdTypeEnum>[
  _$kYCSubmitBodyIdTypeEnum_NIN,
  _$kYCSubmitBodyIdTypeEnum_BVN,
]);

Serializer<KYCSubmitBodyIdTypeEnum> _$kYCSubmitBodyIdTypeEnumSerializer =
    _$KYCSubmitBodyIdTypeEnumSerializer();

class _$KYCSubmitBodyIdTypeEnumSerializer
    implements PrimitiveSerializer<KYCSubmitBodyIdTypeEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'NIN': 'NIN',
    'BVN': 'BVN',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'NIN': 'NIN',
    'BVN': 'BVN',
  };

  @override
  final Iterable<Type> types = const <Type>[KYCSubmitBodyIdTypeEnum];
  @override
  final String wireName = 'KYCSubmitBodyIdTypeEnum';

  @override
  Object serialize(Serializers serializers, KYCSubmitBodyIdTypeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  KYCSubmitBodyIdTypeEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      KYCSubmitBodyIdTypeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$KYCSubmitBody extends KYCSubmitBody {
  @override
  final KYCSubmitBodyIdTypeEnum idType;
  @override
  final String idNumber;

  factory _$KYCSubmitBody([void Function(KYCSubmitBodyBuilder)? updates]) =>
      (KYCSubmitBodyBuilder()..update(updates))._build();

  _$KYCSubmitBody._({required this.idType, required this.idNumber}) : super._();
  @override
  KYCSubmitBody rebuild(void Function(KYCSubmitBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  KYCSubmitBodyBuilder toBuilder() => KYCSubmitBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is KYCSubmitBody &&
        idType == other.idType &&
        idNumber == other.idNumber;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, idType.hashCode);
    _$hash = $jc(_$hash, idNumber.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'KYCSubmitBody')
          ..add('idType', idType)
          ..add('idNumber', idNumber))
        .toString();
  }
}

class KYCSubmitBodyBuilder
    implements Builder<KYCSubmitBody, KYCSubmitBodyBuilder> {
  _$KYCSubmitBody? _$v;

  KYCSubmitBodyIdTypeEnum? _idType;
  KYCSubmitBodyIdTypeEnum? get idType => _$this._idType;
  set idType(KYCSubmitBodyIdTypeEnum? idType) => _$this._idType = idType;

  String? _idNumber;
  String? get idNumber => _$this._idNumber;
  set idNumber(String? idNumber) => _$this._idNumber = idNumber;

  KYCSubmitBodyBuilder() {
    KYCSubmitBody._defaults(this);
  }

  KYCSubmitBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _idType = $v.idType;
      _idNumber = $v.idNumber;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(KYCSubmitBody other) {
    _$v = other as _$KYCSubmitBody;
  }

  @override
  void update(void Function(KYCSubmitBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  KYCSubmitBody build() => _build();

  _$KYCSubmitBody _build() {
    final _$result = _$v ??
        _$KYCSubmitBody._(
          idType: BuiltValueNullFieldError.checkNotNull(
              idType, r'KYCSubmitBody', 'idType'),
          idNumber: BuiltValueNullFieldError.checkNotNull(
              idNumber, r'KYCSubmitBody', 'idNumber'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
