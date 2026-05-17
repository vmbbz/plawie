import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../constants.dart';
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

  final DeviceIdentity _identity = DeviceIdentity.instance;
  final NodeWsService _ws = NodeWsService();
  final _stateController = StreamController<NodeState>.broadcast();
  StreamSubscription? _frameSubscription;
  StreamSubscription? _pairingSubscription;
  StreamSubscription? _warmingUpSubscription;
  bool _pairingResolveAttempted = false;
  bool _connectInFlight = false;
  DateTime? _pairingRetryNotBefore;
  int _pairingApprovalFailureCount = 0;

  NodeState _state = const NodeState();
  final Map<String, Future<NodeFrame> Function(String, Map<String, dynamic>)>
      _capabilityHandlers = {};
  String? _gatewayAuthToken;
  Completer<String?>? _challengeCompleter;
  String? _pendingChallengeNonce;
  static final _requestIdPattern = RegExp(r'^[a-f0-9-]{16,}$');

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
    // Reset pairing state on each fresh init — the singleton persists across
    // gateway restarts and a stale _pairingResolveAttempted=true would silently
    // block all subsequent connect() calls.
    _pairingResolveAttempted = false;
    final deviceId = _identity.deviceId ?? '';
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

      _challengeCompleter = Completer<String?>();
      await _ws.connect(targetHost, targetPort);
      log('[NODE] WebSocket connected, awaiting challenge...');

      // Wait for the gateway challenge nonce before sending the connect frame.
      // The gateway sends connect.challenge proactively on connection open.
      // For localhost trusted devices it may skip the challenge — 800ms timeout then proceed.
      // Sending nonce: '' causes INVALID_REQUEST (schema requires min 1 char when present).
      final challengeNonce =
          await _awaitChallengeNonce(const Duration(milliseconds: 3000));
      await _sendConnect(challengeNonce);
    } catch (e) {
      _updateState(_state.copyWith(
        status: NodeStatus.error,
        errorMessage: 'Connection failed: $e',
      ));
      log('[NODE] Connection failed: $e');
    } finally {
      _connectInFlight = false;
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
    final pendingNonce = _pendingChallengeNonce;
    if (pendingNonce != null) {
      _pendingChallengeNonce = null;
      _challengeCompleter = null;
      return pendingNonce;
    }

    _challengeCompleter ??= Completer<String?>();
    try {
      return await _challengeCompleter!.future.timeout(timeout) ?? '';
    } catch (_) {
      return '';
    } finally {
      _pendingChallengeNonce = null;
      _challengeCompleter = null;
    }
  }

  Future<void> _handleSocketReconnectReady() async {
    if (_state.status == NodeStatus.disabled ||
        _pairingResolveAttempted ||
        _connectInFlight) {
      return;
    }

    final retryAt = _pairingRetryNotBefore;
    if (retryAt != null && DateTime.now().isBefore(retryAt)) return;

    _connectInFlight = true;
    try {
      _updateState(_state.copyWith(status: NodeStatus.connecting));
      log('[NODE] WebSocket reconnected, completing handshake...');
      _challengeCompleter = Completer<String?>();
      final challengeNonce =
          await _awaitChallengeNonce(const Duration(milliseconds: 800));
      await _sendConnect(challengeNonce);
    } catch (e) {
      _updateState(_state.copyWith(
        status: NodeStatus.error,
        errorMessage: 'Reconnect handshake failed: $e',
      ));
      log('[NODE] Reconnect handshake failed: $e');
    } finally {
      _connectInFlight = false;
    }
  }

  void _onFrame(NodeFrame frame) {
    if (frame.isEvent) {
      _handleEvent(frame);
    }
  }

  Future<void> _handleEvent(NodeFrame frame) async {
    switch (frame.event) {
      case '_disconnected':
        if (_state.status != NodeStatus.disabled) {
          _updateState(_state.copyWith(
            status: NodeStatus.disconnected,
            clearConnectedAt: true,
          ));
          log('[NODE] Disconnected; reconnect delegated to socket backoff/watchdog');
        }
        break;

      case 'connect.challenge':
        final nonce = frame.payload?['nonce'] as String?;
        _pendingChallengeNonce = nonce ?? '';
        if (_challengeCompleter != null && !_challengeCompleter!.isCompleted) {
          _challengeCompleter!.complete(nonce ?? '');
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

  /// Build and send the `connect` request per Gateway Protocol v3.
  Future<void> _sendConnect(String nonce) async {
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
    // autoApproveCidrs fires ONLY for role:node with NO requested scopes.
    // Omit scopes on fresh pairing (no deviceToken) so autoApprove triggers.
    // When the device is already approved (has deviceToken), include scopes normally.
    final activeDeviceToken = deviceToken;
    final hasDeviceToken =
        activeDeviceToken != null && activeDeviceToken.isNotEmpty;
    final scopes =
        hasDeviceToken ? const <String>['node.device'] : const <String>[];
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

    final connectFrame = NodeFrame.request('connect', {
      'minProtocol': 3,
      'maxProtocol': 3,
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
      'device': {
        'id': _identity.deviceId ?? '',
        'publicKey': _identity.publicKeyBase64Url ?? '',
        'signature': signature,
        if (nonce.isNotEmpty)
          'nonce':
              nonce, // omit when empty — gateway schema requires min 1 char
        'signedAt': signedAtMs,
      },
      'auth': {
        if (_gatewayAuthToken != null) 'token': _gatewayAuthToken,
        if (activeDeviceToken != null && activeDeviceToken.isNotEmpty)
          'deviceToken': activeDeviceToken,
      },
      'locale': 'en-US',
      // Include caps/commands for node registration
      'caps': caps,
      'commands': commands,
    });

    log('[NODE] Connect frame caps=$caps commands=$commands');
    log('[NODE] Connect frame platform=android');
    final response = await _ws.sendRequest(connectFrame);
    log('[NODE] Connect response ok=${response.isOk} payload=${response.payload}');

    if (response.isOk) {
      // hello-ok
      final authPayload = response.payload?['auth'] as Map<String, dynamic>?;
      final deviceToken = authPayload?['deviceToken'] as String?;
      if (deviceToken != null) {
        prefs.nodeDeviceToken = deviceToken;
      }
      _onConnected(response);
    } else if (response.isError) {
      final errPayload = response.payload ?? response.error ?? {};
      final code = errPayload['code'] as String? ?? '';
      final message = errPayload['message'] as String? ?? 'Connect failed';

      if (code == 'TOKEN_INVALID' ||
          code == 'NOT_PAIRED' ||
          code == 'DEVICE_NOT_PAIRED') {
        log('[NODE] Not paired or token invalid, gateway will close with 1008...');
        // Do nothing — await the 1008 close event to trigger _handleNodePairingRequired
      } else if (code == 'UNAVAILABLE') {
        log('[NODE] Gateway is warming up (UNAVAILABLE). Entering grace period...');
        _updateState(_state.copyWith(status: NodeStatus.warmingUp));
        // NodeWsService will trigger _disconnected on close, or we can force it
      } else {
        _updateState(_state.copyWith(
          status: NodeStatus.error,
          errorMessage: message,
        ));
        log('[NODE] Connect error: $code - $message');
      }
    }
  }

  void _onConnected(NodeFrame frame) {
    _pairingRetryNotBefore = null;
    _pairingApprovalFailureCount = 0;
    _updateState(_state.copyWith(
      status: NodeStatus.paired,
      connectedAt: DateTime.now(),
      clearPairingCode: true,
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

    final prefs = PreferencesService();
    await prefs.init();
    // Never reuse a token after 1008 pairing-required.
    // Reusing stale auth details keeps superseding pending request IDs.
    prefs.nodeDeviceToken = null;

    var approved = false;
    try {
      if (requestId == null ||
          requestId.isEmpty ||
          !_requestIdPattern.hasMatch(requestId)) {
        log('[NODE] Pairing required but no valid requestId was provided');
      } else {
        final approvedToken = await _approveNodeViaDevicePairing(requestId);
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
      }
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
    _pairingResolveAttempted = false;
    if (approved) {
      _attachWsListeners();
      _ws.resumeReconnect(delayMs: 1500);
      return;
    }

    if (_pairingRetryNotBefore == null) {
      final retryDelaySeconds = _pairingApprovalFailureCount == 1 ? 30 : 60;
      _pairingRetryNotBefore =
          DateTime.now().add(Duration(seconds: retryDelaySeconds));
      log('[NODE] Pairing approval will retry in ${retryDelaySeconds}s');
      _attachWsListeners();
      _ws.resumeReconnect(delayMs: retryDelaySeconds * 1000);
    }
  }

  Future<String?> _approveNodeViaDevicePairing(String requestId) async {
    log('[NODE] Pairing required (1008) — approving request $requestId via OpenClaw CLI...');
    _gatewayAuthToken ??= await _readGatewayToken();
    final gatewayUrl =
        'ws://${_state.gatewayHost ?? AppConstants.gatewayHost}:${_state.gatewayPort ?? AppConstants.gatewayPort}';
    final requestIdToApprove = requestId.trim();
    try {
      await NativeBridge.runInProot(
          'openclaw devices approve $requestIdToApprove --json',
          timeout: 40);
    } catch (e) {
      if (_isPairingApprovalBlockedError(e)) rethrow;
      // Fallback for builds that require explicit gateway endpoint/auth args.
      final gatewayToken = _gatewayAuthToken;
      if (gatewayToken == null || gatewayToken.isEmpty) rethrow;
      log('[NODE] Plain CLI approval failed; retrying with explicit gateway URL/token. Error: $e');
      await NativeBridge.runInProot(
        'openclaw devices approve $requestIdToApprove '
        '--url ${NativeBridge.shellQuote(gatewayUrl)} '
        '--token ${NativeBridge.shellQuote(gatewayToken)} '
        '--json',
        timeout: 40,
      );
    }

    return _readApprovedNodeTokenFromStore();
  }

  bool _isPairingApprovalBlockedError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('scope upgrade pending approval') ||
        message.contains(
            'device is asking for more scopes than currently approved') ||
        message.contains('invalid scope for requested roles');
  }

  Future<String?> _readApprovedNodeTokenFromStore() async {
    final pairedStoreToken = await _readApprovedNodeTokenFromPairedStore();
    if (pairedStoreToken != null && pairedStoreToken.isNotEmpty) {
      return pairedStoreToken;
    }
    return _readApprovedNodeTokenFromNodeStore();
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
