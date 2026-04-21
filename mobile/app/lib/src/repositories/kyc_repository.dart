import 'package:dio/dio.dart';
import 'package:offlinepay_api/offlinepay_api.dart' as gen;


enum KycIdType {
  bvn,
  nin;

  String get wire => switch (this) {
        KycIdType.bvn => 'BVN',
        KycIdType.nin => 'NIN',
      };

  String get label => switch (this) {
        KycIdType.bvn => 'BVN',
        KycIdType.nin => 'NIN',
      };

  String get targetTier => switch (this) {
        KycIdType.nin => 'TIER_2',
        KycIdType.bvn => 'TIER_3',
      };

  static KycIdType fromWire(String s) {
    switch (s.toUpperCase()) {
      case 'NIN':
        return KycIdType.nin;
      case 'BVN':
      default:
        return KycIdType.bvn;
    }
  }
}

enum KycStatus { verified, rejected }

class KycSubmission {
  final String id;
  final String userId;
  final KycIdType idType;
  final String idNumber;
  final KycStatus status;
  final String? rejectionReason;
  final String? tierGranted;
  final DateTime submittedAt;
  final DateTime? verifiedAt;

  const KycSubmission({
    required this.id,
    required this.userId,
    required this.idType,
    required this.idNumber,
    required this.status,
    required this.rejectionReason,
    required this.tierGranted,
    required this.submittedAt,
    required this.verifiedAt,
  });

  factory KycSubmission.fromGen(gen.KYCSubmission s) => KycSubmission(
        id: s.id,
        userId: s.userId,
        idType: KycIdType.fromWire(s.idType),
        idNumber: s.idNumber,
        status: s.status == gen.KYCSubmissionStatusEnum.VERIFIED
            ? KycStatus.verified
            : KycStatus.rejected,
        rejectionReason: s.rejectionReason,
        tierGranted: s.tierGranted,
        submittedAt: s.submittedAt,
        verifiedAt: s.verifiedAt,
      );

  bool get verified => status == KycStatus.verified;
}

class KycSubmissionFailed implements Exception {
  final String? code;
  final String message;
  final int? statusCode;
  const KycSubmissionFailed(this.code, this.message, [this.statusCode]);
  @override
  String toString() =>
      'KycSubmissionFailed(${code ?? 'unknown'}: $message, status=${statusCode ?? '?'})';

  bool get isValidation => statusCode == 400;
  bool get isRateLimited => statusCode == 429;
}

class KycRepository {
  final gen.OfflinepayApi _api;

  KycRepository({required gen.OfflinepayApi api}) : _api = api;

  gen.DefaultApi get _default => _api.getDefaultApi();

  Map<String, dynamic> _authHeaders(String accessToken) => <String, dynamic>{
        'Authorization': 'Bearer $accessToken',
      };

  Future<KycSubmission> submit({
    required KycIdType idType,
    required String idNumber,
    required String accessToken,
  }) async {
    try {
      final body = gen.KYCSubmitBody((b) => b
        ..idType = switch (idType) {
          KycIdType.nin => gen.KYCSubmitBodyIdTypeEnum.NIN,
          KycIdType.bvn => gen.KYCSubmitBodyIdTypeEnum.BVN,
        }
        ..idNumber = idNumber);
      final resp = await _default.postV1KycSubmit(
        kYCSubmitBody: body,
        headers: _authHeaders(accessToken),
      );
      final data = resp.data;
      if (data == null) {
        throw StateError('kyc: submit returned empty body');
      }
      return KycSubmission.fromGen(data);
    } on DioException catch (e) {
      String? code;
      String message = e.message ?? 'submission failed';
      final respData = e.response?.data;
      if (respData is Map) {
        final c = respData['code'];
        final m = respData['message'];
        if (c is String) code = c;
        if (m is String) message = m;
      }
      throw KycSubmissionFailed(code, message, e.response?.statusCode);
    }
  }

  Future<List<KycSubmission>> list({required String accessToken}) async {
    final resp = await _default.getV1KycSubmissions(
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) return const <KycSubmission>[];
    return data.items.map(KycSubmission.fromGen).toList(growable: false);
  }

  Future<Map<String, String>> hint({required String accessToken}) async {
    final resp = await _default.getV1KycHint(
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) return const <String, String>{};
    return Map<String, String>.from(data.asMap());
  }
}
