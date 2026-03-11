import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:solana/solana.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:bs58/bs58.dart';
import 'package:dio/dio.dart';

/// Real Solana Service — replaces all mock/demo implementations
/// Uses the `solana` Dart SDK for keypair, RPC, and transactions.
class SolanaService {
  static final SolanaService _instance = SolanaService._internal();
  factory SolanaService() => _instance;
  SolanaService._internal();

  final Logger _logger = Logger();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final StreamController<SolanaEvent> _eventController =
      StreamController.broadcast();

  // RPC endpoints
  static const String _mainnetRpc = 'https://api.mainnet-beta.solana.com';
  static const String _devnetRpc = 'https://api.devnet.solana.com';

  // State
  Ed25519HDKeyPair? _keyPair;
  String? _publicKey;
  bool _isConnected = false;
  bool _useDevnet = true; // Default to devnet for safety

  // Cached balances
  Decimal _solBalance = Decimal.zero;
  List<TokenBalance> _tokenBalances = [];

  Stream<SolanaEvent> get events => _eventController.stream;
  bool get isConnected => _isConnected;
  String? get publicKey => _publicKey;
  bool get useDevnet => _useDevnet;
  Decimal get solBalance => _solBalance;
  List<TokenBalance> get tokenBalances => _tokenBalances;
  Ed25519HDKeyPair? get keyPair => _keyPair;

  String get rpcUrl => _useDevnet ? _devnetRpc : _mainnetRpc;
  String get networkName => _useDevnet ? 'Devnet' : 'Mainnet';

  SolanaClient get _client => SolanaClient(
        rpcUrl: Uri.parse(rpcUrl),
        websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
      );

  /// Toggle between devnet and mainnet
  Future<void> setNetwork({required bool devnet}) async {
    _useDevnet = devnet;
    await _secureStorage.write(
      key: 'solana_use_devnet',
      value: devnet.toString(),
    );
    _logger.i('Solana network set to ${devnet ? "Devnet" : "Mainnet"}');

    // Refresh balance if connected
    if (_isConnected) {
      await refreshBalance();
    }
  }

  /// Initialize service — load stored wallet and network preference
  Future<void> initialize() async {
    try {
      _logger.i('Initializing Solana Service...');

      // Load network preference
      final storedNetwork =
          await _secureStorage.read(key: 'solana_use_devnet');
      if (storedNetwork != null) {
        _useDevnet = storedNetwork == 'true';
      }

      // Check if we have a stored wallet
      final storedKey =
          await _secureStorage.read(key: 'solana_private_key_bytes');
      if (storedKey != null) {
        await _loadStoredWallet(storedKey);
      }

      _logger.i('Solana Service initialized (${networkName})');
    } catch (e) {
      _logger.e('Failed to initialize Solana Service: $e');
      _eventController.add(SolanaEvent.error('Initialization failed: $e'));
    }
  }

  /// Create a new wallet with a real Ed25519 keypair
  Future<bool> createWallet() async {
    try {
      _logger.i('Creating new Solana wallet...');

      // Generate a real keypair
      _keyPair = await Ed25519HDKeyPair.random();
      _publicKey = _keyPair!.address;

      // Extract and store the private key bytes
      final privateKeyBytes = await _keyPair!.extract();
      final privateKeyBase64 = base64Encode(privateKeyBytes.bytes);
      await _secureStorage.write(
        key: 'solana_private_key_bytes',
        value: privateKeyBase64,
      );

      _isConnected = true;
      _eventController.add(SolanaEvent.walletCreated(_publicKey!));
      _eventController.add(SolanaEvent.connected(_publicKey!));

      _logger.i('New wallet created: $_publicKey');

      // Fetch initial balance
      await refreshBalance();

      return true;
    } catch (e) {
      _logger.e('Failed to create wallet: $e');
      _eventController.add(SolanaEvent.error('Wallet creation failed: $e'));
      return false;
    }
  }

  /// Connect to an existing wallet via base58 private key
  Future<bool> connectWallet(String privateKeyBase58) async {
    try {
      _logger.i('Connecting to existing wallet...');

      // Decode base58 private key
      final keyBytes = base58.decode(privateKeyBase58);

      // Create keypair from private key bytes
      _keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: keyBytes.sublist(0, 32),
      );
      _publicKey = _keyPair!.address;

      // Store the private key bytes
      final privateKeyBase64 = base64Encode(keyBytes);
      await _secureStorage.write(
        key: 'solana_private_key_bytes',
        value: privateKeyBase64,
      );

      _isConnected = true;
      _eventController.add(SolanaEvent.connected(_publicKey!));

      _logger.i('Wallet connected: $_publicKey');

      // Fetch initial balance
      await refreshBalance();

      return true;
    } catch (e) {
      _logger.e('Failed to connect wallet: $e');
      _eventController.add(SolanaEvent.error('Wallet connection failed: $e'));
      return false;
    }
  }

  /// Load stored wallet from secure storage
  Future<void> _loadStoredWallet(String privateKeyBase64) async {
    try {
      final keyBytes = base64Decode(privateKeyBase64);

      _keyPair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: keyBytes.sublist(0, 32),
      );
      _publicKey = _keyPair!.address;
      _isConnected = true;

      _eventController.add(SolanaEvent.connected(_publicKey!));
      _logger.i('Loaded stored wallet: $_publicKey');
    } catch (e) {
      _logger.e('Failed to load stored wallet: $e');
      await _secureStorage.delete(key: 'solana_private_key_bytes');
    }
  }

  /// Disconnect wallet
  Future<void> disconnectWallet() async {
    try {
      _isConnected = false;
      _publicKey = null;
      _keyPair = null;
      _solBalance = Decimal.zero;
      _tokenBalances = [];

      await _secureStorage.delete(key: 'solana_private_key_bytes');

      _eventController.add(SolanaEvent.disconnected());
      _logger.i('Wallet disconnected');
    } catch (e) {
      _logger.e('Failed to disconnect wallet: $e');
    }
  }

  /// Refresh SOL balance and token balances
  Future<void> refreshBalance() async {
    if (!_isConnected || _publicKey == null) return;

    try {
      await Future.wait([
        getSolBalance(),
        _fetchTokenBalances(),
      ]);
    } catch (e) {
      _logger.w('Failed to refresh balances: $e');
    }
  }

  /// Get real SOL balance via RPC
  Future<Decimal> getSolBalance() async {
    if (!_isConnected || _publicKey == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final client = _client;
      final pubKey = Ed25519HDPublicKey.fromBase58(_publicKey!);
      final balanceResult = await client.rpcClient.getBalance(
        pubKey.toBase58(),
      );

      // Convert lamports to SOL (1 SOL = 1,000,000,000 lamports)
      final lamports = balanceResult.value;
      _solBalance = Decimal.parse(
        (lamports / 1000000000).toStringAsFixed(9),
      );

      _eventController
          .add(SolanaEvent.balanceUpdated('SOL', _solBalance));

      _logger.i('SOL balance: $_solBalance');
      return _solBalance;
    } catch (e) {
      _logger.e('Failed to get SOL balance: $e');
      _eventController
          .add(SolanaEvent.error('Failed to get SOL balance: $e'));
      rethrow;
    }
  }

  /// Fetch SPL token balances via direct JSON-RPC (avoids SDK type issues)
  Future<void> _fetchTokenBalances() async {
    if (!_isConnected || _publicKey == null) return;

    try {
      final dio = Dio();
      final response = await dio.post(
        rpcUrl,
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'getTokenAccountsByOwner',
          'params': [
            _publicKey!,
            {'programId': 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'},
            {'encoding': 'jsonParsed'},
          ],
        },
      );

      _tokenBalances = [];
      final result = response.data['result'];
      if (result != null && result['value'] != null) {
        for (final account in result['value']) {
          try {
            final info = account['account']['data']['parsed']['info'];
            if (info != null) {
              final tokenAmount = info['tokenAmount'];
              if (tokenAmount != null) {
                final mint = info['mint'] as String? ?? '';
                final amountStr = tokenAmount['amount'] as String? ?? '0';
                final decimals =
                    (tokenAmount['decimals'] as num?)?.toInt() ?? 0;
                final uiAmountNum = tokenAmount['uiAmount'] as num? ?? 0;

                _tokenBalances.add(TokenBalance(
                  mint: mint,
                  amount: Decimal.parse(amountStr),
                  decimals: decimals,
                  uiAmount: Decimal.parse(uiAmountNum.toString()),
                ));
              }
            }
          } catch (e) {
            _logger.w('Failed to parse token account: $e');
          }
        }
      }

      _logger.i('Found ${_tokenBalances.length} token accounts');
    } catch (e) {
      _logger.w('Failed to fetch token balances: $e');
    }
  }

  /// Get token balance for a specific mint
  Future<TokenBalance> getTokenBalance(String mintAddress) async {
    if (!_isConnected || _publicKey == null) {
      throw Exception('Wallet not connected');
    }

    // Check cached balances first
    final cached = _tokenBalances.where((tb) => tb.mint == mintAddress);
    if (cached.isNotEmpty) return cached.first;

    // Return zero balance if not found
    return TokenBalance(
      mint: mintAddress,
      amount: Decimal.zero,
      decimals: 0,
      uiAmount: Decimal.zero,
    );
  }

  /// Send a serialized transaction (base64 encoded)
  Future<String> sendTransaction(String transactionBase64) async {
    if (!_isConnected || _keyPair == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final client = _client;
      final signature = await client.rpcClient.sendTransaction(
        transactionBase64,
        preflightCommitment: Commitment.confirmed,
      );

      _eventController.add(SolanaEvent.transactionSent(signature));
      _logger.i('Transaction sent: $signature');

      // Refresh balance after sending
      Future.delayed(const Duration(seconds: 3), refreshBalance);

      return signature;
    } catch (e) {
      _logger.e('Failed to send transaction: $e');
      _eventController
          .add(SolanaEvent.error('Transaction sending failed: $e'));
      rethrow;
    }
  }

  /// Send SOL to a recipient
  Future<String> sendSol({
    required String recipientAddress,
    required Decimal amountSol,
  }) async {
    if (!_isConnected || _keyPair == null) {
      throw Exception('Wallet not connected');
    }

    try {
      _logger.i('Sending $amountSol SOL to $recipientAddress');

      final client = _client;
      final lamports =
          (amountSol * Decimal.fromInt(1000000000)).toBigInt().toInt();

      final recipient = Ed25519HDPublicKey.fromBase58(recipientAddress);

      final signature = await client.transferLamports(
        source: _keyPair!,
        destination: recipient,
        lamports: lamports,
      );

      _eventController.add(SolanaEvent.transactionSent(signature));
      _logger.i('SOL transfer sent: $signature');

      // Refresh balance after sending
      Future.delayed(const Duration(seconds: 3), refreshBalance);

      return signature;
    } catch (e) {
      _logger.e('Failed to send SOL: $e');
      _eventController.add(SolanaEvent.error('SOL transfer failed: $e'));
      rethrow;
    }
  }

  /// Get transaction history (recent signatures)
  Future<List<TransactionInfo>> getTransactionHistory({int limit = 10}) async {
    if (!_isConnected || _publicKey == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final client = _client;
      final signatures = await client.rpcClient.getSignaturesForAddress(
        _publicKey!,
        limit: limit,
      );

      final transactions = <TransactionInfo>[];
      for (final sig in signatures) {
        transactions.add(TransactionInfo(
          signature: sig.signature,
          timestamp: sig.blockTime != null
              ? DateTime.fromMillisecondsSinceEpoch(sig.blockTime! * 1000)
              : DateTime.now(),
          type: sig.memo,
          status: sig.confirmationStatus?.name ?? 'unknown',
        ));
      }

      return transactions;
    } catch (e) {
      _logger.e('Failed to get transaction history: $e');
      _eventController
          .add(SolanaEvent.error('Failed to get transaction history: $e'));
      rethrow;
    }
  }

  /// Get the private key as base58 (for export/backup)
  Future<String?> exportPrivateKey() async {
    if (_keyPair == null) return null;
    try {
      final privateKeyBytes = await _keyPair!.extract();
      return base58.encode(Uint8List.fromList(privateKeyBytes.bytes));
    } catch (e) {
      _logger.e('Failed to export private key: $e');
      return null;
    }
  }

  /// Get portfolio summary
  Future<PortfolioSummary> getPortfolioSummary() async {
    if (!_isConnected) {
      throw Exception('Wallet not connected');
    }

    await refreshBalance();

    return PortfolioSummary(
      solBalance: _solBalance,
      tokenBalances: _tokenBalances,
      totalValue: _solBalance +
          _tokenBalances.fold(
            Decimal.zero,
            (sum, token) => sum + token.uiAmount,
          ),
    );
  }

  /// Dispose service
  Future<void> dispose() async {
    await _eventController.close();
    _isConnected = false;
    _publicKey = null;
    _keyPair = null;
  }
}

/// Token balance model
class TokenBalance extends Equatable {
  final String mint;
  final Decimal amount;
  final int decimals;
  final Decimal uiAmount;

  const TokenBalance({
    required this.mint,
    required this.amount,
    required this.decimals,
    required this.uiAmount,
  });

  @override
  List<Object?> get props => [mint, amount, decimals, uiAmount];
}

/// Transaction info model
class TransactionInfo extends Equatable {
  final String signature;
  final DateTime timestamp;
  final String? type;
  final Decimal? amount;
  final String? status;

  const TransactionInfo({
    required this.signature,
    required this.timestamp,
    this.type,
    this.amount,
    this.status,
  });

  @override
  List<Object?> get props => [signature, timestamp, type, amount, status];
}

/// Portfolio summary model
class PortfolioSummary extends Equatable {
  final Decimal solBalance;
  final List<TokenBalance> tokenBalances;
  final Decimal totalValue;

  const PortfolioSummary({
    required this.solBalance,
    required this.tokenBalances,
    required this.totalValue,
  });

  @override
  List<Object?> get props => [solBalance, tokenBalances, totalValue];
}

/// Solana event model
class SolanaEvent extends Equatable {
  final SolanaEventType type;
  final String? data;
  final String? error;

  const SolanaEvent({
    required this.type,
    this.data,
    this.error,
  });

  factory SolanaEvent.connected(String publicKey) =>
      SolanaEvent(type: SolanaEventType.connected, data: publicKey);

  factory SolanaEvent.disconnected() =>
      SolanaEvent(type: SolanaEventType.disconnected);

  factory SolanaEvent.walletCreated(String publicKey) =>
      SolanaEvent(type: SolanaEventType.walletCreated, data: publicKey);

  factory SolanaEvent.balanceUpdated(String token, Decimal balance) =>
      SolanaEvent(
          type: SolanaEventType.balanceUpdated, data: '$token:$balance');

  factory SolanaEvent.transactionSigned(String signature) =>
      SolanaEvent(type: SolanaEventType.transactionSigned, data: signature);

  factory SolanaEvent.transactionSent(String signature) =>
      SolanaEvent(type: SolanaEventType.transactionSent, data: signature);

  factory SolanaEvent.error(String error) =>
      SolanaEvent(type: SolanaEventType.error, error: error);

  @override
  List<Object?> get props => [type, data, error];
}

/// Solana event type enum
enum SolanaEventType {
  connected,
  disconnected,
  walletCreated,
  balanceUpdated,
  transactionSigned,
  transactionSent,
  error,
}
