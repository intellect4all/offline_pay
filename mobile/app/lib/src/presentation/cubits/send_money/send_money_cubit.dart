import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../repositories/transfer_repository.dart';
import '../session/session_cubit.dart';
import 'send_money_state.dart';

class SendMoneyCubit extends Cubit<SendMoneyUiState> {
  final TransferRepository _repo;
  final SessionCubit _session;

  SendMoneyCubit({
    required TransferRepository repo,
    required SessionCubit session,
  })  : _repo = repo,
        _session = session,
        super(const SendMoneyUiState());

  String? _token() => _session.state.session?.accessToken;

  Future<void> resolveAccount(String number) async {
    final token = _token();
    if (token == null) {
      emit(state.copyWith(error: 'Not signed in'));
      return;
    }
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final r = await _repo.resolve(number, token);
      emit(state.copyWith(
        recipient: r,
        step: SendMoneyStep.enterAmount,
        loading: false,
      ));
    } on AccountNotFound {
      emit(state.copyWith(
        error: 'No account found for $number',
        loading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: _friendly(e), loading: false));
    }
  }

  void setAmount(int kobo) {
    emit(state.copyWith(
      amountKobo: kobo,
      step: SendMoneyStep.confirming,
    ));
  }

  Future<void> submit(String reference, String pin) async {
    final recipient = state.recipient;
    final amount = state.amountKobo;
    final token = _token();
    if (recipient == null || amount == null || token == null) {
      emit(state.copyWith(error: 'Missing details'));
      return;
    }
    emit(state.copyWith(
      step: SendMoneyStep.polling,
      loading: true,
      clearError: true,
      clearPinOutcome: true,
    ));
    try {
      final initial = await _repo.initiate(
        receiverAccountNumber: recipient.accountNumber,
        amountKobo: amount,
        reference: reference,
        pin: pin,
        accessToken: token,
      );
      emit(state.copyWith(result: initial));

      if (!initial.status.isTerminal) {
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          try {
            final latest = await _repo.get(initial.id, token);
            emit(state.copyWith(result: latest));
            if (latest.status.isTerminal) break;
          } catch (e) {
            if (kDebugMode) {
              debugPrint('send_money: poll error: $e');
            }
          }
        }
      }
      emit(state.copyWith(step: SendMoneyStep.done, loading: false));
    } on TransferRejected catch (e) {
      if (e.isPinNotSet) {
        emit(state.copyWith(
          lastPinOutcome: SendMoneyPinOutcome.notSet,
          error: 'Set your PIN to send money',
          step: SendMoneyStep.confirming,
          loading: false,
        ));
      } else if (e.isPinBad) {
        emit(state.copyWith(
          lastPinOutcome: SendMoneyPinOutcome.bad,
          error: 'Incorrect PIN',
          step: SendMoneyStep.confirming,
          loading: false,
        ));
      } else if (e.isPinLocked) {
        emit(state.copyWith(
          lastPinOutcome: SendMoneyPinOutcome.locked,
          error: 'PIN locked — try again in 15 minutes',
          step: SendMoneyStep.confirming,
          loading: false,
        ));
      } else if (e.isKycTierBlocked) {
        emit(state.copyWith(
          error: 'Complete KYC in Settings to send money.',
          step: SendMoneyStep.enterAmount,
          loading: false,
        ));
      } else if (e.isExceedsSingleLimit) {
        emit(state.copyWith(
          error: "Amount above your tier's single-transfer limit.",
          step: SendMoneyStep.enterAmount,
          loading: false,
        ));
      } else if (e.isExceedsDailyLimit) {
        emit(state.copyWith(
          error: "You've reached today's transfer limit.",
          step: SendMoneyStep.enterAmount,
          loading: false,
        ));
      } else if (e.isFraudBlocked) {
        emit(state.copyWith(
          error:
              'This transfer was blocked for security review. Contact support if you believe this is an error.',
          step: SendMoneyStep.confirming,
          loading: false,
        ));
      } else {
        emit(state.copyWith(
          error: e.message,
          step: SendMoneyStep.done,
          loading: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        error: _friendly(e),
        step: SendMoneyStep.done,
        loading: false,
      ));
    }
  }

  void reset() {
    emit(const SendMoneyUiState());
  }

  String _friendly(Object e) {
    final msg = e.toString();
    return msg.length > 240 ? msg.substring(0, 240) : msg;
  }
}

String generateTransferReference() {
  final ts = DateTime.now().microsecondsSinceEpoch.toString();
  final rnd = Random().nextInt(1 << 30).toString();
  return '$ts-$rnd';
}
