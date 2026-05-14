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
  NodeService._internal();

  final DeviceIdentity _identity = DeviceIdentity.instance;
  final NodeWsService _ws = NodeWsService();
  final _stateController = StreamController<NodeState>.broadcast();
  StreamSubscription? _frameSubscription;
  StreamSubscription? _pairingSubscription;
  bool _pairingResolveAttempted = false;

  NodeState _state = const NodeState();
  final Map<String, Future<NodeFrame> Function(String, Map<String, dynamic>)>
      _capabilityHandlers = {};
  String? _gatewayAuthToken;
  Completer<String?>? _challengeCompleter;

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

  }

  Future<void> connect({String? host, int? port}) async {
    if (_pairingResolveAttempted) {
      log('[NODE] Pairing in progress — skipping duplicate connect (pairingResolveAttempted=true)');
      return;
    }

    final isComplete = await NativeBridge.isBootstrapComplete();
    if (!isComplete) {
      log('[NODE] Bootstrap incomplete. Node connection deferred.');
      return;
    }

    final prefs = PreferencesService();
    await prefs.init();

    final targetHost = host ?? prefs.nodeGatewayHost ?? AppConstants.gatewayHost;
    final targetPort = port ?? prefs.nodeGatewayPort ?? AppConstants.gatewayPort;

    _updateState(_state.copyWith(
      status: NodeStatus.connecting,
      clearError: true,
      gatewayHost: targetHost,
      gatewayPort: targetPort,
    ));
    log('[NODE] Connecting to $targetHost:$targetPort...');

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

    try {
      _challengeCompleter = Completer<String?>();
      await _ws.connect(targetHost, targetPort);
      log('[NODE] WebSocket connected, awaiting challenge...');

      // Wait for the gateway challenge nonce before sending the connect frame.
      // The gateway sends connect.challenge proactively on connection open.
      // For localhost trusted devices it may skip the challenge — 800ms timeout then proceed.
      // Sending nonce: '' causes INVALID_REQUEST (schema requires min 1 char when present).
      String challengeNonce;
      try {
        challengeNonce = await _challengeCompleter!.future
            .timeout(const Duration(milliseconds: 3000)) ?? '';
      } catch (_) {
        challengeNonce = ''; // No challenge within timeout — send without nonce field
      }
      await _sendConnect(challengeNonce);
    } catch (e) {
      _updateState(_state.copyWith(
        status: NodeStatus.error,
        errorMessage: 'Connection failed: $e',
      ));
      log('[NODE] Connection failed: $e');
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
          log('[NODE] Disconnected, will retry...');
        }
        break;

      case 'connect.challenge':
        final nonce = frame.payload?['nonce'] as String?;
        if (_challengeCompleter != null && !_challengeCompleter!.isCompleted) {
          _challengeCompleter!.complete(nonce ?? '');
        }
        _updateState(_state.copyWith(status: NodeStatus.challenging));
        log(nonce != null ? '[NODE] Challenge received' : '[NODE] Challenge missing nonce');
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
          errorMessage: 'Security policy rejected the connection (Origin Mismatch).',
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
    const scopes = <String>['node.device'];
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
      'scopes': scopes,
      'device': {
        'id': _identity.deviceId ?? '',
        'publicKey': _identity.publicKeyBase64Url ?? '',
        'signature': signature,
        if (nonce.isNotEmpty) 'nonce': nonce, // omit when empty — gateway schema requires min 1 char
        'signedAt': signedAtMs,
      },
      'auth': {
        if (_gatewayAuthToken != null) 'token': _gatewayAuthToken,
        if (deviceToken != null && deviceToken.isNotEmpty) 'deviceToken': deviceToken,
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

      if (code == 'TOKEN_INVALID' || code == 'NOT_PAIRED' ||
          code == 'DEVICE_NOT_PAIRED') {
        log('[NODE] Not paired or token invalid, gateway will close with 1008...');
        // Do nothing — await the 1008 close event to trigger _handleNodePairingRequired
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
    final nodeId = invokePayload['nodeId'] as String? ?? (_identity.deviceId ?? '');
    final paramsJSON = invokePayload['paramsJSON'] as String?;

    if (requestId == null || command == null) {
      log('[NODE] Invoke missing id or command');
      return;
    }

    log('[NODE] Invoke: $command');

    Map<String, dynamic> commandParams = {};
    if (paramsJSON != null && paramsJSON.isNotEmpty) {
      try {
        commandParams = Map<String, dynamic>.from(
            jsonDecode(paramsJSON) as Map);
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

  /// Called when the gateway closes the WebSocket with 1008 (pairing required).
  /// This means the device is known to the gateway but not approved yet.
  Future<void> _handleNodePairingRequired([String? requestId]) async {
    if (_pairingResolveAttempted) return;
    _pairingResolveAttempted = true;
    clearCachedToken();
    _ws.haltReconnect();

    if (requestId != null && requestId.isNotEmpty) {
      log('[NODE] Pairing required (1008) — auto-approving device $requestId...');
      try {
        await NativeBridge.approveDevice(requestId);
        await Future.delayed(const Duration(milliseconds: 2000));
        log('[NODE] Device approved successfully');
      } catch (e) {
        log('[NODE] Auto-approve failed: $e');
      }
    } else {
      // If no requestId was provided, we can't auto-approve.
      // Do NOT clear records here unless we are sure they are corrupted.
      log('[NODE] Pairing required but no requestId provided. Manual approval may be needed.');
    }

    await _ws.disconnect();
    _pairingResolveAttempted = false;
    unawaited(Future.delayed(
      const Duration(milliseconds: 1500),
      () => connect(),
    ));
  }

  Future<void> _clearNodeDeviceRecord() async {
    log('[NODE] Pairing required (1008) — clearing stale device record via filesystem...');
    try {
      final filesDir = await NativeBridge.getFilesDir();
      
      final devicesDir = Directory('$filesDir/rootfs/ubuntu/root/.openclaw/storage/devices');
      if (devicesDir.existsSync()) {
        devicesDir.deleteSync(recursive: true);
      }
      final devicesFile = File('$filesDir/rootfs/ubuntu/root/.openclaw/storage/devices.json');
      if (devicesFile.existsSync()) {
        devicesFile.deleteSync();
      }

      log('[NODE] Device record cleared — will re-pair on next connect');
      final prefs = PreferencesService();
      await prefs.init();
      prefs.nodeDeviceToken = null;
      _gatewayAuthToken = null;
    } catch (e) {
      log('[NODE] Could not clear device record: $e');
    }
  }

  Future<void> disconnect() async {
    _frameSubscription?.cancel();
    _pairingSubscription?.cancel();
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
    _ws.dispose();
    _stateController.close();
  }
}
