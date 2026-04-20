//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:offlinepay_api/src/model/display_card_input.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'auth_tokens.g.dart';

/// AuthTokens
///
/// Properties:
/// * [userId] 
/// * [accountNumber] 
/// * [accessToken] 
/// * [refreshToken] 
/// * [accessExpiresAt] 
/// * [refreshExpiresAt] 
/// * [displayCard] - Server-issued identity credential. Clients cache this for use in every PaymentRequest they publish. Optional on login responses (clients should fall back to GET /v1/identity/display-card); always populated on signup. 
@BuiltValue()
abstract class AuthTokens implements Built<AuthTokens, AuthTokensBuilder> {
  @BuiltValueField(wireName: r'user_id')
  String get userId;

  @BuiltValueField(wireName: r'account_number')
  String get accountNumber;

  @BuiltValueField(wireName: r'access_token')
  String get accessToken;

  @BuiltValueField(wireName: r'refresh_token')
  String get refreshToken;

  @BuiltValueField(wireName: r'access_expires_at')
  DateTime get accessExpiresAt;

  @BuiltValueField(wireName: r'refresh_expires_at')
  DateTime get refreshExpiresAt;

  /// Server-issued identity credential. Clients cache this for use in every PaymentRequest they publish. Optional on login responses (clients should fall back to GET /v1/identity/display-card); always populated on signup. 
  @BuiltValueField(wireName: r'display_card')
  DisplayCardInput? get displayCard;

  AuthTokens._();

  factory AuthTokens([void updates(AuthTokensBuilder b)]) = _$AuthTokens;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AuthTokensBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AuthTokens> get serializer => _$AuthTokensSerializer();
}

class _$AuthTokensSerializer implements PrimitiveSerializer<AuthTokens> {
  @override
  final Iterable<Type> types = const [AuthTokens, _$AuthTokens];

  @override
  final String wireName = r'AuthTokens';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AuthTokens object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'user_id';
    yield serializers.serialize(
      object.userId,
      specifiedType: const FullType(String),
    );
    yield r'account_number';
    yield serializers.serialize(
      object.accountNumber,
      specifiedType: const FullType(String),
    );
    yield r'access_token';
    yield serializers.serialize(
      object.accessToken,
      specifiedType: const FullType(String),
    );
    yield r'refresh_token';
    yield serializers.serialize(
      object.refreshToken,
      specifiedType: const FullType(String),
    );
    yield r'access_expires_at';
    yield serializers.serialize(
      object.accessExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'refresh_expires_at';
    yield serializers.serialize(
      object.refreshExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    if (object.displayCard != null) {
      yield r'display_card';
      yield serializers.serialize(
        object.displayCard,
        specifiedType: const FullType(DisplayCardInput),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    AuthTokens object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AuthTokensBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'user_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.userId = valueDes;
          break;
        case r'account_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.accountNumber = valueDes;
          break;
        case r'access_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.accessToken = valueDes;
          break;
        case r'refresh_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.refreshToken = valueDes;
          break;
        case r'access_expires_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.accessExpiresAt = valueDes;
          break;
        case r'refresh_expires_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.refreshExpiresAt = valueDes;
          break;
        case r'display_card':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DisplayCardInput),
          ) as DisplayCardInput;
          result.displayCard.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AuthTokens deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AuthTokensBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}

