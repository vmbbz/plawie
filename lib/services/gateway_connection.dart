import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../constants.dart';

/// Persistent WebSocket connection to the OpenClaw gateway.
///
/// Maintains a single WS connection with:
/// - Automatic reconnect on disconnect (exponential backoff)
/// - Proper OpenClaw Protocol v3 handshake
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
  static const _maxReconnectAttempts = 10;

  final _stateNotifier = StreamController<GatewayConnectionState>.broadcast();
  Stream<GatewayConnectionState> get stateStream => _stateNotifier.stream;

  // Pending request completers — keyed by request ID
  final Map<String, StreamController<Map<String, dynamic>>> _pendingRequests = {};

  // Global event stream for unsolicited events (chat, etc.)
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  Completer<void>? _handshakeCompleter;

  /// Connect to the gateway with the given auth token.
  Future<bool> connect(String token) async {
    if (_state == GatewayConnectionState.connected && _token == token) {
      return true; // Already connected
    }

    _token = token;
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

    // Listen for frames
    _subscription = _channel!.stream.listen(
      _onFrame,
      onError: (_) => _onDisconnect(),
      onDone: _onDisconnect,
    );

    // Send Protocol v3 connect frame.
    // Local connections (127.0.0.1) auto-approve pairing, so device
    // identity/signing is not required.
    final connectId = const Uuid().v4();
    _channel!.sink.add(jsonEncode({
      'type': 'req',
      'id': connectId,
      'method': 'connect',
      'params': {
        'minProtocol': 3,
        'maxProtocol': 3,
        'client': {
          'id': AppConstants.packageName,
          'version': AppConstants.version,
          'platform': 'android',
          'mode': 'node',
        },
        'role': 'node',
        'scopes': ['chat', 'system'],
        'auth': {'token': _token},
        'locale': 'en-US',
      },
    }));

    // Wait for hello-ok (increased timeout for slower devices)
    try {
      await _handshakeCompleter!.future.timeout(const Duration(seconds: 10));
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

  void _onFrame(dynamic raw) {
    try {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = frame['type'] as String?;

      // Handshake response
      if (type == 'hello-ok') {
        if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
          _handshakeCompleter!.complete();
        }
        return;
      }

      // Response to a pending request
      if (type == 'res' && frame['id'] != null) {
        final id = frame['id'] as String;
        if (_pendingRequests.containsKey(id)) {
          _pendingRequests[id]!.add(frame);
        }
        return;
      }

      // Events (chat deltas, etc.)
      if (type == 'event') {
        _eventController.add(frame);
        // Broadcast to all pending request handlers
        for (final controller in _pendingRequests.values) {
          controller.add(frame);
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
          _channel!.sink.add(jsonEncode({
            'type': 'req',
            'method': 'ping',
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
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _updateState(GatewayConnectionState newState) {
    _state = newState;
    _stateNotifier.add(newState);
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
