import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import 'device_identity.dart';

/// Persistent WebSocket connection to the OpenClaw gateway.
///
/// Implements OpenClaw Protocol v3 with:
/// - Ed25519 device identity (signed connect frame)
/// - Challenge-response nonce handling
/// - Automatic reconnect on disconnect (exponential backoff)
/// - Ping keep-alive
/// - Connection state tracking
enum GatewayConnectionState { disconnected, connecting, handshaking, connected }

class GatewayConnection {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  GatewayConnectionState _state = GatewayConnectionState.disconnected;
  GatewayConnectionState get state => _state;

  String? _token;
  int _reconnectAttempts = 0;
  // 50 attempts ≈ 12+ minutes of exponential backoff.
  // 10 was too small for phones that can be dormant for hours.
  static const _maxReconnectAttempts = 50;

  final DeviceIdentity _identity = DeviceIdentity();
  bool _identityLoaded = false;

  /// The connect request ID, used to match the hello-ok (type:res) response.
  String? _connectRequestId;

  /// The main session key returned by the gateway in the connect response.
  String? mainSessionKey;

  /// The list of methods supported by the gateway, extracted from the hello-ok response.
  List<String> supportedMethods = [];

  final _stateNotifier = StreamController<GatewayConnectionState>.broadcast();
  Stream<GatewayConnectionState> get stateStream => _stateNotifier.stream;

  // Pending request completers — keyed by request ID
  final Map<String, StreamController<Map<String, dynamic>>> _pendingRequests = {};

  // Global event stream for unsolicited events (chat, agent, etc.)
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  Completer<void>? _handshakeCompleter;
  Completer<String?>? _challengeCompleter;

  /// Connect to the gateway with the given auth token.
  Future<bool> connect(String token) async {
    if (_state == GatewayConnectionState.connected && _token == token) {
      return true; // Already connected
    }

    _token = token;

    // Ensure device identity is loaded/generated
    if (!_identityLoaded) {
      await _identity.loadOrCreate();
      _identityLoaded = true;
    }

    return _doConnect();
  }

  Future<bool> _doConnect() async {
    _updateState(GatewayConnectionState.connecting);
    _cleanup();

    try {
      final wsUri = Uri.parse(AppConstants.gatewayWsUrl);
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;
    } catch (e) {
      _updateState(GatewayConnectionState.disconnected);
      _scheduleReconnect();
      return false;
    }

    _updateState(GatewayConnectionState.handshaking);
    _handshakeCompleter = Completer<void>();
    _challengeCompleter = Completer<String?>();

    // Listen for frames
    _subscription = _channel!.stream.listen(
      _onFrame,
      onError: (_) => _onDisconnect(),
      onDone: _onDisconnect,
    );

    // For local connections (127.0.0.1), the gateway skips the challenge.
    // Wait briefly for a challenge nonce, then proceed without one.
    String? nonce;
    try {
      nonce = await _challengeCompleter!.future
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {
      nonce = null; // No challenge for local connections
    }

    // Build and send the Protocol v3 connect frame with device identity
    await _sendConnectFrame(nonce);

    // Wait for connect response (type: 'res' matching our connect ID)
    try {
      await _handshakeCompleter!.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      _updateState(GatewayConnectionState.disconnected);
      _cleanup();
      _scheduleReconnect();
      return false;
    }

    _reconnectAttempts = 0;
    _updateState(GatewayConnectionState.connected);
    _startPing();
    return true;
  }

  Future<void> _sendConnectFrame(String? nonce) async {
    final deviceBlock = await _identity.buildDeviceBlock(
      clientId: 'openclaw-android',
      clientMode: 'ui',
      role: 'operator',
      scopes: ['operator.admin', 'operator.read', 'operator.write', 'chat', 'agent', 'system', 'operator'],
      token: _token,
      nonce: nonce,
    );

    _connectRequestId = const Uuid().v4();
    final frame = <String, dynamic>{
      'type': 'req',
      'id': _connectRequestId,
      'method': 'connect',
      'params': {
        'minProtocol': 3,
        'maxProtocol': 3,
        'client': {
          'id': 'openclaw-android',
          'version': AppConstants.version,
          'platform': 'android',
          'mode': 'ui',
        },
        'role': 'operator',
        'scopes': ['operator.admin', 'operator.read', 'operator.write', 'chat', 'agent', 'system', 'operator'],
        'auth': {'token': _token},
        'locale': 'en-US',
      },
    };

    // Add device identity block if available
    if (deviceBlock != null) {
      (frame['params'] as Map<String, dynamic>)['device'] = deviceBlock;
    }

    _channel!.sink.add(jsonEncode(frame));
  }

  void _onFrame(dynamic raw) {
    try {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = frame['type'] as String?;

      // ── Connect response (hello-ok) ──
      // The gateway sends the connect response as type:'res' with our connect ID.
      // The server logs call it "hello-ok" but the wire protocol uses type:'res'.
      if (type == 'res' && frame['id'] == _connectRequestId) {
        // Check if the connect was successful
        final ok = frame['ok'] as bool? ?? false;
        if (ok) {
          // Extract mainSessionKey from the payload
          final payload = frame['payload'] as Map<String, dynamic>?;
          final snapshot = payload?['snapshot'] as Map<String, dynamic>?;
          final sessionDefaults = snapshot?['sessionDefaults'] as Map<String, dynamic>?;
          mainSessionKey = sessionDefaults?['mainSessionKey'] as String? ?? 'main';

          // Extract supported methods
          final features = payload?['features'] as Map<String, dynamic>?;
          final methods = features?['methods'] as List?;
          if (methods != null) {
            supportedMethods = List<String>.from(methods);
          }

          // Persist device token if provided
          final auth = payload?['auth'] as Map<String, dynamic>?;
          // ignore: unused_local_variable
          final deviceToken = auth?['deviceToken'] as String?;
          // TODO: persist deviceToken for future connections
        }

        _connectRequestId = null; // Clear so we don't match again
        if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
          if (ok) {
            _handshakeCompleter!.complete();
          } else {
            // Error could be a Map or a String. Avoid fatal TypeErrors on Strings.
            final errorRaw = frame['error'];
            String msg = 'connect rejected';
            if (errorRaw is Map) {
              msg = errorRaw['message']?.toString() ?? 'connect rejected';
            } else if (errorRaw != null) {
              msg = errorRaw.toString();
            }
            _handshakeCompleter!.completeError(Exception(msg));
          }
        }
        return;
      }

      // ── Response to a pending RPC request ──
      if (type == 'res' && frame['id'] != null) {
        final id = frame['id'] as String;
        if (_pendingRequests.containsKey(id)) {
          _pendingRequests[id]!.add(frame);
        }
        return;
      }

      // ── Events ──
      if (type == 'event') {
        final event = frame['event'] as String?;

        // Handle challenge-response during handshake
        if (event == 'connect.challenge') {
          final payload = frame['payload'] as Map<String, dynamic>?;
          final nonce = payload?['nonce'] as String?;
          if (_challengeCompleter != null && !_challengeCompleter!.isCompleted) {
            _challengeCompleter!.complete(nonce);
          }
          return;
        }

        _eventController.add(frame);
        // Also broadcast to any pending request handlers
        for (final controller in _pendingRequests.values) {
          controller.add(frame);
        }
        return;
      }

      // ── Gateway Errors ──
      // The gateway blasts fatal errors (like rate limits) down with type:'error', NOT as 'event' or 'res'.
      if (type == 'error') {
        // If the handshake was in progress and failed immediately
        if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
          final payloadRaw = frame['payload'];
          String msg = 'Fatal Gateway Connection Error';
          if (payloadRaw is Map) {
            msg = payloadRaw['message']?.toString() ?? msg;
          } else if (payloadRaw != null) {
            msg = payloadRaw.toString();
          }
          _handshakeCompleter!.completeError(Exception(msg));
          _connectRequestId = null;
        }

        final errorId = frame['id'] as String?;
        // If it has an ID, route it to the specific pending request that failed
        if (errorId != null && _pendingRequests.containsKey(errorId)) {
          _pendingRequests[errorId]!.add(frame);
        } else {
          // If no ID, it's a global socket error (like rate limit). Broadcast everywhere.
          _eventController.add(frame);
          for (final controller in _pendingRequests.values) {
            controller.add(frame);
          }
        }
        return;
      }

      // Pong
      if (type == 'pong') return;
    } catch (_) {}
  }

  void _onDisconnect() {
    _updateState(GatewayConnectionState.disconnected);
    _cleanup();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_token == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    _reconnectAttempts++;
    final delayMs = min(
      (AppConstants.wsReconnectBaseMs * pow(AppConstants.wsReconnectMultiplier, _reconnectAttempts - 1)).toInt(),
      AppConstants.wsReconnectCapMs,
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      _doConnect();
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_state == GatewayConnectionState.connected && _channel != null) {
        try {
          // Send a protocol-compliant native ping instead of an RPC request
          _channel!.sink.add(jsonEncode({
            'type': 'ping',
            'id': const Uuid().v4(),
          }));
        } catch (_) {}
      }
    });
  }

  /// Send an RPC request and return a stream of response frames.
  Stream<Map<String, dynamic>> sendRequest(Map<String, dynamic> payload) {
    final id = payload['id'] as String? ?? const Uuid().v4();
    payload['id'] = id;
    // Ensure Protocol v3 frame format
    payload['type'] = 'req';

    final controller = StreamController<Map<String, dynamic>>();
    _pendingRequests[id] = controller;

    controller.onCancel = () {
      _pendingRequests.remove(id);
    };

    if (_state == GatewayConnectionState.connected && _channel != null) {
      _channel!.sink.add(jsonEncode(payload));
    } else {
      controller.addError(StateError('Not connected to gateway'));
      controller.close();
    }

    return controller.stream;
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _connectRequestId = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _updateState(GatewayConnectionState newState) {
    _state = newState;
    _stateNotifier.add(newState);
  }

  /// Reset the reconnect attempt counter so the automatic backoff loop
  /// can start fresh. Call this when the app comes to the foreground after
  /// a sleep/wake cycle where the old counter may have been exhausted.
  void resetReconnectCounter() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
  }

  /// Disconnect and stop reconnecting.
  void disconnect() {
    _token = null;
    _reconnectAttempts = _maxReconnectAttempts; // Prevent reconnect
    _reconnectTimer?.cancel();
    _cleanup();
    _updateState(GatewayConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _stateNotifier.close();
    _eventController.close();
    for (final c in _pendingRequests.values) {
      c.close();
    }
    _pendingRequests.clear();
  }
}
