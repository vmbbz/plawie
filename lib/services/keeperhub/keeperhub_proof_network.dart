abstract final class KeeperHubProofNetwork {
  static const int chainId = 8453;
  static const String name = 'Base Mainnet';

  /// Read-only compatibility for receipts created before the mainnet policy.
  /// New proposals, approvals, submissions, and receipt verification must use
  /// [chainId].
  static const int legacyBaseSepoliaChainId = 84532;
}
