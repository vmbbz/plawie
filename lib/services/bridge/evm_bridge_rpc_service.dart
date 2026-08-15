import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'bridge_models.dart';

const evmSourceRpcUrls = <int, String>{
  1: 'https://ethereum-rpc.publicnode.com',
  8453: 'https://mainnet.base.org',
  4663: 'https://rpc.mainnet.chain.robinhood.com',
};

enum EvmReceiptStatus { pending, succeeded, reverted }

final class EvmReceiptObservation {
  const EvmReceiptObservation({
    required this.status,
    required this.transactionHash,
    this.blockNumber,
  });

  final EvmReceiptStatus status;
  final String transactionHash;
  final BigInt? blockNumber;
}

final class EvmTransactionObservation {
  const EvmTransactionObservation({
    required this.chainId,
    required this.transactionHash,
    required this.from,
    required this.to,
    required this.valueHex,
    required this.dataHex,
  });

  final int chainId;
  final String transactionHash;
  final String from;
  final String to;
  final String valueHex;
  final String dataHex;
}

final class EvmRpcException implements Exception {
  const EvmRpcException(this.code, {this.retryAfter});

  final String code;
  final Duration? retryAfter;

  @override
  String toString() => 'EvmRpcException: $code';
}

final class EvmRpcRawResponse {
  const EvmRpcRawResponse({
    required this.statusCode,
    required this.headers,
    required this.json,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Object? json;
}

abstract interface class EvmRpcTransport {
  Future<EvmRpcRawResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required int maxBytes,
  });
}

abstract interface class EvmBridgeRpc {
  Future<BigInt> allowance({
    required int chainId,
    required String tokenAddress,
    required String owner,
    required String spender,
  });

  String encodeExactApproval(String spender, BigInt amount);

  String encodeExactTransfer(String destination, BigInt amount);

  Future<BigInt> estimateGas(EvmBridgeExecutionPayload payload);

  Future<EvmReceiptObservation> waitForReceipt({
    required int chainId,
    required String transactionHash,
  });

  Future<EvmTransactionObservation?> transactionByHash({
    required int chainId,
    required String transactionHash,
  });
}

final class HttpEvmRpcTransport implements EvmRpcTransport {
  HttpEvmRpcTransport({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  @override
  Future<EvmRpcRawResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required int maxBytes,
  }) async {
    if (!_isShippedRpcUri(uri)) {
      throw const EvmRpcException('rpc_host_not_allowed');
    }
    if (maxBytes < 1 || maxBytes > 64 * 1024) {
      throw const EvmRpcException('invalid_response_limit');
    }
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json; charset=utf-8'
      ..body = jsonEncode(body);

    try {
      final streamed = await _client.send(request).timeout(timeout);
      if (streamed.isRedirect ||
          (streamed.statusCode >= 300 && streamed.statusCode < 400)) {
        throw const EvmRpcException('redirect_rejected');
      }
      final declaredLength = streamed.contentLength;
      if (declaredLength != null && declaredLength > maxBytes) {
        throw const EvmRpcException('response_too_large');
      }
      final bytes = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in streamed.stream.timeout(timeout)) {
        total += chunk.length;
        if (total > maxBytes) {
          throw const EvmRpcException('response_too_large');
        }
        bytes.add(chunk);
      }
      final headers = <String, String>{
        for (final entry in streamed.headers.entries)
          entry.key.toLowerCase(): entry.value,
      };
      if (streamed.statusCode == 429) {
        return EvmRpcRawResponse(
          statusCode: streamed.statusCode,
          headers: Map<String, String>.unmodifiable(headers),
          json: const <String, Object?>{},
        );
      }
      final contentType = headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.contains('application/json') &&
          !contentType.contains('+json')) {
        throw const EvmRpcException('invalid_content_type');
      }
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      } on FormatException {
        throw const EvmRpcException('invalid_json');
      }
      return EvmRpcRawResponse(
        statusCode: streamed.statusCode,
        headers: Map<String, String>.unmodifiable(headers),
        json: decoded,
      );
    } on EvmRpcException {
      rethrow;
    } on TimeoutException {
      throw const EvmRpcException('timeout');
    } catch (_) {
      throw const EvmRpcException('transport_failed');
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

final class EvmBridgeRpcService implements EvmBridgeRpc {
  EvmBridgeRpcService({
    EvmRpcTransport? transport,
    Map<int, String> rpcUrls = evmSourceRpcUrls,
    int Function()? requestIdFactory,
  })  : _transport = transport ?? HttpEvmRpcTransport(),
        _requestIdFactory = requestIdFactory ?? _randomRequestId,
        _rpcUrls = Map<int, String>.unmodifiable(rpcUrls) {
    if (!_sameRpcPolicy(rpcUrls, evmSourceRpcUrls)) {
      throw const EvmRpcException('rpc_policy_mismatch');
    }
  }

  static final BigInt _maximumUint256 = (BigInt.one << 256) - BigInt.one;
  static final BigInt _minimumGas = BigInt.from(21000);
  static final BigInt _maximumGas = BigInt.from(5000000);

  final EvmRpcTransport _transport;
  final int Function() _requestIdFactory;
  final Map<int, String> _rpcUrls;

  @override
  Future<BigInt> allowance({
    required int chainId,
    required String tokenAddress,
    required String owner,
    required String spender,
  }) async {
    _requireAddress(tokenAddress);
    _requireAddress(owner);
    _requireAddress(spender);
    final result = await _rpc(
      chainId,
      'eth_call',
      <Object?>[
        <String, Object?>{
          'to': tokenAddress,
          'data': '0xdd62ed3e${_addressWord(owner)}${_addressWord(spender)}',
        },
        'latest',
      ],
    );
    if (result is! String || !RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(result)) {
      throw const EvmRpcException('invalid_eth_call_word');
    }
    return BigInt.parse(result.substring(2), radix: 16);
  }

  @override
  String encodeExactApproval(String spender, BigInt amount) {
    _requireAddress(spender);
    _requireUint256(amount);
    if (amount == _maximumUint256) {
      throw const EvmRpcException('maximum_allowance_rejected');
    }
    return '0x095ea7b3${_addressWord(spender)}${_uint256Word(amount)}';
  }

  @override
  String encodeExactTransfer(String destination, BigInt amount) {
    _requireAddress(destination);
    _requireUint256(amount);
    return '0xa9059cbb${_addressWord(destination)}${_uint256Word(amount)}';
  }

  @override
  Future<BigInt> estimateGas(EvmBridgeExecutionPayload payload) async {
    _requireChain(payload.chainId);
    _requireAddress(payload.from);
    _requireAddress(payload.to);
    final value = _parseQuantity(payload.valueHex, 'invalid_transaction_value');
    _requireData(payload.dataHex);
    final result = await _rpc(
      payload.chainId,
      'eth_estimateGas',
      <Object?>[
        <String, Object?>{
          'from': payload.from,
          'to': payload.to,
          'value': _quantity(value),
          'data': payload.dataHex.toLowerCase(),
        },
      ],
    );
    final estimate = _parseRpcQuantity(result, 'invalid_gas_estimate');
    if (estimate < _minimumGas || estimate > _maximumGas) {
      throw const EvmRpcException('gas_estimate_out_of_bounds');
    }
    return estimate;
  }

  @override
  Future<EvmReceiptObservation> waitForReceipt({
    required int chainId,
    required String transactionHash,
  }) async {
    _requireTransactionHash(transactionHash);
    final result = await _rpc(
      chainId,
      'eth_getTransactionReceipt',
      <Object?>[transactionHash.toLowerCase()],
    );
    if (result == null) {
      return EvmReceiptObservation(
        status: EvmReceiptStatus.pending,
        transactionHash: transactionHash.toLowerCase(),
      );
    }
    if (result is! Map) {
      throw const EvmRpcException('invalid_receipt');
    }
    final receipt = Map<String, Object?>.from(result);
    final returnedHash = receipt['transactionHash'];
    if (returnedHash is! String ||
        returnedHash.toLowerCase() != transactionHash.toLowerCase()) {
      throw const EvmRpcException('receipt_hash_mismatch');
    }
    final status = switch (receipt['status']) {
      '0x1' => EvmReceiptStatus.succeeded,
      '0x0' => EvmReceiptStatus.reverted,
      _ => throw const EvmRpcException('invalid_receipt_status'),
    };
    final blockNumber = _parseRpcQuantity(
      receipt['blockNumber'],
      'invalid_receipt_block',
    );
    if (blockNumber <= BigInt.zero) {
      throw const EvmRpcException('invalid_receipt_block');
    }
    return EvmReceiptObservation(
      status: status,
      transactionHash: transactionHash.toLowerCase(),
      blockNumber: blockNumber,
    );
  }

  @override
  Future<EvmTransactionObservation?> transactionByHash({
    required int chainId,
    required String transactionHash,
  }) async {
    _requireTransactionHash(transactionHash);
    final rpcChain = _parseRpcQuantity(
      await _rpc(chainId, 'eth_chainId', const <Object?>[]),
      'invalid_rpc_chain',
    );
    if (rpcChain != BigInt.from(chainId)) {
      throw const EvmRpcException('rpc_chain_mismatch');
    }
    final result = await _rpc(
      chainId,
      'eth_getTransactionByHash',
      <Object?>[transactionHash.toLowerCase()],
    );
    if (result == null) return null;
    if (result is! Map) {
      throw const EvmRpcException('invalid_transaction');
    }
    final transaction = Map<String, Object?>.from(result);
    final hash = transaction['hash'];
    if (hash is! String ||
        hash.toLowerCase() != transactionHash.toLowerCase()) {
      throw const EvmRpcException('transaction_hash_mismatch');
    }
    final from = transaction['from'];
    final to = transaction['to'];
    final value = transaction['value'];
    final input = transaction['input'];
    if (from is! String ||
        to is! String ||
        value is! String ||
        input is! String) {
      throw const EvmRpcException('invalid_transaction');
    }
    _requireAddress(from);
    _requireAddress(to);
    final parsedValue = _parseQuantity(value, 'invalid_transaction_value');
    _requireData(input);
    final returnedChain = transaction['chainId'];
    if (returnedChain != null &&
        _parseRpcQuantity(returnedChain, 'invalid_transaction_chain') !=
            BigInt.from(chainId)) {
      throw const EvmRpcException('transaction_chain_mismatch');
    }
    return EvmTransactionObservation(
      chainId: chainId,
      transactionHash: hash.toLowerCase(),
      from: from.toLowerCase(),
      to: to.toLowerCase(),
      valueHex: _quantity(parsedValue),
      dataHex: input.toLowerCase(),
    );
  }

  Future<Object?> _rpc(
    int chainId,
    String method,
    List<Object?> params,
  ) async {
    final uri = _requireChain(chainId);
    final id = _requestIdFactory();
    if (id < 1 || id > 0x7fffffff) {
      throw const EvmRpcException('invalid_request_id');
    }
    final response = await _transport.postJson(
      uri,
      <String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      },
      maxBytes: 64 * 1024,
    );
    if (response.statusCode == 429) {
      throw EvmRpcException(
        'rate_limited',
        retryAfter: _retryAfter(response.headers['retry-after']),
      );
    }
    if (response.statusCode != 200) {
      throw const EvmRpcException('rpc_http_error');
    }
    final raw = response.json;
    if (raw is! Map) throw const EvmRpcException('invalid_rpc_response');
    final json = Map<String, Object?>.from(raw);
    if (json['jsonrpc'] != '2.0' || json['id'] != id) {
      throw const EvmRpcException('rpc_response_mismatch');
    }
    if (json['error'] != null) {
      throw const EvmRpcException('rpc_error');
    }
    if (!json.containsKey('result')) {
      throw const EvmRpcException('rpc_result_missing');
    }
    return json['result'];
  }

  Uri _requireChain(int chainId) {
    final raw = _rpcUrls[chainId];
    if (raw == null) throw const EvmRpcException('unsupported_chain');
    final uri = Uri.parse(raw);
    if (!_isShippedRpcUri(uri)) {
      throw const EvmRpcException('rpc_host_not_allowed');
    }
    return uri;
  }
}

bool _sameRpcPolicy(Map<int, String> left, Map<int, String> right) {
  if (left.length != right.length) return false;
  for (final entry in right.entries) {
    if (left[entry.key] != entry.value) return false;
  }
  return true;
}

bool _isShippedRpcUri(Uri uri) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    (!uri.hasPort || uri.port == 443) &&
    evmSourceRpcUrls.values.any((raw) => Uri.parse(raw) == uri);

void _requireAddress(String value) {
  if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value)) {
    throw const EvmRpcException('invalid_evm_address');
  }
}

void _requireTransactionHash(String value) {
  if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(value)) {
    throw const EvmRpcException('invalid_transaction_hash');
  }
}

void _requireUint256(BigInt value) {
  if (value < BigInt.zero || value > EvmBridgeRpcService._maximumUint256) {
    throw const EvmRpcException('invalid_uint256');
  }
}

String _addressWord(String value) =>
    '000000000000000000000000${value.substring(2).toLowerCase()}';

String _uint256Word(BigInt value) => value.toRadixString(16).padLeft(64, '0');

void _requireData(String value) {
  if (!RegExp(r'^0x(?:[0-9a-fA-F]{2})*$').hasMatch(value) ||
      value.length > 2 + 128 * 1024) {
    throw const EvmRpcException('invalid_transaction_data');
  }
}

BigInt _parseQuantity(String value, String code) {
  if (!RegExp(r'^0x(?:0|[1-9a-fA-F][0-9a-fA-F]*)$').hasMatch(value)) {
    throw EvmRpcException(code);
  }
  return BigInt.parse(value.substring(2), radix: 16);
}

BigInt _parseRpcQuantity(Object? value, String code) {
  if (value is! String ||
      !RegExp(r'^0x(?:0|[1-9a-fA-F][0-9a-fA-F]*)$').hasMatch(value) ||
      value.length > 66) {
    throw EvmRpcException(code);
  }
  return BigInt.parse(value.substring(2), radix: 16);
}

String _quantity(BigInt value) => '0x${value.toRadixString(16)}';

Duration _retryAfter(String? raw) {
  final seconds = int.tryParse(raw ?? '') ?? 2;
  return Duration(seconds: seconds.clamp(1, 60));
}

int _randomRequestId() => Random.secure().nextInt(0x7ffffffe) + 1;
