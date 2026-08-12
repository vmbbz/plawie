enum AiPaymentFundingMode {
  prepaidBalance,
  perRequest,
}

enum AiPaymentConnectionMode {
  walletIdentity,
}

enum AiPaymentHeaderContract {
  paymentSignatureV2,
  x402Payment,
}

/// Trusted product metadata for providers that can be funded or paid with the
/// app's Base wallet. Provider behavior is intentionally explicit: a prepaid
/// balance is not presented as if it were the same thing as per-request x402.
class AiPaymentProviderOption {
  const AiPaymentProviderOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.description,
    required this.fundingMode,
    required this.connectionMode,
    required this.allowedHosts,
    required this.supportsTopUp,
    required this.paymentHeaderContract,
    this.allowsResourceLessTopUpChallenge = false,
    this.topUpEndpoint,
    this.balanceEndpointTemplate,
  });

  final String id;
  final String label;
  final String subtitle;
  final String description;
  final AiPaymentFundingMode fundingMode;
  final AiPaymentConnectionMode connectionMode;
  final Set<String> allowedHosts;
  final bool supportsTopUp;
  final AiPaymentHeaderContract paymentHeaderContract;

  /// An explicit compatibility exception for a provider whose documented
  /// top-up `PAYMENT-REQUIRED` header omits the normal x402 `resource` field.
  /// The transport substitutes only its catalogued HTTPS top-up endpoint.
  final bool allowsResourceLessTopUpChallenge;
  final Uri? topUpEndpoint;
  final String? balanceEndpointTemplate;

  String get fundingLabel => switch (fundingMode) {
        AiPaymentFundingMode.prepaidBalance => 'Prepaid provider balance',
        AiPaymentFundingMode.perRequest => 'Pay per request',
      };

  String get paymentHeaderName => switch (paymentHeaderContract) {
        AiPaymentHeaderContract.paymentSignatureV2 => 'PAYMENT-SIGNATURE',
        AiPaymentHeaderContract.x402Payment => 'X-402-Payment',
      };
}

class AiPaymentProviderCatalog {
  static const String network = 'eip155:8453';
  static const String networkLabel = 'Base Mainnet';
  static const String assetLabel = 'USDC';
  static const String usdcContract =
      '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';

  static final List<AiPaymentProviderOption> providers =
      <AiPaymentProviderOption>[
    AiPaymentProviderOption(
      id: 'venice',
      label: 'Venice',
      subtitle: 'Wallet access · no API key',
      description:
          'Top up a wallet-linked Venice balance, then use supported models and media routes.',
      fundingMode: AiPaymentFundingMode.prepaidBalance,
      connectionMode: AiPaymentConnectionMode.walletIdentity,
      allowedHosts: const <String>{'api.venice.ai'},
      supportsTopUp: true,
      paymentHeaderContract: AiPaymentHeaderContract.x402Payment,
      allowsResourceLessTopUpChallenge: true,
      topUpEndpoint: Uri.parse('https://api.venice.ai/api/v1/x402/top-up'),
      balanceEndpointTemplate:
          'https://api.venice.ai/api/v1/x402/balance/{walletAddress}',
    ),
    const AiPaymentProviderOption(
      id: 'blockrun',
      label: 'BlockRun',
      subtitle: 'Per-request x402 · no API key',
      description:
          'Each paid request returns its own exact Base USDC challenge; there is no Plawie top-up balance.',
      fundingMode: AiPaymentFundingMode.perRequest,
      connectionMode: AiPaymentConnectionMode.walletIdentity,
      allowedHosts: <String>{'blockrun.ai'},
      supportsTopUp: false,
      paymentHeaderContract: AiPaymentHeaderContract.paymentSignatureV2,
    ),
  ];

  static AiPaymentProviderOption? byId(String? id) {
    final normalized = id?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final provider in providers) {
      if (provider.id == normalized) return provider;
    }
    return null;
  }
}
