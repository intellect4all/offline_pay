// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_session_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DeviceSessionResponseScopeEnum
    _$deviceSessionResponseScopeEnum_offlinePay =
    const DeviceSessionResponseScopeEnum._('offlinePay');

DeviceSessionResponseScopeEnum _$deviceSessionResponseScopeEnumValueOf(
    String name) {
  switch (name) {
    case 'offlinePay':
      return _$deviceSessionResponseScopeEnum_offlinePay;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DeviceSessionResponseScopeEnum>
    _$deviceSessionResponseScopeEnumValues = BuiltSet<
        DeviceSessionResponseScopeEnum>(const <DeviceSessionResponseScopeEnum>[
  _$deviceSessionResponseScopeEnum_offlinePay,
]);

Serializer<DeviceSessionResponseScopeEnum>
    _$deviceSessionResponseScopeEnumSerializer =
    _$DeviceSessionResponseScopeEnumSerializer();

class _$DeviceSessionResponseScopeEnumSerializer
    implements PrimitiveSerializer<DeviceSessionResponseScopeEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'offlinePay': 'offline_pay',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'offline_pay': 'offlinePay',
  };

  @override
  final Iterable<Type> types = const <Type>[DeviceSessionResponseScopeEnum];
  @override
  final String wireName = 'DeviceSessionResponseScopeEnum';

  @override
  Object serialize(
          Serializers serializers, DeviceSessionResponseScopeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DeviceSessionResponseScopeEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DeviceSessionResponseScopeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DeviceSessionResponse extends DeviceSessionResponse {
  @override
  final String token;
  @override
  final String serverPublicKey;
  @override
  final String keyId;
  @override
  final DateTime issuedAt;
  @override
  final DateTime expiresAt;
  @override
  final DeviceSessionResponseScopeEnum scope;

  factory _$DeviceSessionResponse(
          [void Function(DeviceSessionResponseBuilder)? updates]) =>
      (DeviceSessionResponseBuilder()..update(updates))._build();

  _$DeviceSessionResponse._(
      {required this.token,
      required this.serverPublicKey,
      required this.keyId,
      required this.issuedAt,
      required this.expiresAt,
      required this.scope})
      : super._();
  @override
  DeviceSessionResponse rebuild(
          void Function(DeviceSessionResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeviceSessionResponseBuilder toBuilder() =>
      DeviceSessionResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceSessionResponse &&
        token == other.token &&
        serverPublicKey == other.serverPublicKey &&
        keyId == other.keyId &&
        issuedAt == other.issuedAt &&
        expiresAt == other.expiresAt &&
        scope == other.scope;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, token.hashCode);
    _$hash = $jc(_$hash, serverPublicKey.hashCode);
    _$hash = $jc(_$hash, keyId.hashCode);
    _$hash = $jc(_$hash, issuedAt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, scope.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceSessionResponse')
          ..add('token', token)
          ..add('serverPublicKey', serverPublicKey)
          ..add('keyId', keyId)
          ..add('issuedAt', issuedAt)
          ..add('expiresAt', expiresAt)
          ..add('scope', scope))
        .toString();
  }
}

class DeviceSessionResponseBuilder
    implements Builder<DeviceSessionResponse, DeviceSessionResponseBuilder> {
  _$DeviceSessionResponse? _$v;

  String? _token;
  String? get token => _$this._token;
  set token(String? token) => _$this._token = token;

  String? _serverPublicKey;
  String? get serverPublicKey => _$this._serverPublicKey;
  set serverPublicKey(String? serverPublicKey) =>
      _$this._serverPublicKey = serverPublicKey;

  String? _keyId;
  String? get keyId => _$this._keyId;
  set keyId(String? keyId) => _$this._keyId = keyId;

  DateTime? _issuedAt;
  DateTime? get issuedAt => _$this._issuedAt;
  set issuedAt(DateTime? issuedAt) => _$this._issuedAt = issuedAt;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  DeviceSessionResponseScopeEnum? _scope;
  DeviceSessionResponseScopeEnum? get scope => _$this._scope;
  set scope(DeviceSessionResponseScopeEnum? scope) => _$this._scope = scope;

  DeviceSessionResponseBuilder() {
    DeviceSessionResponse._defaults(this);
  }

  DeviceSessionResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _token = $v.token;
      _serverPublicKey = $v.serverPublicKey;
      _keyId = $v.keyId;
      _issuedAt = $v.issuedAt;
      _expiresAt = $v.expiresAt;
      _scope = $v.scope;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceSessionResponse other) {
    _$v = other as _$DeviceSessionResponse;
  }

  @override
  void update(void Function(DeviceSessionResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceSessionResponse build() => _build();

  _$DeviceSessionResponse _build() {
    final _$result = _$v ??
        _$DeviceSessionResponse._(
          token: BuiltValueNullFieldError.checkNotNull(
              token, r'DeviceSessionResponse', 'token'),
          serverPublicKey: BuiltValueNullFieldError.checkNotNull(
              serverPublicKey, r'DeviceSessionResponse', 'serverPublicKey'),
          keyId: BuiltValueNullFieldError.checkNotNull(
              keyId, r'DeviceSessionResponse', 'keyId'),
          issuedAt: BuiltValueNullFieldError.checkNotNull(
              issuedAt, r'DeviceSessionResponse', 'issuedAt'),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt, r'DeviceSessionResponse', 'expiresAt'),
          scope: BuiltValueNullFieldError.checkNotNull(
              scope, r'DeviceSessionResponse', 'scope'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
