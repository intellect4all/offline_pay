// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_session_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DeviceSessionRequestScopeEnum _$deviceSessionRequestScopeEnum_offlinePay =
    const DeviceSessionRequestScopeEnum._('offlinePay');

DeviceSessionRequestScopeEnum _$deviceSessionRequestScopeEnumValueOf(
    String name) {
  switch (name) {
    case 'offlinePay':
      return _$deviceSessionRequestScopeEnum_offlinePay;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DeviceSessionRequestScopeEnum>
    _$deviceSessionRequestScopeEnumValues = BuiltSet<
        DeviceSessionRequestScopeEnum>(const <DeviceSessionRequestScopeEnum>[
  _$deviceSessionRequestScopeEnum_offlinePay,
]);

Serializer<DeviceSessionRequestScopeEnum>
    _$deviceSessionRequestScopeEnumSerializer =
    _$DeviceSessionRequestScopeEnumSerializer();

class _$DeviceSessionRequestScopeEnumSerializer
    implements PrimitiveSerializer<DeviceSessionRequestScopeEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'offlinePay': 'offline_pay',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'offline_pay': 'offlinePay',
  };

  @override
  final Iterable<Type> types = const <Type>[DeviceSessionRequestScopeEnum];
  @override
  final String wireName = 'DeviceSessionRequestScopeEnum';

  @override
  Object serialize(
          Serializers serializers, DeviceSessionRequestScopeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DeviceSessionRequestScopeEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DeviceSessionRequestScopeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DeviceSessionRequest extends DeviceSessionRequest {
  @override
  final String deviceId;
  @override
  final DeviceSessionRequestScopeEnum? scope;

  factory _$DeviceSessionRequest(
          [void Function(DeviceSessionRequestBuilder)? updates]) =>
      (DeviceSessionRequestBuilder()..update(updates))._build();

  _$DeviceSessionRequest._({required this.deviceId, this.scope}) : super._();
  @override
  DeviceSessionRequest rebuild(
          void Function(DeviceSessionRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeviceSessionRequestBuilder toBuilder() =>
      DeviceSessionRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceSessionRequest &&
        deviceId == other.deviceId &&
        scope == other.scope;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deviceId.hashCode);
    _$hash = $jc(_$hash, scope.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceSessionRequest')
          ..add('deviceId', deviceId)
          ..add('scope', scope))
        .toString();
  }
}

class DeviceSessionRequestBuilder
    implements Builder<DeviceSessionRequest, DeviceSessionRequestBuilder> {
  _$DeviceSessionRequest? _$v;

  String? _deviceId;
  String? get deviceId => _$this._deviceId;
  set deviceId(String? deviceId) => _$this._deviceId = deviceId;

  DeviceSessionRequestScopeEnum? _scope;
  DeviceSessionRequestScopeEnum? get scope => _$this._scope;
  set scope(DeviceSessionRequestScopeEnum? scope) => _$this._scope = scope;

  DeviceSessionRequestBuilder() {
    DeviceSessionRequest._defaults(this);
  }

  DeviceSessionRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceId = $v.deviceId;
      _scope = $v.scope;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceSessionRequest other) {
    _$v = other as _$DeviceSessionRequest;
  }

  @override
  void update(void Function(DeviceSessionRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceSessionRequest build() => _build();

  _$DeviceSessionRequest _build() {
    final _$result = _$v ??
        _$DeviceSessionRequest._(
          deviceId: BuiltValueNullFieldError.checkNotNull(
              deviceId, r'DeviceSessionRequest', 'deviceId'),
          scope: scope,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
