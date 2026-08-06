import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import 'legacy_evm_key_normalizer.dart';
import 'native_bridge.dart';

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

/// Base Chain (Coinbase L2) wallet service.
/// Chain ID 8453 (mainnet) / 84532 (sepolia testnet).
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

  // RPC endpoints
  static const String _mainnetRpc = 'https://mainnet.base.org';
  static const String _sepoliaRpc = 'https://sepolia.base.org';

  // USDC on Base Mainnet (native Circle issuance)
  static const String _usdcMainnet =
      '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';
  // USDC on Base Sepolia (testnet)
  static const String _usdcSepolia =
      '0x036CbD53842c5426634e7929541eC2318f3dCF7e';

  // State
  SecureWalletStatus _walletStatus = SecureWalletStatus.absent();
  bool _useSepolia = false; // default mainnet

  // Cached balances
  Decimal _ethBalance = Decimal.zero;
  Decimal _usdcBalance = Decimal.zero;

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
  bool get useSepolia => _useSepolia;
  Decimal get ethBalance => _ethBalance;
  Decimal get usdcBalance => _usdcBalance;
  List<BaseTx> get txHistory => _txHistory;
  String get rpcUrl => _useSepolia ? _sepoliaRpc : _mainnetRpc;
  String get networkName => _useSepolia ? 'Base Sepolia' : 'Base Mainnet';
  int get chainId => _useSepolia ? 84532 : 8453;
  String get usdcContract => _useSepolia ? _usdcSepolia : _usdcMainnet;

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
    if (action != 'send_eth' && action != 'send_usdc') {
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

  Web3Client _makeClient() => Web3Client(rpcUrl, http.Client());

  /// Toggle between mainnet and sepolia
  Future<void> setNetwork({required bool sepolia}) async {
    _useSepolia = sepolia;
    await _secureStorage.write(
      key: 'base_use_sepolia',
      value: sepolia.toString(),
    );
    _logger.i('Base network set to ${sepolia ? "Sepolia" : "Mainnet"}');
    if (isConnected) await refreshBalance();
  }

  /// Initialize — load stored wallet and network preference
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Base Service...');

      final storedNetwork = await _secureStorage.read(key: 'base_use_sepolia');
      if (storedNetwork != null) {
        _useSepolia = storedNetwork == 'true';
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
    _usdcBalance = Decimal.zero;
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

  /// Get ETH and USDC balances
  Future<void> refreshBalance() async {
    if (!isConnected || address == null) return;
    final client = _makeClient();
    try {
      // ETH balance
      final ethAmount =
          await client.getBalance(EthereumAddress.fromHex(address!));
      _ethBalance = _weiToDecimal(ethAmount.getInWei, 18);

      // USDC balance via balanceOf — ERC-20 with 6 decimals
      _usdcBalance = await _getErc20Balance(client, usdcContract, address!, 6);

      _eventController.add(BaseEvent.balanceUpdated(
        ethBalance: _ethBalance,
        usdcBalance: _usdcBalance,
      ));
      _logger.i(
          'Balance: ${_ethBalance.toStringAsFixed(6)} ETH  |  ${_usdcBalance.toStringAsFixed(2)} USDC');
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
    if (!consumeVisibleTransferApproval(
      approval,
      action: 'send_eth',
      destination: toAddressOrName,
      amount: amount,
    )) {
      throw StateError('Human approval is required for every Base transfer.');
    }
    _assertConnected();
    final client = _makeClient();
    try {
      final to = await _resolveAddress(toAddressOrName);
      final weiValue = _decimalToWei(amount, 18);
      final txHash = await _signAndBroadcast(
        client: client,
        kind: 'eth',
        to: EthereumAddress.fromHex(to),
        value: weiValue,
        data: Uint8List(0),
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
    if (!consumeVisibleTransferApproval(
      approval,
      action: 'send_usdc',
      destination: toAddressOrName,
      amount: amount,
    )) {
      throw StateError('Human approval is required for every Base transfer.');
    }
    _assertConnected();
    final client = _makeClient();
    try {
      final to = await _resolveAddress(toAddressOrName);
      final contract = DeployedContract(
        ContractAbi.fromJson(_erc20TransferAbi, 'ERC20'),
        EthereumAddress.fromHex(usdcContract),
      );
      final fn = contract.function('transfer');
      // USDC has 6 decimals
      final rawAmount = _decimalToWei(amount, 6);
      final data = fn.encodeCall([EthereumAddress.fromHex(to), rawAmount]);
      final txHash = await _signAndBroadcast(
        client: client,
        kind: 'usdc',
        to: EthereumAddress.fromHex(usdcContract),
        value: BigInt.zero,
        data: data,
      );
      _logger.i('USDC sent: $txHash');
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
    final signedHex = await NativeBridge.signSecureEvmTransaction(
      <String, dynamic>{
        'kind': kind,
        'chainId': chainId.toString(),
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
      _resolveAddress(nameOrAddress);

  Future<String> _resolveAddress(String nameOrAddress) async {
    if (nameOrAddress.startsWith('0x') && nameOrAddress.length == 42) {
      return nameOrAddress;
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
    try {
      final base = _useSepolia
          ? 'https://api-sepolia.basescan.org'
          : 'https://api.basescan.org';
      final url =
          Uri.parse('$base/api?module=account&action=txlist&address=$address'
              '&startblock=0&endblock=99999999&page=1&offset=$limit&sort=desc');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == '1' && body['result'] is List) {
          _txHistory = (body['result'] as List).map((tx) {
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
  final Decimal? usdcBalance;
  final String? txHash;
  final String? message;

  const BaseEvent._({
    required this.type,
    this.address,
    this.ethBalance,
    this.usdcBalance,
    this.txHash,
    this.message,
  });

  factory BaseEvent.walletLoaded(String address) =>
      BaseEvent._(type: BaseEventType.walletLoaded, address: address);
  factory BaseEvent.walletCreated(String address) =>
      BaseEvent._(type: BaseEventType.walletCreated, address: address);
  factory BaseEvent.balanceUpdated(
          {required Decimal ethBalance, required Decimal usdcBalance}) =>
      BaseEvent._(
          type: BaseEventType.balanceUpdated,
          ethBalance: ethBalance,
          usdcBalance: usdcBalance);
  factory BaseEvent.transactionSent(String txHash) =>
      BaseEvent._(type: BaseEventType.transactionSent, txHash: txHash);
  factory BaseEvent.disconnected() =>
      BaseEvent._(type: BaseEventType.disconnected);
  factory BaseEvent.walletStatusChanged() =>
      BaseEvent._(type: BaseEventType.walletStatusChanged);
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
