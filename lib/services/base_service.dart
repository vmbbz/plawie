import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

/// Base Chain (Coinbase L2) wallet service.
/// Chain ID 8453 (mainnet) / 84532 (sepolia testnet).
/// Uses web3dart for EVM-compatible wallet operations.
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
  EthPrivateKey? _credentials;
  String? _address;
  bool _isConnected = false;
  bool _useSepolia = false; // default mainnet

  // Cached balances
  Decimal _ethBalance = Decimal.zero;
  Decimal _usdcBalance = Decimal.zero;

  // Tx history cache
  List<BaseTx> _txHistory = [];

  Stream<BaseEvent> get events => _eventController.stream;
  bool get isConnected => _isConnected;
  String? get address => _address;
  bool get useSepolia => _useSepolia;
  Decimal get ethBalance => _ethBalance;
  Decimal get usdcBalance => _usdcBalance;
  List<BaseTx> get txHistory => _txHistory;
  String get rpcUrl => _useSepolia ? _sepoliaRpc : _mainnetRpc;
  String get networkName => _useSepolia ? 'Base Sepolia' : 'Base Mainnet';
  int get chainId => _useSepolia ? 84532 : 8453;
  String get usdcContract => _useSepolia ? _usdcSepolia : _usdcMainnet;

  Web3Client _makeClient() => Web3Client(rpcUrl, http.Client());

  /// Toggle between mainnet and sepolia
  Future<void> setNetwork({required bool sepolia}) async {
    _useSepolia = sepolia;
    await _secureStorage.write(
      key: 'base_use_sepolia',
      value: sepolia.toString(),
    );
    _logger.i('Base network set to ${sepolia ? "Sepolia" : "Mainnet"}');
    if (_isConnected) await refreshBalance();
  }

  /// Initialize — load stored wallet and network preference
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Base Service...');

      final storedNetwork = await _secureStorage.read(key: 'base_use_sepolia');
      if (storedNetwork != null) {
        _useSepolia = storedNetwork == 'true';
      }

      final storedKey = await _secureStorage.read(key: 'base_private_key');
      if (storedKey != null) {
        _loadFromPrivateKey(storedKey);
      }
    } catch (e) {
      _logger.e('Failed to initialize Base Service: $e');
    }
  }

  void _loadFromPrivateKey(String hexKey) {
    _credentials = EthPrivateKey.fromHex(hexKey);
    _address = _credentials!.address.hexEip55;
    _isConnected = true;
    _eventController.add(BaseEvent.walletLoaded(_address!));
    _logger.i('Base wallet loaded: $_address');
  }

  /// Create a new EVM wallet
  Future<String> createWallet() async {
    try {
      _logger.i('Generating new Base wallet...');
      final creds = EthPrivateKey.createRandom(Random.secure());
      final hexKey = bytesToHex(creds.privateKey, include0x: false);
      await _secureStorage.write(key: 'base_private_key', value: hexKey);
      _loadFromPrivateKey(hexKey);
      await refreshBalance();
      _eventController.add(BaseEvent.walletCreated(_address!));
      return _address!;
    } catch (e) {
      _logger.e('Failed to create wallet: $e');
      rethrow;
    }
  }

  /// Import wallet from hex private key
  Future<void> importWallet(String privateKeyHex) async {
    try {
      final clean = privateKeyHex.startsWith('0x')
          ? privateKeyHex.substring(2)
          : privateKeyHex;
      final hexKey = clean;
      await _secureStorage.write(key: 'base_private_key', value: hexKey);
      _loadFromPrivateKey(hexKey);
      await refreshBalance();
    } catch (e) {
      _logger.e('Failed to import wallet: $e');
      rethrow;
    }
  }

  /// Get ETH and USDC balances
  Future<void> refreshBalance() async {
    if (!_isConnected || _address == null) return;
    final client = _makeClient();
    try {
      // ETH balance
      final ethAmount =
          await client.getBalance(EthereumAddress.fromHex(_address!));
      _ethBalance = _weiToDecimal(ethAmount.getInWei, 18);

      // USDC balance via balanceOf — ERC-20 with 6 decimals
      _usdcBalance = await _getErc20Balance(client, usdcContract, _address!, 6);

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
    return Decimal.parse('$whole.${fracStr.substring(0, min(6, fracStr.length))}');
  }

  /// Get ERC-20 token balance (returns human-readable Decimal)
  Future<Decimal> _getErc20Balance(
      Web3Client client, String contractAddr, String walletAddr, int decimals) async {
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
  Future<String> sendEth(String toAddressOrName, Decimal amount) async {
    _assertConnected();
    final client = _makeClient();
    try {
      final to = await _resolveAddress(toAddressOrName);
      // Convert ETH amount to wei BigInt
      final weiValue = _decimalToWei(amount, 18);
      final txHash = await client.sendTransaction(
        _credentials!,
        Transaction(
          to: EthereumAddress.fromHex(to),
          value: EtherAmount.inWei(weiValue),
        ),
        chainId: chainId,
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
  Future<String> sendUsdc(String toAddressOrName, Decimal amount) async {
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
      final txHash = await client.sendTransaction(
        _credentials!,
        Transaction.callContract(
          contract: contract,
          function: fn,
          parameters: [EthereumAddress.fromHex(to), rawAmount],
        ),
        chainId: chainId,
      );
      _logger.i('USDC sent: $txHash');
      _eventController.add(BaseEvent.transactionSent(txHash));
      Future.delayed(const Duration(seconds: 3), refreshBalance);
      return txHash;
    } finally {
      client.dispose();
    }
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
      final response = await http
          .get(
            Uri.parse('https://api.ensideas.com/ens/resolve/$nameOrAddress'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 6));
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
    if (!_isConnected || _address == null) return [];
    try {
      final base = _useSepolia
          ? 'https://api-sepolia.basescan.org'
          : 'https://api.basescan.org';
      final url = Uri.parse(
          '$base/api?module=account&action=txlist&address=$_address'
          '&startblock=0&endblock=99999999&page=1&offset=$limit&sort=desc');
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == '1' && body['result'] is List) {
          _txHistory = (body['result'] as List).map((tx) {
            final m = tx as Map<String, dynamic>;
            final weiValue =
                BigInt.tryParse(m['value'] ?? '0') ?? BigInt.zero;
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

  /// Export private key hex (for backup)
  Future<String?> exportPrivateKey() async {
    return await _secureStorage.read(key: 'base_private_key');
  }

  /// Delete wallet from secure storage
  Future<void> deleteWallet() async {
    await _secureStorage.delete(key: 'base_private_key');
    _credentials = null;
    _address = null;
    _isConnected = false;
    _ethBalance = Decimal.zero;
    _usdcBalance = Decimal.zero;
    _eventController.add(BaseEvent.disconnected());
  }

  void _assertConnected() {
    if (!_isConnected || _credentials == null) {
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
  factory BaseEvent.error(String message) =>
      BaseEvent._(type: BaseEventType.error, message: message);
}

enum BaseEventType {
  walletLoaded,
  walletCreated,
  balanceUpdated,
  transactionSent,
  disconnected,
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
