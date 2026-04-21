import 'package:equatable/equatable.dart';

import '../../../repositories/transfer_repository.dart';

enum SendMoneyStep {
  enterAccount,
  enterAmount,
  confirming,
  polling,
  done,
}

enum SendMoneyPinOutcome { notSet, bad, locked }

class SendMoneyUiState extends Equatable {
  final SendMoneyStep step;
  final ResolvedAccount? recipient;
  final int? amountKobo;
  final TransferResult? result;
  final String? error;
  final bool loading;
  final SendMoneyPinOutcome? lastPinOutcome;

  const SendMoneyUiState({
    this.step = SendMoneyStep.enterAccount,
    this.recipient,
    this.amountKobo,
    this.result,
    this.error,
    this.loading = false,
    this.lastPinOutcome,
  });

  SendMoneyUiState copyWith({
    SendMoneyStep? step,
    ResolvedAccount? recipient,
    int? amountKobo,
    TransferResult? result,
    String? error,
    bool? loading,
    SendMoneyPinOutcome? lastPinOutcome,
    bool clearRecipient = false,
    bool clearAmount = false,
    bool clearResult = false,
    bool clearError = false,
    bool clearPinOutcome = false,
  }) {
    return SendMoneyUiState(
      step: step ?? this.step,
      recipient: clearRecipient ? null : (recipient ?? this.recipient),
      amountKobo: clearAmount ? null : (amountKobo ?? this.amountKobo),
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      loading: loading ?? this.loading,
      lastPinOutcome: clearPinOutcome
          ? null
          : (lastPinOutcome ?? this.lastPinOutcome),
    );
  }

  @override
  List<Object?> get props =>
      [step, recipient, amountKobo, result, error, loading, lastPinOutcome];
}
