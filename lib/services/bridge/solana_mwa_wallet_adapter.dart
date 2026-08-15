import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'bridge_models.dart';
import 'external_wallet_session_service.dart';

abstract interface class SolanaMwaPlatform {
  Future<Object?> authorize();

  Future<Object?> submitTransaction(String base64Transaction);

  Future<void> deauthorize();
}

final class MethodChannelSolanaMwaPlatform implements SolanaMwaPlatform {
  const MethodChannelSolanaMwaPlatform({
    MethodChannel channel = const MethodChannel(
      'com.openclaw.plawie/solana_mwa',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<Object?> authorize() => _channel.invokeMethod<Object?>('authorize');

  @override
  Future<void> deauthorize() => _channel.invokeMethod<void>('deauthorize');

  @override
  Future<Object?> submitTransaction(String base64Transaction) =>
      _channel.invokeMethod<Object?>('submitTransaction', <String, Object>{
        'transaction': base64Transaction,
      });
}

final class SolanaMwaWalletAdapter implements ExternalWalletAdapter {
  SolanaMwaWalletAdapter({
    SolanaMwaPlatform platform = const MethodChannelSolanaMwaPlatform(),
    bool? supportedPlatform,
  })  : _platform = platform,
        _supportedPlatform = supportedPlatform ?? Platform.isAndroid;

  final SolanaMwaPlatform _platform;
  final bool _supportedPlatform;
  ExternalWalletIdentity? _identity;

  @override
  ExternalWalletTransport get transport => ExternalWalletTransport.solanaMwa;

  @override
  Future<ExternalWalletOption> discover(BridgeChain chain) async {
    if (chain.type != BridgeChainType.svm ||
        chain.id != BridgeConstants.solanaChainId) {
      return const ExternalWalletOption(
        transport: ExternalWalletTransport.solanaMwa,
        label: 'Android Solana wallet',
        available: false,
        reason: 'Mobile Wallet Adapter supports Solana mainnet only.',
      );
    }
    return ExternalWalletOption(
      transport: transport,
      label: 'Android Solana wallet',
      available: _supportedPlatform,
      reason:
          _supportedPlatform ? null : 'Mobile Wallet Adapter requires Android.',
    );
  }

  @override
  Future<ExternalWalletIdentity> connect(BridgeChain chain) async {
    if (!_supportedPlatform ||
        chain.type != BridgeChainType.svm ||
        chain.id != BridgeConstants.solanaChainId) {
      throw const ExternalWalletException('wallet_transport_unavailable');
    }
    final raw = await _guard(_platform.authorize);
    final map = _strictMap(raw);
    final methods = _stringSet(map['methods']);
    final publicMethods = <String>{};
    if (methods.contains('signTransactions')) {
      publicMethods.add('solana_signTransaction');
    }
    if (methods.contains('signAndSendTransactions')) {
      publicMethods.add('solana_signAndSendTransaction');
    }
    if (publicMethods.isEmpty ||
        map['chainId'] != BridgeConstants.solanaChainId ||
        map['chainType'] != 'svm') {
      throw const ExternalWalletException('wallet_response_invalid');
    }
    final label = map['walletLabel'];
    final address = map['address'];
    if (label is! String ||
        label.trim().isEmpty ||
        address is! String ||
        !RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address)) {
      throw const ExternalWalletException('wallet_response_invalid');
    }
    final identity = ExternalWalletIdentity(
      transport: transport,
      walletLabel: label.trim(),
      publicAddress: address,
      chainId: BridgeConstants.solanaChainId,
      chainType: BridgeChainType.svm,
      approvedMethods: Set<String>.unmodifiable(publicMethods),
      approvedFeatures: Set<String>.unmodifiable(_stringSet(map['features'])),
    );
    _identity = identity;
    return identity;
  }

  @override
  Future<void> disconnect() async {
    _identity = null;
    if (!_supportedPlatform) return;
    await _guard<void>(() => _platform.deauthorize());
  }

  @override
  Future<String> sendEvmTransaction(
    EvmBridgeExecutionPayload payload,
  ) =>
      Future<String>.error(
        const ExternalWalletException('wallet_transport_chain_mismatch'),
      );

  @override
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  ) async {
    final identity = _identity;
    if (identity == null) {
      throw const ExternalWalletException('wallet_not_connected');
    }
    if (payload.from != identity.publicAddress) {
      throw const ExternalWalletException('wallet_account_mismatch');
    }
    _validateCanonicalTransaction(payload.base64Transaction);
    final raw = await _guard<Object?>(
      () => _platform.submitTransaction(payload.base64Transaction),
    );
    final map = _strictMap(raw);
    final mode = map['mode'];
    if (mode == 'signOnly' && map.length == 2) {
      final bytes = _byteList(map['signedTransactionBytes']);
      if (bytes == null || bytes.isEmpty || bytes.length > 1232) {
        throw const ExternalWalletException('wallet_response_invalid');
      }
      return SignedSolanaTransaction(Uint8List.fromList(bytes));
    }
    if (mode == 'signAndSend' && map.length == 2) {
      final signature = map['signatureBase58'];
      if (signature is! String || _decodeBase58(signature).length != 64) {
        throw const ExternalWalletException('wallet_response_invalid');
      }
      return SubmittedSolanaTransaction(signature);
    }
    throw const ExternalWalletException('wallet_response_invalid');
  }
}

Future<T> _guard<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on MissingPluginException {
    throw const ExternalWalletException('wallet_transport_unavailable');
  } on PlatformException catch (error) {
    throw ExternalWalletException(switch (error.code) {
      'MWA_NO_WALLET' => 'wallet_transport_unavailable',
      'MWA_CANCELLED' => 'wallet_user_rejected',
      'MWA_BUSY' => 'wallet_operation_in_progress',
      'MWA_INVALID_PAYLOAD' => 'wallet_payload_invalid',
      'MWA_AUTH_FAILED' => 'wallet_connect_failed',
      'MWA_SUBMIT_FAILED' => 'wallet_request_failed',
      'MWA_DEAUTHORIZE_FAILED' => 'wallet_disconnect_failed',
      _ => 'wallet_request_failed',
    });
  } on ExternalWalletException {
    rethrow;
  } catch (_) {
    throw const ExternalWalletException('wallet_request_failed');
  }
}

Map<Object?, Object?> _strictMap(Object? raw) {
  if (raw is! Map) {
    throw const ExternalWalletException('wallet_response_invalid');
  }
  return Map<Object?, Object?>.from(raw);
}

Set<String> _stringSet(Object? raw) {
  if (raw is! List || raw.any((item) => item is! String)) {
    throw const ExternalWalletException('wallet_response_invalid');
  }
  return Set<String>.unmodifiable(raw.cast<String>());
}

List<int>? _byteList(Object? raw) {
  if (raw is Uint8List) return raw;
  if (raw is List &&
      raw.every((item) => item is int && item >= 0 && item < 256)) {
    return raw.cast<int>();
  }
  return null;
}

void _validateCanonicalTransaction(String encoded) {
  Uint8List bytes;
  try {
    bytes = base64Decode(encoded);
  } on FormatException {
    throw const ExternalWalletException('wallet_payload_invalid');
  }
  if (bytes.isEmpty || bytes.length > 1232 || base64Encode(bytes) != encoded) {
    throw const ExternalWalletException('wallet_payload_invalid');
  }
}

Uint8List _decodeBase58(String encoded) {
  if (encoded.isEmpty ||
      !RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$').hasMatch(encoded)) {
    return Uint8List(0);
  }
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  var value = BigInt.zero;
  for (final codeUnit in encoded.codeUnits) {
    final digit = alphabet.indexOf(String.fromCharCode(codeUnit));
    if (digit < 0) return Uint8List(0);
    value = value * BigInt.from(58) + BigInt.from(digit);
  }
  final body = <int>[];
  while (value > BigInt.zero) {
    body.add((value & BigInt.from(255)).toInt());
    value >>= 8;
  }
  final leadingZeros =
      encoded.length - encoded.replaceFirst(RegExp(r'^1+'), '').length;
  return Uint8List.fromList(<int>[
    ...List<int>.filled(leadingZeros, 0),
    ...body.reversed,
  ]);
}
