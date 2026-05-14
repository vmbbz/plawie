import 'dart:async';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:io';
import '../constants.dart';
import '../models/node_frame.dart';

class NodeWsService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _frameController = StreamController<NodeFrame>.broadcast();
  final _pendingRequests = <String, Completer<NodeFrame>>{};

  bool _connected = false;
  bool _shouldReconnect = false;
  bool _pairingInProgress = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _url;
  DateTime? _lastActivity;

  Stream<NodeFrame> get frameStream => _frameController.stream;
  bool get isConnected => _connected;
  bool get isPairingInProgress => _pairingInProgress;

  // Fires when the gateway closes with 1008 (pairing required).
  final _pairingRequiredController = StreamController<String?>.broadcast();
  Stream<String?> get pairingRequiredStream =>
      _pairingRequiredController.stream;

  /// Returns true if the WebSocket hasn't received any data for over 90s,
  /// indicating the connection is likely stale.
  bool get isStale =>
      _connected &&
      _lastActivity != null &&
      DateTime.now().difference(_lastActivity!).inSeconds > 90;

  Future<void> connect(String host, int port) async {
    _url = 'ws://$host:$port';
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    await _doConnect();
  }

  Completer<void>? _socketCompleter;
  Completer<void>? _handshakeCompleter;

  Future<void> _doConnect() async {
    if (_url == null) return;

    try {
      // FIX: Explicitly send Origin header to resolve 1008 'origin-mismatch' errors.
      // We use IOWebSocketChannel directly to pass custom headers.
      final socket = await WebSocket.connect(
        _url!,
        headers: {'Origin': 'http://127.0.0.1:18789'},
      ).timeout(const Duration(seconds: 5));

      _channel = IOWebSocketChannel(socket);
      _socketCompleter = Completer<void>();
      _handshakeCompleter = Completer<void>();
      _lastActivity = DateTime.now();

      _subscription = _channel!.stream.listen(
        (data) {
          _lastActivity = DateTime.now();
          try {
            final frame = NodeFrame.decode(data as String);

            // Handle handshake (hello-ok)
            if (frame.type == 'hello-ok' ||
                (frame.payload?['type'] == 'hello-ok')) {
              if (_handshakeCompleter != null &&
                  !_handshakeCompleter!.isCompleted) {
                _handshakeCompleter!.complete();
              }
              _connected = true;
              _reconnectAttempt = 0;
              _startPing();

              // hello-ok is the response to the initial 'connect' request.
              // Some gateway versions include the original request ID, others don't.
              final requestId = frame.id;
              if (requestId != null &&
                  _pendingRequests.containsKey(requestId)) {
                _pendingRequests.remove(requestId)!.complete(frame);
              } else if (_pendingRequests.isNotEmpty) {
                // Fallback: If we have exactly one pending request (the connect one),
                // and we get hello-ok, it's likely the answer.
                final firstKey = _pendingRequests.keys.first;
                _pendingRequests.remove(firstKey)!.complete(frame);
              }
              return;
            }

            // Match pending request/response
            if (frame.isResponse && frame.id != null) {
              final completer = _pendingRequests.remove(frame.id);
              if (completer != null) {
                completer.complete(frame);
                return;
              }
            }
            _frameController.add(frame);
          } catch (_) {}
        },
        onError: (_) => _handleDisconnect(),
        onDone: () {
          // Capture close code AND reason BEFORE _handleDisconnect nulls the channel
          final closeCode = _channel?.closeCode;
          final closeReason = _channel?.closeReason ?? '';
          
          final requestIdMatch =
              RegExp(r'requestId:\s*([a-f0-9-]+)').firstMatch(closeReason);
          final requestId = requestIdMatch?.group(1);

          final pairingRequired = closeCode == 1008 &&
              (requestId != null || closeReason.contains('pairing required'));
          final policyRejected = closeCode == 1008 &&
              !pairingRequired &&
              (closeReason.contains('origin not allowed') ||
                  closeReason.contains('origin-mismatch'));

          if (pairingRequired && !_pairingRequiredController.isClosed) {
            // CRITICAL: Stop reconnect immediately and synchronously.
            _shouldReconnect = false;
            _reconnectTimer?.cancel();
            
            signalPairingRequired(requestId);
          } else if (policyRejected) {
            _shouldReconnect = false;
            _reconnectTimer?.cancel();
            // Policy rejection (Origin mismatch) — do not signal pairing, just stop.
            _frameController.add(NodeFrame.event('_policy_rejected'));
          }

          _handleDisconnect();
        },
      );

      await _channel!.ready;
      if (!_socketCompleter!.isCompleted) {
        _socketCompleter!.complete();
      }
    } catch (_) {
      _handleDisconnect();
      rethrow;
    }
  }

  /// Wait for the socket to be connected (channel.ready).
  Future<void> waitForSocket() async {
    if (_socketCompleter != null) {
      await _socketCompleter!.future;
    } else if (_channel == null) {
      throw StateError('WebSocket not connecting');
    }
  }

  /// Wait for the connection to be fully handshaked (hello-ok received).
  Future<void> waitForReady() async {
    if (_connected) return;
    if (_handshakeCompleter != null) {
      await _handshakeCompleter!.future;
    } else {
      throw StateError('WebSocket not handshaking');
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connected && _channel != null) {
        try {
          _channel!.sink.add('{"type":"ping"}');
        } catch (_) {
          _handleDisconnect();
        }
      }
    });
  }

  void _handleDisconnect() {
    if (_channel == null) return;
    _connected = false;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel = null;

    // Fail all pending requests
    for (final completer in _pendingRequests.values) {
      completer.completeError('WebSocket disconnected');
    }
    _pendingRequests.clear();

    _frameController.add(NodeFrame.event('_disconnected'));

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delayMs = min(
      (AppConstants.wsReconnectBaseMs *
              pow(AppConstants.wsReconnectMultiplier, _reconnectAttempt))
          .round(),
      AppConstants.wsReconnectCapMs,
    );
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_shouldReconnect) {
        try {
          await _doConnect();
        } catch (_) {
          // Exceptions are handled inside _doConnect, but if it throws synchronously
          // we don't want it to crash the timer.
        }
      }
    });
  }

  /// Send a request frame and wait for the matching response.
  Future<NodeFrame> sendRequest(NodeFrame request, {Duration? timeout}) async {
    // If it's the initial connect request, only wait for the socket to be up.
    // Otherwise, wait for the full handshake.
    if (request.type == 'req' && request.method == 'connect') {
      await waitForSocket();
    } else {
      await waitForReady();
    }
    if (_channel == null) {
      throw StateError('WebSocket not connected');
    }
    final completer = Completer<NodeFrame>();
    _pendingRequests[request.id!] = completer;
    _channel!.sink.add(request.encode());

    final effectiveTimeout = timeout ?? const Duration(seconds: 15);
    return completer.future.timeout(effectiveTimeout, onTimeout: () {
      _pendingRequests.remove(request.id);
      throw TimeoutException('Request timed out', effectiveTimeout);
    });
  }

  /// Send a frame without waiting for response.
  Future<void> send(NodeFrame frame) async {
    try {
      // Connect frame or events can be sent as soon as socket is ready
      if (frame.method == 'connect' || frame.type == 'event') {
        await waitForSocket();
      } else {
        await waitForReady();
      }
      if (_channel != null) {
        _channel!.sink.add(frame.encode());
      }
    } catch (_) {
      // Non-fatal for fire-and-forget send
    }
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _pairingInProgress = false; // reset so next connect() cycle can pair again
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _connected = false;
    await _channel?.sink.close();
    _channel = null;

    for (final completer in _pendingRequests.values) {
      completer.completeError('Disconnected');
    }
    _pendingRequests.clear();
  }

  /// Stop reconnect timers and close any in-flight socket connections.
  /// Use this during pairing approval to freeze all outbound traffic while
  /// letting the gateway event loop drain before the CLI approve call.
  void haltReconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    // Close the sink to abort any pending connect frame in flight.
    try {
      _channel?.sink.close();
    } catch (_) {}
  }

  /// Emit a pairing-required signal exactly once. Subsequent calls are no-ops
  /// until disconnect() resets the flag, preventing duplicate approval flows.
  void signalPairingRequired(String? requestId) {
    if (_pairingInProgress) return;
    _pairingInProgress = true;
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    if (!_pairingRequiredController.isClosed) {
      _pairingRequiredController.add(requestId);
    }
  }

  /// Re-enable auto-reconnect after a pairing approval sequence and schedule
  /// the next attempt after [delayMs]. Resets backoff so reconnect is prompt.
  void resumeReconnect({int delayMs = 1500}) {
    if (_url == null) return;
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_shouldReconnect) {
        try {
          await _doConnect();
        } catch (_) {}
      }
    });
  }

  void dispose() {
    disconnect();
    _frameController.close();
    _pairingRequiredController.close();
  }
}
