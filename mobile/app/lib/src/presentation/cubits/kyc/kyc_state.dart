import 'package:equatable/equatable.dart';

import '../../../repositories/kyc_repository.dart';

class KycUiState extends Equatable {
  final List<KycSubmission> submissions;
  final bool loading;
  final bool submitting;
  final String? error;
  final KycSubmission? lastResult;

  final Map<String, String> hint;

  const KycUiState({
    this.submissions = const [],
    this.loading = false,
    this.submitting = false,
    this.error,
    this.lastResult,
    this.hint = const {},
  });

  KycUiState copyWith({
    List<KycSubmission>? submissions,
    bool? loading,
    bool? submitting,
    String? error,
    KycSubmission? lastResult,
    Map<String, String>? hint,
    bool clearError = false,
    bool clearLastResult = false,
  }) {
    return KycUiState(
      submissions: submissions ?? this.submissions,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
      lastResult:
          clearLastResult ? null : (lastResult ?? this.lastResult),
      hint: hint ?? this.hint,
    );
  }

  @override
  List<Object?> get props =>
      [submissions, loading, submitting, error, lastResult, hint];
}
