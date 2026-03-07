import 'dart:async';
import 'native_bridge.dart';

class DiagnosticService {
  /// Run a set of lightweight proot checks to surface why the gateway
  /// may not be starting. Returns a map of results.
  static Future<Map<String, String>> runGatewayDiagnostics() async {
    final results = <String, String>{};

    try {
      // Check for tmux binary
      final tmux = await _runSafe("command -v tmux || echo MISSING");
      results['tmux'] = tmux.trim();
    } catch (e) {
      results['tmux'] = 'error: $e';
    }

    try {
      // Check for openclaw binary
      final openclaw = await _runSafe("command -v openclaw || echo MISSING");
      results['openclaw'] = openclaw.trim();
    } catch (e) {
      results['openclaw'] = 'error: $e';
    }

    try {
      // Check if gateway process is running (original approach)
      final gatewayProcess = await _runSafe("pgrep -f 'openclaw gateway' > /dev/null && echo RUNNING || echo NOT_RUNNING");
      results['gateway_process'] = gatewayProcess.trim();
    } catch (e) {
      results['gateway_process'] = 'error: $e';
    }

    try {
      // Check common log locations where openclaw might write
      final logCheck = await _runSafe("ls -la /root/.openclaw/logs/ 2>/dev/null && echo LOGS_IN_LOGS_DIR || echo LOGS_IN_DEFAULT_DIR");
      results['log_location'] = logCheck.trim();
    } catch (e) {
      results['log_location'] = 'error: $e';
    }

    try {
      // Tail gateway log (up to last 200 lines)
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
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && $cmd', // Dual-shim verified.
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
