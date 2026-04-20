//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'current_ceiling_response.g.dart';

/// CurrentCeilingResponse
///
/// Properties:
/// * [present] - False when the payer has no offline wallet (no ACTIVE or RECOVERY_PENDING ceiling). All other fields are omitted or zero in that case. 
/// * [ceilingId] 
/// * [status] - ACTIVE or RECOVERY_PENDING.
/// * [ceilingKobo] 
/// * [settledKobo] - Total settled across every payment token issued against this ceiling. `ceiling_kobo - settled_kobo = remaining_kobo`. 
/// * [remainingKobo] - The amount the lien would return to main if the ceiling released right now. Used for the offline-wallet card and to cross-check against the lien account balance. 
/// * [issuedAt] 
/// * [expiresAt] 
/// * [releaseAfter] - Populated only when status is RECOVERY_PENDING. After this instant the expiry sweep releases the remaining lien back to main. 
@BuiltValue()
abstract class CurrentCeilingResponse implements Built<CurrentCeilingResponse, CurrentCeilingResponseBuilder> {
  /// False when the payer has no offline wallet (no ACTIVE or RECOVERY_PENDING ceiling). All other fields are omitted or zero in that case. 
  @BuiltValueField(wireName: r'present')
  bool get present;

  @BuiltValueField(wireName: r'ceiling_id')
  String? get ceilingId;

  /// ACTIVE or RECOVERY_PENDING.
  @BuiltValueField(wireName: r'status')
  String? get status;

  @BuiltValueField(wireName: r'ceiling_kobo')
  int? get ceilingKobo;

  /// Total settled across every payment token issued against this ceiling. `ceiling_kobo - settled_kobo = remaining_kobo`. 
  @BuiltValueField(wireName: r'settled_kobo')
  int? get settledKobo;

  /// The amount the lien would return to main if the ceiling released right now. Used for the offline-wallet card and to cross-check against the lien account balance. 
  @BuiltValueField(wireName: r'remaining_kobo')
  int? get remainingKobo;

  @BuiltValueField(wireName: r'issued_at')
  DateTime? get issuedAt;

  @BuiltValueField(wireName: r'expires_at')
  DateTime? get expiresAt;

  /// Populated only when status is RECOVERY_PENDING. After this instant the expiry sweep releases the remaining lien back to main. 
  @BuiltValueField(wireName: r'release_after')
  DateTime? get releaseAfter;

  CurrentCeilingResponse._();

  factory CurrentCeilingResponse([void updates(CurrentCeilingResponseBuilder b)]) = _$CurrentCeilingResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CurrentCeilingResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CurrentCeilingResponse> get serializer => _$CurrentCeilingResponseSerializer();
}

class _$CurrentCeilingResponseSerializer implements PrimitiveSerializer<CurrentCeilingResponse> {
  @override
  final Iterable<Type> types = const [CurrentCeilingResponse, _$CurrentCeilingResponse];

  @override
  final String wireName = r'CurrentCeilingResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CurrentCeilingResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'present';
    yield serializers.serialize(
      object.present,
      specifiedType: const FullType(bool),
    );
    if (object.ceilingId != null) {
      yield r'ceiling_id';
      yield serializers.serialize(
        object.ceilingId,
        specifiedType: const FullType(String),
      );
    }
    if (object.status != null) {
      yield r'status';
      yield serializers.serialize(
        object.status,
        specifiedType: const FullType(String),
      );
    }
    if (object.ceilingKobo != null) {
      yield r'ceiling_kobo';
      yield serializers.serialize(
        object.ceilingKobo,
        specifiedType: const FullType(int),
      );
    }
    if (object.settledKobo != null) {
      yield r'settled_kobo';
      yield serializers.serialize(
        object.settledKobo,
        specifiedType: const FullType(int),
      );
    }
    if (object.remainingKobo != null) {
      yield r'remaining_kobo';
      yield serializers.serialize(
        object.remainingKobo,
        specifiedType: const FullType(int),
      );
    }
    if (object.issuedAt != null) {
      yield r'issued_at';
      yield serializers.serialize(
        object.issuedAt,
        specifiedType: const FullType(DateTime),
      );
    }
    if (object.expiresAt != null) {
      yield r'expires_at';
      yield serializers.serialize(
        object.expiresAt,
        specifiedType: const FullType(DateTime),
      );
    }
    if (object.releaseAfter != null) {
      yield r'release_after';
      yield serializers.serialize(
        object.releaseAfter,
        specifiedType: const FullType(DateTime),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    CurrentCeilingResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CurrentCeilingResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'present':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.present = valueDes;
          break;
        case r'ceiling_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.ceilingId = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.status = valueDes;
          break;
        case r'ceiling_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.ceilingKobo = valueDes;
          break;
        case r'settled_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.settledKobo = valueDes;
          break;
        case r'remaining_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.remainingKobo = valueDes;
          break;
        case r'issued_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.issuedAt = valueDes;
          break;
        case r'expires_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.expiresAt = valueDes;
          break;
        case r'release_after':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.releaseAfter = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CurrentCeilingResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CurrentCeilingResponseBuilder();
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

