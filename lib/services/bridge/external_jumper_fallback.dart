import 'bridge_models.dart';

final class ExternalJumperFallback {
  const ExternalJumperFallback();

  Uri build(BridgeFundingRequest request) {
    if (request.baseDestinationAddress.isEmpty ||
        request.amount.isEmpty ||
        request.sourceToken.address.isEmpty) {
      throw const BridgeValidationException('invalid_jumper_prefill');
    }
    return Uri.https('jumper.exchange', '/', <String, String>{
      'fromAmount': request.amount,
      'fromChain': request.sourceChain.id.toString(),
      'fromToken': request.sourceToken.address,
      'toChain': BridgeConstants.baseChainId.toString(),
      'toToken': BridgeConstants.baseUsdc,
      'toAddress': request.baseDestinationAddress,
    });
  }
}
