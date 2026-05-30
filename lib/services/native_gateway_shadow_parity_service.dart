import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';

class NativeGatewayShadowParityReport {
  final Map<String, dynamic> local;
  final Map<String, dynamic>? native;
  final Map<String, dynamic>? dryRun;
  final List<String> differences;
  final bool nativeCompared;
  final bool dryRunForwarded;

  const NativeGatewayShadowParityReport({
    required this.local,
    required this.differences,
    required this.nativeCompared,
    this.dryRunForwarded = false,
    this.native,
    this.dryRun,
  });

  bool get parityOk => nativeCompared && differences.isEmpty;
  bool get dryRunOk =>
      dryRunForwarded &&
      dryRun?['ok'] == true &&
      dryRun?['parsed'] == true &&
      dryRun?['route'] == 'disabled' &&
      dryRun?['acceptedForRouting'] == false &&
      dryRun?['acceptedForQueue'] == true &&
      dryRun?['queuedForDryRun'] == true &&
      dryRun?['queueStatus'] == 'parsed_disabled' &&
      dryRun?['providerCallsEnabled'] == false &&
      dryRun?['executionEnabled'] == false;
}

/// Diagnostics-only shadow observer for the native Node Gateway migration.
///
/// The observer never routes chat and never stores raw user text. It computes a
/// redacted metadata snapshot for the production PRoot `chat.send` frame, then
/// optionally asks the embedded Node probe to parse the same frame if the probe
/// is already running on the alternate diagnostics port.
class NativeGatewayShadowParityService {
  NativeGatewayShadowParityService._();

  static const bool _smokeDiagnosticsEnabled = bool.fromEnvironment(
    'PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS',
    defaultValue: false,
  );

  static const bool _shadowDiagnosticsEnabled = bool.fromEnvironment(
    'PLAWIE_NATIVE_GATEWAY_SHADOW_PARITY_DIAGNOSTICS',
    defaultValue: false,
  );

  static bool get shadowDiagnosticsEnabled => _shadowDiagnosticsEnabled;

  static bool get diagnosticsEnabled =>
      _smokeDiagnosticsEnabled || _shadowDiagnosticsEnabled;

  static DateTime? _lastNativeSkipLogAt;
  static DateTime? _lastNativeDryRunSkipLogAt;
  static final List<Map<String, dynamic>> _recentReports =
      <Map<String, dynamic>>[];

  static List<Map<String, dynamic>> get recentReports =>
      List.unmodifiable(_recentReports);

  static Future<NativeGatewayShadowParityReport?> observeChatSendFrame(
    Map<String, dynamic> frame, {
    required void Function(String message) log,
  }) async {
    if (!diagnosticsEnabled) return null;

    final local = _redactedWsChatSendShape(frame);
    log('[NATIVE-SHADOW] PRoot chat.send shape: ${jsonEncode(local)}');

    Map<String, dynamic>? normalizedNative;
    var differences = const <String>[];
    var nativeCompared = false;

    try {
      final native = await _parseWithNativeProbe(frame);
      final nativeShape = native['requestShape'];
      if (nativeShape is! Map<String, dynamic>) {
        log('[NATIVE-SHADOW] native parser returned no requestShape');
        differences = const <String>['requestShape'];
      } else {
        normalizedNative = _redactedNativeShape(nativeShape);
        differences = _diff(local, normalizedNative);
        nativeCompared = true;
        log(
          '[NATIVE-SHADOW] parity: ${jsonEncode({
                'ok': differences.isEmpty,
                'localHash': local['metadataHash'],
                'nativeHash': normalizedNative['metadataHash'],
                'differences': differences,
              })}',
        );
      }
    } catch (e) {
      _logNativeProbeSkip(log, e);
    }

    Map<String, dynamic>? dryRunAck;
    var dryRunForwarded = false;
    try {
      final dryRun = await _dryRunWithNativeProbe(frame);
      dryRunAck = _redactedDryRunAck(dryRun);
      dryRunForwarded = true;
      log(
        '[NATIVE-DRYRUN] ack: ${jsonEncode({
              'ok': dryRunAck['ok'],
              'parsed': dryRunAck['parsed'],
              'route': dryRunAck['route'],
              'localHash': local['metadataHash'],
              'dryRunHash': dryRunAck['metadataHash'],
              'hashMatches': local['metadataHash'] == dryRunAck['metadataHash'],
              'acceptedForRouting': dryRunAck['acceptedForRouting'],
              'acceptedForQueue': dryRunAck['acceptedForQueue'],
              'queuedForDryRun': dryRunAck['queuedForDryRun'],
              'queueStatus': dryRunAck['queueStatus'],
              'queueDepthBefore': dryRunAck['queueDepthBefore'],
              'queueDepthAfter': dryRunAck['queueDepthAfter'],
              'nativeSessionId': dryRunAck['nativeSessionId'],
              'runId': dryRunAck['runId'],
              'duplicate': dryRunAck['duplicate'],
              'providerCallsEnabled': dryRunAck['providerCallsEnabled'],
              'executionEnabled': dryRunAck['executionEnabled'],
              'sessionKey': dryRunAck['sessionKey'],
              'messageChars': dryRunAck['messageChars'],
              'mobileToolHints': dryRunAck['mobileToolHints'],
            })}',
      );
    } catch (e) {
      _logNativeDryRunSkip(log, e);
    }

    final report = NativeGatewayShadowParityReport(
      local: local,
      native: normalizedNative,
      dryRun: dryRunAck,
      differences: differences,
      nativeCompared: nativeCompared,
      dryRunForwarded: dryRunForwarded,
    );
    _remember(report);
    return report;
  }

  static void _remember(NativeGatewayShadowParityReport report) {
    _recentReports.add({
      'at': DateTime.now().toIso8601String(),
      'nativeCompared': report.nativeCompared,
      'parityOk': report.parityOk,
      'dryRunForwarded': report.dryRunForwarded,
      'dryRunOk': report.dryRunOk,
      'differences': report.differences,
      'localHash': report.local['metadataHash'],
      'nativeHash': report.native?['metadataHash'],
      'dryRunHash': report.dryRun?['metadataHash'],
      'sessionKey': report.local['sessionKey'],
      'nativeSessionId': report.dryRun?['nativeSessionId'],
      'runId': report.dryRun?['runId'],
      'queueStatus': report.dryRun?['queueStatus'],
      'queueDepthAfter': report.dryRun?['queueDepthAfter'],
      'messageChars': report.local['messageChars'],
      'mobileToolHints': report.local['mobileToolHints'],
    });
    if (_recentReports.length > 24) {
      _recentReports.removeRange(0, _recentReports.length - 24);
    }
  }

  static Map<String, dynamic> _redactedWsChatSendShape(
    Map<String, dynamic> frame,
  ) {
    final params = frame['params'] is Map
        ? Map<String, dynamic>.from(frame['params'] as Map)
        : <String, dynamic>{};
    final message =
        params['message'] is String ? params['message'] as String : '';
    final hints = _mobileToolHints(message);
    final metadata = <String, dynamic>{
      'requestShape': 'openclaw-ws-rpc-chat-send',
      'frameType': frame['type'],
      'method': frame['method'],
      'hasId': (frame['id'] as String?)?.isNotEmpty == true,
      'hasParams': params.isNotEmpty,
      'sessionKey': params['sessionKey'],
      'messageChars': message.length,
      'hasMessage': message.isNotEmpty,
      'idempotencyKeyPresent':
          (params['idempotencyKey'] as String?)?.isNotEmpty == true,
      'timeoutMs': params['timeoutMs'],
      'hasMobileToolContext': message.contains('<plawie_mobile_tool_context>'),
      'mobileNodeHandle': _extractMobileNodeHandle(message),
      'notificationListDisabled': message.contains(
        'Notification listing/reading is not currently exposed',
      ),
      'mobileToolHints': hints,
      'looksLikeProductionChatSend': frame['type'] == 'req' &&
          frame['method'] == 'chat.send' &&
          (frame['id'] as String?)?.isNotEmpty == true &&
          params['sessionKey'] is String &&
          params['message'] is String &&
          (params['idempotencyKey'] as String?)?.isNotEmpty == true &&
          params['timeoutMs'] is num,
      'acceptedForRouting': false,
      'providerCallsEnabled': false,
      'executionEnabled': false,
    };
    return {
      ...metadata,
      'metadataHash': _metadataHash(metadata),
    };
  }

  static Map<String, dynamic> _redactedNativeShape(Map<String, dynamic> shape) {
    final metadata = <String, dynamic>{
      'requestShape': shape['requestShape'],
      'frameType': shape['frameType'],
      'method': shape['method'],
      'hasId': shape['hasId'],
      'hasParams': shape['hasParams'],
      'sessionKey': shape['sessionKey'],
      'messageChars': shape['messageChars'],
      'hasMessage': shape['hasMessage'],
      'idempotencyKeyPresent': shape['idempotencyKeyPresent'],
      'timeoutMs': shape['timeoutMs'],
      'hasMobileToolContext': shape['hasMobileToolContext'],
      'mobileNodeHandle': shape['mobileNodeHandle'],
      'notificationListDisabled': shape['notificationListDisabled'],
      'mobileToolHints': _sortedStringList(shape['mobileToolHints']),
      'looksLikeProductionChatSend': shape['looksLikeProductionChatSend'],
      'acceptedForRouting': shape['acceptedForRouting'],
      'providerCallsEnabled': shape['providerCallsEnabled'],
      'executionEnabled': shape['executionEnabled'],
    };
    return {
      ...metadata,
      'metadataHash': _metadataHash(metadata),
    };
  }

  static Future<Map<String, dynamic>> _parseWithNativeProbe(
    Map<String, dynamic> frame,
  ) async {
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(
              '${AppConstants.nativeGatewaySmokeUrl}/gateway/ws-frame-shape',
            ),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(frame),
          )
          .timeout(const Duration(milliseconds: 900));

      if (response.statusCode != 200) {
        throw StateError('native probe HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('native probe response was not an object');
      }
      return decoded;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _dryRunWithNativeProbe(
    Map<String, dynamic> frame,
  ) async {
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(
              '${AppConstants.nativeGatewaySmokeUrl}/gateway/chat-send-dry-run',
            ),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(frame),
          )
          .timeout(const Duration(milliseconds: 1200));

      if (response.statusCode != 202) {
        throw StateError('native dry-run HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('native dry-run response was not an object');
      }
      return decoded;
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _redactedDryRunAck(
    Map<String, dynamic> response,
  ) {
    final ack = response['ack'] is Map
        ? Map<String, dynamic>.from(response['ack'] as Map)
        : <String, dynamic>{};
    return {
      'ok': response['ok'] == true,
      'type': response['type'],
      'method': response['method'],
      'parsed': response['parsed'] == true,
      'route': ack['route'],
      'acceptedForRouting': response['acceptedForRouting'] == true,
      'acceptedForQueue': response['acceptedForQueue'] == true,
      'queuedForDryRun': response['queuedForDryRun'] == true,
      'queueStatus': response['queueStatus'] ?? ack['queueStatus'],
      'queueDepthBefore': ack['queueDepthBefore'],
      'queueDepthAfter': ack['queueDepthAfter'],
      'pendingQueueDepth': ack['pendingQueueDepth'],
      'chatRoutingEnabled': response['chatRoutingEnabled'] == true,
      'providerCallsEnabled': response['providerCallsEnabled'] == true,
      'executionEnabled': response['executionEnabled'] == true,
      'sessionKey': ack['sessionKey'],
      'nativeSessionId': ack['nativeSessionId'],
      'requestId': ack['requestId'],
      'runId': ack['runId'],
      'sequence': ack['sequence'],
      'sessionAccepted': ack['sessionAccepted'],
      'sessionCompleted': ack['sessionCompleted'],
      'sessionDuplicate': ack['sessionDuplicate'],
      'duplicate': ack['duplicate'] == true,
      'duplicateOfRequestId': ack['duplicateOfRequestId'],
      'queuedAt': ack['queuedAt'],
      'parsedAt': ack['parsedAt'],
      'idempotencyKeyPresent': ack['idempotencyKeyPresent'] == true,
      'timeoutMs': ack['timeoutMs'],
      'messageChars': ack['messageChars'],
      'hasMobileToolContext': ack['hasMobileToolContext'] == true,
      'mobileNodeHandle': ack['mobileNodeHandle'],
      'mobileToolHints': _sortedStringList(ack['mobileToolHints']),
      'metadataHash': ack['metadataHash'],
    };
  }

  static List<String> _mobileToolHints(String message) {
    final hints = <String>[
      'camera_snap',
      'device_status',
      'avatar.gesture',
      'canvas.navigate',
      'canvas.eval',
      'canvas.snapshot',
      'haptic.vibrate',
      'sensor.read',
      'sensor.list',
      'flash.status',
      'notifications.list',
    ].where(message.contains).toList();
    hints.sort();
    return hints;
  }

  static List<String> _sortedStringList(Object? value) {
    if (value is! List) return <String>[];
    final items = value.map((entry) => entry.toString()).toList();
    items.sort();
    return items;
  }

  static String? _extractMobileNodeHandle(String message) {
    final match = RegExp(r'gateway handle is "([^"]+)"').firstMatch(message);
    return match?.group(1);
  }

  static String _metadataHash(Map<String, dynamic> metadata) {
    final digest = sha256.convert(utf8.encode(jsonEncode(metadata)));
    return digest.toString().substring(0, 16);
  }

  static List<String> _diff(
    Map<String, dynamic> local,
    Map<String, dynamic> native,
  ) {
    final differences = <String>[];
    for (final key in local.keys) {
      if (key == 'metadataHash') continue;
      final left = local[key];
      final right = native[key];
      if (jsonEncode(left) != jsonEncode(right)) {
        differences.add(key);
      }
    }
    return differences;
  }

  static void _logNativeProbeSkip(
    void Function(String message) log,
    Object error,
  ) {
    final now = DateTime.now();
    final last = _lastNativeSkipLogAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastNativeSkipLogAt = now;
    log(
      '[NATIVE-SHADOW] native parser unavailable; local redacted shape only '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeDryRunSkip(
    void Function(String message) log,
    Object error,
  ) {
    final now = DateTime.now();
    final last = _lastNativeDryRunSkipLogAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastNativeDryRunSkipLogAt = now;
    log(
      '[NATIVE-DRYRUN] native dry-run unavailable; PRoot remains primary '
      '(${error.runtimeType})',
    );
  }
}
