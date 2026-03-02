import 'package:flutter/services.dart';
import 'preferences_service.dart';

class NativeBridge {
  static const _channel = MethodChannel('com.nxg.openclawproot/native');
  static const _eventChannel = EventChannel('com.nxg.openclawproot/gateway_logs');

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
    final nativeOk = await _channel.invokeMethod('isBootstrapComplete') ?? false;
    final prefs = PreferencesService();
    await prefs.init();
    return nativeOk || prefs.setupComplete;
  }

  static Future<Map<String, dynamic>> getBootstrapStatus() async {
    final result = await _channel.invokeMethod('getBootstrapStatus');
    return Map<String, dynamic>.from(result);
  }

  static Future<bool> extractRootfs(String tarPath) async {
    return await _channel.invokeMethod('extractRootfs', {'tarPath': tarPath});
  }

  // NOTE: No isolate needed — Kotlin already dispatches runInProotSync
  // inside a background Thread{}, so this call returns to Dart instantly.
  static Future<String> runInProot(String command, {int timeout = 900}) async {
    return await _channel.invokeMethod('runInProot', {'command': command, 'timeout': timeout});
  }

  static Future<bool> startGateway() async {
    return await _channel.invokeMethod('startGateway');
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
    return await _channel.invokeMethod('extractNodeTarball', {'tarPath': tarPath});
  }

  static Future<bool> createBinWrappers(String packageName) async {
    return await _channel.invokeMethod('createBinWrappers', {'packageName': packageName});
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
    return await _channel.invokeMethod('updateNodeNotification', {'text': text});
  }

  static Future<bool> startSetupService() async {
    return await _channel.invokeMethod('startSetupService');
  }

  static Future<bool> updateSetupNotification(String text, {int progress = -1}) async {
    return await _channel.invokeMethod('updateSetupNotification', {'text': text, 'progress': progress});
  }

  static Future<bool> stopSetupService() async {
    return await _channel.invokeMethod('stopSetupService');
  }

  static Future<bool> showUrlNotification(String url, {String title = 'URL Detected'}) async {
    return await _channel.invokeMethod('showUrlNotification', {'url': url, 'title': title});
  }

  static Stream<String> get gatewayLogStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }

  static Future<String?> requestScreenCapture(int durationMs) async {
    return await _channel.invokeMethod('requestScreenCapture', {'durationMs': durationMs});
  }

  static Future<bool> stopScreenCapture() async {
    return await _channel.invokeMethod('stopScreenCapture');
  }
}
