import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const _prefDeviceToken = 'openclaw_operator_device_token';

  final DeviceIdentity _identity = DeviceIdentity();
  bool _identityLoaded = false;
  String? _deviceToken;

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

  Future<bool>? _connectFuture;

  /// Connect to the gateway with the given auth token.
  Future<bool> connect(String token) async {
    if (_state == GatewayConnectionState.connected && _token == token) {
      return true; // Already connected
    }

    if (_connectFuture != null) {
      return _connectFuture!;
    }

    _token = token;

    // Cancel any pending auto-reconnect timer so it doesn't race with this
    // explicit connect call and fire a second _doConnect() concurrently.
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Ensure device identity is loaded/generated
    if (!_identityLoaded) {
      await _identity.loadOrCreate();
      _identityLoaded = true;
      // Also load any persisted device token from a previous successful session.
      // Including this token in the auth block lets the gateway skip the
      // scope-upgrade audit on reconnect, preventing pairing-required loops.
      final prefs = await SharedPreferences.getInstance();
      _deviceToken = prefs.getString(_prefDeviceToken);
    }

    _connectFuture = _doConnect();
    try {
      final result = await _connectFuture!;
      return result;
    } finally {
      _connectFuture = null;
    }
  }

  Future<bool> _doConnect() async {
    _updateState(GatewayConnectionState.connecting);
    _cleanup();

    try {
      final wsUri = Uri.parse(AppConstants.gatewayWsUrl);
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready.timeout(const Duration(seconds: 5));
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
        'auth': {
          'token': _token,
          if (_deviceToken != null && _deviceToken!.isNotEmpty) 'deviceToken': _deviceToken,
        },
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

          // Persist device token so future connects include it in the auth block.
          // Without this, every reconnect triggers the security scope-upgrade
          // audit → pairing-required, even for already-approved devices.
          final auth = payload?['auth'] as Map<String, dynamic>?;
          final newDeviceToken = auth?['deviceToken'] as String?;
          if (newDeviceToken != null && newDeviceToken.isNotEmpty) {
            _deviceToken = newDeviceToken;
            unawaited(SharedPreferences.getInstance().then(
              (prefs) => prefs.setString(_prefDeviceToken, newDeviceToken),
            ));
          }
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
    // Error all in-flight requests immediately so callers fail fast
    // instead of waiting for the 240s timeout before showing an error.
    for (final c in _pendingRequests.values) {
      if (!c.isClosed) {
        c.addError(StateError('WebSocket disconnected'));
        c.close();
      }
    }
    _pendingRequests.clear();
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
      // Guard: skip if connect() already has a _connectFuture in flight.
      // Without this, the timer and an explicit connect() call race and
      // _cleanup() in the second _doConnect() tears down the first one's channel.
      if (_connectFuture == null) _doConnect();
    });
  }

  // Pre-encoded ping frame — allocated once, reused every 30s.
  // The gateway pong handler doesn't use the id field so we omit it.
  static const _pingFrame = '{"type":"ping"}';

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_state == GatewayConnectionState.connected && _channel != null) {
        try {
          _channel!.sink.add(_pingFrame);
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

  /// Update session metadata (e.g. primaryModel, contextWindow) in-memory.
  /// Prevents the need for a 10-minute gateway restart on model switch.
  Future<void> patchSessionMetadata(Map<String, dynamic> metadata) async {
    if (_state != GatewayConnectionState.connected) return;
    
    final payload = {
      'method': 'sessions.patch',
      'params': {
        'sessionKey': mainSessionKey ?? 'main',
        'patch': {
          'metadata': metadata,
        },
      },
    };
    
    // We send and forget, as the gateway applies these instantly.
    // The next chat.send will pick up the updated metadata.
    sendRequest(payload);
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _connectRequestId = null;
    // Capture the channel ref first, then null it so no other code can use it.
    // Fire close() as a best-effort fire-and-forget — this sends the WS close
    // frame to the server, preventing the server from keeping the dead socket
    // alive for its full 440s timeout.
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      unawaited(ch.sink.close().catchError((_) {}));
    }
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
