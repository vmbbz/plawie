import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'solana_transaction_envelope.dart';

final Uri solanaMainnetRpcUri =
    Uri.parse('https://api.mainnet-beta.solana.com');

enum SolanaSignatureStatus {
  notFound,
  processed,
  confirmed,
  finalized,
  failed,
}

final class SolanaSignatureObservation {
  const SolanaSignatureObservation({
    required this.signature,
    required this.status,
    this.slot,
  });

  final String signature;
  final SolanaSignatureStatus status;
  final int? slot;
}

final class SolanaAddressSignature {
  const SolanaAddressSignature({
    required this.signature,
    required this.slot,
    required this.blockTime,
    required this.failed,
  });

  final String signature;
  final int slot;
  final DateTime? blockTime;
  final bool failed;
}

final class SolanaSignatureHistory {
  const SolanaSignatureHistory({
    required this.entries,
    required this.complete,
    required this.truncated,
  });

  final List<SolanaAddressSignature> entries;
  final bool complete;
  final bool truncated;
}

final class SolanaFetchedTransaction {
  const SolanaFetchedTransaction({
    required this.signature,
    required this.transactionBytes,
    required this.slot,
    required this.failed,
  });

  final String signature;
  final Uint8List transactionBytes;
  final int slot;
  final bool failed;
}

final class SolanaRpcException implements Exception {
  const SolanaRpcException(
    this.code, {
    this.outcomeUnknown = false,
  });

  final String code;
  final bool outcomeUnknown;

  @override
  String toString() => 'SolanaRpcException: $code';
}

final class SolanaRpcRawResponse {
  const SolanaRpcRawResponse({
    required this.statusCode,
    required this.headers,
    required this.json,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Object? json;
}

abstract interface class SolanaRpcTransport {
  Future<SolanaRpcRawResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required int maxBytes,
  });
}

abstract interface class SolanaRpcBroadcaster {
  Future<String> sendTransaction(Uint8List signedTransaction);

  Future<SolanaSignatureObservation> signatureStatus(String signature);

  Future<SolanaSignatureHistory> signaturesForAddress(
    String address, {
    required DateTime since,
    int limit = 200,
  });

  Future<SolanaFetchedTransaction?> transaction(String signature);

  Future<bool> isBlockhashValid(String blockhash);
}

final class HttpSolanaRpcTransport implements SolanaRpcTransport {
  HttpSolanaRpcTransport({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  @override
  Future<SolanaRpcRawResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required int maxBytes,
  }) async {
    if (uri != solanaMainnetRpcUri ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      throw const SolanaRpcException('rpc_host_not_allowed');
    }
    if (maxBytes < 1 || maxBytes > 64 * 1024) {
      throw const SolanaRpcException('invalid_response_limit');
    }
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..persistentConnection = false
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json; charset=utf-8'
      ..body = jsonEncode(body);
    try {
      final response = await _client.send(request).timeout(timeout);
      if (response.isRedirect ||
          (response.statusCode >= 300 && response.statusCode < 400)) {
        throw const SolanaRpcException('redirect_rejected');
      }
      final declaredLength = response.contentLength;
      if (declaredLength != null && declaredLength > maxBytes) {
        throw const SolanaRpcException('response_too_large');
      }
      final bytes = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in response.stream.timeout(timeout)) {
        total += chunk.length;
        if (total > maxBytes) {
          throw const SolanaRpcException('response_too_large');
        }
        bytes.add(chunk);
      }
      final headers = <String, String>{
        for (final entry in response.headers.entries)
          entry.key.toLowerCase(): entry.value,
      };
      final contentType = headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.contains('application/json') &&
          !contentType.contains('+json')) {
        throw const SolanaRpcException('invalid_content_type');
      }
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      } on FormatException {
        throw const SolanaRpcException('invalid_json');
      }
      return SolanaRpcRawResponse(
        statusCode: response.statusCode,
        headers: Map<String, String>.unmodifiable(headers),
        json: decoded,
      );
    } on SolanaRpcException {
      rethrow;
    } on TimeoutException {
      throw const SolanaRpcException('timeout', outcomeUnknown: true);
    } catch (_) {
      throw const SolanaRpcException(
        'transport_failed',
        outcomeUnknown: true,
      );
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

final class SolanaRpcBroadcasterService implements SolanaRpcBroadcaster {
  SolanaRpcBroadcasterService({
    SolanaRpcTransport? transport,
    int Function()? requestIdFactory,
    SolanaTransactionEnvelope envelope = const SolanaTransactionEnvelope(),
  })  : _transport = transport ?? HttpSolanaRpcTransport(),
        _requestIdFactory = requestIdFactory ?? _randomRequestId,
        _envelope = envelope;

  final SolanaRpcTransport _transport;
  final int Function() _requestIdFactory;
  final SolanaTransactionEnvelope _envelope;

  @override
  Future<String> sendTransaction(Uint8List signedTransaction) async {
    final expectedSignature = _firstSignature(signedTransaction);
    final result = await _rpc(
      'sendTransaction',
      <Object?>[
        base64Encode(signedTransaction),
        <String, Object?>{
          'encoding': 'base64',
          'skipPreflight': false,
          'preflightCommitment': 'confirmed',
          'maxRetries': 0,
        },
      ],
    );
    if (result is! String || result != expectedSignature) {
      throw const SolanaRpcException('signature_mismatch');
    }
    return result;
  }

  @override
  Future<SolanaSignatureObservation> signatureStatus(String signature) async {
    _requireSignature(signature);
    final result = await _rpc(
      'getSignatureStatuses',
      <Object?>[
        <String>[signature],
        <String, Object?>{'searchTransactionHistory': true},
      ],
    );
    if (result is! Map) {
      throw const SolanaRpcException('invalid_signature_status');
    }
    final map = Map<String, Object?>.from(result);
    final context = map['context'];
    final values = map['value'];
    if (context is! Map || values is! List || values.length != 1) {
      throw const SolanaRpcException('invalid_signature_status');
    }
    final slot = Map<String, Object?>.from(context)['slot'];
    if (slot is! int || slot < 0) {
      throw const SolanaRpcException('invalid_signature_status');
    }
    final raw = values.single;
    if (raw == null) {
      return SolanaSignatureObservation(
        signature: signature,
        status: SolanaSignatureStatus.notFound,
        slot: slot,
      );
    }
    if (raw is! Map) {
      throw const SolanaRpcException('invalid_signature_status');
    }
    final status = Map<String, Object?>.from(raw);
    if (status['err'] != null) {
      return SolanaSignatureObservation(
        signature: signature,
        status: SolanaSignatureStatus.failed,
        slot: slot,
      );
    }
    final mapped = switch (status['confirmationStatus']) {
      'processed' => SolanaSignatureStatus.processed,
      'confirmed' => SolanaSignatureStatus.confirmed,
      'finalized' => SolanaSignatureStatus.finalized,
      _ => throw const SolanaRpcException('invalid_signature_status'),
    };
    return SolanaSignatureObservation(
      signature: signature,
      status: mapped,
      slot: slot,
    );
  }

  @override
  Future<SolanaSignatureHistory> signaturesForAddress(
    String address, {
    required DateTime since,
    int limit = 200,
  }) async {
    _requirePublicKey(address);
    if (limit < 1 || limit > 200) {
      throw const SolanaRpcException('invalid_history_limit');
    }
    final result = await _rpc(
      'getSignaturesForAddress',
      <Object?>[
        address,
        <String, Object?>{
          'limit': limit,
          'commitment': 'confirmed',
        },
      ],
    );
    if (result is! List || result.length > limit) {
      throw const SolanaRpcException('invalid_signature_history');
    }
    final all = <SolanaAddressSignature>[];
    for (final raw in result) {
      if (raw is! Map) {
        throw const SolanaRpcException('invalid_signature_history');
      }
      final map = Map<String, Object?>.from(raw);
      final signature = map['signature'];
      final slot = map['slot'];
      final blockTime = map['blockTime'];
      if (signature is! String ||
          slot is! int ||
          slot < 0 ||
          (blockTime != null && (blockTime is! int || blockTime < 0))) {
        throw const SolanaRpcException('invalid_signature_history');
      }
      _requireSignature(signature);
      all.add(
        SolanaAddressSignature(
          signature: signature,
          slot: slot,
          blockTime: blockTime == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  (blockTime as int) * 1000,
                  isUtc: true,
                ),
          failed: map['err'] != null,
        ),
      );
    }
    final cutoff = since.toUtc();
    final complete = all.length < limit ||
        (all.isNotEmpty &&
            all.last.blockTime != null &&
            all.last.blockTime!.isBefore(cutoff));
    return SolanaSignatureHistory(
      entries: List<SolanaAddressSignature>.unmodifiable(
        all.where(
          (entry) =>
              entry.blockTime == null || !entry.blockTime!.isBefore(cutoff),
        ),
      ),
      complete: complete,
      truncated: !complete,
    );
  }

  @override
  Future<SolanaFetchedTransaction?> transaction(String signature) async {
    _requireSignature(signature);
    final result = await _rpc(
      'getTransaction',
      <Object?>[
        signature,
        <String, Object?>{
          'encoding': 'base64',
          'commitment': 'confirmed',
          'maxSupportedTransactionVersion': 0,
        },
      ],
    );
    if (result == null) return null;
    if (result is! Map) {
      throw const SolanaRpcException('invalid_transaction');
    }
    final map = Map<String, Object?>.from(result);
    final slot = map['slot'];
    final transaction = map['transaction'];
    final meta = map['meta'];
    if (slot is! int ||
        slot < 0 ||
        transaction is! List ||
        transaction.length != 2 ||
        transaction[0] is! String ||
        transaction[1] != 'base64' ||
        meta is! Map) {
      throw const SolanaRpcException('invalid_transaction');
    }
    late Uint8List bytes;
    try {
      final decoded = base64Decode(transaction[0] as String);
      if (decoded.isEmpty ||
          decoded.length > SolanaTransactionEnvelope.maximumTransactionBytes ||
          base64Encode(decoded) != transaction[0]) {
        throw const SolanaRpcException('invalid_transaction');
      }
      bytes = Uint8List.fromList(decoded);
    } on FormatException {
      throw const SolanaRpcException('invalid_transaction');
    }
    return SolanaFetchedTransaction(
      signature: signature,
      transactionBytes: bytes,
      slot: slot,
      failed: Map<String, Object?>.from(meta)['err'] != null,
    );
  }

  @override
  Future<bool> isBlockhashValid(String blockhash) async {
    _requireBlockhash(blockhash);
    final result = await _rpc(
      'isBlockhashValid',
      <Object?>[
        blockhash,
        <String, Object?>{'commitment': 'confirmed'},
      ],
    );
    if (result is! Map) {
      throw const SolanaRpcException('invalid_blockhash_status');
    }
    final map = Map<String, Object?>.from(result);
    final context = map['context'];
    final value = map['value'];
    if (context is! Map ||
        Map<String, Object?>.from(context)['slot'] is! int ||
        value is! bool) {
      throw const SolanaRpcException('invalid_blockhash_status');
    }
    return value;
  }

  Future<Object?> _rpc(String method, List<Object?> params) async {
    final id = _requestIdFactory();
    if (id < 1 || id > 0x7fffffff) {
      throw const SolanaRpcException('invalid_request_id');
    }
    final response = await _transport.postJson(
      solanaMainnetRpcUri,
      <String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      },
      maxBytes: 64 * 1024,
    );
    if (response.statusCode != 200) {
      throw const SolanaRpcException('rpc_http_error');
    }
    final raw = response.json;
    if (raw is! Map) {
      throw const SolanaRpcException('invalid_rpc_response');
    }
    final json = Map<String, Object?>.from(raw);
    if (json['jsonrpc'] != '2.0' || json['id'] != id) {
      throw const SolanaRpcException('rpc_response_mismatch');
    }
    if (json['error'] != null) {
      throw const SolanaRpcException('rpc_error');
    }
    if (!json.containsKey('result')) {
      throw const SolanaRpcException('rpc_result_missing');
    }
    return json['result'];
  }

  String _firstSignature(Uint8List signedTransaction) {
    if (signedTransaction.isEmpty ||
        signedTransaction.length >
            SolanaTransactionEnvelope.maximumTransactionBytes) {
      throw const SolanaRpcException('invalid_signed_transaction');
    }
    var offset = 0;
    var count = 0;
    var shift = 0;
    var encodedLength = 0;
    while (true) {
      if (offset >= signedTransaction.length || encodedLength == 3) {
        throw const SolanaRpcException('invalid_signed_transaction');
      }
      final current = signedTransaction[offset++];
      final payload = current & 0x7f;
      if (shift == 14 && payload > 3) {
        throw const SolanaRpcException('invalid_signed_transaction');
      }
      count |= payload << shift;
      encodedLength += 1;
      if ((current & 0x80) == 0) {
        if (encodedLength > 1 && payload == 0) {
          throw const SolanaRpcException('invalid_signed_transaction');
        }
        break;
      }
      shift += 7;
    }
    if (count < 1 || offset + count * 64 >= signedTransaction.length) {
      throw const SolanaRpcException('invalid_signed_transaction');
    }
    final signature = signedTransaction.sublist(offset, offset + 64);
    if (signature.every((byte) => byte == 0)) {
      throw const SolanaRpcException('invalid_signed_transaction');
    }
    return _envelope.base58Encode(signature);
  }

  void _requireSignature(String signature) {
    try {
      _envelope.base58Decode(signature, expectedLength: 64);
    } catch (_) {
      throw const SolanaRpcException('invalid_signature');
    }
  }

  void _requirePublicKey(String address) {
    try {
      _envelope.base58Decode(address, expectedLength: 32);
    } catch (_) {
      throw const SolanaRpcException('invalid_public_key');
    }
  }

  void _requireBlockhash(String blockhash) {
    try {
      _envelope.base58Decode(blockhash, expectedLength: 32);
    } catch (_) {
      throw const SolanaRpcException('invalid_blockhash');
    }
  }
}

int _randomRequestId() => Random.secure().nextInt(0x7ffffffe) + 1;
