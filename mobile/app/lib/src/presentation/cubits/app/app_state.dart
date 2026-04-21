import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:offlinepay_core/offlinepay_core.dart'
    show DisplayCard, PaymentChannel, PaymentRequest;

import '../../../services/local_queue.dart';

class ActiveCeiling extends Equatable {
  final String id;
  final int ceilingKobo;
  final int sequenceStart;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String bankKeyId;
  final Uint8List payerPublicKey;
  final Uint8List bankSignature;

  final String ceilingTokenBlob;

  const ActiveCeiling({
    required this.id,
    required this.ceilingKobo,
    required this.sequenceStart,
    required this.issuedAt,
    required this.expiresAt,
    required this.bankKeyId,
    required this.payerPublicKey,
    required this.bankSignature,
    required this.ceilingTokenBlob,
  });

  @override
  List<Object?> get props => [
        id,
        ceilingKobo,
        sequenceStart,
        issuedAt,
        expiresAt,
        bankKeyId,
        payerPublicKey,
        bankSignature,
        ceilingTokenBlob,
      ];
}

class RecoveringCeiling extends Equatable {
  final String id;
  final int quarantinedKobo;
  final DateTime releaseAfter;

  const RecoveringCeiling({
    required this.id,
    required this.quarantinedKobo,
    required this.releaseAfter,
  });

  @override
  List<Object?> get props => [id, quarantinedKobo, releaseAfter];
}

class ActiveRequest extends Equatable {
  final PaymentRequest request;
  final List<Uint8List> qrFrames;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const ActiveRequest({
    required this.request,
    required this.qrFrames,
    required this.issuedAt,
    required this.expiresAt,
  });

  int get amountKobo => request.payload.amount;
  Uint8List get sessionNonce => request.payload.sessionNonce;

  @override
  List<Object?> get props => [issuedAt, expiresAt, sessionNonce];
}

class AppUiState extends Equatable {
  final String? userId;
  final int mainBalanceKobo;
  final int offlineBalanceKobo;
  final int lienBalanceKobo;
  final int receivingPendingKobo;
  final ActiveCeiling? activeCeiling;
  final RecoveringCeiling? recoveringCeiling;
  final List<LocalTxn> activity;
  final bool online;
  final bool hasRemoteBalances;
  final int currentTab;
  final PaymentChannel preferredChannel;
  final int sentSum;
  final int realmKeyVersion;
  final bool refreshing;
  final DisplayCard? displayCard;
  final ActiveRequest? activeRequest;

  const AppUiState({
    this.userId,
    this.mainBalanceKobo = 0,
    this.offlineBalanceKobo = 0,
    this.lienBalanceKobo = 0,
    this.receivingPendingKobo = 0,
    this.activeCeiling,
    this.recoveringCeiling,
    this.activity = const [],
    this.online = false,
    this.hasRemoteBalances = false,
    this.currentTab = 0,
    this.preferredChannel = PaymentChannel.qr,
    this.sentSum = 0,
    this.realmKeyVersion = 0,
    this.refreshing = false,
    this.displayCard,
    this.activeRequest,
  });

  int get offlineRemainingKobo =>
      activeCeiling == null ? 0 : activeCeiling!.ceilingKobo - sentSum;

  AppUiState copyWith({
    String? userId,
    int? mainBalanceKobo,
    int? offlineBalanceKobo,
    int? lienBalanceKobo,
    int? receivingPendingKobo,
    ActiveCeiling? activeCeiling,
    bool clearActiveCeiling = false,
    RecoveringCeiling? recoveringCeiling,
    bool clearRecoveringCeiling = false,
    List<LocalTxn>? activity,
    bool? online,
    bool? hasRemoteBalances,
    int? currentTab,
    PaymentChannel? preferredChannel,
    int? sentSum,
    int? realmKeyVersion,
    bool? refreshing,
    DisplayCard? displayCard,
    bool clearDisplayCard = false,
    ActiveRequest? activeRequest,
    bool clearActiveRequest = false,
  }) {
    return AppUiState(
      userId: userId ?? this.userId,
      mainBalanceKobo: mainBalanceKobo ?? this.mainBalanceKobo,
      offlineBalanceKobo: offlineBalanceKobo ?? this.offlineBalanceKobo,
      lienBalanceKobo: lienBalanceKobo ?? this.lienBalanceKobo,
      receivingPendingKobo:
          receivingPendingKobo ?? this.receivingPendingKobo,
      activeCeiling:
          clearActiveCeiling ? null : (activeCeiling ?? this.activeCeiling),
      recoveringCeiling: clearRecoveringCeiling
          ? null
          : (recoveringCeiling ?? this.recoveringCeiling),
      activity: activity ?? this.activity,
      online: online ?? this.online,
      hasRemoteBalances: hasRemoteBalances ?? this.hasRemoteBalances,
      currentTab: currentTab ?? this.currentTab,
      preferredChannel: preferredChannel ?? this.preferredChannel,
      sentSum: sentSum ?? this.sentSum,
      realmKeyVersion: realmKeyVersion ?? this.realmKeyVersion,
      refreshing: refreshing ?? this.refreshing,
      displayCard: clearDisplayCard ? null : (displayCard ?? this.displayCard),
      activeRequest:
          clearActiveRequest ? null : (activeRequest ?? this.activeRequest),
    );
  }

  @override
  List<Object?> get props => [
        userId,
        mainBalanceKobo,
        offlineBalanceKobo,
        lienBalanceKobo,
        receivingPendingKobo,
        activeCeiling,
        recoveringCeiling,
        activity,
        online,
        hasRemoteBalances,
        currentTab,
        preferredChannel,
        sentSum,
        realmKeyVersion,
        refreshing,
        displayCard,
        activeRequest,
      ];
}
