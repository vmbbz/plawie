import 'bridge_models.dart';

const allowedBridgeTransitions = <BridgeFundingState, Set<BridgeFundingState>>{
  BridgeFundingState.draft: <BridgeFundingState>{
    BridgeFundingState.checkingCapabilities,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.checkingCapabilities: <BridgeFundingState>{
    BridgeFundingState.connectingWallet,
    BridgeFundingState.collectingRefundAddress,
    BridgeFundingState.failed,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.connectingWallet: <BridgeFundingState>{
    BridgeFundingState.quoting,
    BridgeFundingState.failed,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.collectingRefundAddress: <BridgeFundingState>{
    BridgeFundingState.quoting,
    BridgeFundingState.failed,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.quoting: <BridgeFundingState>{
    BridgeFundingState.awaitingPlawieReview,
    BridgeFundingState.awaitingDeposit,
    BridgeFundingState.failed,
    BridgeFundingState.cancelled,
  },
  BridgeFundingState.awaitingPlawieReview: <BridgeFundingState>{
    BridgeFundingState.awaitingExternalWallet,
    BridgeFundingState.quoting,
    BridgeFundingState.cancelled,
    BridgeFundingState.failed,
  },
  BridgeFundingState.awaitingExternalWallet: <BridgeFundingState>{
    BridgeFundingState.awaitingPlawieReview,
    BridgeFundingState.submitted,
    BridgeFundingState.sourcePending,
  },
  BridgeFundingState.awaitingDeposit: <BridgeFundingState>{
    BridgeFundingState.depositDetected,
    BridgeFundingState.expired,
    BridgeFundingState.failed,
  },
  BridgeFundingState.depositDetected: <BridgeFundingState>{
    BridgeFundingState.destinationPending,
    BridgeFundingState.completed,
    BridgeFundingState.refunded,
    BridgeFundingState.partial,
    BridgeFundingState.failed,
  },
  BridgeFundingState.submitted: <BridgeFundingState>{
    BridgeFundingState.sourcePending,
    BridgeFundingState.destinationPending,
    BridgeFundingState.completed,
    BridgeFundingState.refunded,
    BridgeFundingState.partial,
    BridgeFundingState.failed,
  },
  BridgeFundingState.sourcePending: <BridgeFundingState>{
    BridgeFundingState.destinationPending,
    BridgeFundingState.completed,
    BridgeFundingState.refunded,
    BridgeFundingState.partial,
    BridgeFundingState.failed,
  },
  BridgeFundingState.destinationPending: <BridgeFundingState>{
    BridgeFundingState.completed,
    BridgeFundingState.refunded,
    BridgeFundingState.partial,
    BridgeFundingState.failed,
  },
};

final class SolanaNoSubmissionEvidence {
  const SolanaNoSubmissionEvidence({
    required this.sourceChainId,
    required this.blockhashInvalid,
    required this.completeHistoryScan,
    required this.exactMatchFound,
  });

  final int sourceChainId;
  final bool blockhashInvalid;
  final bool completeHistoryScan;
  final bool exactMatchFound;

  bool get provesExpiry =>
      sourceChainId == BridgeConstants.solanaChainId &&
      blockhashInvalid &&
      completeHistoryScan &&
      !exactMatchFound;
}

final class RelayLateDepositEvidence {
  const RelayLateDepositEvidence({
    required this.requestId,
    required this.depositAddress,
    required this.sourceTransactionHash,
  });

  final String requestId;
  final String depositAddress;
  final String sourceTransactionHash;

  bool get isComplete =>
      RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(requestId) &&
      depositAddress.isNotEmpty &&
      (RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(sourceTransactionHash) ||
          RegExp(r'^[1-9A-HJ-NP-Za-km-z]{80,90}$')
              .hasMatch(sourceTransactionHash));
}

final class BridgeFundingStateMachine {
  const BridgeFundingStateMachine();

  bool canMove(BridgeFundingState from, BridgeFundingState to) =>
      allowedBridgeTransitions[from]?.contains(to) ?? false;

  bool canMoveWithEvidence(
    BridgeFundingState from,
    BridgeFundingState to, {
    required SolanaNoSubmissionEvidence evidence,
  }) =>
      from == BridgeFundingState.awaitingExternalWallet &&
      to == BridgeFundingState.expired &&
      evidence.provesExpiry;

  bool canMoveAfterRelayLateDeposit(
    BridgeFundingState from,
    BridgeFundingState to, {
    required RelayLateDepositEvidence evidence,
  }) =>
      from == BridgeFundingState.expired &&
      to == BridgeFundingState.depositDetected &&
      evidence.isComplete;

  void requireMove(BridgeFundingState from, BridgeFundingState to) {
    if (!canMove(from, to)) {
      throw StateError('Illegal bridge funding transition: $from -> $to.');
    }
  }

  void requireMoveWithEvidence(
    BridgeFundingState from,
    BridgeFundingState to, {
    required SolanaNoSubmissionEvidence evidence,
  }) {
    if (!canMoveWithEvidence(from, to, evidence: evidence)) {
      throw StateError(
        'Illegal evidenced bridge funding transition: $from -> $to.',
      );
    }
  }

  void requireMoveAfterRelayLateDeposit(
    BridgeFundingState from,
    BridgeFundingState to, {
    required RelayLateDepositEvidence evidence,
  }) {
    if (!canMoveAfterRelayLateDeposit(from, to, evidence: evidence)) {
      throw StateError(
        'Illegal Relay late-deposit transition: $from -> $to.',
      );
    }
  }
}
