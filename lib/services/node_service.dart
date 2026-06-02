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
  bool _pairingSnapshotRepairInFlight = false;
  int _preferredConnectProtocol = AppConstants.wsProtocolMaxVersion;
  DateTime? _pairingRetryNotBefore;
  int _pairingApprovalFailureCount = 0;

  NodeState _state = const NodeState();
  final Map<String, Future<NodeFrame> Function(String, Map<String, dynamic>)>
      _capabilityHandlers = {};
  Future<bool> Function(String requestId)? approvePairingRequestViaGateway;
  String? _gatewayAuthToken;
  String? _liveNativeCommandContractHash;
  Completer<String?>? _challengeCompleter;
  String? _cachedChallengeNonce;
  DateTime? _cachedChallengeReceivedAt;
  Future<void>? _initFuture;
  static const Duration _challengeNonceTtl = Duration(seconds: 5);
  static const Duration _challengeWaitTimeout = Duration(seconds: 12);
  static final _uuidPattern =
      RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$');
  static final _uuidSearchPattern =
      RegExp(r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}');

  Stream<NodeState> get stateStream => _stateController.stream;
  NodeState get state => _state;
  bool get isConnectionStale => _ws.isStale;
  bool get isConnected => _ws.isConnected;

  void clearCachedToken() => _gatewayAuthToken = null;

  Future<bool> _nativeOwnerSelected() async {
    try {
      final prefs = PreferencesService();
      await prefs.init();
      return prefs.gatewayRuntimeOwner ==
          PreferencesService.gatewayRuntimeOwnerNativeProduction;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _openClawStoreRoots() async {
    final filesDir = await NativeBridge.getFilesDir();
    final nativeRoot = '$filesDir/native-node-embedded/native-home/.openclaw';
    final prootRoot = '$filesDir/rootfs/ubuntu/root/.openclaw';
    final nativeSelected = await _nativeOwnerSelected();
    return nativeSelected
        ? <String>[nativeRoot, prootRoot]
        : <String>[prootRoot, nativeRoot];
  }

  Future<List<File>> _openClawStoreFiles(String relativePath) async {
    final roots = await _openClawStoreRoots();
    return roots.map((root) => File('$root/$relativePath')).toList();
  }

  Future<Object?> _readFirstOpenClawStoreJson(String relativePath) async {
    for (final file in await _openClawStoreFiles(relativePath)) {
      try {
        if (!await file.exists()) continue;
        final raw = await file.readAsString();
        if (raw.trim().isEmpty) continue;
        return jsonDecode(raw);
      } catch (_) {}
    }
    return null;
  }

  Future<List<Object>> _readAllOpenClawStoreJson(String relativePath) async {
    final values = <Object>[];
    for (final file in await _openClawStoreFiles(relativePath)) {
      try {
        if (!await file.exists()) continue;
        final raw = await file.readAsString();
        if (raw.trim().isEmpty) continue;
        values.add(jsonDecode(raw) as Object);
      } catch (_) {}
    }
    return values;
  }

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

  Future<void> init() => _initFuture ??= _initInternal();

  Future<void> _initInternal() async {
    await _identity.init();
    final prefs = PreferencesService();
    await prefs.init();
    await _ensurePairingMatchesDeclaredCommands(prefs);
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

  Future<void> _ensurePairingMatchesDeclaredCommands(
    PreferencesService prefs,
  ) async {
    if (_capabilityHandlers.isEmpty) {
      return;
    }

    final signature = _declaredCommandContractSignature();
    final previousSignature = prefs.nodeCommandContractHash;

    if (previousSignature == signature) {
      return;
    }

    if (await _pairedNodeCommandsCoverDeclared()) {
      prefs.nodeCommandContractHash = signature;
      return;
    }

    prefs.nodeCommandContractHash = signature;

    // OpenClaw stores command allow/deny expectations at pairing time. When we
    // change the declared command surface, the old node token can stay "paired"
    // while invoke calls are rejected. Force a clean re-pair once per contract
    // revision so the gateway refreshes the command snapshot.
    prefs.nodeDeviceToken = null;
    _gatewayAuthToken = null;

    final deviceId = _identity.deviceId ?? '';
    if (deviceId.isEmpty) {
      return;
    }

    log('[NODE] Command contract changed; refreshing gateway pairing snapshot.');
    await _removePairedGatewayDevice(
      deviceId,
      successLog:
          '[NODE] Cleared stale paired-node record for updated command contract',
    );
  }

  Future<void> _repairPairedNodeSnapshot(PreferencesService prefs) async {
    if (_pairingSnapshotRepairInFlight) return;
    _pairingSnapshotRepairInFlight = true;
    try {
      if (!await _pairedNodeSnapshotNeedsCommandRepair()) return;

      log('[NODE] Paired gateway snapshot is missing node commands; repairing pairing snapshot.');
      _gatewayAuthToken = null;
      _pairingResolveAttempted = false;

      if (await _approvePendingNodePairingSnapshot(prefs)) {
        return;
      }

      prefs.nodeDeviceToken = null;
      prefs.nodeCommandContractHash = null;
      try {
        final approvedToken = await _approveNodeViaDevicePairing(null);
        if (approvedToken != null && approvedToken.isNotEmpty) {
          prefs.nodeDeviceToken = approvedToken;
          final preview = approvedToken.length > 8
              ? '${approvedToken.substring(0, 8)}...'
              : approvedToken;
          log('[NODE] Approved pending node command snapshot ($preview)');
        } else {
          log('[NODE] Pending node snapshot approved; token will be learned on reconnect');
        }

        await Future.delayed(const Duration(milliseconds: 250));
        if (!await _pairedNodeSnapshotNeedsCommandRepair()) {
          prefs.nodeCommandContractHash = _declaredCommandContractSignature();
          return;
        }
        log('[NODE] Pending approval did not refresh command snapshot; removing stale paired record');
      } catch (e) {
        log('[NODE] Pending node snapshot approval unavailable: $e');
      }

      prefs.nodeDeviceToken = null;
      _gatewayAuthToken = null;
      final deviceId = _identity.deviceId ?? '';
      if (deviceId.isNotEmpty) {
        await _removePairedGatewayDevice(
          deviceId,
          successLog:
              '[NODE] Removed stale paired-node snapshot missing commands',
        );
      }
    } finally {
      _pairingSnapshotRepairInFlight = false;
    }
  }

  Future<bool> _removePairedGatewayDevice(
    String deviceId, {
    String? successLog,
  }) async {
    if (deviceId.isEmpty) return false;
    if (await _nativeOwnerSelected()) {
      final removed =
          await _removePairedGatewayDeviceFromNativeStores(deviceId);
      if (removed && successLog != null) log(successLog);
      if (!removed) {
        log('[NODE] Native owner: no paired-node store record found to remove; skipping PRoot CLI.');
      }
      return removed;
    }

    try {
      await NativeBridge.runInProot(
        '$kOpenClawCommand devices remove ${NativeBridge.shellQuote(deviceId)} --json',
        timeout: 20,
      );
      if (successLog != null) log(successLog);
      return true;
    } catch (_) {
      try {
        await NativeBridge.runInProot(
          '$kOpenClawCommand devices remove ${NativeBridge.shellQuote(deviceId)}',
          timeout: 20,
        );
        if (successLog != null) log(successLog);
        return true;
      } catch (_) {
        // Best effort only; if remove is unavailable or the record does not
        // exist, token reset still forces the requestId-based approval path.
        return false;
      }
    }
  }

  Future<bool> _removePairedGatewayDeviceFromNativeStores(
    String deviceId,
  ) async {
    var removed = false;
    for (final relativePath in const [
      'devices/paired.json',
      'nodes/paired.json',
    ]) {
      final file = (await _openClawStoreFiles(relativePath)).first;
      try {
        if (!await file.exists()) continue;
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map) continue;
        final map = Map<String, dynamic>.from(decoded);
        if (_removeDeviceRecordFromJsonMap(map, deviceId)) {
          await file.writeAsString(jsonEncode(map));
          removed = true;
        }
      } catch (_) {}
    }
    return removed;
  }

  bool _removeDeviceRecordFromJsonMap(
    Map<String, dynamic> map,
    String deviceId,
  ) {
    var removed = false;
    if (map.remove(deviceId) != null) removed = true;

    for (final key in map.keys.toList()) {
      final value = map[key];
      if (value is Map) {
        final child = Map<String, dynamic>.from(value);
        final mentionsDevice = _containsStringValue(child, deviceId);
        final mentionsNodeRole =
            _containsStringValue(child, AppConstants.nodeRole);
        if (mentionsDevice && mentionsNodeRole) {
          map.remove(key);
          removed = true;
          continue;
        }
        if (_removeDeviceRecordFromJsonMap(child, deviceId)) {
          map[key] = child;
          removed = true;
        }
      } else if (value is List) {
        final filtered = <Object?>[];
        for (final child in value) {
          if (child is Map) {
            final childMap = Map<String, dynamic>.from(child);
            final mentionsDevice = _containsStringValue(childMap, deviceId);
            final mentionsNodeRole =
                _containsStringValue(childMap, AppConstants.nodeRole);
            if (mentionsDevice && mentionsNodeRole) {
              removed = true;
              continue;
            }
            if (_removeDeviceRecordFromJsonMap(childMap, deviceId)) {
              filtered.add(childMap);
              removed = true;
              continue;
            }
          }
          filtered.add(child);
        }
        if (filtered.length != value.length) {
          map[key] = filtered;
        }
      }
    }
    return removed;
  }

  Future<bool> _pairedNodeSnapshotNeedsCommandRepair() async {
    if (_capabilityHandlers.isEmpty) return false;
    final deviceId = _identity.deviceId ?? '';
    if (deviceId.isEmpty) return false;

    if (await _liveNativePairingCoversDeclaredCommands()) {
      return false;
    }

    if (await _nativeOwnerSelected() &&
        await _nativeStoredContractAlreadyAccepted()) {
      return false;
    }

    try {
      if (await _pairedNodeCommandsCoverDeclared()) return false;
      if (await _readPendingNodePairingRequestIdFromStore() != null) {
        return true;
      }

      final declaredCommands = _capabilityHandlers.keys.toSet();
      for (final decoded
          in await _readAllOpenClawStoreJson('devices/paired.json')) {
        final record = _findDeviceRecord(decoded, deviceId);
        if (record == null) continue;
        if (!_recordHasRole(record, AppConstants.nodeRole)) continue;

        final pairedCommands = _stringSet(record['commands']);
        if (pairedCommands.isEmpty) return true;
        return !declaredCommands.every(pairedCommands.contains);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _liveNativePairingCoversDeclaredCommands() async {
    if (!await _nativeOwnerSelected()) return false;
    if (_state.status != NodeStatus.paired || !_ws.isConnected) return false;
    return _liveNativeCommandContractHash == _declaredCommandContractSignature();
  }

  Future<bool> _nativeStoredContractAlreadyAccepted() async {
    try {
      final prefs = PreferencesService();
      await prefs.init();
      final token = prefs.nodeDeviceToken?.trim() ?? '';
      if (token.isEmpty) return false;
      return prefs.nodeCommandContractHash == _declaredCommandContractSignature();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _pairedNodeCommandsCoverDeclared() async {
    final declaredCommands = _capabilityHandlers.keys.toSet();
    if (declaredCommands.isEmpty) return false;

    final nodeCommands = await _readPairedNodeCommandSet();
    if (nodeCommands != null && nodeCommands.isNotEmpty) {
      return declaredCommands.every(nodeCommands.contains);
    }

    final deviceCommands = await _readPairedDeviceCommandSet();
    if (deviceCommands != null && deviceCommands.isNotEmpty) {
      return declaredCommands.every(deviceCommands.contains);
    }
    return false;
  }

  Future<Set<String>?> _readPairedNodeCommandSet() async {
    final deviceId = _identity.deviceId ?? '';
    if (deviceId.isEmpty) return null;
    try {
      final decoded = await _readFirstOpenClawStoreJson('nodes/paired.json');
      if (decoded == null) return null;
      final record = _findDeviceRecord(decoded, deviceId);
      if (record == null) return null;
      return _stringSet(record['commands']);
    } catch (_) {
      return null;
    }
  }

  Future<Set<String>?> _readPairedDeviceCommandSet() async {
    final deviceId = _identity.deviceId ?? '';
    if (deviceId.isEmpty) return null;
    try {
      final decoded = await _readFirstOpenClawStoreJson('devices/paired.json');
      if (decoded == null) return null;
      final record = _findDeviceRecord(decoded, deviceId);
      if (record == null) return null;
      if (!_recordHasRole(record, AppConstants.nodeRole)) return null;
      return _stringSet(record['commands']);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _approvePendingNodePairingSnapshot(
    PreferencesService prefs,
  ) async {
    final requestId = await _readPendingNodePairingRequestIdFromStore();
    if (requestId == null || requestId.isEmpty) return false;

    if (await _nativeOwnerSelected()) {
      log('[NODE] Native owner: approving pending node command snapshot $requestId via Gateway RPC...');
      final approved =
          await approvePairingRequestViaGateway?.call(requestId) ?? false;
      if (!approved) {
        log('[NODE] Native owner: Gateway RPC approval unavailable for pending node snapshot');
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 250));
      if (await _pairedNodeCommandsCoverDeclared()) {
        prefs.nodeCommandContractHash = _declaredCommandContractSignature();
        log('[NODE] Approved node command snapshot via Gateway RPC');
        return true;
      }
      log('[NODE] Native owner: Gateway RPC approval completed but command snapshot is still missing');
      return false;
    }

    log('[NODE] Approving pending node command snapshot $requestId via OpenClaw nodes CLI...');
    _gatewayAuthToken ??= await _readGatewayToken();
    final gatewayUrl =
        'ws://${_state.gatewayHost ?? AppConstants.gatewayHost}:${_state.gatewayPort ?? AppConstants.gatewayPort}';
    final gatewayToken = _gatewayAuthToken;

    Future<void> approveWith(String extraArgs) async {
      await NativeBridge.runInProot(
        '$kOpenClawCommand nodes approve $requestId$extraArgs --json',
        timeout: 40,
      );
    }

    try {
      if (gatewayToken != null && gatewayToken.isNotEmpty) {
        try {
          await approveWith(
            ' --url ${NativeBridge.shellQuote(gatewayUrl)}'
            ' --token ${NativeBridge.shellQuote(gatewayToken)}',
          );
        } catch (e) {
          log('[NODE] Explicit node pairing approval failed ($e); retrying with local CLI session...');
          await approveWith('');
        }
      } else {
        await approveWith('');
      }

      await Future.delayed(const Duration(milliseconds: 250));
      if (await _pairedNodeCommandsCoverDeclared()) {
        prefs.nodeCommandContractHash = _declaredCommandContractSignature();
        log('[NODE] Approved node command snapshot');
        return true;
      }
      log('[NODE] Node pairing approval completed but command snapshot is still missing');
    } catch (e) {
      log('[NODE] Node pairing approval failed: $e');
    }
    return false;
  }

  Future<String?> _readPendingNodePairingRequestIdFromStore() async {
    final deviceId = _identity.deviceId ?? '';
    if (deviceId.isEmpty) return null;
    try {
      for (final file in await _openClawStoreFiles('nodes/pending.json')) {
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        final requestId = NativeBridge.extractPendingDeviceRequestId(
          content,
          deviceId: deviceId,
          role: AppConstants.nodeRole,
        );
        if (requestId != null && requestId.isNotEmpty) return requestId;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, dynamic>? _findDeviceRecord(Object? value, String deviceId) {
    if (deviceId.isEmpty) return null;
    if (value is Map) {
      final map = value.map((key, val) => MapEntry('$key', val));
      if (map.containsKey(deviceId) && map[deviceId] is Map) {
        return Map<String, dynamic>.from(map[deviceId] as Map);
      }
      if (_containsStringValue(map, deviceId)) {
        final directDeviceId = map['deviceId']?.toString();
        final directNodeId = map['nodeId']?.toString();
        if (directDeviceId == deviceId || directNodeId == deviceId) {
          return Map<String, dynamic>.from(map);
        }
      }
      for (final child in map.values) {
        final record = _findDeviceRecord(child, deviceId);
        if (record != null) return record;
      }
    } else if (value is List) {
      for (final child in value) {
        final record = _findDeviceRecord(child, deviceId);
        if (record != null) return record;
      }
    }
    return null;
  }

  bool _recordHasRole(Map<String, dynamic> record, String role) {
    if (role.isEmpty) return false;
    if (record['role']?.toString() == role) return true;
    final roles = record['roles'];
    if (roles is List && roles.any((value) => value?.toString() == role)) {
      return true;
    }
    return false;
  }

  Set<String> _stringSet(Object? value) {
    if (value is! List) return const <String>{};
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  String _declaredCommandContractSignature() {
    final commands = _capabilityHandlers.keys.toList()..sort();
    // Bump this when the gateway-visible node snapshot shape changes, not only
    // when the command names change. v5 adds avatar node commands.
    return 'v5:${commands.join('|')}';
  }

  String _capFamilyForCommand(String command) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '.');
    final family = normalized.split('.').first;
    if (family == 'vibrate') return 'haptic';
    return family;
  }

  Future<void> connect({String? host, int? port}) async {
    if (_capabilityHandlers.isEmpty) {
      log('[NODE] Connect deferred: no device capabilities registered yet');
      return;
    }
    final needsSnapshotRepair = await _pairedNodeSnapshotNeedsCommandRepair();
    if (_state.status == NodeStatus.paired && _ws.isConnected) {
      if (!needsSnapshotRepair && !_ws.isStale) {
        return;
      }
      log(needsSnapshotRepair
          ? '[NODE] Connected gateway node snapshot is missing commands; reconnecting to refresh pairing'
          : '[NODE] Existing WebSocket is stale; reconnecting to refresh node commands');
      await _ws.disconnect();
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
      await _ensurePairingMatchesDeclaredCommands(prefs);
      if (needsSnapshotRepair ||
          await _pairedNodeSnapshotNeedsCommandRepair()) {
        await _repairPairedNodeSnapshot(prefs);
      }

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
      await _sendConnectWithFreshNonce(_challengeWaitTimeout);
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
      _cachedChallengeNonce = null;
      _cachedChallengeReceivedAt = null;
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
    // Reconnect callbacks can arrive after a successful pair if the socket
    // layer briefly flaps. Avoid re-running handshake while already healthy.
    if (_state.status == NodeStatus.paired && _ws.isConnected) {
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
      await _sendConnectWithFreshNonce(_challengeWaitTimeout);
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
      for (final file in await _openClawStoreFiles('openclaw.json')) {
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        final config = jsonDecode(content) as Map<String, dynamic>;
        final token = config['gateway']?['auth']?['token'] as String? ??
            config['gateway']?['token'] as String? ??
            config['auth']?['token'] as String?;
        if (token != null && token.isNotEmpty) {
          log('[NODE] Gateway token read from ${file.path}');
          return token;
        }
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
    final commands = _capabilityHandlers.keys.toList()..sort();
    final caps = commands.map(_capFamilyForCommand).toSet().toList()..sort();
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
      if (await _nativeOwnerSelected()) {
        final signature = _declaredCommandContractSignature();
        _liveNativeCommandContractHash = signature;
        prefs.nodeCommandContractHash = signature;
        return;
      }
      if (await _pairedNodeSnapshotNeedsCommandRepair()) {
        await _approvePendingNodePairingSnapshot(prefs);
      }
    } else if (response.isError) {
      final errPayload = response.payload ?? response.error ?? {};
      final code = errPayload['code'] as String? ?? '';
      final message = errPayload['message'] as String? ?? 'Connect failed';
      final details = errPayload['details'];
      final detailCode =
          details is Map ? details['code']?.toString() ?? '' : '';
      final detailReason = details is Map
          ? details['reason']?.toString().toLowerCase() ?? ''
          : '';
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
        final requestId = _extractPairingRequestId(details);
        final label = requestId == null || requestId.isEmpty
            ? 'latest pending node request'
            : requestId;
        log('[NODE] Pairing requested by connect response; approving $label now.');
        await _handleNodePairingRequired(requestId);
      } else if (code == 'UNAVAILABLE') {
        log('[NODE] Gateway is warming up (UNAVAILABLE). Entering grace period...');
        _updateState(_state.copyWith(status: NodeStatus.warmingUp));
        // NodeWsService will trigger _disconnected on close, or we can force it
      } else if (code == 'INVALID_REQUEST' &&
          normalizedMessage.contains("required property 'nonce'")) {
        log('[NODE] Gateway required a fresh nonce; reopening socket for secure reconnect.');
        await _ws.forceReconnect(reason: 'gateway-required-nonce');
      } else if (code == 'DEVICE_AUTH_NONCE_MISMATCH' ||
          detailCode == 'DEVICE_AUTH_NONCE_MISMATCH' ||
          detailReason == 'device-nonce-mismatch' ||
          normalizedMessage.contains('nonce mismatch')) {
        // Explicit recovery path for nonce drift across reconnect churn.
        _cachedChallengeNonce = null;
        _cachedChallengeReceivedAt = null;
        _challengeCompleter = null;
        log('[NODE] Nonce mismatch from gateway; clearing cached nonce and retrying handshake.');
        await _ws.forceReconnect(reason: 'device-nonce-mismatch');
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

  String? _extractPairingRequestId(dynamic details) {
    if (details is Map) {
      const keys = [
        'requestId',
        'requestID',
        'request_id',
        'pairingRequestId',
        'pairing_request_id',
        'id',
      ];
      for (final key in keys) {
        final value = details[key]?.toString().trim();
        if (value != null && _uuidPattern.hasMatch(value)) {
          return value;
        }
      }
      for (final value in details.values) {
        final nested = _extractPairingRequestId(value);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    } else if (details is List) {
      for (final value in details) {
        final nested = _extractPairingRequestId(value);
        if (nested != null && nested.isNotEmpty) return nested;
      }
    } else if (details != null) {
      return _uuidSearchPattern.firstMatch(details.toString())?.group(0);
    }
    return null;
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
    _gatewayAuthToken ??= await _readGatewayToken();
    if (await _nativeOwnerSelected()) {
      log('[NODE] Pairing required — approving $requestLabel via Gateway RPC.');
      var requestIdToApprove = requestId?.trim() ?? '';
      if (requestIdToApprove.isEmpty ||
          !_uuidPattern.hasMatch(requestIdToApprove)) {
        requestIdToApprove = await _readPendingNodeRequestIdFromStore(
              fallbackRequestId: requestIdToApprove,
            ) ??
            '';
      }
      if (requestIdToApprove.isEmpty ||
          !_uuidPattern.hasMatch(requestIdToApprove)) {
        throw StateError('No valid pending node pairing request found');
      }
      final approved =
          await approvePairingRequestViaGateway?.call(requestIdToApprove) ??
              false;
      if (!approved) {
        throw UnsupportedError(
          'Native owner could not approve node pairing via Gateway RPC. '
          'PRoot CLI fallback is rollback-only.',
        );
      }
      await Future.delayed(const Duration(milliseconds: 250));
      final token = await _readApprovedNodeTokenFromStore();
      if (token != null && token.isNotEmpty) {
        log('[NODE] Native owner: recovered approved node token after RPC approval');
        return token;
      }
      log('[NODE] Native owner: RPC approved pairing; token will be learned on reconnect');
      return null;
    }

    log('[NODE] Pairing required — approving $requestLabel via OpenClaw CLI...');
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
        final output = await NativeBridge.runInProot(
          '$kOpenClawCommand devices approve $requestIdToApprove '
          '--url ${NativeBridge.shellQuote(gatewayUrl)} '
          '--token ${NativeBridge.shellQuote(gatewayToken)} '
          '--json',
          timeout: 40,
        );
        return _tokenFromApprovalOutput(output) ??
            await _readApprovedNodeTokenFromStore();
      } catch (e) {
        if (_isUnknownRequestIdError(e)) {
          final refreshedId = await _resolvePendingNodeRequestId(
            fallbackRequestId: requestIdToApprove,
            gatewayUrl: gatewayUrl,
            token: gatewayToken,
          );
          if (refreshedId != null && refreshedId != requestIdToApprove) {
            requestIdToApprove = refreshedId;
            final output = await NativeBridge.runInProot(
              '$kOpenClawCommand devices approve $requestIdToApprove '
              '--url ${NativeBridge.shellQuote(gatewayUrl)} '
              '--token ${NativeBridge.shellQuote(gatewayToken)} '
              '--json',
              timeout: 40,
            );
            return _tokenFromApprovalOutput(output) ??
                await _readApprovedNodeTokenFromStore();
          }
        }
        log('[NODE] Explicit approval failed ($e); retrying with local CLI session...');
      }
    }

    // Fallback path: local CLI session, with one stale-request recovery attempt.
    try {
      final output = await NativeBridge.runInProot(
        '$kOpenClawCommand devices approve $requestIdToApprove --json',
        timeout: 40,
      );
      return _tokenFromApprovalOutput(output) ??
          await _readApprovedNodeTokenFromStore();
    } catch (e) {
      if (_isUnknownRequestIdError(e)) {
        final refreshedId = await _resolvePendingNodeRequestId(
          fallbackRequestId: requestIdToApprove,
          gatewayUrl: gatewayUrl,
          token: gatewayToken,
        );
        if (refreshedId != null && refreshedId != requestIdToApprove) {
          requestIdToApprove = refreshedId;
          final output = await NativeBridge.runInProot(
            '$kOpenClawCommand devices approve $requestIdToApprove --json',
            timeout: 40,
          );
          return _tokenFromApprovalOutput(output) ??
              await _readApprovedNodeTokenFromStore();
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  String? _tokenFromApprovalOutput(String output) {
    if (output.trim().isEmpty) return null;
    try {
      return _findAnyToken(jsonDecode(output));
    } catch (_) {
      final jsonStart = output.indexOf(RegExp(r'[\{\[]'));
      if (jsonStart < 0) return null;
      try {
        return _findAnyToken(jsonDecode(output.substring(jsonStart)));
      } catch (_) {
        return null;
      }
    }
  }

  Future<String?> _resolvePendingNodeRequestId({
    required String fallbackRequestId,
    required String gatewayUrl,
    required String? token,
  }) async {
    if (!await _nativeOwnerSelected()) {
      try {
        final explicitArgs = token != null && token.isNotEmpty
            ? ' --url ${NativeBridge.shellQuote(gatewayUrl)}'
                ' --token ${NativeBridge.shellQuote(token)}'
            : '';
        final output = await NativeBridge.runInProot(
          '$kOpenClawCommand devices list --json$explicitArgs',
          timeout: 20,
        );
        final cliRequestId = NativeBridge.extractPendingDeviceRequestId(
          output,
          requestedId: fallbackRequestId,
          deviceId: _identity.deviceId,
          role: AppConstants.nodeRole,
        );
        if (cliRequestId != null && cliRequestId.isNotEmpty) {
          return cliRequestId;
        }
      } catch (_) {}
    }

    return _readPendingNodeRequestIdFromStore(
      fallbackRequestId: fallbackRequestId,
    );
  }

  Future<String?> _readPendingNodeRequestIdFromStore({
    required String fallbackRequestId,
  }) async {
    try {
      final files = [
        ...await _openClawStoreFiles('nodes/pending.json'),
        ...await _openClawStoreFiles('devices/pending.json'),
      ];
      for (final pendingFile in files) {
        if (!await pendingFile.exists()) continue;
        final content = await pendingFile.readAsString();
        final requestId = NativeBridge.extractPendingDeviceRequestId(
          content,
          requestedId: fallbackRequestId,
          deviceId: _identity.deviceId,
          role: AppConstants.nodeRole,
        );
        if (requestId != null && requestId.isNotEmpty) {
          return requestId;
        }
      }
    } catch (_) {}
    return null;
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
      final nodeId = _identity.deviceId ?? '';
      for (final decoded
          in await _readAllOpenClawStoreJson('devices/paired.json')) {
        final token = _findTokenForDevice(decoded, nodeId);
        if (token != null && token.isNotEmpty) return token;
      }
    } catch (_) {
      return null;
    }
    return null;
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
      final nodeId = _identity.deviceId ?? '';
      for (final decoded
          in await _readAllOpenClawStoreJson('nodes/paired.json')) {
        if (decoded is! Map) continue;
        final map = Map<String, dynamic>.from(decoded);
        final record = map[nodeId];
        if (record is Map) {
          final token = record['token'] as String?;
          if (token != null && token.isNotEmpty) return token;
        }
        final token = _findTokenForDevice(map, nodeId);
        if (token != null && token.isNotEmpty) return token;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<String?> _readApprovedNodeTokenFromNodeStore() async {
    try {
      for (final decoded in await _readAllOpenClawStoreJson('node.json')) {
        if (decoded is! Map) continue;
        final map = Map<String, dynamic>.from(decoded);
        final directToken = map['token'];
        if (directToken is String && directToken.isNotEmpty) {
          return directToken;
        }

        final deviceToken = map['deviceToken'];
        if (deviceToken is String && deviceToken.isNotEmpty) {
          return deviceToken;
        }

        final gateway = map['gateway'];
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
