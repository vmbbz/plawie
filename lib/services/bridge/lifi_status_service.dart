import 'bridge_http_client.dart';
import 'bridge_models.dart';

final class LifiStatusObservation {
  const LifiStatusObservation({
    required this.state,
    required this.providerStatus,
    required this.providerSubstatus,
    required this.destinationTransactionHash,
    required this.actualOutputUnits,
    required this.explorerLinks,
  });

  final BridgeFundingState state;
  final String providerStatus;
  final String? providerSubstatus;
  final String? destinationTransactionHash;
  final String? actualOutputUnits;
  final List<Uri> explorerLinks;
}

final class LifiStatusException implements Exception {
  const LifiStatusException(this.code, {this.retryAfter});

  final String code;
  final Duration? retryAfter;

  @override
  String toString() => 'LifiStatusException: $code';
}

abstract interface class LifiSettlementStatusProvider {
  Future<LifiStatusObservation> status({
    required String sourceTransactionHash,
    required int sourceChainId,
    required String routeTool,
  });
}

final class LifiStatusService implements LifiSettlementStatusProvider {
  LifiStatusService({BridgeHttpTransport? transport})
      : _transport = transport ?? BridgeHttpClient();

  static final Uri _endpoint = Uri.https('li.quest', '/v1/status');
  static const Set<String> _trustedExplorerHosts = <String>{
    'scan.li.fi',
    'etherscan.io',
    'www.etherscan.io',
    'basescan.org',
    'www.basescan.org',
    'explorer.mainnet.chain.robinhood.com',
    'solscan.io',
    'www.solscan.io',
  };

  final BridgeHttpTransport _transport;

  @override
  Future<LifiStatusObservation> status({
    required String sourceTransactionHash,
    required int sourceChainId,
    required String routeTool,
  }) async {
    _requireSourceHash(sourceTransactionHash, sourceChainId);
    final normalizedTool = routeTool.trim();
    if (normalizedTool.isEmpty ||
        normalizedTool.length > 128 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(normalizedTool)) {
      throw const LifiStatusException('invalid_bridge_tool');
    }
    if (!_supportedSourceChain(sourceChainId)) {
      throw const LifiStatusException('unsupported_source_chain');
    }

    final boundedTool =
        RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(normalizedTool)
            ? normalizedTool
            : null;
    late BridgeHttpResponse response;
    try {
      response = await _transport.getJson(
        _endpoint.replace(
          queryParameters: <String, String>{
            'txHash': sourceTransactionHash,
            'fromChain': sourceChainId.toString(),
            'toChain': BridgeConstants.baseChainId.toString(),
            if (boundedTool != null) 'bridge': boundedTool,
          },
        ),
        maxBytes: 256 * 1024,
      );
      // Older receipts stored LI.FI's display label instead of its canonical
      // tool key. Retry the same evidence-bound lookup once without the
      // optional bridge hint when LI.FI explicitly rejects that label.
      if (boundedTool != null && _unknownBridgeTool(response)) {
        response = await _transport.getJson(
          _endpoint.replace(
            queryParameters: <String, String>{
              'txHash': sourceTransactionHash,
              'fromChain': sourceChainId.toString(),
              'toChain': BridgeConstants.baseChainId.toString(),
            },
          ),
          maxBytes: 256 * 1024,
        );
      }
    } on BridgeHttpException catch (error) {
      if (error.code == 'timeout') {
        return const LifiStatusObservation(
          state: BridgeFundingState.sourcePending,
          providerStatus: 'PENDING',
          providerSubstatus: 'TRANSPORT_TIMEOUT',
          destinationTransactionHash: null,
          actualOutputUnits: null,
          explorerLinks: <Uri>[],
        );
      }
      throw LifiStatusException('transport_${error.code}');
    }

    if (response.statusCode == 429) {
      throw LifiStatusException(
        'rate_limited',
        retryAfter: _retryAfter(response.headers['retry-after']),
      );
    }
    if (response.statusCode == 404 &&
        response.json is Map &&
        Map<String, Object?>.from(response.json as Map)['code'] == 1003) {
      return _notFoundObservation();
    }
    if (response.statusCode != 200) {
      throw const LifiStatusException('status_http_error');
    }
    final raw = response.json;
    if (raw is! Map) {
      throw const LifiStatusException('invalid_status_response');
    }
    final json = Map<String, Object?>.from(raw);
    final status = json['status'];
    if (status is! String) {
      throw const LifiStatusException('invalid_status_response');
    }
    final substatusValue = json['substatus'];
    if (substatusValue != null && substatusValue is! String) {
      throw const LifiStatusException('invalid_status_response');
    }
    final substatus = substatusValue as String?;

    if (status == 'NOT_FOUND') {
      if (substatus != null) {
        throw const LifiStatusException('invalid_status_response');
      }
      return _notFoundObservation();
    }

    final state = _mapState(status, substatus);
    final sending = _requiredMap(json['sending']);
    final receiving =
        json['receiving'] == null ? null : _requiredMap(json['receiving']);
    final returnedSourceHash = sending['txHash'];
    final returnedSourceChain = sending['chainId'];
    final destinationHash = receiving?['txHash'];
    final destinationChain = receiving?['chainId'];
    if (returnedSourceHash is! String ||
        !_sameHash(returnedSourceHash, sourceTransactionHash) ||
        returnedSourceChain != sourceChainId) {
      throw const LifiStatusException('status_response_mismatch');
    }
    if (receiving == null) {
      if (state != BridgeFundingState.sourcePending &&
          state != BridgeFundingState.destinationPending &&
          state != BridgeFundingState.failed) {
        throw const LifiStatusException('status_response_mismatch');
      }
    } else if (destinationChain != BridgeConstants.baseChainId ||
        (destinationHash != null &&
            (destinationHash is! String || !_validEvmHash(destinationHash)))) {
      throw const LifiStatusException('status_response_mismatch');
    }
    if ((state == BridgeFundingState.completed ||
            state == BridgeFundingState.partial) &&
        destinationHash is! String) {
      throw const LifiStatusException('status_response_mismatch');
    }
    final amount = receiving?['amount'];
    if (amount != null &&
        (amount is! String || !RegExp(r'^[0-9]+$').hasMatch(amount))) {
      throw const LifiStatusException('invalid_status_response');
    }

    return LifiStatusObservation(
      state: state,
      providerStatus: status,
      providerSubstatus: substatus,
      destinationTransactionHash:
          destinationHash is String ? destinationHash.toLowerCase() : null,
      actualOutputUnits: amount as String?,
      explorerLinks: List<Uri>.unmodifiable(
        _trustedLinks(
          json: json,
          sending: sending,
          receiving: receiving,
          sourceHash: sourceTransactionHash,
          destinationHash: destinationHash is String ? destinationHash : null,
        ),
      ),
    );
  }

  BridgeFundingState _mapState(String status, String? substatus) {
    if (status == 'PENDING' && substatus == 'WAIT_SOURCE_CONFIRMATIONS') {
      return BridgeFundingState.sourcePending;
    }
    if (status == 'PENDING' && substatus == 'WAIT_DESTINATION_TRANSACTION') {
      return BridgeFundingState.destinationPending;
    }
    if (status == 'DONE' && substatus == 'COMPLETED') {
      return BridgeFundingState.completed;
    }
    if (status == 'DONE' && substatus == 'PARTIAL') {
      return BridgeFundingState.partial;
    }
    if (status == 'DONE' && substatus == 'REFUNDED') {
      return BridgeFundingState.refunded;
    }
    if (status == 'FAILED' && substatus != null && substatus.isNotEmpty) {
      return BridgeFundingState.failed;
    }
    throw const LifiStatusException('unsupported_status');
  }

  List<Uri> _trustedLinks({
    required Map<String, Object?> json,
    required Map<String, Object?> sending,
    required Map<String, Object?>? receiving,
    required String sourceHash,
    required String? destinationHash,
  }) {
    final result = <Uri>[];
    _addTrustedTransactionLink(result, sending['txLink'], sourceHash);
    if (receiving != null && destinationHash != null) {
      _addTrustedTransactionLink(result, receiving['txLink'], destinationHash);
    }
    final lifiLink = _trustedUri(json['lifiExplorerLink']);
    if (lifiLink != null && lifiLink.host.toLowerCase() == 'scan.li.fi') {
      result.add(lifiLink);
    }
    return result;
  }

  void _addTrustedTransactionLink(
    List<Uri> result,
    Object? raw,
    String transactionHash,
  ) {
    final uri = _trustedUri(raw);
    if (uri != null &&
        uri.toString().toLowerCase().contains(transactionHash.toLowerCase())) {
      result.add(uri);
    }
  }

  Uri? _trustedUri(Object? raw) {
    if (raw is! String) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        !_trustedExplorerHosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    return uri;
  }

  LifiStatusObservation _notFoundObservation() => const LifiStatusObservation(
        state: BridgeFundingState.sourcePending,
        providerStatus: 'NOT_FOUND',
        providerSubstatus: null,
        destinationTransactionHash: null,
        actualOutputUnits: null,
        explorerLinks: <Uri>[],
      );
}

Map<String, Object?> _requiredMap(Object? value) {
  if (value is! Map) {
    throw const LifiStatusException('invalid_status_response');
  }
  return Map<String, Object?>.from(value);
}

bool _supportedSourceChain(int chainId) =>
    chainId == BridgeConstants.ethereumChainId ||
    chainId == BridgeConstants.baseChainId ||
    chainId == BridgeConstants.robinhoodChainId ||
    chainId == BridgeConstants.solanaChainId;

void _requireSourceHash(String value, int chainId) {
  if (chainId == BridgeConstants.solanaChainId) {
    if (!RegExp(r'^[1-9A-HJ-NP-Za-km-z]{80,90}$').hasMatch(value)) {
      throw const LifiStatusException('invalid_source_transaction_hash');
    }
    return;
  }
  if (!_validEvmHash(value)) {
    throw const LifiStatusException('invalid_source_transaction_hash');
  }
}

bool _validEvmHash(String value) =>
    RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(value);

bool _sameHash(String left, String right) =>
    left.startsWith('0x') || right.startsWith('0x')
        ? left.toLowerCase() == right.toLowerCase()
        : left == right;

Duration _retryAfter(String? raw) {
  final seconds = int.tryParse(raw ?? '') ?? 2;
  return Duration(seconds: seconds.clamp(1, 60));
}

bool _unknownBridgeTool(BridgeHttpResponse response) {
  if (response.statusCode != 400 || response.json is! Map) return false;
  final json = Map<String, Object?>.from(response.json as Map);
  return json['code'] == 1011;
}
