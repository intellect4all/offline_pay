//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:offlinepay_api/src/model/kyc_submission.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'kyc_submission_list.g.dart';

/// KYCSubmissionList
///
/// Properties:
/// * [items] 
@BuiltValue()
abstract class KYCSubmissionList implements Built<KYCSubmissionList, KYCSubmissionListBuilder> {
  @BuiltValueField(wireName: r'items')
  BuiltList<KYCSubmission> get items;

  KYCSubmissionList._();

  factory KYCSubmissionList([void updates(KYCSubmissionListBuilder b)]) = _$KYCSubmissionList;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(KYCSubmissionListBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<KYCSubmissionList> get serializer => _$KYCSubmissionListSerializer();
}

class _$KYCSubmissionListSerializer implements PrimitiveSerializer<KYCSubmissionList> {
  @override
  final Iterable<Type> types = const [KYCSubmissionList, _$KYCSubmissionList];

  @override
  final String wireName = r'KYCSubmissionList';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    KYCSubmissionList object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(KYCSubmission)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    KYCSubmissionList object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required KYCSubmissionListBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(KYCSubmission)]),
          ) as BuiltList<KYCSubmission>;
          result.items.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  KYCSubmissionList deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = KYCSubmissionListBuilder();
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

