import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'preferences_service.dart';
import '../constants/openclaw_paths.dart';

enum SecureWalletState {
  absent,
  healthy,
  legacyMigrationRequired,
  authenticationUnavailable,
  envelopeCorrupt,
  keystoreKeyMissing,
  keystoreKeyInvalidated,
  orphanedKeystoreAlias,
  operationBusy,
  unavailable,
}

class SecureWalletException implements Exception {
  final String code;
  final String message;

  const SecureWalletException({required this.code, required this.message});

  @override
  String toString() => '$code: $message';
}

class SecureWalletStatus {
  final SecureWalletState state;
  final String? address;
  final String securityLevel;
  final String authenticationMode;
  final String errorCode;
  final String envelopeIntegrity;
  final bool authenticationAvailable;
  final bool hardwareBacked;
  final bool verificationPending;
  final String verificationCode;

  const SecureWalletStatus({
    required this.state,
    required this.address,
    required this.securityLevel,
    required this.authenticationMode,
    required this.errorCode,
    required this.envelopeIntegrity,
    required this.authenticationAvailable,
    required this.hardwareBacked,
    required this.verificationPending,
    required this.verificationCode,
  });

  factory SecureWalletStatus.absent() => const SecureWalletStatus(
        state: SecureWalletState.absent,
        address: null,
        securityLevel: 'not-created',
        authenticationMode: '',
        errorCode: '',
        envelopeIntegrity: 'absent',
        authenticationAvailable: false,
        hardwareBacked: false,
        verificationPending: false,
        verificationCode: '',
      );

  factory SecureWalletStatus.unavailable({required String errorCode}) =>
      SecureWalletStatus(
        state: SecureWalletState.unavailable,
        address: null,
        securityLevel: 'unknown',
        authenticationMode: '',
        errorCode: errorCode,
        envelopeIntegrity: 'unknown',
        authenticationAvailable: false,
        hardwareBacked: false,
        verificationPending: false,
        verificationCode: '',
      );

  factory SecureWalletStatus.fromNative(Map<String, dynamic> value) {
    const states = <String, SecureWalletState>{
      'absent': SecureWalletState.absent,
      'healthy': SecureWalletState.healthy,
      'authenticationUnavailable': SecureWalletState.authenticationUnavailable,
      'envelopeCorrupt': SecureWalletState.envelopeCorrupt,
      'keystoreKeyMissing': SecureWalletState.keystoreKeyMissing,
      'keystoreKeyInvalidated': SecureWalletState.keystoreKeyInvalidated,
      'orphanedKeystoreAlias': SecureWalletState.orphanedKeystoreAlias,
      'operationBusy': SecureWalletState.operationBusy,
    };
    final wireState = value['state']?.toString();
    final state = states[wireState] ?? SecureWalletState.unavailable;
    final rawAddress = value['address']?.toString().trim() ?? '';
    final rawErrorCode = value['errorCode']?.toString().trim() ?? '';
    return SecureWalletStatus(
      state: state,
      address: rawAddress.isEmpty ? null : rawAddress,
      securityLevel: value['securityLevel']?.toString() ?? 'unknown',
      authenticationMode: value['authenticationMode']?.toString() ?? '',
      errorCode: state == SecureWalletState.unavailable && rawErrorCode.isEmpty
          ? 'WALLET_STATUS_UNKNOWN'
          : rawErrorCode,
      envelopeIntegrity: value['envelopeIntegrity']?.toString() ?? 'unknown',
      authenticationAvailable: value['authenticationAvailable'] == true,
      hardwareBacked: value['hardwareBacked'] == true,
      verificationPending: value['verificationPending'] == true,
      verificationCode: value['verificationCode']?.toString() ?? '',
    );
  }

  bool get isConnected =>
      state == SecureWalletState.healthy && address?.isNotEmpty == true;

  bool get canCreate => state == SecureWalletState.absent;

  bool get canRestore =>
      state != SecureWalletState.operationBusy &&
      state != SecureWalletState.unavailable;

  bool get requiresDestructiveRecovery =>
      state == SecureWalletState.envelopeCorrupt ||
      state == SecureWalletState.keystoreKeyMissing ||
      state == SecureWalletState.keystoreKeyInvalidated;

  SecureWalletStatus withLegacyWalletAddress(String legacyAddress) {
    if (state != SecureWalletState.absent || legacyAddress.trim().isEmpty) {
      return this;
    }
    return SecureWalletStatus(
      state: SecureWalletState.legacyMigrationRequired,
      address: legacyAddress.trim(),
      securityLevel: securityLevel,
      authenticationMode: authenticationMode,
      errorCode: '',
      envelopeIntegrity: envelopeIntegrity,
      authenticationAvailable: authenticationAvailable,
      hardwareBacked: hardwareBacked,
      verificationPending: false,
      verificationCode: '',
    );
  }
}

class NativeFfmpegRunResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const NativeFfmpegRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get ok => exitCode == 0;
}

class NativeManagedCliRunResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final String binaryPath;

  const NativeManagedCliRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.binaryPath,
  });

  bool get ok => exitCode == 0;
}

class NativeBridge {
  static const _channel = MethodChannel('com.openclaw.plawie/native');
  static const _eventChannel = EventChannel('com.openclaw.plawie/gateway_logs');

  static Future<SecureWalletStatus> getSecureEvmWalletStatus() =>
      _invokeSecureWalletStatus('getSecureEvmWalletStatus');

  static Future<SecureWalletStatus> createSecureEvmWallet() =>
      _invokeSecureWalletStatus('createSecureEvmWallet');

  static Future<SecureWalletStatus> importSecureEvmWallet(
    Uint8List privateKey,
  ) =>
      _invokeSecureWalletStatus(
        'importSecureEvmWallet',
        <String, dynamic>{'privateKey': privateKey},
      );

  static Future<SecureWalletStatus> _invokeSecureWalletStatus(
    String method, [
    Object? arguments,
  ]) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        method,
        arguments,
      );
      return SecureWalletStatus.fromNative(
        Map<String, dynamic>.from(result ?? const <dynamic, dynamic>{}),
      );
    } on PlatformException catch (error) {
      throw SecureWalletException(
        code: error.code,
        message: error.message ?? 'The secure wallet operation failed.',
      );
    }
  }

  static Future<String> signSecureEvmTransaction(
    Map<String, dynamic> transaction,
  ) async {
    return await _channel.invokeMethod<String>(
          'signSecureEvmTransaction',
          transaction,
        ) ??
        '';
  }

  static Future<Map<String, dynamic>> signSecureX402Authorization(
    Map<String, dynamic> authorization,
  ) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'signSecureX402Authorization',
      authorization,
    );
    return Map<String, dynamic>.from(result ?? const <dynamic, dynamic>{});
  }

  static Future<Map<String, dynamic>> signSecureVeniceBalanceIdentity(
    Map<String, dynamic> identity,
  ) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'signSecureVeniceBalanceIdentity',
      identity,
    );
    return Map<String, dynamic>.from(result ?? const <dynamic, dynamic>{});
  }

  /// Shows the private-key backup in an Android-owned authenticated dialog.
  /// The key never crosses the MethodChannel into Dart.
  static Future<void> showSecureEvmWalletBackup() async {
    await _channel.invokeMethod('showSecureEvmWalletBackup');
  }

  static Future<void> deleteSecureEvmWallet() async {
    await _channel.invokeMethod('deleteSecureEvmWallet');
  }

  static Future<String> getProotPath() async {
    return await _channel.invokeMethod('getProotPath');
  }

  static Future<String> getArch() async {
    return await _channel.invokeMethod('getArch');
  }

  static Future<String> getFilesDir() async {
    return await _channel.invokeMethod('getFilesDir');
  }

  static Future<String?> pickGif() async {
    final result = await _channel.invokeMethod<String?>('pickGif');
    return result?.trim().isEmpty == true ? null : result?.trim();
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
    if (!nativeOk && prefs.setupComplete) {
      try {
        final status = await getBootstrapStatus();
        if (prefs.gatewayRuntimeOwner ==
            PreferencesService.gatewayRuntimeOwnerNativeProduction) {
          return status['nativeOpenClawInstalled'] == true;
        }
        if (status['nodeMeetsMinimum'] == false) return false;
      } catch (_) {}
    }
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

  /// Downloads and installs the latest official OpenClaw gateway attested by
  /// the upstream GitHub release. This is native-only and never enters PRoot.
  static Future<Map<String, dynamic>> provisionOfficialOpenClaw() async {
    final result = await _channel.invokeMethod('provisionOfficialOpenClaw');
    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> getNativeOpenClawStatus() async {
    final result = await _channel.invokeMethod('getNativeOpenClawStatus');
    return Map<String, dynamic>.from(result);
  }

  /// Returns the sanitized, durable progress state written by the isolated
  /// official-gateway installer. This exposes no package credentials or URLs.
  static Future<Map<String, dynamic>>
      getOfficialOpenClawProvisionStatus() async {
    final result =
        await _channel.invokeMethod('getOfficialOpenClawProvisionStatus');
    return Map<String, dynamic>.from(result);
  }

  static Future<void> ensureAgentSkillsAwareness() async {
    await _channel.invokeMethod('ensureAgentSkillsAwareness');
  }

  static Future<Map<String, dynamic>> runNativePython(
    Map<String, dynamic> payload,
  ) async {
    final raw = await _channel.invokeMethod<String>('runNativePython', {
      'payloadJson': jsonEncode(payload),
    });
    final decoded = jsonDecode(raw ?? '{}');
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {
      'ok': false,
      'exitCode': 1,
      'stdout': '',
      'stderr': 'Native Python bridge returned a non-object response.',
    };
  }

  static Future<NativeFfmpegRunResult> runManagedFfmpeg(
    List<String> args, {
    required int timeoutSeconds,
  }) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'runManagedFfmpeg',
      {
        'args': args,
        'timeoutSeconds': timeoutSeconds,
      },
    );
    final result = Map<String, dynamic>.from(raw ?? const <dynamic, dynamic>{});
    return NativeFfmpegRunResult(
      exitCode: (result['exitCode'] as num?)?.toInt() ?? 1,
      stdout: result['stdout']?.toString() ?? '',
      stderr: result['stderr']?.toString() ?? '',
    );
  }

  static Future<NativeManagedCliRunResult> runManagedCli(
    String binName,
    List<String> args, {
    Map<String, String> env = const <String, String>{},
    required int timeoutSeconds,
  }) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'runManagedCli',
      {
        'binName': binName,
        'args': args,
        'env': env,
        'timeoutSeconds': timeoutSeconds,
      },
    );
    final result = Map<String, dynamic>.from(raw ?? const <dynamic, dynamic>{});
    return NativeManagedCliRunResult(
      exitCode: (result['exitCode'] as num?)?.toInt() ?? 1,
      stdout: result['stdout']?.toString() ?? '',
      stderr: result['stderr']?.toString() ?? '',
      binaryPath: result['binaryPath']?.toString() ?? '',
    );
  }

  static Future<bool> startNativeNodeSkillRunnerRuntime() async {
    return await _channel.invokeMethod('startNativeNodeSkillRunnerRuntime');
  }

  static Future<bool> stopNativeNodeSkillRunnerRuntime() async {
    return await _channel.invokeMethod('stopNativeNodeSkillRunnerRuntime');
  }

  static Future<String> getNativeNodeSkillRunnerRuntimeLogs() async {
    return await _channel.invokeMethod('getNativeNodeSkillRunnerRuntimeLogs');
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

    // Replace naked 'openclaw' commands only. Package specs such as
    // openclaw@2026.7.1 and package archive names must be left untouched.
    // (?<![/\.]) matches only if NOT preceded by / or .
    // (?![.@-]) avoids .js entry points, npm package specs, and filenames.
    return cmd.replaceAllMapped(RegExp(r'(?<![/\.])\bopenclaw\b(?![\.@-])'),
        (match) {
      return kOpenClawCommand;
    });
  }

  /// Destroy the persistent shell process (called when terminal screen closes).
  static Future<void> destroyShell() async {
    await _channel.invokeMethod('destroyShell');
  }

  static Future<bool> startGateway({bool allowDuringSetup = false}) async {
    return await _channel.invokeMethod('startGateway', {
      'allowDuringSetup': allowDuringSetup,
    });
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

  static Future<bool> startNativeGatewaySmokeRuntime() async {
    return await _channel
            .invokeMethod<bool>('startNativeGatewaySmokeRuntime') ??
        false;
  }

  static Future<bool> stopNativeGatewaySmokeRuntime() async {
    return await _channel.invokeMethod<bool>('stopNativeGatewaySmokeRuntime') ??
        false;
  }

  static Future<bool> isNativeGatewaySmokeRuntimeRunning() async {
    return await _channel
            .invokeMethod<bool>('isNativeGatewaySmokeRuntimeRunning') ??
        false;
  }

  static Future<String> getNativeGatewaySmokeRuntimeLogs() async {
    return await _channel
            .invokeMethod<String>('getNativeGatewaySmokeRuntimeLogs') ??
        '';
  }

  static Future<bool> startNativeNodeSmokeRuntime() async {
    return await _channel.invokeMethod<bool>('startNativeNodeSmokeRuntime') ??
        false;
  }

  static Future<bool> startNativeNodeProductionPortCanaryRuntime() async {
    return await _channel.invokeMethod<bool>(
          'startNativeNodeProductionPortCanaryRuntime',
        ) ??
        false;
  }

  static Future<bool> startNativeNodeFullGatewayBootstrapRuntime() async {
    return await _channel.invokeMethod<bool>(
          'startNativeNodeFullGatewayBootstrapRuntime',
        ) ??
        false;
  }

  static Future<bool> startNativeNodeFullGatewayProductionRuntime() async {
    return await _channel.invokeMethod<bool>(
          'startNativeNodeFullGatewayProductionRuntime',
        ) ??
        false;
  }

  static Future<bool> stopNativeNodeSmokeRuntime() async {
    return await _channel.invokeMethod<bool>('stopNativeNodeSmokeRuntime') ??
        false;
  }

  static Future<bool> promoteNativeGatewayNotification() async {
    return await _channel
            .invokeMethod<bool>('promoteNativeGatewayNotification') ??
        false;
  }

  static Future<bool> isNativeNodeSmokeRuntimeRunning() async {
    return await _channel
            .invokeMethod<bool>('isNativeNodeSmokeRuntimeRunning') ??
        false;
  }

  static Future<bool> isNativeNodeProductionPortCanaryRuntimeRunning() async {
    return await _channel.invokeMethod<bool>(
          'isNativeNodeProductionPortCanaryRuntimeRunning',
        ) ??
        false;
  }

  static Future<bool> isNativeNodeFullGatewayBootstrapRuntimeRunning() async {
    return await _channel.invokeMethod<bool>(
          'isNativeNodeFullGatewayBootstrapRuntimeRunning',
        ) ??
        false;
  }

  static Future<bool> isNativeNodeFullGatewayProductionRuntimeRunning() async {
    return await _channel.invokeMethod<bool>(
          'isNativeNodeFullGatewayProductionRuntimeRunning',
        ) ??
        false;
  }

  static Future<bool> isNativeNodeIsolatedProcessAlive() async {
    return await _channel.invokeMethod<bool>(
          'isNativeNodeIsolatedProcessAlive',
        ) ??
        false;
  }

  static Future<String> getNativeNodeSmokeRuntimeLogs() async {
    return await _channel
            .invokeMethod<String>('getNativeNodeSmokeRuntimeLogs') ??
        '';
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
    // PRoot rollback maintenance only. Native libnode.so does not use these
    // Linux package assets to start the Gateway.
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

  static Future<int> getBatteryLevel() async {
    return await _channel.invokeMethod<int>('getBatteryLevel') ?? -1;
  }

  static Future<bool> isCharging() async {
    return await _channel.invokeMethod<bool>('isCharging') ?? false;
  }

  static Future<int> getTotalMemoryMb() async {
    return await _channel.invokeMethod<int>('getTotalMemoryMb') ?? 4096;
  }

  static Future<Map<String, dynamic>?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final result = await _channel.invokeMethod('reverseGeocode', {
      'lat': latitude,
      'lng': longitude,
    });
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  // ── Wake Word "Plawie" ─────────────────────────────────────────────────────

  static const _hotwordChannel = MethodChannel('com.openclaw.plawie/hotword');
  static const _hotwordEventChannel =
      EventChannel('com.openclaw.plawie/hotword_events');

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
