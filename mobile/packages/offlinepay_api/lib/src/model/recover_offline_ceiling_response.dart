//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'recover_offline_ceiling_response.g.dart';

/// RecoverOfflineCeilingResponse
///
/// Properties:
/// * [ceilingId] 
/// * [quarantinedKobo] - Amount held in quarantine. Funds are released to the main wallet by the expiry sweep once `release_after` passes. Late-arriving offline claims against this ceiling will settle first and reduce the released amount accordingly. 
/// * [releaseAfter] - Wall-clock time after which the expiry sweep returns the remaining lien balance to the main wallet. Equals the ceiling's original expiry plus the auto-settle timeout plus a 30-minute grace. 
@BuiltValue()
abstract class RecoverOfflineCeilingResponse implements Built<RecoverOfflineCeilingResponse, RecoverOfflineCeilingResponseBuilder> {
  @BuiltValueField(wireName: r'ceiling_id')
  String get ceilingId;

  /// Amount held in quarantine. Funds are released to the main wallet by the expiry sweep once `release_after` passes. Late-arriving offline claims against this ceiling will settle first and reduce the released amount accordingly. 
  @BuiltValueField(wireName: r'quarantined_kobo')
  int get quarantinedKobo;

  /// Wall-clock time after which the expiry sweep returns the remaining lien balance to the main wallet. Equals the ceiling's original expiry plus the auto-settle timeout plus a 30-minute grace. 
  @BuiltValueField(wireName: r'release_after')
  DateTime get releaseAfter;

  RecoverOfflineCeilingResponse._();

  factory RecoverOfflineCeilingResponse([void updates(RecoverOfflineCeilingResponseBuilder b)]) = _$RecoverOfflineCeilingResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RecoverOfflineCeilingResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RecoverOfflineCeilingResponse> get serializer => _$RecoverOfflineCeilingResponseSerializer();
}

class _$RecoverOfflineCeilingResponseSerializer implements PrimitiveSerializer<RecoverOfflineCeilingResponse> {
  @override
  final Iterable<Type> types = const [RecoverOfflineCeilingResponse, _$RecoverOfflineCeilingResponse];

  @override
  final String wireName = r'RecoverOfflineCeilingResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RecoverOfflineCeilingResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'ceiling_id';
    yield serializers.serialize(
      object.ceilingId,
      specifiedType: const FullType(String),
    );
    yield r'quarantined_kobo';
    yield serializers.serialize(
      object.quarantinedKobo,
      specifiedType: const FullType(int),
    );
    yield r'release_after';
    yield serializers.serialize(
      object.releaseAfter,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RecoverOfflineCeilingResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RecoverOfflineCeilingResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'ceiling_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.ceilingId = valueDes;
          break;
        case r'quarantined_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.quarantinedKobo = valueDes;
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
  RecoverOfflineCeilingResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RecoverOfflineCeilingResponseBuilder();
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

