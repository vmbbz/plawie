import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../constants.dart';
import 'device_identity.dart';
import 'openclaw_service.dart';

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
  static const _prefWsProtocol = 'openclaw_operator_ws_protocol';
  static const _defaultWsProtocol = 4;
  static const _protocolCandidates = <int>[4, 5, 6, 3];

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

  final DeviceIdentity _identity = DeviceIdentity.operator;
  bool _identityLoaded = false;
  String? _deviceToken;

  /// The connect request ID, used to match the hello-ok (type:res) response.
  String? _connectRequestId;

  /// The main session key returned by the gateway in the connect response.
  String? mainSessionKey;

  /// The list of methods supported by the gateway, extracted from the hello-ok response.
  List<String> supportedMethods = [];

  /// The canvas/web UI URL returned by the gateway in hello-ok.
  /// This is a fully-authenticated URL — use it directly instead of probing the CLI.
  String? canvasHostUrl;

  final _stateNotifier = StreamController<GatewayConnectionState>.broadcast();
  Stream<GatewayConnectionState> get stateStream => _stateNotifier.stream;

  // Pending request completers — keyed by request ID
  final Map<String, StreamController<Map<String, dynamic>>> _pendingRequests =
      {};

  // Global event stream for unsolicited events (chat, agent, etc.)
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  // Fires when the gateway closes with 1008 (pairing required).
  // GatewayService subscribes and clears the stale device record via PRoot.
  final _pairingRequiredController = StreamController<String?>.broadcast();
  Stream<String?> get pairingRequiredStream =>
      _pairingRequiredController.stream;

  /// The device ID loaded by the identity module. Non-null after connect() is called.
  String? get deviceId => _identity.deviceId;

  /// Shared-prefs key — exposed so callers can purge the token on pairing recovery.
  static const prefDeviceToken = _prefDeviceToken;
  static const prefWsProtocol = _prefWsProtocol;

  Completer<void>? _handshakeCompleter;
  Completer<String?>? _challengeCompleter;
  bool _protocolMismatchDuringConnect = false;
  int _preferredProtocol = _defaultWsProtocol;
  int? _lastCloseCode;
  String? _lastCloseReason;
  DateTime? _lastDisconnectAt;

  int? get lastCloseCode => _lastCloseCode;
  String? get lastCloseReason => _lastCloseReason;
  DateTime? get lastDisconnectAt => _lastDisconnectAt;

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
      await _identity.init();
      _identityLoaded = true;
      // Also load any persisted device token from a previous successful session.
      // Including this token in the auth block lets the gateway skip the
      // scope-upgrade audit on reconnect, preventing pairing-required loops.
      final prefs = await SharedPreferences.getInstance();
      _deviceToken = prefs.getString(_prefDeviceToken);
      final storedProtocol =
          prefs.getInt(_prefWsProtocol) ?? AppConstants.wsProtocolMaxVersion;
      _preferredProtocol = _sanitizeProtocol(storedProtocol);
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
    _protocolMismatchDuringConnect = false;

    try {
      final wsUri = Uri.parse(AppConstants.gatewayWsUrl);
      // FIX: Explicitly send Origin header to resolve 1008 'origin-mismatch' errors.
      // We use IOWebSocketChannel directly to pass custom headers.
      final socket = await WebSocket.connect(
        wsUri.toString(),
        headers: {'Origin': 'http://127.0.0.1:18789'},
      ).timeout(const Duration(seconds: 5));

      _channel = IOWebSocketChannel(socket);
    } catch (e) {
      _onDisconnect(
        closeReason: 'connect-failed: $e',
      );
      return false;
    }

    _updateState(GatewayConnectionState.handshaking);
    _handshakeCompleter = Completer<void>();
    _challengeCompleter = Completer<String?>();

    // Listen for frames
    _subscription = _channel!.stream.listen(
      _onFrame,
      onError: (error) => _onDisconnect(
        closeReason: 'socket-error: $error',
      ),
      onDone: () {
        // Capture the close code BEFORE _cleanup() nulls _channel.
        final closeCode = _channel?.closeCode;
        final closeReason = _channel?.closeReason ?? '';
        String? reqId;
        if (closeCode == 1008 && closeReason.contains('pairing required')) {
          final m = RegExp(
                  r'requestId:\s*([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})')
              .firstMatch(closeReason);
          reqId = m?.group(1);
        }
        final pairingRequired = closeCode == 1008 &&
            (reqId != null || closeReason.contains('pairing required'));
        final policyRejected = closeCode == 1008 &&
            !pairingRequired &&
            (closeReason.contains('origin not allowed') ||
                closeReason.contains('origin-mismatch'));
        final protocolMismatch = closeReason.toLowerCase().contains(
              'protocol mismatch',
            );
        _onDisconnect(
          pairingRequired: pairingRequired,
          policyRejected: policyRejected,
          protocolMismatch: protocolMismatch,
          requestId: reqId,
          closeCode: closeCode,
          closeReason: closeReason,
        );
      },
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
      _onDisconnect(
        closeReason: 'handshake-timeout',
      );
      return false;
    }

    _reconnectAttempts = 0;
    _updateState(GatewayConnectionState.connected);
    _startPing();
    return true;
  }

  Future<void> _sendConnectFrame(String? nonce) async {
    final version = await OpenClawCommandService.detectOpenClawVersion();
    final connectProtocol = _preferredProtocol;

    const clientId = 'openclaw-control-ui';
    const clientMode = 'ui';
    const role = 'operator';
    // Keep the operator handshake inside the documented operator scope namespace.
    // Requesting non-operator scopes (e.g. "agent") causes INVALID_REQUEST on
    // newer gateways, and requesting operator.admin by default creates noisy
    // scope-upgrade loops for first-pair bootstrap sessions.
    const scopes = [
      'operator.approvals',
      'operator.read',
      'operator.talk.secrets',
      'operator.write',
    ];

    final deviceBlock = await _identity.buildDeviceBlock(
      clientId: clientId,
      clientMode: clientMode,
      role: role,
      scopes: scopes,
      token: _token,
      nonce: nonce,
    );

    _connectRequestId = const Uuid().v4();
    final frame = <String, dynamic>{
      'type': 'req',
      'id': _connectRequestId,
      'method': 'connect',
      'params': {
        'minProtocol': connectProtocol,
        'maxProtocol': connectProtocol,
        'client': {
          'id': clientId,
          'version': version,
          'platform': 'android',
          'mode': clientMode,
        },
        'role': role,
        'scopes': scopes,
        'auth': {
          'token': _token,
          if (_deviceToken != null && _deviceToken!.isNotEmpty)
            'deviceToken': _deviceToken,
        },
        'locale': 'en-US',
        'userAgent': 'plawie-android/${AppConstants.version}',
        'caps': const <String>[],
        'commands': const <String>[],
        'permissions': const <String, dynamic>{},
        // caps/commands belong ONLY on the role=node connection (NodeService/NodeWsService).
        // Declaring them on the operator role produces gateway warnings and is ignored.
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
          final sessionDefaults =
              snapshot?['sessionDefaults'] as Map<String, dynamic>?;
          mainSessionKey =
              sessionDefaults?['mainSessionKey'] as String? ?? 'main';

          // Extract supported methods
          final features = payload?['features'] as Map<String, dynamic>?;
          final methods = features?['methods'] as List?;
          if (methods != null) {
            supportedMethods = List<String>.from(methods);
          }

          // Extract the gateway's own web UI URL — fully authenticated, no CLI probe needed.
          canvasHostUrl = payload?['canvasHostUrl'] as String?;

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
              _handleProtocolMismatch(
                Map<String, dynamic>.from(errorRaw),
              );
            } else if (errorRaw != null) {
              msg = errorRaw.toString();
            }
            final requestId = _extractPairingRequestId(frame) ??
                _extractPairingRequestId(msg);
            final errorCode =
                errorRaw is Map ? errorRaw['code']?.toString() : null;
            final isPairingRequired =
                _isPairingRequired(msg, requestId, errorCode);
            if (isPairingRequired) {
              if (!_pairingRequiredController.isClosed) {
                _pairingRequiredController.add(requestId);
              }
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
          if (_challengeCompleter != null &&
              !_challengeCompleter!.isCompleted) {
            _challengeCompleter!.complete(nonce);
          }
          return;
        }

        _eventController.add(frame);
        // Streaming chunks (agent, chat lifecycle) carry NO id field — broadcast to
        // ALL pending requests so chat.send receives its content frames.
        // Events with an explicit id are also forwarded to the matching request.
        final id = frame['id'] as String?;
        for (final entry in _pendingRequests.entries) {
          if (!entry.value.isClosed) {
            if (id == null || id == entry.key) {
              entry.value.add(frame);
            }
          }
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
          final requestId =
              _extractPairingRequestId(frame) ?? _extractPairingRequestId(msg);
          final errorCode =
              payloadRaw is Map ? payloadRaw['code']?.toString() : null;
          final isPairingRequired =
              _isPairingRequired(msg, requestId, errorCode);
          if (isPairingRequired) {
            if (!_pairingRequiredController.isClosed) {
              _pairingRequiredController.add(requestId);
            }
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

  bool _isPairingRequired(String message, String? requestId, String? code) {
    if (requestId != null && requestId.isNotEmpty) return true;
    final lowerMessage = message.toLowerCase();
    final upperCode = code?.toUpperCase() ?? '';
    return lowerMessage.contains('pairing required') ||
        lowerMessage.contains('not paired') ||
        lowerMessage.contains('not approved') ||
        upperCode == 'NOT_PAIRED' ||
        upperCode == 'DEVICE_NOT_PAIRED' ||
        upperCode == 'TOKEN_INVALID';
  }

  String? _extractPairingRequestId(Object? value) {
    if (value is String) {
      final match = RegExp(
                  r'requestId:\s*([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})')
              .firstMatch(value) ??
          RegExp(r'"requestId"\s*:\s*"([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})"')
              .firstMatch(value);
      return match?.group(1);
    }
    if (value is Map) {
      final direct = value['requestId'];
      if (direct is String && direct.isNotEmpty) return direct;
      for (final child in value.values) {
        final match = _extractPairingRequestId(child);
        if (match != null) return match;
      }
    }
    if (value is List) {
      for (final child in value) {
        final match = _extractPairingRequestId(child);
        if (match != null) return match;
      }
    }
    return null;
  }

  void _onDisconnect({
    bool pairingRequired = false,
    bool policyRejected = false,
    bool protocolMismatch = false,
    String? requestId,
    int? closeCode,
    String? closeReason,
  }) {
    final normalizedReason = (closeReason == null || closeReason.isEmpty)
        ? 'socket-closed'
        : closeReason;

    _lastCloseCode = closeCode;
    _lastCloseReason = normalizedReason;
    _lastDisconnectAt = DateTime.now();
    if (protocolMismatch) {
      if (!_protocolMismatchDuringConnect) {
        _advanceProtocolFallback();
      } else {
        _protocolMismatchDuringConnect = true;
      }
    }
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
    if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
      _handshakeCompleter!.completeError(
        StateError(
            pairingRequired ? 'Pairing required' : 'WebSocket disconnected'),
      );
    }
    if (pairingRequired && !_pairingRequiredController.isClosed) {
      _pairingRequiredController.add(requestId);
      return;
    }
    if (policyRejected) return;
    if (protocolMismatch || _protocolMismatchDuringConnect) {
      _scheduleReconnect(fastRetry: true);
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect({bool fastRetry = false}) {
    if (_token == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;

    int delayMs;
    if (fastRetry) {
      _reconnectAttempts = 0;
      delayMs = 350;
    } else {
      _reconnectAttempts++;
      delayMs = min(
        (AppConstants.wsReconnectBaseMs *
                pow(AppConstants.wsReconnectMultiplier, _reconnectAttempts - 1))
            .toInt(),
        AppConstants.wsReconnectCapMs,
      );
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      // Guard: skip if connect() already has a _connectFuture in flight.
      // Without this, the timer and an explicit connect() call race and
      // _cleanup() in the second _doConnect() tears down the first one's channel.
      if (_connectFuture == null) _doConnect();
    });
  }

  int _sanitizeProtocol(int value) {
    if (value <= 0) return _defaultWsProtocol;
    if (value > 16) return _defaultWsProtocol;
    return value;
  }

  int _extractExpectedProtocol(Map<String, dynamic> error) {
    final details = error['details'];
    if (details is Map) {
      final expected = details['expectedProtocol'] ??
          details['protocol'] ??
          details['serverProtocol'];
      if (expected is int) return _sanitizeProtocol(expected);
      if (expected is num) return _sanitizeProtocol(expected.toInt());
      if (expected is String) {
        final parsed = int.tryParse(expected);
        if (parsed != null) return _sanitizeProtocol(parsed);
      }
    }
    return -1;
  }

  void _persistPreferredProtocol() {
    final protocol = _preferredProtocol;
    unawaited(SharedPreferences.getInstance().then(
      (prefs) => prefs.setInt(_prefWsProtocol, protocol),
    ));
  }

  void _handleProtocolMismatch(Map<String, dynamic> error) {
    final code = error['code']?.toString().toUpperCase();
    final message = error['message']?.toString().toLowerCase() ?? '';
    final isMismatch = message.contains('protocol mismatch') ||
        (code == 'INVALID_REQUEST' && message.contains('protocol'));
    if (!isMismatch) return;

    final expected = _extractExpectedProtocol(error);
    if (expected > 0 && expected != _preferredProtocol) {
      _preferredProtocol = expected;
      _persistPreferredProtocol();
      _protocolMismatchDuringConnect = true;
      return;
    }

    _advanceProtocolFallback();
  }

  void _advanceProtocolFallback() {
    final current = _sanitizeProtocol(_preferredProtocol);
    final ordered = <int>[];
    final seen = <int>{};
    for (final candidate in _protocolCandidates) {
      final p = _sanitizeProtocol(candidate);
      if (seen.add(p)) ordered.add(p);
    }
    if (!seen.contains(current)) {
      ordered.insert(0, current);
      seen.add(current);
    }

    final idx = ordered.indexOf(current);
    final next = ordered[(idx + 1) % ordered.length];
    if (next != _preferredProtocol) {
      _preferredProtocol = next;
      _persistPreferredProtocol();
    }
    _protocolMismatchDuringConnect = true;
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

    // Gateway schema: params must have 'key' (not 'sessionKey'), no 'patch' wrapper.
    // Metadata fields go directly alongside 'key' in params.
    final payload = {
      'type': 'req',
      'method': 'sessions.patch',
      'id': const Uuid().v4(),
      'params': {
        'key': mainSessionKey ?? 'main',
        ...metadata,
      },
    };

    // Fire-and-forget via direct sink — avoids registering a pending request controller
    // that would never be cleaned up (no listener → onCancel never fires), which would
    // otherwise receive and buffer every streaming chunk from subsequent chat.send calls.
    _channel!.sink.add(jsonEncode(payload));
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
    _pairingRequiredController.close();
    for (final c in _pendingRequests.values) {
      c.close();
    }
    _pendingRequests.clear();
  }
}
