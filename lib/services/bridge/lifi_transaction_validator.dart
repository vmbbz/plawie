import 'dart:convert';

import 'bridge_models.dart';

final class LifiTransactionValidator {
  const LifiTransactionValidator();

  void validate(
    BridgeExecutableQuote quote, {
    required BridgeFundingRequest request,
    required String connectedAddress,
    required String baseAddress,
    required DateTime now,
  }) {
    final estimate = quote.estimate;
    final normalized = estimate.request;
    if (normalized.sourceChain.id != request.sourceChain.id ||
        normalized.sourceChain.type != request.sourceChain.type ||
        quote.destinationChainId != BridgeConstants.baseChainId ||
        !_sameAddress(quote.connectedSourceAddress, connectedAddress,
            request.sourceChain.type) ||
        !_sameAddress(normalized.sourceAddress ?? '', connectedAddress,
            request.sourceChain.type) ||
        !_sameAddress(normalized.baseDestinationAddress, baseAddress,
            BridgeChainType.evm) ||
        quote.destinationToken.chainId != BridgeConstants.baseChainId ||
        !_sameAddress(quote.destinationToken.address, BridgeConstants.baseUsdc,
            BridgeChainType.evm) ||
        quote.destinationToken.symbol.toUpperCase() != 'USDC' ||
        quote.destinationToken.decimals != 6 ||
        normalized.amountUnits != request.amountUnits ||
        normalized.sourceToken.chainId != request.sourceToken.chainId ||
        !_sameAddress(normalized.sourceToken.address,
            request.sourceToken.address, request.sourceChain.type) ||
        normalized.sourceToken.symbol.toUpperCase() !=
            request.sourceToken.symbol.toUpperCase() ||
        normalized.sourceToken.decimals != request.sourceToken.decimals ||
        BigInt.tryParse(estimate.minimumOutputUnits) == null ||
        BigInt.parse(estimate.minimumOutputUnits) <= BigInt.zero ||
        estimate.expiresAt.toUtc().difference(now.toUtc()) <
            const Duration(seconds: 30)) {
      throw const BridgeValidationException('quote_mismatch');
    }

    final payload = quote.payload;
    if (request.sourceChain.type == BridgeChainType.evm) {
      if (payload is! EvmBridgeExecutionPayload) {
        throw const BridgeValidationException('evm_payload_required');
      }
      _validateEvm(payload, estimate, connectedAddress, request.sourceChain.id);
      return;
    }
    if (payload is! SolanaBridgeExecutionPayload) {
      throw const BridgeValidationException('solana_payload_required');
    }
    if (payload.from != connectedAddress ||
        normalized.sourceAddress != connectedAddress) {
      throw const BridgeValidationException('solana_signer_changed');
    }
    late List<int> decoded;
    try {
      decoded = base64Decode(payload.base64Transaction);
    } on FormatException {
      throw const BridgeValidationException('invalid_solana_transaction');
    }
    if (decoded.isEmpty || decoded.length > 1232) {
      throw const BridgeValidationException('invalid_solana_transaction');
    }
  }

  void _validateEvm(
    EvmBridgeExecutionPayload payload,
    BridgeEstimate estimate,
    String connectedAddress,
    int sourceChainId,
  ) {
    final validAddress = RegExp(r'^0x[0-9a-fA-F]{40}$');
    final quantity = RegExp(r'^0x(?:0|[1-9a-fA-F][0-9a-fA-F]*)$');
    final data = RegExp(r'^0x(?:[0-9a-fA-F]{2})*$');
    if (payload.chainId != sourceChainId ||
        !_sameAddress(payload.from, connectedAddress, BridgeChainType.evm) ||
        !validAddress.hasMatch(payload.to) ||
        !quantity.hasMatch(payload.valueHex) ||
        !quantity.hasMatch(payload.gasLimitHex) ||
        !data.hasMatch(payload.dataHex) ||
        (payload.dataHex.length - 2) ~/ 2 > 256 * 1024 ||
        !_optionalSameEvm(payload.approvalAddress, estimate.approvalAddress)) {
      throw const BridgeValidationException('invalid_evm_transaction');
    }
  }
}

bool _sameAddress(String left, String right, BridgeChainType type) =>
    type == BridgeChainType.evm
        ? left.toLowerCase() == right.toLowerCase()
        : left == right;

bool _optionalSameEvm(String? left, String? right) {
  if (left == null || right == null) return left == right;
  return left.toLowerCase() == right.toLowerCase();
}
