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
  Duration? _nextReconnectDelayOverride;
  Timer? _pingTimer;
  String? _url;
  String? _connectRequestId;
  DateTime? _lastActivity;
  int? _lastCloseCode;
  String? _lastCloseReason;
  DateTime? _lastDisconnectAt;
  bool _connectAttemptInFlight = false;
  bool _disconnectInProgress = false;

  Stream<NodeFrame> get frameStream => _frameController.stream;
  bool get isConnected => _connected;
  bool get isPairingInProgress => _pairingInProgress;
  Future<void> Function()? onReconnectReady;
  int? get lastCloseCode => _lastCloseCode;
  String? get lastCloseReason => _lastCloseReason;
  DateTime? get lastDisconnectAt => _lastDisconnectAt;

  // Fires when the gateway closes with 1008 (pairing required).
  final _pairingRequiredController = StreamController<String?>.broadcast();
  Stream<String?> get pairingRequiredStream =>
      _pairingRequiredController.stream;

  // Fires when the gateway is busy or starting (1005 or startup-sidecars-pending).
  final _warmingUpController = StreamController<void>.broadcast();
  Stream<void> get warmingUpStream => _warmingUpController.stream;

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
    _reconnectTimer?.cancel();
    await _doConnect();
  }

  Completer<void>? _socketCompleter;
  Completer<void>? _handshakeCompleter;

  void _resetConnectCompleters(Object error) {
    final socket = _socketCompleter;
    if (socket != null && !socket.isCompleted) {
      socket.completeError(error);
    }
    final handshake = _handshakeCompleter;
    if (handshake != null && !handshake.isCompleted) {
      handshake.completeError(error);
    }
    _socketCompleter = null;
    _handshakeCompleter = null;
  }

  Future<void> _doConnect({bool notifyReady = false}) async {
    if (_url == null) return;
    if (_connectAttemptInFlight) {
      await _waitForExistingSocketAttempt();
      return;
    }
    _connectAttemptInFlight = true;

    try {
      // FIX: Explicitly send Origin header to resolve 1008 'origin-mismatch' errors.
      // We use IOWebSocketChannel directly to pass custom headers.
      final socket = await WebSocket.connect(
        _url!,
        headers: {'Origin': 'http://127.0.0.1:18789'},
      ).timeout(
          const Duration(seconds: 45)); // Increased for high-load PRoot stalls

      _channel = IOWebSocketChannel(socket);
      _socketCompleter = Completer<void>();
      _handshakeCompleter = Completer<void>();
      _lastActivity = DateTime.now();

      _subscription = _channel!.stream.listen(
        (data) {
          _lastActivity = DateTime.now();
          try {
            final frame = NodeFrame.decode(data as String);

            // Legacy compatibility: some older gateways emit a synthetic hello-ok.
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
              if (frame.id == _connectRequestId) {
                _connectRequestId = null;
                if (frame.isOk) {
                  if (_handshakeCompleter != null &&
                      !_handshakeCompleter!.isCompleted) {
                    _handshakeCompleter!.complete();
                  }
                  _connected = true;
                  _reconnectAttempt = 0;
                  _startPing();
                } else {
                  if (_handshakeCompleter != null &&
                      !_handshakeCompleter!.isCompleted) {
                    final message = frame.error?['message']?.toString() ??
                        'connect rejected';
                    _handshakeCompleter!.completeError(StateError(message));
                  }
                }
              }
              final completer = _pendingRequests.remove(frame.id);
              if (completer != null) {
                completer.complete(frame);
                return;
              }
            }
            _frameController.add(frame);
          } catch (_) {}
        },
        onError: (error) => _handleDisconnect(
          closeReason: 'socket-error: $error',
        ),
        onDone: () {
          // Capture close code AND reason BEFORE _handleDisconnect nulls the channel
          final closeCode = _channel?.closeCode;
          final closeReason = _channel?.closeReason ?? '';

          final requestIdMatch = RegExp(
                  r'requestId:\s*([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})')
              .firstMatch(closeReason);
          final requestId = requestIdMatch?.group(1);

          final pairingRequired = closeCode == 1008 &&
              (requestId != null || closeReason.contains('pairing required'));
          final policyRejected = closeCode == 1008 &&
              !pairingRequired &&
              (closeReason.contains('origin not allowed') ||
                  closeReason.contains('origin-mismatch'));
          final warmingUp = closeReason.contains('startup-sidecars-pending') ||
              closeReason.contains('gateway starting') ||
              closeCode == 1005;

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
          } else if (warmingUp) {
            // Gateway is busy/starting. Slow down reconnect.
            _nextReconnectDelayOverride = const Duration(seconds: 10);
            if (!_warmingUpController.isClosed) {
              _warmingUpController.add(null);
            }
          }

          _handleDisconnect(closeCode: closeCode, closeReason: closeReason);
        },
      );

      await _channel!.ready;
      if (!_socketCompleter!.isCompleted) {
        _socketCompleter!.complete();
      }
      if (notifyReady) {
        final callback = onReconnectReady;
        if (callback != null) {
          unawaited(callback());
        }
      }
    } catch (_) {
      _handleDisconnect(closeReason: 'connect-failed');
      rethrow;
    } finally {
      _connectAttemptInFlight = false;
    }
  }

  /// Wait for the socket to be connected (channel.ready).
  Future<void> waitForSocket() async {
    var completer = _socketCompleter;
    if (completer == null && _connectAttemptInFlight) {
      await _waitForExistingSocketAttempt();
      completer = _socketCompleter;
    }
    if (completer == null && _channel == null) {
      // Race guard: a caller can hit waitForSocket() just after a reconnect
      // disconnect reset the previous completer. Try one immediate re-connect
      // before surfacing "WebSocket not connecting".
      if (_url != null && _shouldReconnect && !_connectAttemptInFlight) {
        try {
          await _doConnect();
        } catch (_) {}
      }
      completer = _socketCompleter;
    }
    if (completer == null) {
      throw StateError('WebSocket not connecting');
    }
    await completer.future;
    if (_channel == null) {
      throw StateError('WebSocket not connected');
    }
  }

  Future<void> _waitForExistingSocketAttempt() async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(deadline)) {
      final completer = _socketCompleter;
      if (completer != null) {
        await completer.future;
        return;
      }
      if (!_connectAttemptInFlight) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Wait for the connection to be fully handshaked (hello-ok received).
  Future<void> waitForReady() async {
    if (_connected) return;
    final completer = _handshakeCompleter;
    if (completer == null) {
      throw StateError('WebSocket not handshaking');
    }
    await completer.future;
    if (!_connected) {
      throw StateError('WebSocket handshake not completed');
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connected && _channel != null) {
        try {
          _channel!.sink.add('{"type":"ping"}');
        } catch (_) {
          _handleDisconnect(closeReason: 'ping-send-failed');
        }
      }
    });
  }

  void _handleDisconnect({int? closeCode, String? closeReason}) {
    if (_disconnectInProgress) return;
    _disconnectInProgress = true;
    try {
      final normalizedReason = (closeReason == null || closeReason.isEmpty)
          ? 'socket-closed'
          : closeReason;

      _lastCloseCode = closeCode;
      _lastCloseReason = normalizedReason;
      _lastDisconnectAt = DateTime.now();
      _connected = false;
      _connectRequestId = null;
      _pingTimer?.cancel();
      _subscription?.cancel();
      _channel = null;

      // Fail all pending requests
      for (final completer in _pendingRequests.values) {
        completer.completeError('WebSocket disconnected');
      }
      _pendingRequests.clear();
      _resetConnectCompleters(StateError('WebSocket disconnected'));

      _frameController.add(NodeFrame.event('_disconnected', {
        if (closeCode != null) 'closeCode': closeCode,
        'closeReason': normalizedReason,
        if (_lastDisconnectAt != null)
          'at': _lastDisconnectAt!.toIso8601String(),
      }));

      if (_shouldReconnect) {
        _scheduleReconnect();
      }
    } finally {
      _disconnectInProgress = false;
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    int delayMs;

    if (_nextReconnectDelayOverride != null) {
      delayMs = _nextReconnectDelayOverride!.inMilliseconds;
      _nextReconnectDelayOverride = null; // Clear after use
    } else {
      delayMs = min(
        (AppConstants.wsReconnectBaseMs *
                pow(AppConstants.wsReconnectMultiplier, _reconnectAttempt))
            .round(),
        AppConstants.wsReconnectCapMs,
      );
    }
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_shouldReconnect) {
        try {
          await _doConnect(notifyReady: true);
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
    if (request.type == 'req' && request.method == 'connect') {
      _connectRequestId = request.id;
    }
    final completer = Completer<NodeFrame>();
    _pendingRequests[request.id!] = completer;
    _channel!.sink.add(request.encode());

    final effectiveTimeout = timeout ??
        const Duration(seconds: 30); // Increased for gateway handshakes
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
    _resetConnectCompleters(StateError('Disconnected'));

    for (final completer in _pendingRequests.values) {
      completer.completeError('Disconnected');
    }
    _pendingRequests.clear();
  }

  /// Close the current socket but keep auto-reconnect enabled.
  ///
  /// Used when the app detects a bad/stale handshake before sending `connect`.
  /// Calling disconnect() would disable reconnect entirely, which is too harsh
  /// for transient gateway settle races.
  Future<void> forceReconnect({String reason = 'manual-reconnect'}) async {
    if (_url == null) return;
    _shouldReconnect = true;
    _reconnectTimer?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _handleDisconnect(closeReason: reason);
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
          await _doConnect(notifyReady: true);
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
