import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/bridge_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const machine = BridgeFundingStateMachine();

  test('accepts intended funding paths and rejects state skips', () {
    expect(
      machine.canMove(
        BridgeFundingState.draft,
        BridgeFundingState.checkingCapabilities,
      ),
      isTrue,
    );
    expect(
      machine.canMove(
        BridgeFundingState.awaitingExternalWallet,
        BridgeFundingState.submitted,
      ),
      isTrue,
    );
    expect(
      machine.canMove(
        BridgeFundingState.awaitingExternalWallet,
        BridgeFundingState.cancelled,
      ),
      isFalse,
    );
    expect(
      machine.canMove(
        BridgeFundingState.awaitingExternalWallet,
        BridgeFundingState.failed,
      ),
      isFalse,
    );
    expect(
      machine.canMove(
        BridgeFundingState.awaitingExternalWallet,
        BridgeFundingState.expired,
      ),
      isFalse,
    );
    expect(
      machine.canMove(
        BridgeFundingState.awaitingDeposit,
        BridgeFundingState.depositDetected,
      ),
      isTrue,
    );
    expect(
      machine.canMove(
        BridgeFundingState.completed,
        BridgeFundingState.submitted,
      ),
      isFalse,
    );
    expect(
      () => machine.requireMove(
        BridgeFundingState.draft,
        BridgeFundingState.submitted,
      ),
      throwsStateError,
    );
  });

  test('Solana expiry requires complete no-submission evidence', () {
    const evidence = SolanaNoSubmissionEvidence(
      sourceChainId: BridgeConstants.solanaChainId,
      blockhashInvalid: true,
      completeHistoryScan: true,
      exactMatchFound: false,
    );

    expect(evidence.provesExpiry, isTrue);
    expect(
      machine.canMoveWithEvidence(
        BridgeFundingState.awaitingExternalWallet,
        BridgeFundingState.expired,
        evidence: evidence,
      ),
      isTrue,
    );
    expect(
      () => machine.requireMoveWithEvidence(
        BridgeFundingState.awaitingExternalWallet,
        BridgeFundingState.expired,
        evidence: evidence,
      ),
      returnsNormally,
    );
  });

  test('every incomplete or mismatched expiry proof is rejected', () {
    const rejectedEvidence = <SolanaNoSubmissionEvidence>[
      SolanaNoSubmissionEvidence(
        sourceChainId: BridgeConstants.ethereumChainId,
        blockhashInvalid: true,
        completeHistoryScan: true,
        exactMatchFound: false,
      ),
      SolanaNoSubmissionEvidence(
        sourceChainId: BridgeConstants.solanaChainId,
        blockhashInvalid: false,
        completeHistoryScan: true,
        exactMatchFound: false,
      ),
      SolanaNoSubmissionEvidence(
        sourceChainId: BridgeConstants.solanaChainId,
        blockhashInvalid: true,
        completeHistoryScan: false,
        exactMatchFound: false,
      ),
      SolanaNoSubmissionEvidence(
        sourceChainId: BridgeConstants.solanaChainId,
        blockhashInvalid: true,
        completeHistoryScan: true,
        exactMatchFound: true,
      ),
    ];

    for (final evidence in rejectedEvidence) {
      expect(evidence.provesExpiry, isFalse);
      expect(
        machine.canMoveWithEvidence(
          BridgeFundingState.awaitingExternalWallet,
          BridgeFundingState.expired,
          evidence: evidence,
        ),
        isFalse,
      );
      expect(
        () => machine.requireMoveWithEvidence(
          BridgeFundingState.awaitingExternalWallet,
          BridgeFundingState.expired,
          evidence: evidence,
        ),
        throwsStateError,
      );
    }
  });

  test('evidence cannot bypass or decorate any other transition', () {
    const evidence = SolanaNoSubmissionEvidence(
      sourceChainId: BridgeConstants.solanaChainId,
      blockhashInvalid: true,
      completeHistoryScan: true,
      exactMatchFound: false,
    );

    expect(
      machine.canMoveWithEvidence(
        BridgeFundingState.draft,
        BridgeFundingState.checkingCapabilities,
        evidence: evidence,
      ),
      isFalse,
    );
    expect(
      machine.canMoveWithEvidence(
        BridgeFundingState.awaitingDeposit,
        BridgeFundingState.expired,
        evidence: evidence,
      ),
      isFalse,
    );
    expect(
      () => machine.requireMoveWithEvidence(
        BridgeFundingState.awaitingExternalWallet,
        BridgeFundingState.submitted,
        evidence: evidence,
      ),
      throwsStateError,
    );
  });

  test('terminal states have no outgoing transitions', () {
    const terminalStates = <BridgeFundingState>[
      BridgeFundingState.completed,
      BridgeFundingState.failed,
      BridgeFundingState.refunded,
      BridgeFundingState.partial,
      BridgeFundingState.expired,
      BridgeFundingState.cancelled,
    ];

    for (final state in terminalStates) {
      expect(allowedBridgeTransitions[state], isNull);
      for (final target in BridgeFundingState.values) {
        expect(machine.canMove(state, target), isFalse);
      }
    }
  });

  test('transition matrix is immutable', () {
    expect(
      () => allowedBridgeTransitions[BridgeFundingState.draft]!
          .add(BridgeFundingState.submitted),
      throwsUnsupportedError,
    );
  });
}
