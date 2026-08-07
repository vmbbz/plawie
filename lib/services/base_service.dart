import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import 'legacy_evm_key_normalizer.dart';
import 'native_bridge.dart';

enum WalletNetwork { baseMainnet, robinhoodMainnet, baseSepolia }

class WalletTokenDefinition {
  const WalletTokenDefinition({
    required this.symbol,
    required this.contract,
    required this.decimals,
    required this.transferKind,
  });

  final String symbol;
  final String contract;
  final int decimals;
  final String transferKind;
}

class WalletNetworkDefinition {
  const WalletNetworkDefinition({
    required this.network,
    required this.storageValue,
    required this.name,
    required this.chainId,
    required this.readRpcUrl,
    required this.explorerApiUrl,
    required this.isTestnet,
    required this.supportsBasenames,
    required this.supportsX402,
    this.token,
  });

  final WalletNetwork network;
  final String storageValue;
  final String name;
  final int chainId;
  final String readRpcUrl;
  final String explorerApiUrl;
  final bool isTestnet;
  final bool supportsBasenames;
  final bool supportsX402;
  final WalletTokenDefinition? token;
}

/// Canonical, non-secret network and asset policy for the existing secured EVM
/// account. The Robinhood release RPC is supplied at build time; the official
/// public endpoint remains a read/debug fallback only.
abstract final class WalletNetworkPolicy {
  static const String selectedNetworkStorageKey = 'wallet_network_v1';
  static const String legacySepoliaStorageKey = 'base_use_sepolia';

  static const String baseMainnetUsdc =
      '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';
  static const String baseSepoliaUsdc =
      '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
  static const String robinhoodUsdg =
      '0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168';
  static const String robinhoodPublicRpc =
      'https://rpc.mainnet.chain.robinhood.com';
  static const String _robinhoodReleaseRpc = String.fromEnvironment(
    'ROBINHOOD_RPC_URL',
  );

  static const WalletNetworkDefinition baseMainnet = WalletNetworkDefinition(
    network: WalletNetwork.baseMainnet,
    storageValue: 'base_mainnet',
    name: 'Base Mainnet',
    chainId: 8453,
    readRpcUrl: 'https://mainnet.base.org',
    explorerApiUrl: 'https://api.basescan.org',
    isTestnet: false,
    supportsBasenames: true,
    supportsX402: true,
    token: WalletTokenDefinition(
      symbol: 'USDC',
      contract: baseMainnetUsdc,
      decimals: 6,
      transferKind: 'usdc',
    ),
  );

  static const WalletNetworkDefinition robinhoodMainnet =
      WalletNetworkDefinition(
    network: WalletNetwork.robinhoodMainnet,
    storageValue: 'robinhood_mainnet',
    name: 'Robinhood Chain',
    chainId: 4663,
    readRpcUrl: robinhoodPublicRpc,
    explorerApiUrl: 'https://robinhoodchain.blockscout.com',
    isTestnet: false,
    supportsBasenames: false,
    supportsX402: false,
    token: WalletTokenDefinition(
      symbol: 'USDG',
      contract: robinhoodUsdg,
      decimals: 6,
      transferKind: 'usdg',
    ),
  );

  static const WalletNetworkDefinition baseSepolia = WalletNetworkDefinition(
    network: WalletNetwork.baseSepolia,
    storageValue: 'base_sepolia',
    name: 'Base Sepolia',
    chainId: 84532,
    readRpcUrl: 'https://sepolia.base.org',
    explorerApiUrl: 'https://api-sepolia.basescan.org',
    isTestnet: true,
    supportsBasenames: true,
    supportsX402: false,
    token: WalletTokenDefinition(
      symbol: 'USDC',
      contract: baseSepoliaUsdc,
      decimals: 6,
      transferKind: 'usdc',
    ),
  );

  static const List<WalletNetworkDefinition> values = <WalletNetworkDefinition>[
    baseMainnet,
    robinhoodMainnet,
    baseSepolia
  ];

  static WalletNetworkDefinition definition(WalletNetwork network) =>
      values.firstWhere((definition) => definition.network == network);

  static WalletNetwork decodePreference({
    required String? current,
    required String? legacySepolia,
  }) {
    for (final definition in values) {
      if (definition.storageValue == current) return definition.network;
    }
    return legacySepolia == 'true'
        ? WalletNetwork.baseSepolia
        : WalletNetwork.baseMainnet;
  }

  static bool isValidReleaseRpc(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment;
  }

  static bool get hasRobinhoodReleaseRpc =>
      isValidReleaseRpc(_robinhoodReleaseRpc);

  static String get robinhoodRpcUrl =>
      hasRobinhoodReleaseRpc ? _robinhoodReleaseRpc.trim() : robinhoodPublicRpc;

  static bool get robinhoodTransactionsAvailable =>
      !kReleaseMode || hasRobinhoodReleaseRpc;
}

/// A short-lived capability minted only after a visible wallet UI confirms an
/// exact transfer. It is intentionally not serializable, so Gateway/agent
/// payloads cannot manufacture one by sending a map or string.
class BaseTransferApproval {
  final String action;
  final String destination;
  final String amount;
  final int chainId;
  final DateTime expiresAt;
  bool _consumed = false;

  BaseTransferApproval._({
    required this.action,
    required this.destination,
    required this.amount,
    required this.chainId,
    required this.expiresAt,
  });

  bool get consumed => _consumed;
}

/// Secured EVM wallet service for the explicitly supported wallet networks.
/// Uses web3dart for read-only RPC preparation and Android Keystore-backed
/// native signing. Private keys are never retained in Dart after migration or
/// import.
class BaseService {
  static final BaseService _instance = BaseService._internal();
  factory BaseService() => _instance;
  BaseService._internal();

  final Logger _logger = Logger();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final StreamController<BaseEvent> _eventController =
      StreamController.broadcast();

  // State
  SecureWalletStatus _walletStatus = SecureWalletStatus.absent();
  WalletNetwork _selectedNetwork = WalletNetwork.baseMainnet;

  // Cached balances
  Decimal _ethBalance = Decimal.zero;
  Decimal _stablecoinBalance = Decimal.zero;

  // Tx history cache
  List<BaseTx> _txHistory = [];

  Stream<BaseEvent> get events => _eventController.stream;
  SecureWalletStatus get walletStatus => _walletStatus;
  bool get isConnected => _walletStatus.isConnected;
  bool get legacyMigrationRequired =>
      _walletStatus.state == SecureWalletState.legacyMigrationRequired;
  String get securityLevel => _walletStatus.securityLevel;
  String get authenticationMode => _walletStatus.authenticationMode;
  String? get address => _walletStatus.address;
  WalletNetwork get selectedNetwork => _selectedNetwork;
  WalletNetworkDefinition get network =>
      WalletNetworkPolicy.definition(_selectedNetwork);
  bool get useSepolia => _selectedNetwork == WalletNetwork.baseSepolia;
  bool get isBaseMainnet => _selectedNetwork == WalletNetwork.baseMainnet;
  bool get isRobinhoodMainnet =>
      _selectedNetwork == WalletNetwork.robinhoodMainnet;
  Decimal get ethBalance => _ethBalance;
  Decimal get stablecoinBalance => _stablecoinBalance;
  Decimal get usdcBalance =>
      network.token?.symbol == 'USDC' ? _stablecoinBalance : Decimal.zero;
  List<BaseTx> get txHistory => _txHistory;
  String get rpcUrl => isRobinhoodMainnet
      ? WalletNetworkPolicy.robinhoodRpcUrl
      : network.readRpcUrl;
  String get networkName => network.name;
  int get chainId => network.chainId;
  bool get ordinaryTransactionsAvailable =>
      !isRobinhoodMainnet || WalletNetworkPolicy.robinhoodTransactionsAvailable;
  String get ordinaryTransactionUnavailableReason => ordinaryTransactionsAvailable
      ? ''
      : 'Robinhood transactions require a production ROBINHOOD_RPC_URL build configuration.';
  String? get stablecoinSymbol => network.token?.symbol;
  String? get stablecoinContract => network.token?.contract;
  int? get stablecoinDecimals => network.token?.decimals;
  String get usdcContract {
    final token = network.token;
    if (token == null || token.symbol != 'USDC') {
      throw StateError('$networkName does not define a USDC contract.');
    }
    return token.contract;
  }

  /// Mint a one-use transfer capability after the visible wallet UI has
  /// displayed and received confirmation for the exact request.
  ///
  /// This is deliberately separate from x402 approval. x402 will use its own
  /// challenge-bound signer and must never call ordinary transfer methods.
  BaseTransferApproval issueVisibleTransferApproval({
    required String action,
    required String destination,
    required Decimal amount,
  }) {
    if (action != 'send_eth' &&
        action != 'send_usdc' &&
        action != 'send_usdg') {
      throw ArgumentError.value(action, 'action', 'Unsupported transfer');
    }
    if (destination.trim().isEmpty || amount <= Decimal.zero) {
      throw ArgumentError('Transfer destination and amount are required.');
    }
    return BaseTransferApproval._(
      action: action,
      destination: destination.trim(),
      amount: amount.toString(),
      chainId: chainId,
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
    );
  }

  bool consumeVisibleTransferApproval(
    BaseTransferApproval? approval, {
    required String action,
    required String destination,
    required Decimal amount,
  }) {
    if (approval == null ||
        approval._consumed ||
        DateTime.now().isAfter(approval.expiresAt) ||
        approval.action != action ||
        approval.destination != destination.trim() ||
        approval.amount != amount.toString() ||
        approval.chainId != chainId) {
      return false;
    }
    approval._consumed = true;
    return true;
  }

  Web3Client _makeClient([WalletNetworkDefinition? selected]) => Web3Client(
        _rpcUrlFor(selected ?? network),
        http.Client(),
      );

  String _rpcUrlFor(WalletNetworkDefinition selected) =>
      selected.network == WalletNetwork.robinhoodMainnet
          ? WalletNetworkPolicy.robinhoodRpcUrl
          : selected.readRpcUrl;

  /// Compatibility wrapper retained for existing Base-only callers.
  Future<void> setNetwork({required bool sepolia}) async {
    await setWalletNetwork(
      sepolia ? WalletNetwork.baseSepolia : WalletNetwork.baseMainnet,
    );
  }

  Future<void> setWalletNetwork(WalletNetwork selected) async {
    final definition = WalletNetworkPolicy.definition(selected);
    // Keep rollback compatibility. Older APKs safely map Robinhood to Base
    // Mainnet instead of treating an unknown network as Sepolia.
    await _secureStorage.write(
      key: WalletNetworkPolicy.legacySepoliaStorageKey,
      value: (selected == WalletNetwork.baseSepolia).toString(),
    );
    await _secureStorage.write(
      key: WalletNetworkPolicy.selectedNetworkStorageKey,
      value: definition.storageValue,
    );
    _selectedNetwork = selected;
    _stablecoinBalance = Decimal.zero;
    _txHistory = const <BaseTx>[];
    _eventController.add(BaseEvent.networkChanged(definition.name));
    _logger.i('Wallet network set to ${definition.name}');
    if (isConnected) await refreshBalance();
  }

  /// Initialize — load stored wallet and network preference
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Base Service...');

      final storedNetwork = await _secureStorage.read(
        key: WalletNetworkPolicy.selectedNetworkStorageKey,
      );
      final legacyNetwork = await _secureStorage.read(
        key: WalletNetworkPolicy.legacySepoliaStorageKey,
      );
      _selectedNetwork = WalletNetworkPolicy.decodePreference(
        current: storedNetwork,
        legacySepolia: legacyNetwork,
      );
      if (storedNetwork == null) {
        await _secureStorage.write(
          key: WalletNetworkPolicy.selectedNetworkStorageKey,
          value: network.storageValue,
        );
      }

      final nativeStatus = await NativeBridge.getSecureEvmWalletStatus();
      final resolvedStatus = await _withLegacyWalletStatus(nativeStatus);
      _applyWalletStatus(resolvedStatus);
    } on SecureWalletException catch (error) {
      _walletStatus = SecureWalletStatus.unavailable(errorCode: error.code);
      _logger.e(
        'Base wallet initialization failed: '
        '${_walletStatus.state.name}/${_walletStatus.errorCode}',
      );
      _eventController.add(BaseEvent.error(error.message));
    } catch (_) {
      _walletStatus = SecureWalletStatus.unavailable(
        errorCode: 'WALLET_INITIALIZATION_ERROR',
      );
      _logger.e(
        'Base wallet initialization failed: '
        '${_walletStatus.state.name}/${_walletStatus.errorCode}',
      );
      _eventController.add(
        BaseEvent.error('The Base wallet status could not be loaded.'),
      );
    }
  }

  Future<SecureWalletStatus> _withLegacyWalletStatus(
    SecureWalletStatus nativeStatus,
  ) async {
    if (nativeStatus.state != SecureWalletState.absent) return nativeStatus;
    final storedKey = await _secureStorage.read(key: 'base_private_key');
    if (storedKey == null || storedKey.trim().isEmpty) return nativeStatus;

    // Existing installs need one explicit, device-authenticated migration.
    Uint8List? normalized;
    try {
      normalized = LegacyEvmKeyNormalizer.normalize(storedKey);
      // Derive only the public address here; do not retain credentials.
      return nativeStatus.withLegacyWalletAddress(
        EthPrivateKey(normalized).address.hexEip55,
      );
    } finally {
      normalized?.fillRange(0, normalized.length, 0);
    }
  }

  void _applyWalletStatus(SecureWalletStatus status) {
    if (status.state == SecureWalletState.healthy) {
      _applyNativeWalletStatus(status);
      return;
    }
    _walletStatus = status;
    _ethBalance = Decimal.zero;
    _stablecoinBalance = Decimal.zero;
    _eventController.add(BaseEvent.walletStatusChanged());
  }

  /// Re-read the native lifecycle contract. Unknown and failed reads remain
  /// unavailable rather than being interpreted as an empty wallet.
  Future<SecureWalletStatus> refreshWalletStatus() async {
    try {
      final nativeStatus = await NativeBridge.getSecureEvmWalletStatus();
      final resolvedStatus = await _withLegacyWalletStatus(nativeStatus);
      _applyWalletStatus(resolvedStatus);
      return _walletStatus;
    } on SecureWalletException catch (error) {
      _applyWalletStatus(
        SecureWalletStatus.unavailable(errorCode: error.code),
      );
      rethrow;
    } catch (_) {
      _applyWalletStatus(
        SecureWalletStatus.unavailable(
          errorCode: 'WALLET_STATUS_REFRESH_ERROR',
        ),
      );
      rethrow;
    }
  }

  String _validatedNativeWalletAddress(SecureWalletStatus status) {
    final address = status.address?.trim() ?? '';
    if (status.state != SecureWalletState.healthy || address.isEmpty) {
      throw SecureWalletException(
        code: status.errorCode.isEmpty
            ? 'WALLET_STATUS_INVALID'
            : status.errorCode,
        message: 'Android reported an unusable secure wallet state.',
      );
    }
    return EthereumAddress.fromHex(address).hexEip55;
  }

  void _applyNativeWalletStatus(SecureWalletStatus status) {
    final validatedAddress = _validatedNativeWalletAddress(status);
    _walletStatus = SecureWalletStatus(
      state: status.state,
      address: validatedAddress,
      securityLevel: status.securityLevel,
      authenticationMode: status.authenticationMode,
      errorCode: status.errorCode,
      envelopeIntegrity: status.envelopeIntegrity,
      authenticationAvailable: status.authenticationAvailable,
      hardwareBacked: status.hardwareBacked,
      verificationPending: status.verificationPending,
      verificationCode: status.verificationCode,
    );
    _eventController.add(BaseEvent.walletLoaded(validatedAddress));
    _logger.i(
      'Secure Base wallet loaded: '
      '${_walletStatus.state.name}/${_walletStatus.securityLevel}',
    );
  }

  /// Create a new EVM wallet
  Future<String> createWallet() async {
    try {
      if (legacyMigrationRequired) {
        throw StateError(
          'Secure the existing wallet before creating a new one.',
        );
      }
      _logger.i('Generating Android-protected Base wallet...');
      final status = await NativeBridge.createSecureEvmWallet();
      _applyNativeWalletStatus(status);
      await refreshBalance();
      _eventController.add(BaseEvent.walletCreated(address!));
      return address!;
    } catch (e) {
      _logger.e('Failed to create wallet: $e');
      rethrow;
    }
  }

  /// Import wallet from hex private key
  Future<void> importWallet(String privateKeyHex) async {
    Uint8List? privateKey;
    try {
      if (legacyMigrationRequired) {
        throw StateError(
          'Secure or remove the existing legacy wallet before importing.',
        );
      }
      final clean = privateKeyHex.startsWith('0x')
          ? privateKeyHex.substring(2)
          : privateKeyHex;
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(clean)) {
        throw const FormatException('Private key must be 32-byte hexadecimal.');
      }
      privateKey = Uint8List.fromList(hexToBytes(clean));
      final status = await NativeBridge.importSecureEvmWallet(privateKey);
      _applyNativeWalletStatus(status);
      await refreshBalance();
    } catch (e) {
      _logger.e('Failed to import wallet: $e');
      rethrow;
    } finally {
      privateKey?.fillRange(0, privateKey.length, 0);
    }
  }

  /// Remove only a native alias that has no corresponding wallet envelope.
  /// Android owns the destructive confirmation; no secret enters Dart.
  Future<void> recoverOrphanedWalletProtection() async {
    final nativeStatus = await NativeBridge.recoverOrphanedSecureEvmAlias();
    final resolvedStatus = await _withLegacyWalletStatus(nativeStatus);
    _applyWalletStatus(resolvedStatus);
  }

  /// Remove only a native wallet classified as damaged. Android owns the
  /// warning and requires device authentication whenever the alias is usable.
  Future<void> removeDamagedWallet() async {
    final nativeStatus = await NativeBridge.removeDamagedSecureEvmWallet();
    final resolvedStatus = await _withLegacyWalletStatus(nativeStatus);
    _applyWalletStatus(resolvedStatus);
  }

  /// One-time migration from the historical FlutterSecureStorage key into the
  /// auth-per-use Android Keystore envelope. The legacy record is deleted only
  /// after Android confirms the new wallet envelope was written.
  Future<void> migrateLegacyWallet() async {
    Uint8List? privateKey;
    try {
      final stored = await _secureStorage.read(key: 'base_private_key');
      if (stored == null || stored.trim().isEmpty) {
        throw StateError('No legacy wallet is available to migrate.');
      }
      final expectedAddress = address;
      if (expectedAddress == null || expectedAddress.isEmpty) {
        throw StateError('Legacy wallet identity cannot be verified.');
      }

      privateKey = LegacyEvmKeyNormalizer.normalize(stored);
      final normalizedAddress = EthPrivateKey(privateKey).address.hexEip55;
      if (normalizedAddress.toLowerCase() != expectedAddress.toLowerCase()) {
        throw StateError(
          'Legacy wallet identity changed during normalization.',
        );
      }

      final status = await NativeBridge.importSecureEvmWallet(privateKey);
      final nativeAddress = _validatedNativeWalletAddress(status);
      if (nativeAddress.toLowerCase() != normalizedAddress.toLowerCase()) {
        throw StateError('Android imported a different wallet identity.');
      }
      _applyNativeWalletStatus(status);
      await _secureStorage.delete(key: 'base_private_key');
      await refreshBalance();
    } finally {
      privateKey?.fillRange(0, privateKey.length, 0);
    }
  }

  /// Get the selected network's ETH and explicitly supported stablecoin.
  Future<void> refreshBalance() async {
    if (!isConnected || address == null) return;
    final selected = network;
    final client = _makeClient(selected);
    try {
      final ethAmount =
          await client.getBalance(EthereumAddress.fromHex(address!));
      final refreshedEth = _weiToDecimal(ethAmount.getInWei, 18);
      final token = selected.token;
      final refreshedStablecoin = token == null
          ? Decimal.zero
          : await _getErc20Balance(
              client,
              token.contract,
              address!,
              token.decimals,
            );
      if (_selectedNetwork != selected.network) return;
      _ethBalance = refreshedEth;
      _stablecoinBalance = refreshedStablecoin;

      _eventController.add(BaseEvent.balanceUpdated(
        ethBalance: _ethBalance,
        stablecoinBalance: _stablecoinBalance,
        stablecoinSymbol: token?.symbol,
      ));
      final tokenLog = token == null
          ? ''
          : ' | ${_stablecoinBalance.toStringAsFixed(2)} ${token.symbol}';
      _logger.i(
        '${selected.name} balance: '
        '${_ethBalance.toStringAsFixed(6)} ETH$tokenLog',
      );
    } catch (e) {
      _logger.e('refreshBalance error: $e');
      _eventController.add(BaseEvent.error(e.toString()));
    } finally {
      client.dispose();
    }
  }

  Decimal _weiToDecimal(BigInt wei, int decimals) {
    if (wei == BigInt.zero) return Decimal.zero;
    final divisor = BigInt.from(10).pow(decimals);
    final whole = wei ~/ divisor;
    final frac = wei % divisor;
    final fracStr = frac.toString().padLeft(decimals, '0');
    return Decimal.parse(
        '$whole.${fracStr.substring(0, min(6, fracStr.length))}');
  }

  /// Get ERC-20 token balance (returns human-readable Decimal)
  Future<Decimal> _getErc20Balance(Web3Client client, String contractAddr,
      String walletAddr, int decimals) async {
    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20BalanceAbi, 'ERC20'),
        EthereumAddress.fromHex(contractAddr),
      );
      final fn = contract.function('balanceOf');
      final result = await client.call(
        contract: contract,
        function: fn,
        params: [EthereumAddress.fromHex(walletAddr)],
      );
      final raw = result.first as BigInt;
      return _weiToDecimal(raw, decimals);
    } catch (e) {
      _logger.w('ERC-20 balance failed: $e');
      return Decimal.zero;
    }
  }

  /// Send ETH to an address or .base.eth name
  Future<String> sendEth(
    String toAddressOrName,
    Decimal amount, {
    required BaseTransferApproval approval,
  }) async {
    final selected = network;
    _assertOrdinaryTransactionsAvailable();
    if (!consumeVisibleTransferApproval(
      approval,
      action: 'send_eth',
      destination: toAddressOrName,
      amount: amount,
    )) {
      throw StateError('Human approval is required for every wallet transfer.');
    }
    _assertConnected();
    final client = _makeClient(selected);
    try {
      final to = await _resolveAddress(toAddressOrName, selected);
      final weiValue = _decimalToWei(amount, 18);
      final txHash = await _signAndBroadcast(
        client: client,
        kind: 'eth',
        to: EthereumAddress.fromHex(to),
        value: weiValue,
        data: Uint8List(0),
        selected: selected,
      );
      _logger.i('ETH sent: $txHash');
      _eventController.add(BaseEvent.transactionSent(txHash));
      Future.delayed(const Duration(seconds: 3), refreshBalance);
      return txHash;
    } finally {
      client.dispose();
    }
  }

  /// Send USDC to an address or .base.eth name
  Future<String> sendUsdc(
    String toAddressOrName,
    Decimal amount, {
    required BaseTransferApproval approval,
  }) async {
    final selected = network;
    final token = selected.token;
    if (token == null || token.symbol != 'USDC') {
      throw StateError('$networkName does not support USDC transfers.');
    }
    _assertOrdinaryTransactionsAvailable();
    if (!consumeVisibleTransferApproval(
      approval,
      action: 'send_usdc',
      destination: toAddressOrName,
      amount: amount,
    )) {
      throw StateError('Human approval is required for every wallet transfer.');
    }
    _assertConnected();
    final client = _makeClient(selected);
    try {
      final to = await _resolveAddress(toAddressOrName, selected);
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20TransferAbi, 'ERC20'),
        EthereumAddress.fromHex(token.contract),
      );
      final fn = contract.function('transfer');
      final rawAmount = _decimalToWei(amount, token.decimals);
      final data = fn.encodeCall([EthereumAddress.fromHex(to), rawAmount]);
      final txHash = await _signAndBroadcast(
        client: client,
        kind: 'usdc',
        to: EthereumAddress.fromHex(token.contract),
        value: BigInt.zero,
        data: data,
        selected: selected,
      );
      _logger.i('USDC sent: $txHash');
      _eventController.add(BaseEvent.transactionSent(txHash));
      Future.delayed(const Duration(seconds: 3), refreshBalance);
      return txHash;
    } finally {
      client.dispose();
    }
  }

  /// Send only the official USDG token on Robinhood Chain. This is a bounded
  /// ordinary transfer and is never used as an x402/provider-payment path.
  Future<String> sendUsdg(
    String toAddress,
    Decimal amount, {
    required BaseTransferApproval approval,
  }) async {
    final selected = network;
    final token = selected.token;
    if (!isRobinhoodMainnet || token == null || token.symbol != 'USDG') {
      throw StateError('USDG transfers require Robinhood Chain.');
    }
    _assertOrdinaryTransactionsAvailable();
    if (!consumeVisibleTransferApproval(
      approval,
      action: 'send_usdg',
      destination: toAddress,
      amount: amount,
    )) {
      throw StateError('Human approval is required for every wallet transfer.');
    }
    _assertConnected();
    final client = _makeClient(selected);
    try {
      final to = await _resolveAddress(toAddress, selected);
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20TransferAbi, 'ERC20'),
        EthereumAddress.fromHex(token.contract),
      );
      final data = contract.function('transfer').encodeCall(<dynamic>[
        EthereumAddress.fromHex(to),
        _decimalToWei(amount, token.decimals),
      ]);
      final txHash = await _signAndBroadcast(
        client: client,
        kind: token.transferKind,
        to: EthereumAddress.fromHex(token.contract),
        value: BigInt.zero,
        data: data,
        selected: selected,
      );
      _logger.i('USDG sent on Robinhood Chain: $txHash');
      _eventController.add(BaseEvent.transactionSent(txHash));
      Future.delayed(const Duration(seconds: 3), refreshBalance);
      return txHash;
    } finally {
      client.dispose();
    }
  }

  Future<String> _signAndBroadcast({
    required Web3Client client,
    required String kind,
    required EthereumAddress to,
    required BigInt value,
    required Uint8List data,
    required WalletNetworkDefinition selected,
  }) async {
    final from = EthereumAddress.fromHex(address!);
    final gasPrice = await client.getGasPrice();
    final nonce = await client.getTransactionCount(
      from,
      atBlock: const BlockNum.pending(),
    );
    final gasLimit = await client.estimateGas(
      sender: from,
      to: to,
      data: data,
      value: EtherAmount.inWei(value),
      gasPrice: gasPrice,
    );
    final balance =
        await client.getBalance(from, atBlock: const BlockNum.pending());
    final maximumCost = value + gasPrice.getInWei * gasLimit;
    if (balance.getInWei < maximumCost) {
      throw StateError(
        'Insufficient ETH for the transfer plus the maximum network fee.',
      );
    }
    if (_selectedNetwork != selected.network) {
      throw StateError('Wallet network changed before signing. Review again.');
    }
    final signedHex = await NativeBridge.signSecureEvmTransaction(
      <String, dynamic>{
        'kind': kind,
        'chainId': selected.chainId.toString(),
        'nonce': nonce.toString(),
        'gasPrice': gasPrice.getInWei.toString(),
        'gasLimit': gasLimit.toString(),
        'to': to.hex,
        'value': value.toString(),
        'data': bytesToHex(data, include0x: true),
      },
    );
    if (!RegExp(r'^0x[0-9a-fA-F]+$').hasMatch(signedHex)) {
      throw StateError('Android returned an invalid signed transaction.');
    }
    return client.sendRawTransaction(
      Uint8List.fromList(hexToBytes(signedHex)),
    );
  }

  BigInt _decimalToWei(Decimal amount, int decimals) {
    final multiplier = Decimal.parse('1${'0' * decimals}');
    return (amount * multiplier).toBigInt();
  }

  /// Resolve a .base.eth name to an 0x address.
  /// Falls back to input if already an 0x address.
  Future<String> resolveBasename(String nameOrAddress) =>
      _resolveAddress(nameOrAddress, network);

  Future<String> _resolveAddress(
    String nameOrAddress,
    WalletNetworkDefinition selected,
  ) async {
    if (nameOrAddress.startsWith('0x') && nameOrAddress.length == 42) {
      return EthereumAddress.fromHex(nameOrAddress).hexEip55;
    }
    if (!selected.supportsBasenames) {
      throw FormatException(
          '${selected.name} requires an explicit 0x address.');
    }
    try {
      final response = await http.get(
        Uri.parse('https://api.ensideas.com/ens/resolve/$nameOrAddress'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final addr = data['address'] as String?;
        if (addr != null && addr.startsWith('0x')) return addr;
      }
    } catch (_) {}
    throw Exception('Could not resolve "$nameOrAddress"');
  }

  /// Fetch transaction history via Basescan API (etherscan-compatible)
  Future<List<BaseTx>> fetchHistory({int limit = 10}) async {
    if (!isConnected || address == null) return [];
    final selected = network;
    try {
      final base = selected.explorerApiUrl;
      final url =
          Uri.parse('$base/api?module=account&action=txlist&address=$address'
              '&startblock=0&endblock=99999999&page=1&offset=$limit&sort=desc');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == '1' && body['result'] is List) {
          final refreshedHistory = (body['result'] as List).map((tx) {
            final m = tx as Map<String, dynamic>;
            final weiValue = BigInt.tryParse(m['value'] ?? '0') ?? BigInt.zero;
            return BaseTx(
              hash: m['hash'] ?? '',
              from: m['from'] ?? '',
              to: m['to'] ?? '',
              value: _weiToDecimal(weiValue, 18),
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                  (int.tryParse(m['timeStamp'] ?? '0') ?? 0) * 1000),
              isError: m['isError'] == '1',
            );
          }).toList();
          if (_selectedNetwork != selected.network) return const <BaseTx>[];
          _txHistory = refreshedHistory;
          return _txHistory;
        }
      }
    } catch (e) {
      _logger.w('History fetch failed: $e');
    }
    return [];
  }

  /// Shows an Android-owned, device-authenticated backup dialog. The private
  /// key is not returned to Dart.
  Future<void> showPrivateKeyBackup() async {
    await NativeBridge.showSecureEvmWalletBackup();
  }

  /// Delete wallet from secure storage
  Future<void> deleteWallet() async {
    if (!isConnected) {
      throw StateError(
        'Ordinary removal is available only for a healthy secure wallet.',
      );
    }
    await NativeBridge.deleteSecureEvmWallet();
    await _secureStorage.delete(key: 'base_private_key');
    await refreshWalletStatus();
    _eventController.add(BaseEvent.disconnected());
  }

  void _assertConnected() {
    if (!isConnected || address == null) {
      throw StateError('No wallet connected');
    }
  }

  void _assertOrdinaryTransactionsAvailable() {
    if (!ordinaryTransactionsAvailable) {
      throw StateError(ordinaryTransactionUnavailableReason);
    }
  }

  // ── Minimal ERC-20 ABI fragments ─────────────────────────────────────────

  static const _erc20BalanceAbi = '''[{
    "constant": true,
    "inputs": [{"name": "_owner","type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "balance","type": "uint256"}],
    "type": "function"
  }]''';

  static const _erc20TransferAbi = '''[{
    "constant": false,
    "inputs": [
      {"name": "_to","type": "address"},
      {"name": "_value","type": "uint256"}
    ],
    "name": "transfer",
    "outputs": [{"name": "","type": "bool"}],
    "type": "function"
  }]''';
}

// ── Events ─────────────────────────────────────────────────────────────────

class BaseEvent {
  final BaseEventType type;
  final String? address;
  final Decimal? ethBalance;
  final Decimal? stablecoinBalance;
  final String? stablecoinSymbol;
  @Deprecated('Use stablecoinBalance and stablecoinSymbol.')
  final Decimal? usdcBalance;
  final String? txHash;
  final String? message;

  const BaseEvent._({
    required this.type,
    this.address,
    this.ethBalance,
    this.stablecoinBalance,
    this.stablecoinSymbol,
    this.usdcBalance,
    this.txHash,
    this.message,
  });

  factory BaseEvent.walletLoaded(String address) =>
      BaseEvent._(type: BaseEventType.walletLoaded, address: address);
  factory BaseEvent.walletCreated(String address) =>
      BaseEvent._(type: BaseEventType.walletCreated, address: address);
  factory BaseEvent.balanceUpdated(
          {required Decimal ethBalance,
          required Decimal stablecoinBalance,
          required String? stablecoinSymbol}) =>
      BaseEvent._(
          type: BaseEventType.balanceUpdated,
          ethBalance: ethBalance,
          stablecoinBalance: stablecoinBalance,
          stablecoinSymbol: stablecoinSymbol,
          usdcBalance:
              stablecoinSymbol == 'USDC' ? stablecoinBalance : Decimal.zero);
  factory BaseEvent.transactionSent(String txHash) =>
      BaseEvent._(type: BaseEventType.transactionSent, txHash: txHash);
  factory BaseEvent.disconnected() =>
      BaseEvent._(type: BaseEventType.disconnected);
  factory BaseEvent.walletStatusChanged() =>
      BaseEvent._(type: BaseEventType.walletStatusChanged);
  factory BaseEvent.networkChanged(String networkName) =>
      BaseEvent._(type: BaseEventType.networkChanged, message: networkName);
  factory BaseEvent.error(String message) =>
      BaseEvent._(type: BaseEventType.error, message: message);
}

enum BaseEventType {
  walletLoaded,
  walletCreated,
  balanceUpdated,
  transactionSent,
  disconnected,
  walletStatusChanged,
  networkChanged,
  error,
}

// ── Transaction model ──────────────────────────────────────────────────────

class BaseTx {
  final String hash;
  final String from;
  final String to;
  final Decimal value;
  final DateTime timestamp;
  final bool isError;

  const BaseTx({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.timestamp,
    required this.isError,
  });
}
