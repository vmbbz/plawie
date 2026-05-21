import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../constants.dart';
import '../constants/openclaw_paths.dart';
import '../models/node_frame.dart';
import '../models/node_state.dart';
import 'native_bridge.dart';
import 'device_identity.dart';
import 'node_ws_service.dart';
import 'preferences_service.dart';
import 'openclaw_service.dart';

class NodeService {
  static final NodeService _instance = NodeService._internal();
  factory NodeService() => _instance;
  NodeService._internal() {
    _ws.onReconnectReady = _handleSocketReconnectReady;
  }

  final DeviceIdentity _identity = DeviceIdentity.node;
  final NodeWsService _ws = NodeWsService();
  final _stateController = StreamController<NodeState>.broadcast();
  StreamSubscription? _frameSubscription;
  StreamSubscription? _pairingSubscription;
  StreamSubscription? _warmingUpSubscription;
  bool _pairingResolveAttempted = false;
  bool _connectInFlight = false;
  bool _pendingReconnectHandshake = false;
  int _preferredConnectProtocol = AppConstants.wsProtocolMaxVersion;
  DateTime? _pairingRetryNotBefore;
  int _pairingApprovalFailureCount = 0;

  NodeState _state = const NodeState();
  final Map<String, Future<NodeFrame> Function(String, Map<String, dynamic>)>
      _capabilityHandlers = {};
  String? _gatewayAuthToken;
  Completer<String?>? _challengeCompleter;
  String? _cachedChallengeNonce;
  DateTime? _cachedChallengeReceivedAt;
  static const Duration _challengeNonceTtl = Duration(seconds: 10);
  static final _uuidPattern =
      RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$');

  Stream<NodeState> get stateStream => _stateController.stream;
  NodeState get state => _state;
  bool get isConnectionStale => _ws.isStale;

  void clearCachedToken() => _gatewayAuthToken = null;

  void _updateState(NodeState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  void log(String message) {
    debugPrint(message); // logcat visibility

    final logs = [..._state.logs, message];
    if (logs.length > 500) {
      logs.removeRange(0, logs.length - 500);
    }
    _updateState(_state.copyWith(logs: logs));
  }

  void registerCapability(
      String name,
      List<String> commands,
      Future<NodeFrame> Function(String command, Map<String, dynamic> params)
          handler) {
    for (final cmd in commands) {
      _capabilityHandlers[cmd] = handler;
    }
  }

  Future<void> init() async {
    await _identity.init();
    final prefs = PreferencesService();
    await prefs.init();
    // Reset pairing state on each fresh init — the singleton persists across
    // gateway restarts and a stale _pairingResolveAttempted=true would silently
    // block all subsequent connect() calls.
    _pairingResolveAttempted = false;
    final deviceId = _identity.deviceId ?? '';
    if (prefs.nodeIdentityDeviceId != deviceId) {
      prefs.nodeDeviceToken = null;
      prefs.nodeIdentityDeviceId = deviceId;
    }
    _updateState(_state.copyWith(deviceId: deviceId));
    final displayId = deviceId.length > 8
        ? '${deviceId.substring(0, 4)}...${deviceId.substring(deviceId.length - 4)}'
        : (deviceId.isNotEmpty ? deviceId : 'ANONYMOUS');

    log('');
    log('  🦞 LOBSTER-$displayId');
    log('  =====================');
    log('');

    if (deviceId.isEmpty) {
      log('[NODE] Warning: Device identity not initialized');
    }

    // ── Network Change Resilience ──
    NativeBridge.onNetworkChanged.listen((isConnected) {
      if (isConnected) {
        log('[NODE] Network restored. Checking connection...');
        if (_state.status == NodeStatus.disconnected ||
            _state.status == NodeStatus.error) {
          log('[NODE] Triggering proactive reconnect...');
          connect();
        }
      } else {
        log('[NODE] Network lost.');
        if (_state.status == NodeStatus.paired ||
            _state.status == NodeStatus.connecting) {
          _updateState(_state.copyWith(status: NodeStatus.disconnected));
        }
      }
    });
  }

  Future<void> connect({String? host, int? port}) async {
    if (_state.status == NodeStatus.paired && _ws.isConnected) {
      return;
    }
    if (_connectInFlight) {
      log('[NODE] Connect already in progress — skipping duplicate request');
      return;
    }
    if (_pairingResolveAttempted) {
      log('[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)');
      return;
    }
    final retryAt = _pairingRetryNotBefore;
    if (retryAt != null) {
      final now = DateTime.now();
      if (now.isBefore(retryAt)) {
        final waitSeconds = retryAt.difference(now).inSeconds;
        log('[NODE] Pairing approval backoff active — retry in ${waitSeconds}s');
        return;
      }
      _pairingRetryNotBefore = null;
    }
    _connectInFlight = true;
    try {
      // STRONGER guard: wait for bootstrap OR gateway startup.
      // We MUST allow the node to connect while bootstrap is still in progress
      // so that the Gateway generates a pairing request for _approveLocalNodeIfNeeded to find.
      while (!await NativeBridge.isBootstrapComplete() &&
          !await NativeBridge.isGatewayRunning()) {
        log('[NODE] Waiting for Gateway to start...');
        await Future.delayed(const Duration(seconds: 2));
      }

      final prefs = PreferencesService();
      await prefs.init();

      final targetHost =
          host ?? prefs.nodeGatewayHost ?? AppConstants.gatewayHost;
      final targetPort =
          port ?? prefs.nodeGatewayPort ?? AppConstants.gatewayPort;

      _updateState(_state.copyWith(
        status: NodeStatus.connecting,
        clearError: true,
        gatewayHost: targetHost,
        gatewayPort: targetPort,
      ));
      log('[NODE] Connecting to $targetHost:$targetPort...');

      _attachWsListeners();

      _challengeCompleter = null;
      _challengeCompleter = Completer<String?>();
      await _ws.connect(targetHost, targetPort);
      log('[NODE] WebSocket connected, awaiting challenge...');

      // Latest gateways require a fresh challenge nonce for node connects.
      // Never send a no-nonce connect frame; it is rejected with 1008.
      await _sendConnectWithFreshNonce(const Duration(seconds: 6));
    } catch (e) {
      _updateState(_state.copyWith(
        status: NodeStatus.error,
        errorMessage: 'Connection failed: $e',
      ));
      log('[NODE] Connection failed: $e');
    } finally {
      _connectInFlight = false;
      _drainQueuedReconnectHandshake();
    }
  }

  void _attachWsListeners() {
    _frameSubscription?.cancel();
    _frameSubscription = _ws.frameStream.listen(_onFrame);
    _pairingSubscription?.cancel();
    _pairingSubscription = _ws.pairingRequiredStream.listen((requestId) {
      // One-shot: cancel immediately so subsequent 1008 closes on stray
      // reconnect attempts don't trigger a second concurrent approval flow.
      _pairingSubscription?.cancel();
      _pairingSubscription = null;
      _handleNodePairingRequired(requestId);
    });
    _warmingUpSubscription?.cancel();
    _warmingUpSubscription = _ws.warmingUpStream.listen((_) {
      log('[NODE] Gateway is warming up. Entering grace period...');
      _updateState(_state.copyWith(status: NodeStatus.warmingUp));
    });
  }

  Future<String> _awaitChallengeNonce(Duration timeout) async {
    final cachedNonce = _consumeCachedChallengeNonce();
    if (cachedNonce.isNotEmpty) return cachedNonce;

    final completer = _challengeCompleter;
    if (completer == null) return '';
    try {
      final nonce = await completer.future.timeout(timeout) ?? '';
      if (nonce.isNotEmpty) return nonce;
      return _consumeCachedChallengeNonce();
    } catch (_) {
      return _consumeCachedChallengeNonce();
    } finally {
      _challengeCompleter = null;
    }
  }

  String _consumeCachedChallengeNonce() {
    final nonce = _cachedChallengeNonce;
    final receivedAt = _cachedChallengeReceivedAt;
    if (nonce == null || nonce.isEmpty || receivedAt == null) {
      _cachedChallengeNonce = null;
      _cachedChallengeReceivedAt = null;
      return '';
    }
    final fresh = DateTime.now().difference(receivedAt) <= _challengeNonceTtl;
    _cachedChallengeNonce = null;
    _cachedChallengeReceivedAt = null;
    return fresh ? nonce : '';
  }

  Future<bool> _sendConnectWithFreshNonce(Duration timeout) async {
    final challengeNonce = await _awaitChallengeNonce(timeout);
    if (challengeNonce.isEmpty) {
      log('[NODE] Challenge nonce not received; reopening socket before secure connect.');
      await _ws.forceReconnect(reason: 'missing-connect-challenge');
      return false;
    }
    await _sendConnect(challengeNonce);
    return true;
  }

  Future<void> _handleSocketReconnectReady() async {
    if (_state.status == NodeStatus.disabled || _pairingResolveAttempted) {
      return;
    }
    if (_connectInFlight) {
      _pendingReconnectHandshake = true;
      return;
    }

    final retryAt = _pairingRetryNotBefore;
    if (retryAt != null && DateTime.now().isBefore(retryAt)) return;

    _connectInFlight = true;
    try {
      _updateState(_state.copyWith(status: NodeStatus.connecting));
      log('[NODE] WebSocket reconnected, completing handshake...');
      _challengeCompleter = null;
      _challengeCompleter = Completer<String?>();
      await _sendConnectWithFreshNonce(const Duration(seconds: 6));
    } catch (e) {
      _updateState(_state.copyWith(
        status: NodeStatus.error,
        errorMessage: 'Reconnect handshake failed: $e',
      ));
      log('[NODE] Reconnect handshake failed: $e');
    } finally {
      _connectInFlight = false;
      _drainQueuedReconnectHandshake();
    }
  }

  void _drainQueuedReconnectHandshake() {
    if (!_pendingReconnectHandshake) return;
    if (_connectInFlight || _pairingResolveAttempted) return;
    _pendingReconnectHandshake = false;
    unawaited(_handleSocketReconnectReady());
  }

  void _onFrame(NodeFrame frame) {
    if (frame.isEvent) {
      _handleEvent(frame);
    }
  }

  Future<void> _handleEvent(NodeFrame frame) async {
    switch (frame.event) {
      case '_disconnected':
        _challengeCompleter = null;
        _cachedChallengeNonce = null;
        _cachedChallengeReceivedAt = null;
        if (_state.status != NodeStatus.disabled) {
          final closeCode = frame.payload?['closeCode'];
          final closeReason =
              frame.payload?['closeReason']?.toString() ?? 'unknown';
          _updateState(_state.copyWith(
            status: NodeStatus.disconnected,
            clearConnectedAt: true,
          ));
          log('[NODE] Disconnected (closeCode=${closeCode ?? 'n/a'} reason=$closeReason); reconnect delegated to socket backoff/watchdog');
        }
        break;

      case 'connect.challenge':
        final nonce = frame.payload?['nonce'] as String?;
        if (_challengeCompleter != null && !_challengeCompleter!.isCompleted) {
          _challengeCompleter!.complete(nonce ?? '');
        } else {
          // Reconnects can receive connect.challenge just before onReconnectReady
          // creates its waiter. Cache only briefly and clear it on disconnect to
          // avoid nonce drift across sockets.
          if (nonce != null && nonce.isNotEmpty) {
            _cachedChallengeNonce = nonce;
            _cachedChallengeReceivedAt = DateTime.now();
            log('[NODE] Challenge received before handshake waiter; cached for reconnect');
          } else {
            log('[NODE] Challenge missing nonce before handshake waiter');
          }
        }
        _updateState(_state.copyWith(status: NodeStatus.challenging));
        log(nonce != null
            ? '[NODE] Challenge received'
            : '[NODE] Challenge missing nonce');
        // connect() awaits _challengeCompleter with timeout — no re-send needed here.
        break;

      case 'node.invoke.request':
        await _handleInvokeRequest(frame.payload ?? {});
        break;

      case '_policy_rejected':
        log('[NODE] Policy rejected (1008 Origin Mismatch). Stopping reconnect to avoid loop.');
        _ws.haltReconnect();
        _updateState(_state.copyWith(
          status: NodeStatus.error,
          errorMessage:
              'Security policy rejected the connection (Origin Mismatch).',
        ));
        break;
    }
  }

  /// Resolve the gateway auth token from available sources.
  Future<String?> _readGatewayToken() async {
    // 1. Primary: read directly from openclaw.json — same authoritative source
    //    as GatewayService.retrieveTokenFromConfig(). This is always current,
    //    even after `openclaw reload` generates a new token.
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final configPath = '$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json';
      final content = await File(configPath).readAsString();
      final config = jsonDecode(content) as Map<String, dynamic>;
      final token = config['gateway']?['auth']?['token'] as String? ??
          config['gateway']?['token'] as String? ??
          config['auth']?['token'] as String?;
      if (token != null && token.isNotEmpty) {
        log('[NODE] Gateway token read from openclaw.json');
        return token;
      }
    } catch (_) {}

    // 2. Fallback: manually configured token (for remote gateways)
    final prefs = PreferencesService();
    await prefs.init();
    final manualToken = prefs.nodeGatewayToken;
    if (manualToken != null && manualToken.isNotEmpty) {
      log('[NODE] Using manually configured gateway token');
      return manualToken;
    }

    log('[NODE] No gateway token available');
    return null;
  }

  /// Build and send the `connect` request and adapt protocol version on mismatch.
  Future<void> _sendConnect(String nonce) async {
    if (nonce.isEmpty) {
      log('[NODE] Refusing to send connect without challenge nonce; reopening socket.');
      await _ws.forceReconnect(reason: 'missing-connect-nonce');
      return;
    }

    final version = await OpenClawCommandService.detectOpenClawVersion();

    final prefs = PreferencesService();
    await prefs.init();
    final deviceToken = prefs.nodeDeviceToken;

    _gatewayAuthToken ??= await _readGatewayToken();

    // Protocol v3: The device identity signature ONLY signs the gateway auth token
    // (if provided). The device token is passed separately in auth.deviceToken.
    final signatureToken = _gatewayAuthToken;

    const clientId = 'node-host';
    const clientMode = 'node';
    const role = AppConstants.nodeRole;
    // Keep node scopes stable and empty across first-pair + reconnect.
    // OpenClaw supersedes pending requests when auth details (including scopes)
    // change, so flipping scope sets between retries causes requestId churn.
    final activeDeviceToken = deviceToken;
    final hasDeviceToken =
        activeDeviceToken != null && activeDeviceToken.isNotEmpty;
    const scopes = <String>[];
    if (hasDeviceToken) {
      final preview = activeDeviceToken.length > 8
          ? '${activeDeviceToken.substring(0, 8)}...'
          : activeDeviceToken;
      log('[NODE] Using cached node device token: $preview');
    } else {
      log('[NODE] No cached node device token — using first-time pairing path');
    }
    final signedAtMs = DateTime.now().millisecondsSinceEpoch;

    // Build the structured payload the gateway verifies:
    // "v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|token|nonce"
    final authPayload = _identity.buildAuthPayload(
      clientId: clientId,
      clientMode: clientMode,
      role: role,
      scopes: scopes,
      signedAtMs: signedAtMs,
      token: signatureToken,
      nonce: nonce,
    );
    final signature = await _identity.sign(authPayload) ?? '';

    // Build caps (unique capability names) and commands from registered handlers
    final commands = _capabilityHandlers.keys.toList();
    final caps = commands.map((c) => c.split('.').first).toSet().toList();
    log('[NODE] Declaring ${commands.length} commands: $commands');

    final connectProtocol = _preferredConnectProtocol > 0
        ? _preferredConnectProtocol
        : AppConstants.wsProtocolMaxVersion;

    final connectFrame = NodeFrame.request('connect', {
      'minProtocol': connectProtocol,
      'maxProtocol': connectProtocol,
      'client': {
        'id': clientId,
        'displayName': 'OpenClaw Mobile',
        'version': version,
        'platform': 'android',
        'deviceFamily': 'Android',
        'mode': clientMode,
      },
      'role': role,
      if (scopes.isNotEmpty) 'scopes': scopes,
      'permissions': <String, dynamic>{},
      'device': {
        'id': _identity.deviceId ?? '',
        'publicKey': _identity.publicKeyBase64Url ?? '',
        'signature': signature,
        'nonce': nonce,
        'signedAt': signedAtMs,
      },
      'auth': {
        if (_gatewayAuthToken != null) 'token': _gatewayAuthToken,
        if (activeDeviceToken != null && activeDeviceToken.isNotEmpty)
          'deviceToken': activeDeviceToken,
      },
      'locale': 'en-US',
      'userAgent': 'plawie-android/${AppConstants.version}',
      // Include caps/commands for node registration
      'caps': caps,
      'commands': commands,
    });

    log('[NODE] Connect frame protocol=v$connectProtocol caps=$caps commands=$commands');
    log('[NODE] Connect frame platform=android');
    final response = await _ws.sendRequest(connectFrame);
    log(_summarizeConnectResponse(response));

    if (response.isOk) {
      // hello-ok
      final authPayload = response.payload?['auth'] as Map<String, dynamic>?;
      final deviceToken = authPayload?['deviceToken'] as String?;
      final negotiatedProtocol =
          _parseProtocolVersion(response.payload?['protocol']);
      if (negotiatedProtocol != null && negotiatedProtocol > 0) {
        _preferredConnectProtocol = negotiatedProtocol;
      }
      if (deviceToken != null) {
        prefs.nodeDeviceToken = deviceToken;
      }
      _onConnected(response);
    } else if (response.isError) {
      final errPayload = response.payload ?? response.error ?? {};
      final code = errPayload['code'] as String? ?? '';
      final message = errPayload['message'] as String? ?? 'Connect failed';
      final details = errPayload['details'];
      final normalizedMessage = message.toLowerCase();

      if (code == 'INVALID_REQUEST' &&
          normalizedMessage.contains('protocol mismatch')) {
        final expectedProtocol = _extractExpectedProtocol(details);
        if (expectedProtocol != null && expectedProtocol > 0) {
          if (expectedProtocol != _preferredConnectProtocol) {
            _preferredConnectProtocol = expectedProtocol;
            log('[NODE] Gateway expects protocol v$expectedProtocol; will retry with that version.');
          }
        } else {
          // No protocol hint in details; rotate through modern protocol candidates.
          final fallback = _nextProtocolCandidate(_preferredConnectProtocol);
          if (fallback > 0 && fallback != _preferredConnectProtocol) {
            _preferredConnectProtocol = fallback;
            log('[NODE] Protocol mismatch without details; falling back to protocol v$fallback on reconnect.');
          }
        }
      }

      if (code == 'TOKEN_INVALID' ||
          code == 'NOT_PAIRED' ||
          code == 'DEVICE_NOT_PAIRED') {
        log('[NODE] Pairing requested; waiting for gateway close to approve by requestId...');
        // Do nothing — await the 1008 close event to trigger _handleNodePairingRequired
      } else if (code == 'UNAVAILABLE') {
        log('[NODE] Gateway is warming up (UNAVAILABLE). Entering grace period...');
        _updateState(_state.copyWith(status: NodeStatus.warmingUp));
        // NodeWsService will trigger _disconnected on close, or we can force it
      } else if (code == 'INVALID_REQUEST' &&
          normalizedMessage.contains("required property 'nonce'")) {
        log('[NODE] Gateway required a fresh nonce; reopening socket for secure reconnect.');
        await _ws.forceReconnect(reason: 'gateway-required-nonce');
      } else {
        _updateState(_state.copyWith(
          status: NodeStatus.error,
          errorMessage: message,
        ));
        log('[NODE] Connect error: $code - $message');
        if (details != null) {
          log('[NODE] Connect error details: $details');
        }
      }
    }
  }

  String _summarizeConnectResponse(NodeFrame response) {
    if (response.isOk) {
      final payload = response.payload ?? const <String, dynamic>{};
      final protocol = _parseProtocolVersion(payload['protocol']) ?? '?';
      final features = payload['features'];
      final methods = features is Map ? features['methods'] : null;
      final methodCount = methods is List ? methods.length : 0;
      final snapshot = payload['snapshot'];
      final presence = snapshot is Map ? snapshot['presence'] : null;
      final presenceCount = presence is List ? presence.length : 0;
      final authPayload = payload['auth'];
      final deviceToken =
          authPayload is Map ? authPayload['deviceToken']?.toString() : null;
      final previewLength = deviceToken == null
          ? 0
          : (deviceToken.length < 6 ? deviceToken.length : 6);
      final tokenPreview = deviceToken != null && deviceToken.isNotEmpty
          ? '${deviceToken.substring(0, previewLength)}...'
          : 'unchanged';
      return '[NODE] Connect accepted (protocol=v$protocol, methods=$methodCount, presence=$presenceCount, token=$tokenPreview)';
    }

    final errPayload = response.payload ?? response.error ?? {};
    final code = errPayload['code']?.toString() ?? 'REJECTED';
    final message =
        errPayload['message']?.toString() ?? 'Gateway rejected connect';
    final details = errPayload['details'];
    final requestId = details is Map ? details['requestId']?.toString() : null;
    if (code == 'NOT_PAIRED' || code == 'DEVICE_NOT_PAIRED') {
      final suffix = requestId != null && requestId.isNotEmpty
          ? ' (requestId=$requestId)'
          : '';
      return '[NODE] Pairing required$suffix';
    }
    return '[NODE] Connect rejected: $code - $message';
  }

  int? _extractExpectedProtocol(dynamic details) {
    if (details is Map) {
      final dynamic expected = details['expectedProtocol'] ??
          details['protocol'] ??
          details['serverProtocol'];
      return _parseProtocolVersion(expected);
    }
    return _parseProtocolVersion(details);
  }

  int? _parseProtocolVersion(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int _nextProtocolCandidate(int current) {
    final base = AppConstants.wsProtocolMaxVersion;
    final candidates = <int>{base, base + 1, base + 2}
        .where((v) => v > 0 && v <= 16)
        .toList()
      ..sort();
    if (candidates.isEmpty) return base;
    final idx = candidates.indexOf(current);
    if (idx == -1) return candidates.first;
    return candidates[(idx + 1) % candidates.length];
  }

  void _onConnected(NodeFrame frame) {
    _pairingRetryNotBefore = null;
    _pairingApprovalFailureCount = 0;
    _cachedChallengeNonce = null;
    _cachedChallengeReceivedAt = null;
    _updateState(_state.copyWith(
      status: NodeStatus.paired,
      connectedAt: DateTime.now(),
      clearPairingCode: true,
      clearError: true,
    ));
    log('[NODE] Paired and connected');
  }

  /// Handle a node.invoke.request event from the gateway.
  /// The gateway sends: event "node.invoke.request" with payload:
  ///   {id, nodeId, command, paramsJSON, timeoutMs}
  /// We must respond by sending a request "node.invoke.result" with:
  ///   {id, nodeId, ok, payload/payloadJSON, error}
  Future<void> _handleInvokeRequest(Map<String, dynamic> invokePayload) async {
    final requestId = invokePayload['id'] as String?;
    final command = invokePayload['command'] as String?;
    final nodeId =
        invokePayload['nodeId'] as String? ?? (_identity.deviceId ?? '');
    final paramsJSON = invokePayload['paramsJSON'] as String?;

    if (requestId == null || command == null) {
      log('[NODE] Invoke missing id or command');
      return;
    }

    log('[NODE] Invoke: $command');

    Map<String, dynamic> commandParams = {};
    if (paramsJSON != null && paramsJSON.isNotEmpty) {
      try {
        commandParams =
            Map<String, dynamic>.from(jsonDecode(paramsJSON) as Map);
      } catch (_) {}
    }

    final handler = _capabilityHandlers[command];
    if (handler == null) {
      log('[NODE] Unknown command: $command');
      _ws.sendRequest(NodeFrame.request('node.invoke.result', {
        'id': requestId,
        'nodeId': nodeId,
        'ok': false,
        'error': {
          'code': 'NOT_SUPPORTED',
          'message': 'Capability $command not available',
        },
      }));
      return;
    }

    try {
      final result = await handler(command, commandParams);
      final resultPayload = <String, dynamic>{
        'id': requestId,
        'nodeId': nodeId,
      };
      if (result.isError) {
        resultPayload['ok'] = false;
        resultPayload['error'] = result.error;
      } else {
        resultPayload['ok'] = true;
        if (result.payload != null) {
          resultPayload['payloadJSON'] = jsonEncode(result.payload);
        }
      }
      _ws.sendRequest(NodeFrame.request('node.invoke.result', resultPayload));
      log('[NODE] Invoke result sent for $command');
    } catch (e) {
      _ws.sendRequest(NodeFrame.request('node.invoke.result', {
        'id': requestId,
        'nodeId': nodeId,
        'ok': false,
        'error': {
          'code': 'INVOKE_ERROR',
          'message': '$e',
        },
      }));
    }
  }

  Future<void> _handleNodePairingRequired([String? requestId]) async {
    if (_pairingResolveAttempted) return;
    _pairingResolveAttempted = true;
    _updateState(_state.copyWith(
      status: NodeStatus.pairing,
      pairingCode: requestId,
      clearError: true,
    ));

    _ws.haltReconnect();
    clearCachedToken();
    _pendingReconnectHandshake = false;

    final prefs = PreferencesService();
    await prefs.init();
    // Never reuse a token after 1008 pairing-required.
    // Reusing stale auth details keeps superseding pending request IDs.
    prefs.nodeDeviceToken = null;

    var approved = false;
    try {
      final hasValidRequestId = requestId != null &&
          requestId.isNotEmpty &&
          _uuidPattern.hasMatch(requestId);
      if (!hasValidRequestId) {
        log('[NODE] Pairing required but no valid requestId was provided; resolving latest pending node request');
      }

      final approvedToken = await _approveNodeViaDevicePairing(
          hasValidRequestId ? requestId : null);
      if (approvedToken != null && approvedToken.isNotEmpty) {
        prefs.nodeDeviceToken = approvedToken;
        final preview = approvedToken.length > 8
            ? '${approvedToken.substring(0, 8)}...'
            : approvedToken;
        log('[NODE] Device approved; received new node token ($preview)');
      } else {
        log('[NODE] Device approved; token will be learned on next successful connect');
      }
      approved = true;
      _pairingApprovalFailureCount = 0;
      _pairingRetryNotBefore = null;
    } catch (e) {
      _pairingApprovalFailureCount++;
      final blocked = _isPairingApprovalBlockedError(e);
      final exhausted = _pairingApprovalFailureCount >= 3;
      log('[NODE] Pairing approval failed: $e');
      _updateState(_state.copyWith(
        status: NodeStatus.error,
        errorMessage: blocked
            ? 'Pairing approval blocked by operator scope upgrade. Repair operator approval before retrying.'
            : 'Pairing approval failed: $e',
      ));
      if (blocked || exhausted) {
        _pairingRetryNotBefore = DateTime.now().add(const Duration(minutes: 5));
        log(blocked
            ? '[NODE] Pairing approval blocked; suppressing automatic retries'
            : '[NODE] Pairing approval failed repeatedly; suppressing automatic retries');
      }
    }

    await _ws.disconnect();
    _challengeCompleter = null;
    _pairingResolveAttempted = false;
    if (approved) {
      _attachWsListeners();
      _ws.resumeReconnect(delayMs: 1500);
      return;
    }

    // Always schedule a reconnect — covers every failure path:
    // blocked/exhausted → _pairingRetryNotBefore already set to 5 min
    // transient 1st/2nd failure → null here, set it now
    _pairingRetryNotBefore ??= DateTime.now().add(
      Duration(seconds: _pairingApprovalFailureCount == 1 ? 30 : 60),
    );
    final retryMs = _pairingRetryNotBefore!
        .difference(DateTime.now())
        .inMilliseconds
        .clamp(5000, 5 * 60 * 1000);
    log('[NODE] Pairing will retry in ${(retryMs / 1000).round()}s');
    _attachWsListeners();
    _ws.resumeReconnect(delayMs: retryMs);
  }

  Future<String?> _approveNodeViaDevicePairing(String? requestId) async {
    final requestLabel = requestId == null || requestId.isEmpty
        ? 'latest pending node request'
        : requestId;
    log('[NODE] Pairing required (1008) — approving $requestLabel via OpenClaw CLI...');
    _gatewayAuthToken ??= await _readGatewayToken();
    final gatewayUrl =
        'ws://${_state.gatewayHost ?? AppConstants.gatewayHost}:${_state.gatewayPort ?? AppConstants.gatewayPort}';
    var requestIdToApprove = requestId?.trim() ?? '';
    final gatewayToken = _gatewayAuthToken;

    // Pending request IDs can be superseded when the node retries connect.
    // Resolve the latest pending request right before approval to avoid
    // "unknown requestId" loops.
    requestIdToApprove = await _resolvePendingNodeRequestId(
          fallbackRequestId: requestIdToApprove,
          gatewayUrl: gatewayUrl,
          token: gatewayToken,
        ) ??
        requestIdToApprove;
    if (requestIdToApprove.isEmpty ||
        !_uuidPattern.hasMatch(requestIdToApprove)) {
      throw StateError('No valid pending node pairing request found');
    }

    // Prefer explicit URL/token first so approval does not depend on a stale
    // local CLI session scope.
    if (gatewayToken != null && gatewayToken.isNotEmpty) {
      try {
        await NativeBridge.runInProot(
          '$kOpenClawCommand devices approve $requestIdToApprove '
          '--url ${NativeBridge.shellQuote(gatewayUrl)} '
          '--token ${NativeBridge.shellQuote(gatewayToken)} '
          '--json',
          timeout: 40,
        );
        return _readApprovedNodeTokenFromStore();
      } catch (e) {
        if (_isUnknownRequestIdError(e)) {
          final refreshedId = await _resolvePendingNodeRequestId(
            fallbackRequestId: requestIdToApprove,
            gatewayUrl: gatewayUrl,
            token: gatewayToken,
          );
          if (refreshedId != null && refreshedId != requestIdToApprove) {
            requestIdToApprove = refreshedId;
            await NativeBridge.runInProot(
              '$kOpenClawCommand devices approve $requestIdToApprove '
              '--url ${NativeBridge.shellQuote(gatewayUrl)} '
              '--token ${NativeBridge.shellQuote(gatewayToken)} '
              '--json',
              timeout: 40,
            );
            return _readApprovedNodeTokenFromStore();
          }
        }
        log('[NODE] Explicit approval failed ($e); retrying with local CLI session...');
      }
    }

    // Fallback path: local CLI session, with one stale-request recovery attempt.
    try {
      await NativeBridge.runInProot(
        '$kOpenClawCommand devices approve $requestIdToApprove --json',
        timeout: 40,
      );
    } catch (e) {
      if (_isUnknownRequestIdError(e)) {
        final refreshedId = await _resolvePendingNodeRequestId(
          fallbackRequestId: requestIdToApprove,
          gatewayUrl: gatewayUrl,
          token: gatewayToken,
        );
        if (refreshedId != null && refreshedId != requestIdToApprove) {
          requestIdToApprove = refreshedId;
          await NativeBridge.runInProot(
            '$kOpenClawCommand devices approve $requestIdToApprove --json',
            timeout: 40,
          );
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    return _readApprovedNodeTokenFromStore();
  }

  Future<String?> _resolvePendingNodeRequestId({
    required String fallbackRequestId,
    required String gatewayUrl,
    required String? token,
  }) async {
    try {
      final explicitArgs = token != null && token.isNotEmpty
          ? ' --url ${NativeBridge.shellQuote(gatewayUrl)}'
              ' --token ${NativeBridge.shellQuote(token)}'
          : '';
      final output = await NativeBridge.runInProot(
        '$kOpenClawCommand devices list --json$explicitArgs',
        timeout: 20,
      );
      return NativeBridge.extractPendingDeviceRequestId(
        output,
        requestedId: fallbackRequestId,
        deviceId: _identity.deviceId,
        role: AppConstants.nodeRole,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isUnknownRequestIdError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('unknown requestid');
  }

  bool _isPairingApprovalBlockedError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('scope upgrade pending approval') ||
        message.contains(
            'device is asking for more scopes than currently approved') ||
        message.contains('invalid scope for requested roles');
  }

  Future<String?> _readApprovedNodeTokenFromStore() async {
    final deviceStoreToken = await _readApprovedNodeTokenFromDeviceStore();
    if (deviceStoreToken != null && deviceStoreToken.isNotEmpty) {
      return deviceStoreToken;
    }

    final pairedStoreToken = await _readApprovedNodeTokenFromPairedStore();
    if (pairedStoreToken != null && pairedStoreToken.isNotEmpty) {
      return pairedStoreToken;
    }
    return _readApprovedNodeTokenFromNodeStore();
  }

  Future<String?> _readApprovedNodeTokenFromDeviceStore() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final pairedPath =
          '$filesDir/rootfs/ubuntu/root/.openclaw/devices/paired.json';
      final pairedFile = File(pairedPath);
      if (!await pairedFile.exists()) return null;

      final decoded = jsonDecode(await pairedFile.readAsString());
      final nodeId = _identity.deviceId ?? '';
      return _findTokenForDevice(decoded, nodeId);
    } catch (_) {
      return null;
    }
  }

  String? _findTokenForDevice(Object? value, String deviceId) {
    if (deviceId.isEmpty) return null;
    if (value is Map) {
      final map = value.map((key, val) => MapEntry('$key', val));
      if (map.containsKey(deviceId)) {
        final token = _findAnyToken(map[deviceId]);
        if (token != null) return token;
      }

      final mentionsDevice = _containsStringValue(map, deviceId);
      final mentionsNodeRole = _containsStringValue(map, AppConstants.nodeRole);
      if (mentionsDevice && mentionsNodeRole) {
        final token = _tokenFromMap(map);
        if (token != null) return token;
      }

      for (final child in map.values) {
        final token = _findTokenForDevice(child, deviceId);
        if (token != null) return token;
      }
    } else if (value is List) {
      for (final child in value) {
        final token = _findTokenForDevice(child, deviceId);
        if (token != null) return token;
      }
    }
    return null;
  }

  String? _tokenFromMap(Map<String, dynamic> map) {
    const tokenKeys = ['token', 'deviceToken', 'authToken', 'bearerToken'];
    for (final key in tokenKeys) {
      final value = map[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _findAnyToken(Object? value) {
    if (value is Map) {
      final map = value.map((key, val) => MapEntry('$key', val));
      final direct = _tokenFromMap(map);
      if (direct != null) return direct;
      for (final child in map.values) {
        final token = _findAnyToken(child);
        if (token != null) return token;
      }
    } else if (value is List) {
      for (final child in value) {
        final token = _findAnyToken(child);
        if (token != null) return token;
      }
    }
    return null;
  }

  bool _containsStringValue(Object? value, String needle) {
    if (needle.isEmpty) return false;
    if (value is String) return value == needle;
    if (value is Map) {
      return value.values.any((v) => _containsStringValue(v, needle));
    }
    if (value is List) return value.any((v) => _containsStringValue(v, needle));
    return false;
  }

  Future<String?> _readApprovedNodeTokenFromPairedStore() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final pairedPath =
          '$filesDir/rootfs/ubuntu/root/.openclaw/nodes/paired.json';
      final pairedFile = File(pairedPath);
      if (!await pairedFile.exists()) return null;

      final decoded =
          jsonDecode(await pairedFile.readAsString()) as Map<String, dynamic>;
      final nodeId = _identity.deviceId ?? '';
      final record = decoded[nodeId];
      if (record is! Map) return null;

      final token = record['token'] as String?;
      return token != null && token.isNotEmpty ? token : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readApprovedNodeTokenFromNodeStore() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final nodePath = '$filesDir/rootfs/ubuntu/root/.openclaw/node.json';
      final nodeFile = File(nodePath);
      if (!await nodeFile.exists()) return null;

      final decoded =
          jsonDecode(await nodeFile.readAsString()) as Map<String, dynamic>;
      final directToken = decoded['token'];
      if (directToken is String && directToken.isNotEmpty) {
        return directToken;
      }

      final deviceToken = decoded['deviceToken'];
      if (deviceToken is String && deviceToken.isNotEmpty) {
        return deviceToken;
      }

      final gateway = decoded['gateway'];
      if (gateway is Map) {
        final nestedToken = gateway['token'];
        if (nestedToken is String && nestedToken.isNotEmpty) {
          return nestedToken;
        }
        final nestedDeviceToken = gateway['deviceToken'];
        if (nestedDeviceToken is String && nestedDeviceToken.isNotEmpty) {
          return nestedDeviceToken;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> disconnect() async {
    _pendingReconnectHandshake = false;
    _frameSubscription?.cancel();
    _pairingSubscription?.cancel();
    _warmingUpSubscription?.cancel();
    await _ws.disconnect();
    _updateState(_state.copyWith(
      status: NodeStatus.disconnected,
      clearConnectedAt: true,
      clearPairingCode: true,
    ));
    log('[NODE] Disconnected');
  }

  Future<void> disable() async {
    await disconnect();
    _updateState(NodeState(
      status: NodeStatus.disabled,
      logs: _state.logs,
      deviceId: _state.deviceId,
    ));
    log('[NODE] Node disabled');
  }

  void dispose() {
    _frameSubscription?.cancel();
    _pairingSubscription?.cancel();
    _warmingUpSubscription?.cancel();
    _ws.dispose();
    _stateController.close();
  }
}
