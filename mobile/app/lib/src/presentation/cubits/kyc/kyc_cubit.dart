import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../repositories/kyc_repository.dart';
import '../session/session_cubit.dart';
import 'kyc_state.dart';

export 'kyc_state.dart';

class KycCubit extends Cubit<KycUiState> {
  final KycRepository _repo;
  final SessionCubit _session;

  KycCubit({
    required KycRepository repo,
    required SessionCubit session,
  })  : _repo = repo,
        _session = session,
        super(const KycUiState());

  String? get _token => _session.state.session?.accessToken;

  Future<void> loadSubmissions() async {
    final token = _token;
    if (token == null) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final items = await _repo.list(accessToken: token);
      emit(state.copyWith(submissions: items, loading: false));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: _friendly(e),
      ));
    }
  }

  Future<void> loadHint() async {
    final token = _token;
    if (token == null) return;
    try {
      final hint = await _repo.hint(accessToken: token);
      if (isClosed) return;
      emit(state.copyWith(hint: hint));
    } catch (_) {
    }
  }

  Future<KycSubmission?> submit({
    required KycIdType idType,
    required String idNumber,
  }) async {
    final token = _token;
    if (token == null) {
      emit(state.copyWith(error: 'You need to be signed in.'));
      return null;
    }
    emit(state.copyWith(
      submitting: true,
      clearError: true,
      clearLastResult: true,
    ));
    try {
      final result = await _repo.submit(
        idType: idType,
        idNumber: idNumber,
        accessToken: token,
      );
      if (!isClosed) {
        emit(state.copyWith(
          submitting: false,
          lastResult: result,
          submissions: [result, ...state.submissions],
        ));
      }
      if (result.verified) {
        await _session.refreshProfile();
      }
      return result;
    } on KycSubmissionFailed catch (e) {
      if (isClosed) return null;
      emit(state.copyWith(
        submitting: false,
        error: _friendlyKyc(e),
      ));
      return null;
    } catch (e) {
      if (isClosed) return null;
      emit(state.copyWith(
        submitting: false,
        error: _friendly(e),
      ));
      return null;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));
  void clearResult() => emit(state.copyWith(clearLastResult: true));

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('timed out')) {
      return "Couldn't reach the server. Check your connection and try again.";
    }
    return 'Something went wrong. Please try again.';
  }

  String _friendlyKyc(KycSubmissionFailed e) {
    if (e.isRateLimited) {
      return 'Too many attempts. Wait a few minutes and try again.';
    }
    if (e.isValidation) {
      return e.message;
    }
    return e.message;
  }
}
