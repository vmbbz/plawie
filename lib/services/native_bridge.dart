import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'preferences_service.dart';
import '../constants/openclaw_paths.dart';

class NativeBridge {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');
  static const _eventChannel =
      EventChannel('com.nxg.openclawproot/gateway_logs');

  static Future<String> getProotPath() async {
    return await _channel.invokeMethod('getProotPath');
  }

  static Future<String> getArch() async {
    return await _channel.invokeMethod('getArch');
  }

  static Future<String> getFilesDir() async {
    return await _channel.invokeMethod('getFilesDir');
  }

  static Future<String> getNativeLibDir() async {
    return await _channel.invokeMethod('getNativeLibDir');
  }

  static Future<void> markBootstrapComplete() async {
    await _channel.invokeMethod('markBootstrapComplete');
  }

  static Future<bool> isBootstrapComplete() async {
    final nativeOk =
        await _channel.invokeMethod('isBootstrapComplete') ?? false;
    final prefs = PreferencesService();
    await prefs.init();
    return nativeOk || prefs.setupComplete;
  }

  static Future<Map<String, dynamic>> getBootstrapStatus() async {
    final result = await _channel.invokeMethod('getBootstrapStatus');
    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> ensureOpenClawReady() async {
    final result = await _channel.invokeMethod('ensureOpenClawReady');
    return Map<String, dynamic>.from(result);
  }

  static Future<bool> extractRootfs(String tarPath) async {
    return await _channel.invokeMethod('extractRootfs', {'tarPath': tarPath});
  }

  static Future<String> runInProot(String command, {int timeout = 900}) async {
    final sanitized = _applyAbsoluteBypass(command);
    final withEnv =
        'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH && '
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && $sanitized';
    return await _channel
        .invokeMethod('runInProot', {'command': withEnv, 'timeout': timeout});
  }

  /// Execute a command in the persistent shell (one PRoot process reused across calls).
  /// Uses milliseconds for timeout (default 30s). Prefer this over runInProot in the terminal.
  static Future<String> executeInShell(String command,
      {int timeoutMs = 30000}) async {
    final sanitized = _applyAbsoluteBypass(command);
    final withEnv =
        'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH && '
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && $sanitized';
    return await _channel.invokeMethod(
        'executeInShell', {'command': withEnv, 'timeoutMs': timeoutMs});
  }

  static String _applyAbsoluteBypass(String cmd) {
    if (!cmd.contains('openclaw')) return cmd;

    // Replace naked 'openclaw' command but NOT if it's already part of a path
    // or the .js entry point itself.
    // (?<![/\.]) matches only if NOT preceded by / or .
    // (?!\.js) matches only if NOT followed by .js
    return cmd.replaceAllMapped(RegExp(r'(?<![/\.])\bopenclaw\b(?!\.js)'),
        (match) {
      return kOpenClawCommand;
    });
  }

  /// Destroy the persistent shell process (called when terminal screen closes).
  static Future<void> destroyShell() async {
    await _channel.invokeMethod('destroyShell');
  }

  static Future<bool> startGateway() async {
    return await _channel.invokeMethod('startGateway');
  }

  static String shellQuote(String value) {
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  static String? extractPendingDeviceRequestId(
    String output, {
    String? requestedId,
    String? deviceId,
    String? role,
  }) {
    final uuidPattern =
        RegExp(r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}');
    if (requestedId != null &&
        requestedId.isNotEmpty &&
        output.contains(requestedId)) {
      return requestedId;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(output);
    } catch (_) {
      final jsonStart = output.indexOf(RegExp(r'[\{\[]'));
      if (jsonStart >= 0) {
        try {
          decoded = jsonDecode(output.substring(jsonStart));
        } catch (_) {}
      }
    }

    if (decoded != null) {
      final candidates = <Map<String, dynamic>>[];

      void visit(Object? value) {
        if (value is Map) {
          final map = value.map((key, val) => MapEntry('$key', val));
          if (_requestIdFromMap(map) != null) candidates.add(map);
          for (final child in map.values) {
            visit(child);
          }
        } else if (value is List) {
          for (final child in value) {
            visit(child);
          }
        }
      }

      visit(decoded);

      String? pick(bool Function(Map<String, dynamic>) matches) {
        for (final candidate in candidates.reversed) {
          if (matches(candidate)) return _requestIdFromMap(candidate);
        }
        return null;
      }

      final exact = pick((candidate) =>
          requestedId != null && _requestIdFromMap(candidate) == requestedId);
      if (exact != null) return exact;

      final roleDevice = pick((candidate) =>
          _mapHasValue(candidate, role) && _mapHasValue(candidate, deviceId));
      if (roleDevice != null) return roleDevice;

      final byDevice = pick((candidate) => _mapHasValue(candidate, deviceId));
      if (byDevice != null) return byDevice;

      final byRole = pick((candidate) => _mapHasValue(candidate, role));
      if (byRole != null) return byRole;

      final any = pick((_) => true);
      if (any != null) return any;
    }

    final matches = uuidPattern.allMatches(output).map((m) => m.group(0)!);
    return matches.isEmpty ? null : matches.last;
  }

  static String? _requestIdFromMap(Map<String, dynamic> map) {
    const keys = [
      'requestId',
      'requestID',
      'request_id',
      'pairingRequestId',
      'pairing_request_id',
      'id',
    ];
    final uuidPattern = RegExp(
        r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$');
    for (final key in keys) {
      final value = map[key];
      if (value is String && uuidPattern.hasMatch(value)) return value;
    }
    return null;
  }

  static bool _mapHasValue(Map<String, dynamic> map, String? needle) {
    if (needle == null || needle.isEmpty) return false;
    bool walk(Object? value) {
      if (value is String) return value == needle;
      if (value is Map) return value.values.any(walk);
      if (value is List) return value.any(walk);
      return false;
    }

    return walk(map);
  }

  static Future<String> approveDevice(String requestId) async {
    final safeRequestId = requestId.trim();
    if (!RegExp(r'^[a-f0-9-]{16,}$').hasMatch(safeRequestId)) {
      throw Exception('Invalid pairing request id: $requestId');
    }
    return await runInProot(
      'openclaw devices approve $safeRequestId --json',
      timeout: 40,
    );
  }

  static Future<String> removeDevice(String deviceId) async {
    return await runInProot(
      'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
      'export PATH=\$PATH:/usr/local/bin:/usr/bin && openclaw devices remove $deviceId 2>/dev/null || true',
      timeout: 30,
    );
  }

  static Future<bool> stopGateway() async {
    return await _channel.invokeMethod('stopGateway');
  }

  static Future<bool> isGatewayRunning() async {
    return await _channel.invokeMethod<bool>('isGatewayRunning') ?? false;
  }

  static Future<String> getGatewayLogs() async {
    return await _channel.invokeMethod<String>('getGatewayLogs') ?? '';
  }

  static Future<bool> setupDirs() async {
    return await _channel.invokeMethod('setupDirs');
  }

  static Future<bool> installBionicBypass() async {
    return await _channel.invokeMethod('installBionicBypass');
  }

  static Future<bool> writeResolv() async {
    return await _channel.invokeMethod('writeResolv');
  }

  static Future<int> extractDebPackages() async {
    return await _channel.invokeMethod('extractDebPackages');
  }

  static Future<bool> extractNodeTarball(String tarPath) async {
    return await _channel
        .invokeMethod('extractNodeTarball', {'tarPath': tarPath});
  }

  static Future<bool> createBinWrappers(String packageName) async {
    return await _channel
        .invokeMethod('createBinWrappers', {'packageName': packageName});
  }

  static Future<bool> startTerminalService() async {
    return await _channel.invokeMethod('startTerminalService');
  }

  static Future<bool> stopTerminalService() async {
    return await _channel.invokeMethod('stopTerminalService');
  }

  static Future<bool> isTerminalServiceRunning() async {
    return await _channel.invokeMethod('isTerminalServiceRunning');
  }

  static Future<bool> startNodeService() async {
    return await _channel.invokeMethod('startNodeService');
  }

  static Future<bool> stopNodeService() async {
    return await _channel.invokeMethod('stopNodeService');
  }

  static Future<bool> isNodeServiceRunning() async {
    return await _channel.invokeMethod('isNodeServiceRunning');
  }

  static Future<bool> acquirePartialWakeLock() async {
    return await _channel.invokeMethod('acquirePartialWakeLock');
  }

  static Future<bool> releasePartialWakeLock() async {
    return await _channel.invokeMethod('releasePartialWakeLock');
  }

  static Future<bool> isBatteryOptimized() async {
    return await _channel.invokeMethod('isBatteryOptimized');
  }

  static Future<void> requestBatteryOptimization() async {
    return await _channel.invokeMethod('requestBatteryOptimization');
  }

  static Future<bool> updateNodeNotification(String text) async {
    return await _channel
        .invokeMethod('updateNodeNotification', {'text': text});
  }

  static Future<bool> startSetupService() async {
    return await _channel.invokeMethod('startSetupService');
  }

  static Future<bool> updateSetupNotification(String text,
      {int progress = -1}) async {
    return await _channel.invokeMethod(
        'updateSetupNotification', {'text': text, 'progress': progress});
  }

  static Future<bool> stopSetupService() async {
    return await _channel.invokeMethod('stopSetupService');
  }

  static Future<bool> showUrlNotification(String url,
      {String title = 'URL Detected'}) async {
    return await _channel
        .invokeMethod('showUrlNotification', {'url': url, 'title': title});
  }

  static Stream<String> get gatewayLogStream {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
  }

  static Future<String?> requestScreenCapture(int durationMs) async {
    return await _channel
        .invokeMethod('requestScreenCapture', {'durationMs': durationMs});
  }

  static Future<bool> stopScreenCapture() async {
    return await _channel.invokeMethod('stopScreenCapture');
  }

  static Future<String> getDeviceId() async {
    return await _channel.invokeMethod('getDeviceId');
  }

  static Future<String> getDeviceModel() async {
    return await _channel.invokeMethod('getDeviceModel');
  }

  static Future<String> getDeviceBrand() async {
    return await _channel.invokeMethod('getDeviceBrand');
  }

  static Future<String> getAppVersion() async {
    return await _channel.invokeMethod('getAppVersion');
  }

  static Future<int> getTotalMemoryMb() async {
    return await _channel.invokeMethod<int>('getTotalMemoryMb') ?? 4096;
  }

  // ── Integrated Ollama Management ──────────────────────────────────────────

  static Future<bool> isOllamaInstalled() async {
    return await _channel.invokeMethod<bool>('isOllamaInstalled') ?? false;
  }

  static Future<bool> isOllamaRunning() async {
    return await _channel.invokeMethod<bool>('isOllamaRunning') ?? false;
  }

  static Future<bool> startOllama() async {
    return await _channel.invokeMethod<bool>('startOllama') ?? false;
  }

  static Future<bool> stopOllama() async {
    return await _channel.invokeMethod<bool>('stopOllama') ?? false;
  }

  static Future<bool> installOllama(String tempPath) async {
    return await _channel
            .invokeMethod<bool>('installOllama', {'tempPath': tempPath}) ??
        false;
  }

  // ── Wake Word "Plawie" ─────────────────────────────────────────────────────

  static const _hotwordChannel = MethodChannel('com.nxg.openclawproot/hotword');
  static const _hotwordEventChannel =
      EventChannel('com.nxg.openclawproot/hotword_events');

  static Future<bool> startHotword() async {
    return await _hotwordChannel.invokeMethod<bool>('startHotword') ?? false;
  }

  static Future<bool> stopHotword() async {
    return await _hotwordChannel.invokeMethod<bool>('stopHotword') ?? false;
  }

  static Future<bool> setHotwordMode(String mode) async {
    return await _hotwordChannel
            .invokeMethod<bool>('setHotwordMode', {'mode': mode}) ??
        false;
  }

  static Future<bool> isHotwordRunning() async {
    return await _hotwordChannel.invokeMethod<bool>('isHotwordRunning') ??
        false;
  }

  static Stream<String> get hotwordEvents => _hotwordEventChannel
      .receiveBroadcastStream()
      .where((e) => e != null)
      .cast<String>();

  // ── Storage Permission (MANAGE_EXTERNAL_STORAGE) ──────────────────────────

  static Future<bool> checkStoragePermission() async {
    return await _channel.invokeMethod<bool>('checkStoragePermission') ?? false;
  }

  static Future<bool> requestStoragePermission() async {
    return await _channel.invokeMethod<bool>('requestStoragePermission') ??
        false;
  }

  // ── Network Change Callback ──────────────────────────────────────────────

  static final _networkChangeController = StreamController<bool>.broadcast();
  static Stream<bool> get onNetworkChanged => _networkChangeController.stream;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNetworkChanged') {
        final bool isConnected = call.arguments as bool;
        _networkChangeController.add(isConnected);
      }
    });
  }
}
