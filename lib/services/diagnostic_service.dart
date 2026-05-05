import 'dart:async';
import 'native_bridge.dart';

class DiagnosticService {
  /// Run a set of lightweight proot checks to surface why the gateway
  /// may not be starting. Returns a map of results.
  /// Run a comprehensive set of checks to surface installation or runtime issues.
  /// Reports on both the filesystem state (host side) and environment state (proot side).
  static Future<Map<String, String>> runGatewayDiagnostics() async {
    final results = <String, String>{};

    // 1. Filesystem Health (Host side checks via NativeBridge)
    try {
      final status = await NativeBridge.getBootstrapStatus();
      results['rootfs_exists'] = (status['rootfsExists'] ?? false) ? 'OK' : 'MISSING';
      results['bin_bash'] = (status['binBashExists'] ?? false) ? 'OK' : 'MISSING';
      results['node_binary'] = (status['nodeInstalled'] ?? false) ? 'OK' : 'MISSING';
      results['openclaw_package'] = (status['openclawInstalled'] ?? false) ? 'OK' : 'MISSING';
      results['bionic_bypass'] = (status['bypassInstalled'] ?? false) ? 'OK' : 'MISSING';
    } catch (e) {
      results['host_status_error'] = e.toString();
    }

    // 2. Runtime Environment (Inside PRoot)
    try {
      // Check for tmux binary
      final tmux = await _runSafe("command -v tmux || echo MISSING");
      results['tmux_path'] = tmux.trim();
    } catch (e) {
      results['tmux_error'] = e.toString();
    }

    try {
      // Check for node version and arch
      final nodeInfo = await _runSafe("node -v && uname -m");
      results['node_env'] = nodeInfo.trim().replaceAll('\n', ' ');
    } catch (e) {
      results['node_error'] = e.toString();
    }

    try {
      // Check if gateway process is running
      final pgrep = await _runSafe("pgrep -f 'openclaw gateway' > /dev/null && echo RUNNING || echo NOT_RUNNING");
      results['gateway_process'] = pgrep.trim();
    } catch (e) {
      results['gateway_process_error'] = e.toString();
    }

    try {
      // Check config file health
      final configCheck = await _runSafe("ls -l /root/.openclaw/openclaw.json && cat /root/.openclaw/openclaw.json | jq . > /dev/null 2>&1 && echo VALID_JSON || echo INVALID_OR_MISSING");
      results['config_health'] = configCheck.trim();
    } catch (e) {
      results['config_error'] = e.toString();
    }

    try {
      // Tail gateway log
      final logs = await DiagnosticService._getLogs();
      results['gateway_log_tail'] = logs;
    } catch (e) {
      results['gateway_log_tail'] = 'error: $e';
    }

    return results;
  }

  static Future<String> _runSafe(String cmd) async {
    try {
      final out = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && $cmd',
        timeout: 10
      );
      return out;
    } catch (e) {
      return 'exception: ${e.toString()}';
    }
  }

  static Future<String> _getLogs() async {
    try {
      final raw = await NativeBridge.getGatewayLogs();
      return raw;
    } catch (e) {
      return 'error reading logs: $e';
    }
  }
}
