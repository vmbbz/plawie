import 'bridge_models.dart';

sealed class ValidatedBridgeFundingIntent {
  const ValidatedBridgeFundingIntent({
    required this.intentId,
    required this.request,
  });

  final String intentId;
  final BridgeFundingRequest request;
}

final class ValidatedConnectedBridgeIntent
    extends ValidatedBridgeFundingIntent {
  const ValidatedConnectedBridgeIntent({
    required super.intentId,
    required super.request,
    required this.quote,
  });

  final BridgeExecutableQuote quote;
}

final class ValidatedRelayDepositIntent extends ValidatedBridgeFundingIntent {
  const ValidatedRelayDepositIntent({
    required super.intentId,
    required super.request,
    required this.instruction,
  });

  final RelayDepositInstruction instruction;
}

abstract interface class BridgeFundingStrategy {
  Future<BridgeCapabilitySnapshot> capabilities();

  Future<BridgeEstimate> quote(BridgeFundingRequest request);

  Future<BridgeFundingReceipt> submit(ValidatedBridgeFundingIntent intent);

  Future<BridgeFundingObservation> status(BridgeFundingReceipt receipt);
}
