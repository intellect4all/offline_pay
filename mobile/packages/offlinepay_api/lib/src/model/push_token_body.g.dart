// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const PushTokenBodyPlatformEnum _$pushTokenBodyPlatformEnum_android =
    const PushTokenBodyPlatformEnum._('android');
const PushTokenBodyPlatformEnum _$pushTokenBodyPlatformEnum_ios =
    const PushTokenBodyPlatformEnum._('ios');

PushTokenBodyPlatformEnum _$pushTokenBodyPlatformEnumValueOf(String name) {
  switch (name) {
    case 'android':
      return _$pushTokenBodyPlatformEnum_android;
    case 'ios':
      return _$pushTokenBodyPlatformEnum_ios;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<PushTokenBodyPlatformEnum> _$pushTokenBodyPlatformEnumValues =
    BuiltSet<PushTokenBodyPlatformEnum>(const <PushTokenBodyPlatformEnum>[
  _$pushTokenBodyPlatformEnum_android,
  _$pushTokenBodyPlatformEnum_ios,
]);

Serializer<PushTokenBodyPlatformEnum> _$pushTokenBodyPlatformEnumSerializer =
    _$PushTokenBodyPlatformEnumSerializer();

class _$PushTokenBodyPlatformEnumSerializer
    implements PrimitiveSerializer<PushTokenBodyPlatformEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'android': 'android',
    'ios': 'ios',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'android': 'android',
    'ios': 'ios',
  };

  @override
  final Iterable<Type> types = const <Type>[PushTokenBodyPlatformEnum];
  @override
  final String wireName = 'PushTokenBodyPlatformEnum';

  @override
  Object serialize(Serializers serializers, PushTokenBodyPlatformEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  PushTokenBodyPlatformEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      PushTokenBodyPlatformEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$PushTokenBody extends PushTokenBody {
  @override
  final String fcmToken;
  @override
  final PushTokenBodyPlatformEnum platform;

  factory _$PushTokenBody([void Function(PushTokenBodyBuilder)? updates]) =>
      (PushTokenBodyBuilder()..update(updates))._build();

  _$PushTokenBody._({required this.fcmToken, required this.platform})
      : super._();
  @override
  PushTokenBody rebuild(void Function(PushTokenBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PushTokenBodyBuilder toBuilder() => PushTokenBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PushTokenBody &&
        fcmToken == other.fcmToken &&
        platform == other.platform;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, fcmToken.hashCode);
    _$hash = $jc(_$hash, platform.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PushTokenBody')
          ..add('fcmToken', fcmToken)
          ..add('platform', platform))
        .toString();
  }
}

class PushTokenBodyBuilder
    implements Builder<PushTokenBody, PushTokenBodyBuilder> {
  _$PushTokenBody? _$v;

  String? _fcmToken;
  String? get fcmToken => _$this._fcmToken;
  set fcmToken(String? fcmToken) => _$this._fcmToken = fcmToken;

  PushTokenBodyPlatformEnum? _platform;
  PushTokenBodyPlatformEnum? get platform => _$this._platform;
  set platform(PushTokenBodyPlatformEnum? platform) =>
      _$this._platform = platform;

  PushTokenBodyBuilder() {
    PushTokenBody._defaults(this);
  }

  PushTokenBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _fcmToken = $v.fcmToken;
      _platform = $v.platform;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PushTokenBody other) {
    _$v = other as _$PushTokenBody;
  }

  @override
  void update(void Function(PushTokenBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PushTokenBody build() => _build();

  _$PushTokenBody _build() {
    final _$result = _$v ??
        _$PushTokenBody._(
          fcmToken: BuiltValueNullFieldError.checkNotNull(
              fcmToken, r'PushTokenBody', 'fcmToken'),
          platform: BuiltValueNullFieldError.checkNotNull(
              platform, r'PushTokenBody', 'platform'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
