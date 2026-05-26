import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/native_bridge.dart';
import '../services/node_service.dart';
import '../services/preferences_service.dart';
import '../services/capabilities/capability_handler.dart';
import '../models/node_state.dart';
import '../models/node_frame.dart';
import '../models/gateway_state.dart';
import 'gateway_provider.dart' as svc_gateway;
import '../services/capabilities/camera_capability.dart';
import '../services/capabilities/canvas_capability.dart';
import '../services/capabilities/location_capability.dart';
import '../services/capabilities/screen_capability.dart';
import '../services/capabilities/flash_capability.dart';
import '../services/capabilities/vibration_capability.dart';
import '../services/capabilities/sensor_capability.dart';

class NodeProvider extends ChangeNotifier with WidgetsBindingObserver {
  final NodeService _nodeService = NodeService();
  StreamSubscription? _subscription;
  NodeState _state = const NodeState();
  svc_gateway.GatewayProvider? _gatewayProvider;
  GatewayState? _lastGatewayState;
  Timer? _watchdog;
  DateTime? _lastGatewaySettlingLogAt;
  bool _permissionRequestInFlight = false;

  // Capabilities
  final _cameraCapability = CameraCapability();
  final _canvasCapability = CanvasCapability();
  final _flashCapability = FlashCapability();
  final _locationCapability = LocationCapability();
  final _screenCapability = ScreenCapability();
  final _sensorCapability = SensorCapability();
  final _vibrationCapability = VibrationCapability();

  NodeState get state => _state;

  bool get _localGatewayReadyForNode =>
      _gatewayProvider?.state.isInteractiveReady == true;

  bool _isLocalHost(String? host) {
    final value = (host ?? '127.0.0.1').trim().toLowerCase();
    return value.isEmpty || value == '127.0.0.1' || value == 'localhost';
  }

  void _logGatewaySettlingOnce() {
    final now = DateTime.now();
    final last = _lastGatewaySettlingLogAt;
    if (last != null && now.difference(last) < const Duration(seconds: 20)) {
      return;
    }
    _lastGatewaySettlingLogAt = now;
    _nodeService.log(
        '[NODE] Local gateway still settling; pairing waits for RPC/skills readiness');
  }

  NodeProvider() {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _nodeService.stateStream.listen((state) {
      _state = state;
      _updateServiceNotification(state);
      notifyListeners();
    });
    _registerCapabilities();
    _init();
  }

  /// Keep the foreground notification text in sync with the node status.
  void _updateServiceNotification(NodeState state) {
    if (state.isDisabled) return;
    String text;
    switch (state.status) {
      case NodeStatus.paired:
        text = 'Node connected';
        break;
      case NodeStatus.connecting:
      case NodeStatus.challenging:
      case NodeStatus.pairing:
        text = 'Node connecting...';
        break;
      case NodeStatus.disconnected:
        text = 'Node reconnecting...';
        break;
      case NodeStatus.warmingUp:
        text = 'Node warming up...';
        break;
      case NodeStatus.error:
        text = 'Node error — retrying';
        break;
      case NodeStatus.disabled:
        return;
    }
    try {
      NativeBridge.updateNodeNotification(text);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _onAppPaused();
    }
  }

  /// App returned to foreground — force connection health check.
  /// Dart timers freeze while backgrounded, so the watchdog and ping
  /// timers won't have fired.  We must check and reconnect manually.
  Future<void> _onAppResumed() async {
    if (_state.isDisabled) return;

    // Ensure the foreground service is still alive
    try {
      final running = await NativeBridge.isNodeServiceRunning();
      if (!running) {
        await NativeBridge.startNodeService();
      }
    } catch (_) {}

    if (_isLocalHost(_state.gatewayHost) && !_localGatewayReadyForNode) {
      _logGatewaySettlingOnce();
      _startWatchdog();
      return;
    }

    if (_state.isPaired &&
        _nodeService.isConnectionStale &&
        !_state.isConnecting) {
      // WebSocket went stale while in background — force reconnect
      await _nodeService.disconnect();
      await _nodeService.connect();
    } else if ((_state.status == NodeStatus.disconnected ||
            _state.status == NodeStatus.warmingUp ||
            _state.status == NodeStatus.error) &&
        !_state.isConnecting) {
      // Connection dropped while in background
      await _nodeService.connect();
    }

    // Restart watchdog (may have been frozen)
    _startWatchdog();
  }

  /// App going to background — ensure the foreground service is running
  /// so Android keeps our process alive.
  Future<void> _onAppPaused() async {
    if (_state.isDisabled) return;

    try {
      final running = await NativeBridge.isNodeServiceRunning();
      if (!running) {
        await NativeBridge.startNodeService();
      }
    } catch (_) {}
  }

  void _registerCapabilityAliases(
    CapabilityHandler capability,
    Future<NodeFrame> Function(String command, Map<String, dynamic> params)
        handler,
  ) {
    final commands = <String>{};
    for (final command in capability.commands) {
      final canonical = '${capability.name}.$command';
      commands.add(canonical);
      commands.add('${capability.name}_$command');

      // OpenClaw commonly exposes haptics as both haptic.vibrate and vibrate.
      if (capability.name == 'haptic' && command == 'vibrate') {
        commands.add('vibrate');
      }
    }

    _nodeService.registerCapability(
      capability.name,
      commands.toList()..sort(),
      (command, params) =>
          handler(_canonicalNodeCommand(capability.name, command), params),
    );
  }

  String _canonicalNodeCommand(String capabilityName, String command) {
    final trimmed = command.trim();
    if (capabilityName == 'haptic' && trimmed == 'vibrate') {
      return 'haptic.vibrate';
    }

    final aliasPrefix = '${capabilityName}_';
    if (trimmed.startsWith(aliasPrefix)) {
      return '$capabilityName.${trimmed.substring(aliasPrefix.length)}';
    }

    return trimmed;
  }

  void _registerCapabilities() {
    _registerCapabilityAliases(
      _cameraCapability,
      (cmd, params) => _cameraCapability.handleWithPermission(cmd, params),
    );
    _registerCapabilityAliases(
      _canvasCapability,
      (cmd, params) => _canvasCapability.handle(cmd, params),
    );
    _registerCapabilityAliases(
      _locationCapability,
      (cmd, params) => _locationCapability.handleWithPermission(cmd, params),
    );
    _registerCapabilityAliases(
      _screenCapability,
      (cmd, params) => _screenCapability.handle(cmd, params),
    );
    _registerCapabilityAliases(
      _flashCapability,
      (cmd, params) => _flashCapability.handleWithPermission(cmd, params),
    );
    _registerCapabilityAliases(
      _vibrationCapability,
      (cmd, params) => _vibrationCapability.handle(cmd, params),
    );
    _registerCapabilityAliases(
      _sensorCapability,
      (cmd, params) => _sensorCapability.handleWithPermission(cmd, params),
    );
  }

  Future<void> _init() async {
    await _nodeService.init();
    final prefs = PreferencesService();
    await prefs.init();
    if (prefs.nodeEnabled) {
      _nodeService.log('[NODE] Node enabled; waiting for gateway readiness');
      _state = _state.copyWith(status: NodeStatus.disconnected);
      notifyListeners();

      // Permissions are useful before tool invocation, but they must not block
      // the node identity/handshake path. On app-update and background resume
      // Android may defer permission UI, leaving the node service running while
      // Dart still thinks it is disabled.
      unawaited(_requestNodePermissions());
      unawaited(_requestBatteryOptimization());
      await NativeBridge.startNodeService();
      // NOTE: We do NOT call _nodeService.connect() here anymore.
      // Connection is triggered via onGatewayStateUpdate once the gateway
      // is confirmed to be running, or by the watchdog.
      _startWatchdog();

      // REGISTER DEVICE NODES
      await _registerDeviceNodes();

      _startWatchdog();
    }
  }

  Future<void> _registerDeviceNodes() async {
    try {
      // Get device info using existing methods
      final arch = await NativeBridge.getArch();
      final filesDir = await NativeBridge.getFilesDir();

      // Create simple device info for logging
      final deviceInfo = {
        'deviceId': filesDir.hashCode.toString(),
        'deviceName': 'Flutter Device ($arch)',
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'arch': arch,
        'capabilities': [
          'camera.snap',
          'camera.clip',
          'camera.list',
          'location.get',
          'sensor.read',
          'sensor.list',
          'screen.record',
          'haptic.vibrate',
        ],
      };

      // Log device registration (simplified approach)
      debugPrint(
          'Device capabilities registered: ${deviceInfo['capabilities']}');

      // The capabilities are already registered in _registerCapabilities()
      // This is just for logging/debugging purposes
    } catch (e) {
      // Device registration failed - continue with gateway connection
      debugPrint('Device node registration failed: $e');
    }
  }

  void onGatewayStateUpdate(svc_gateway.GatewayProvider gatewayProvider) {
    _gatewayProvider = gatewayProvider;
    final gatewayState = gatewayProvider.state;
    final wasRunning = _lastGatewayState?.isRunning ?? false;
    final isRunning = gatewayState.isRunning;
    final wasInteractiveReady = _lastGatewayState?.isInteractiveReady ?? false;
    final isInteractiveReady = gatewayState.isInteractiveReady;
    _lastGatewayState = gatewayState;

    if (!wasInteractiveReady && isInteractiveReady) {
      // Gateway just became fully interactive - force sync connection status.
      // This ensures any "Connection failed" errors from when the gateway was down
      // are promptly cleared as the node completes its challenge.
      _checkAutoConnect();
    } else if (wasRunning && !isRunning && !_state.isDisabled) {
      // Gateway stopped - disconnect node and stop foreground service
      _stopWatchdog();
      _nodeService.disconnect();
      NativeBridge.stopNodeService();
    }
  }

  Future<void> _checkAutoConnect() async {
    final prefs = PreferencesService();
    await prefs.init();
    if (prefs.nodeEnabled) {
      if (_isLocalHost(prefs.nodeGatewayHost) && !_localGatewayReadyForNode) {
        _logGatewaySettlingOnce();
        _startWatchdog();
        return;
      }
      _nodeService.log('[NODE] Gateway ready; auto-connect check running');
      unawaited(_requestNodePermissions());
      // Ensure foreground service is running before connecting
      try {
        final running = await NativeBridge.isNodeServiceRunning();
        if (!running) {
          await NativeBridge.startNodeService();
        }
      } catch (_) {}
      if (!_state.isConnecting &&
          _state.status != NodeStatus.paired &&
          _state.status != NodeStatus.pairing) {
        _nodeService.log('[NODE] Auto-connect starting handshake');
        await _nodeService.connect();
      }
      _startWatchdog();
    }
  }

  /// Request runtime permissions proactively so they are granted before
  /// the gateway sends invoke requests (which would otherwise be blocked).
  Future<void> _requestNodePermissions() async {
    if (_permissionRequestInFlight) return;
    _permissionRequestInFlight = true;
    try {
      await [
        Permission.camera,
        Permission.location,
        Permission.sensors,
      ].request();
    } catch (e) {
      _nodeService.log('[NODE] Permission request skipped: $e');
    } finally {
      _permissionRequestInFlight = false;
    }
  }

  /// Prompt user to disable battery optimization so Android doesn't kill
  /// the app process while the node is connected in the background.
  Future<void> _requestBatteryOptimization() async {
    try {
      final optimized = await NativeBridge.isBatteryOptimized();
      if (optimized) {
        await NativeBridge.requestBatteryOptimization();
      }
    } catch (_) {}
  }

  /// Periodic watchdog that detects stale/dropped connections and forces
  /// reconnect. Runs every 45s. Handles two cases:
  /// 1. Node should be connected but isn't (dropped in background)
  /// 2. Node appears paired but WebSocket is stale (no data for 90s+)
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 45), (_) async {
      if (_state.isDisabled) return;

      // Also verify foreground service is still alive
      try {
        final running = await NativeBridge.isNodeServiceRunning();
        if (!running && !_state.isDisabled) {
          await NativeBridge.startNodeService();
        }
      } catch (_) {}

      final shouldReconnect = (_state.status == NodeStatus.disconnected ||
              _state.status == NodeStatus.warmingUp ||
              _state.status == NodeStatus.error) &&
          !_state.isConnecting &&
          _state.status != NodeStatus.pairing;
      final canUseGateway = !_isLocalHost(_state.gatewayHost) ||
          (_lastGatewayState?.isInteractiveReady ?? false);
      if (shouldReconnect && canUseGateway) {
        // Connection dropped and gateway is up — reconnect
        _nodeService.connect();
      } else if (_state.isPaired &&
          _nodeService.isConnectionStale &&
          canUseGateway) {
        // Connection appears alive but no data received — force reconnect
        _nodeService.disconnect().then((_) => _nodeService.connect());
      }
    });
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  Future<void> enable() async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.nodeEnabled = true;
    await _requestNodePermissions();
    await _requestBatteryOptimization();

    // Ensure latest compatibility shims are deployed
    try {
      await NativeBridge.installBionicBypass();
    } catch (_) {}

    await NativeBridge.startNodeService();
    if (!_isLocalHost(_state.gatewayHost) || _localGatewayReadyForNode) {
      await _nodeService.connect();
    } else {
      _logGatewaySettlingOnce();
    }
    _startWatchdog();
  }

  Future<void> disable() async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.nodeEnabled = false;
    _stopWatchdog();
    await _nodeService.disable();
    await NativeBridge.stopNodeService();
  }

  Future<void> connectRemote(String host, int port, {String? token}) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.nodeGatewayHost = host;
    prefs.nodeGatewayPort = port;
    prefs.nodeGatewayToken = token;
    prefs.nodeEnabled = true;
    // Clear cached token so it re-reads on next connect
    _nodeService.clearCachedToken();
    await _requestNodePermissions();
    await _requestBatteryOptimization();
    await NativeBridge.startNodeService();
    await _nodeService.connect(host: host, port: port);
    _startWatchdog();
  }

  Future<void> reconnect() async {
    if (_isLocalHost(_state.gatewayHost) && !_localGatewayReadyForNode) {
      _logGatewaySettlingOnce();
      return;
    }
    await _nodeService.disconnect();
    await _nodeService.connect();
  }

  Future<void> refreshToken() async {
    if (_gatewayProvider == null) {
      _nodeService.log('[NODE] GatewayProvider not available');
      return;
    }
    _nodeService.log('[NODE] Manually refreshing gateway token...');
    await _gatewayProvider!.refreshDashboardUrl();
    _nodeService.clearCachedToken();
    await reconnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopWatchdog();
    _subscription?.cancel();
    _nodeService.dispose();
    _cameraCapability.dispose();
    _flashCapability.dispose();
    NativeBridge.stopNodeService();
    super.dispose();
  }
}
