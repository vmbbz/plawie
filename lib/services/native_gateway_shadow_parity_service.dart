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

  static const bool _directCanaryDiagnosticsEnabled = bool.fromEnvironment(
    'PLAWIE_NATIVE_GATEWAY_DIRECT_CANARY_DIAGNOSTICS',
    defaultValue: false,
  );

  static const bool _primaryCanaryDiagnosticsEnabled = bool.fromEnvironment(
    'PLAWIE_NATIVE_GATEWAY_PRIMARY_CANARY_DIAGNOSTICS',
    defaultValue: false,
  );

  static bool get shadowDiagnosticsEnabled => _shadowDiagnosticsEnabled;

  static bool get directCanaryDiagnosticsEnabled =>
      _directCanaryDiagnosticsEnabled;

  static bool get primaryCanaryDiagnosticsEnabled =>
      _primaryCanaryDiagnosticsEnabled;

  static bool get diagnosticsEnabled =>
      _smokeDiagnosticsEnabled ||
      _shadowDiagnosticsEnabled ||
      _directCanaryDiagnosticsEnabled ||
      _primaryCanaryDiagnosticsEnabled;

  static DateTime? _lastNativeSkipLogAt;
  static DateTime? _lastNativeDryRunSkipLogAt;
  static DateTime? _lastNativeDirectCanarySkipLogAt;
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
              'source': dryRunAck['source'],
              'canaryMode': dryRunAck['canaryMode'],
              'directCanary': dryRunAck['directCanary'],
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

  static Future<Map<String, dynamic>?> sendDirectCanaryChatSendFrame(
    Map<String, dynamic> frame, {
    required void Function(String message) log,
  }) async {
    if (!_directCanaryDiagnosticsEnabled) return null;

    final local = _redactedWsChatSendShape(frame);
    try {
      final canary = await _directCanaryWithNativeProbe(frame);
      final ack = _redactedDryRunAck(canary);
      log(
        '[NATIVE-CANARY-DIRECT] ack: ${jsonEncode({
              'ok': ack['ok'],
              'parsed': ack['parsed'],
              'route': ack['route'],
              'source': ack['source'],
              'canaryMode': ack['canaryMode'],
              'directCanary': ack['directCanary'],
              'localHash': local['metadataHash'],
              'canaryHash': ack['metadataHash'],
              'hashMatches': local['metadataHash'] == ack['metadataHash'],
              'acceptedForRouting': ack['acceptedForRouting'],
              'acceptedForQueue': ack['acceptedForQueue'],
              'queuedForDryRun': ack['queuedForDryRun'],
              'queueStatus': ack['queueStatus'],
              'queueDepthBefore': ack['queueDepthBefore'],
              'queueDepthAfter': ack['queueDepthAfter'],
              'nativeSessionId': ack['nativeSessionId'],
              'runId': ack['runId'],
              'duplicate': ack['duplicate'],
              'providerCallsEnabled': ack['providerCallsEnabled'],
              'executionEnabled': ack['executionEnabled'],
              'sessionKey': ack['sessionKey'],
              'messageChars': ack['messageChars'],
              'mobileToolHints': ack['mobileToolHints'],
            })}',
      );
      return ack;
    } catch (e) {
      _logNativeDirectCanarySkip(log, e);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> sendPrimaryCanaryChatSendFrame(
    Map<String, dynamic> frame, {
    required void Function(String message) log,
  }) async {
    if (!_primaryCanaryDiagnosticsEnabled) return null;

    final local = _redactedWsChatSendShape(frame);
    try {
      final canary = await _directCanaryWithNativeProbe(frame);
      final ack = _redactedDryRunAck(canary);
      final hashMatches = local['metadataHash'] == ack['metadataHash'];
      log(
        '[NATIVE-PRIMARY-CANARY] ack: ${jsonEncode({
              'ok': ack['ok'],
              'parsed': ack['parsed'],
              'route': ack['route'],
              'source': ack['source'],
              'canaryMode': ack['canaryMode'],
              'directCanary': ack['directCanary'],
              'localHash': local['metadataHash'],
              'canaryHash': ack['metadataHash'],
              'hashMatches': hashMatches,
              'acceptedForRouting': ack['acceptedForRouting'],
              'acceptedForQueue': ack['acceptedForQueue'],
              'queuedForDryRun': ack['queuedForDryRun'],
              'queueStatus': ack['queueStatus'],
              'queueDepthBefore': ack['queueDepthBefore'],
              'queueDepthAfter': ack['queueDepthAfter'],
              'nativeSessionId': ack['nativeSessionId'],
              'runId': ack['runId'],
              'duplicate': ack['duplicate'],
              'providerCallsEnabled': ack['providerCallsEnabled'],
              'executionEnabled': ack['executionEnabled'],
              'sessionKey': ack['sessionKey'],
              'messageChars': ack['messageChars'],
              'mobileToolHints': ack['mobileToolHints'],
            })}',
      );
      return {
        ...ack,
        'localHash': local['metadataHash'],
        'hashMatches': hashMatches,
      };
    } catch (e) {
      _logNativePrimaryCanarySkip(log, e);
      return null;
    }
  }

  static Stream<Map<String, dynamic>> streamPrimaryCanaryChatSendFrame(
    Map<String, dynamic> frame, {
    required void Function(String message) log,
  }) async* {
    if (!_primaryCanaryDiagnosticsEnabled) {
      throw StateError('native primary canary diagnostics disabled');
    }

    final local = _redactedWsChatSendShape(frame);
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse(
          '${AppConstants.nativeGatewaySmokeUrl}'
          '/gateway/chat-send-canary-stream',
        ),
      )
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(frame);
      final response = await client
          .send(request)
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode != 202) {
        final body = await response.stream.bytesToString();
        throw StateError(
          'native stream canary HTTP ${response.statusCode}: $body',
        );
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map<String, dynamic>) continue;

        if (decoded['event'] == 'ack') {
          final ack = _redactedDryRunAck(decoded);
          final hashMatches = local['metadataHash'] == ack['metadataHash'];
          log(
            '[NATIVE-STREAM-CANARY] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'directCanary': ack['directCanary'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'acceptedForRouting': ack['acceptedForRouting'],
                  'acceptedForQueue': ack['acceptedForQueue'],
                  'queuedForDryRun': ack['queuedForDryRun'],
                  'queueStatus': ack['queueStatus'],
                  'nativeSessionId': ack['nativeSessionId'],
                  'runId': ack['runId'],
                  'duplicate': ack['duplicate'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'messageChars': ack['messageChars'],
                })}',
          );
          yield {
            ...decoded,
            'ack': {
              ...ack,
              'localHash': local['metadataHash'],
              'hashMatches': hashMatches,
            },
          };
          continue;
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeStreamCanarySkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>> streamRoutingSkeletonChatSendFrame(
    Map<String, dynamic> frame, {
    required void Function(String message) log,
  }) async* {
    if (!_primaryCanaryDiagnosticsEnabled) {
      throw StateError('native primary canary diagnostics disabled');
    }

    final local = _redactedWsChatSendShape(frame);
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse(
          '${AppConstants.nativeGatewaySmokeUrl}'
          '/gateway/chat-route-skeleton-stream',
        ),
      )
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(frame);
      final response = await client
          .send(request)
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode != 202) {
        final body = await response.stream.bytesToString();
        throw StateError(
          'native routing skeleton HTTP ${response.statusCode}: $body',
        );
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map<String, dynamic>) continue;

        if (decoded['event'] == 'ack') {
          final ack = _redactedDryRunAck(decoded);
          final hashMatches = local['metadataHash'] == ack['metadataHash'];
          log(
            '[NATIVE-ROUTE-SKELETON] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'directCanary': ack['directCanary'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'acceptedForRouting': ack['acceptedForRouting'],
                  'acceptedForQueue': ack['acceptedForQueue'],
                  'queuedForDryRun': ack['queuedForDryRun'],
                  'queueStatus': ack['queueStatus'],
                  'nativeSessionId': ack['nativeSessionId'],
                  'runId': ack['runId'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'messageChars': ack['messageChars'],
                })}',
          );
          yield {
            ...decoded,
            'ack': {
              ...ack,
              'localHash': local['metadataHash'],
              'hashMatches': hashMatches,
            },
          };
          continue;
        }

        if (decoded['event'] == 'route_plan') {
          final plan = decoded['routePlan'] is Map
              ? Map<String, dynamic>.from(decoded['routePlan'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-ROUTE-SKELETON] plan: ${jsonEncode({
                  'runId': decoded['runId'],
                  'routeStatus': plan['routeStatus'],
                  'acceptedForRouting': plan['acceptedForRouting'],
                  'providerGate':
                      (plan['providerCallGate'] as Map?)?['enabled'] == true,
                  'toolGate':
                      (plan['toolExecutionGate'] as Map?)?['enabled'] == true,
                  'cancelEndpoint': (plan['cancellation'] as Map?)?['endpoint'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeRouteSkeletonSkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>> streamProviderShellChatSendFrame(
    Map<String, dynamic> frame, {
    required void Function(String message) log,
  }) async* {
    if (!_primaryCanaryDiagnosticsEnabled) {
      throw StateError('native primary canary diagnostics disabled');
    }

    final local = _redactedWsChatSendShape(frame);
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse(
          '${AppConstants.nativeGatewaySmokeUrl}'
          '/gateway/chat-provider-shell-stream',
        ),
      )
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(frame);
      final response = await client
          .send(request)
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode != 202) {
        final body = await response.stream.bytesToString();
        throw StateError(
          'native provider shell HTTP ${response.statusCode}: $body',
        );
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map<String, dynamic>) continue;

        if (decoded['event'] == 'ack') {
          final ack = _redactedDryRunAck(decoded);
          final hashMatches = local['metadataHash'] == ack['metadataHash'];
          log(
            '[NATIVE-PROVIDER-SHELL] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'directCanary': ack['directCanary'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'acceptedForRouting': ack['acceptedForRouting'],
                  'acceptedForQueue': ack['acceptedForQueue'],
                  'provider': ack['provider'],
                  'requestedModel': ack['requestedModel'],
                  'transport': ack['transport'],
                  'envelopeHash': ack['envelopeHash'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'messageChars': ack['messageChars'],
                })}',
          );
          yield {
            ...decoded,
            'ack': {
              ...ack,
              'localHash': local['metadataHash'],
              'hashMatches': hashMatches,
            },
          };
          continue;
        }

        if (decoded['event'] == 'provider_envelope') {
          final envelope = decoded['envelope'] is Map
              ? Map<String, dynamic>.from(decoded['envelope'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-PROVIDER-SHELL] envelope: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': envelope['provider'],
                  'requestedModel': envelope['requestedModel'],
                  'providerModel': envelope['providerModel'],
                  'transport': envelope['transport'],
                  'outboundNetworkEnabled':
                      envelope['outboundNetworkEnabled'] == true,
                  'envelopeHash': envelope['envelopeHash'],
                })}',
          );
        }

        if (decoded['event'] == 'provider_gate') {
          final gate = decoded['gate'] is Map
              ? Map<String, dynamic>.from(decoded['gate'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-PROVIDER-SHELL] provider gate: ${jsonEncode({
                  'runId': decoded['runId'],
                  'enabled': gate['enabled'] == true,
                  'status': gate['status'],
                  'reason': gate['reason'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeProviderShellSkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>> streamProviderRequestBuilderChatSendFrame(
    Map<String, dynamic> frame, {
    required void Function(String message) log,
  }) async* {
    if (!_primaryCanaryDiagnosticsEnabled) {
      throw StateError('native primary canary diagnostics disabled');
    }

    final local = _redactedWsChatSendShape(frame);
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse(
          '${AppConstants.nativeGatewaySmokeUrl}'
          '/gateway/chat-provider-request-builder-stream',
        ),
      )
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(frame);
      final response = await client
          .send(request)
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode != 202) {
        final body = await response.stream.bytesToString();
        throw StateError(
          'native provider request builder HTTP ${response.statusCode}: $body',
        );
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map<String, dynamic>) continue;

        if (decoded['event'] == 'ack') {
          final ack = _redactedDryRunAck(decoded);
          final hashMatches = local['metadataHash'] == ack['metadataHash'];
          log(
            '[NATIVE-PROVIDER-BUILDER] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'directCanary': ack['directCanary'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'acceptedForRouting': ack['acceptedForRouting'],
                  'acceptedForQueue': ack['acceptedForQueue'],
                  'provider': ack['provider'],
                  'requestedModel': ack['requestedModel'],
                  'transport': ack['transport'],
                  'headersHash': ack['headersHash'],
                  'bodyHash': ack['bodyHash'],
                  'requestHash': ack['requestHash'],
                  'validationOk': ack['validationOk'],
                  'transportInvocationEnabled':
                      ack['transportInvocationEnabled'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'messageChars': ack['messageChars'],
                })}',
          );
          yield {
            ...decoded,
            'ack': {
              ...ack,
              'localHash': local['metadataHash'],
              'hashMatches': hashMatches,
            },
          };
          continue;
        }

        if (decoded['event'] == 'provider_request') {
          final builder = decoded['requestBuilder'] is Map
              ? Map<String, dynamic>.from(decoded['requestBuilder'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-PROVIDER-BUILDER] request: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': builder['provider'],
                  'requestedModel': builder['requestedModel'],
                  'transport': builder['transport'],
                  'headersHash': builder['headersHash'],
                  'bodyHash': builder['bodyHash'],
                  'requestHash': builder['requestHash'],
                  'validationOk': builder['validationOk'],
                  'transportInvocationEnabled':
                      builder['transportInvocationEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'request_validation') {
          log(
            '[NATIVE-PROVIDER-BUILDER] validation: ${jsonEncode({
                  'runId': decoded['runId'],
                  'validationOk': decoded['validationOk'] == true,
                  'providerConfigStatus':
                      (decoded['providerConfigStatus'] as Map?)?['mode'],
                })}',
          );
        }

        if (decoded['event'] == 'transport_gate') {
          final gate = decoded['gate'] is Map
              ? Map<String, dynamic>.from(decoded['gate'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-PROVIDER-BUILDER] transport gate: ${jsonEncode({
                  'runId': decoded['runId'],
                  'enabled': gate['enabled'] == true,
                  'status': gate['status'],
                  'reason': gate['reason'],
                  'blockedBefore': gate['blockedBefore'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeProviderBuilderSkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>> streamProviderTransportShimChatSendFrame(
    Map<String, dynamic> frame, {
    required void Function(String message) log,
  }) async* {
    if (!_primaryCanaryDiagnosticsEnabled) {
      throw StateError('native primary canary diagnostics disabled');
    }

    final local = _redactedWsChatSendShape(frame);
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse(
          '${AppConstants.nativeGatewaySmokeUrl}'
          '/gateway/chat-provider-transport-shim-stream',
        ),
      )
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(frame);
      final response = await client
          .send(request)
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode != 202) {
        final body = await response.stream.bytesToString();
        throw StateError(
          'native transport shim HTTP ${response.statusCode}: $body',
        );
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map<String, dynamic>) continue;

        if (decoded['event'] == 'ack') {
          final ack = _redactedDryRunAck(decoded);
          final hashMatches = local['metadataHash'] == ack['metadataHash'];
          log(
            '[NATIVE-TRANSPORT-SHIM] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'directCanary': ack['directCanary'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'acceptedForRouting': ack['acceptedForRouting'],
                  'acceptedForQueue': ack['acceptedForQueue'],
                  'provider': ack['provider'],
                  'requestedModel': ack['requestedModel'],
                  'transport': ack['transport'],
                  'requestHash': ack['requestHash'],
                  'transportHash': ack['transportHash'],
                  'validationOk': ack['validationOk'],
                  'abortStage': ack['abortStage'],
                  'dnsLookupStarted': ack['dnsLookupStarted'],
                  'tlsHandshakeStarted': ack['tlsHandshakeStarted'],
                  'socketOpened': ack['socketOpened'],
                  'requestBytesWritten': ack['requestBytesWritten'],
                  'providerBillingSurfaceReached':
                      ack['providerBillingSurfaceReached'],
                  'transportInvocationEnabled':
                      ack['transportInvocationEnabled'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'messageChars': ack['messageChars'],
                })}',
          );
          yield {
            ...decoded,
            'ack': {
              ...ack,
              'localHash': local['metadataHash'],
              'hashMatches': hashMatches,
            },
          };
          continue;
        }

        if (decoded['event'] == 'transport_shim') {
          final shim = decoded['transportShim'] is Map
              ? Map<String, dynamic>.from(decoded['transportShim'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-TRANSPORT-SHIM] shim: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': shim['provider'],
                  'transport': shim['transport'],
                  'transportHash': shim['transportHash'],
                  'validationOk': shim['validationOk'],
                  'stopBefore': shim['stopBefore'],
                })}',
          );
        }

        if (decoded['event'] == 'abort_contract') {
          final abort = decoded['abortContract'] is Map
              ? Map<String, dynamic>.from(decoded['abortContract'] as Map)
              : <String, dynamic>{};
          final probe = decoded['networkProbe'] is Map
              ? Map<String, dynamic>.from(decoded['networkProbe'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-TRANSPORT-SHIM] abort: ${jsonEncode({
                  'runId': decoded['runId'],
                  'abortedLocally': abort['abortedLocally'] == true,
                  'abortStage': abort['abortStage'],
                  'socketOpened': probe['socketOpened'] == true,
                  'requestBytesWritten': probe['requestBytesWritten'],
                  'providerBillingSurfaceReached':
                      probe['providerBillingSurfaceReached'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'transport_gate') {
          final gate = decoded['gate'] is Map
              ? Map<String, dynamic>.from(decoded['gate'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-TRANSPORT-SHIM] gate: ${jsonEncode({
                  'runId': decoded['runId'],
                  'enabled': gate['enabled'] == true,
                  'status': gate['status'],
                  'reason': gate['reason'],
                  'blockedBefore': gate['blockedBefore'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeTransportShimSkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>> streamProviderLiveCanaryChatSendFrame(
    Map<String, dynamic> frame, {
    required Map<String, dynamic> providerConfig,
    required void Function(String message) log,
  }) async* {
    if (!_primaryCanaryDiagnosticsEnabled) {
      throw StateError('native primary canary diagnostics disabled');
    }

    final local = _redactedWsChatSendShape(frame);
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse(
          '${AppConstants.nativeGatewaySmokeUrl}'
          '/gateway/chat-provider-live-canary-stream',
        ),
      )
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode({
          ...frame,
          'nativeCanaryProviderConfig': providerConfig,
        });
      final response = await client
          .send(request)
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode != 202) {
        final body = await response.stream.bytesToString();
        throw StateError(
          'native provider live canary HTTP ${response.statusCode}: $body',
        );
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map<String, dynamic>) continue;

        if (decoded['event'] == 'ack') {
          final ack = _redactedDryRunAck(decoded);
          final hashMatches = local['metadataHash'] == ack['metadataHash'];
          log(
            '[NATIVE-PROVIDER-LIVE] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'directCanary': ack['directCanary'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'acceptedForRouting': ack['acceptedForRouting'],
                  'acceptedForQueue': ack['acceptedForQueue'],
                  'provider': ack['provider'],
                  'requestedModel': ack['requestedModel'],
                  'providerModel': ack['providerModel'],
                  'transport': ack['transport'],
                  'requestHash': ack['requestHash'],
                  'validationOk': ack['validationOk'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'transportInvocationEnabled':
                      ack['transportInvocationEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'providerCallStarted': ack['providerCallStarted'],
                  'maxTokens': ack['maxTokens'],
                  'requestBodyBytes': ack['requestBodyBytes'],
                  'messageChars': ack['messageChars'],
                })}',
          );
          yield {
            ...decoded,
            'ack': {
              ...ack,
              'localHash': local['metadataHash'],
              'hashMatches': hashMatches,
            },
          };
          continue;
        }

        if (decoded['event'] == 'provider_request') {
          final providerRequest = decoded['providerRequest'] is Map
              ? Map<String, dynamic>.from(decoded['providerRequest'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-PROVIDER-LIVE] request: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': providerRequest['provider'],
                  'providerModel': providerRequest['providerModel'],
                  'requestHash': providerRequest['requestHash'],
                  'maxTokens': providerRequest['maxTokens'],
                  'promptChars': providerRequest['promptChars'],
                  'requestBodyBytes': providerRequest['requestBodyBytes'],
                  'providerCallsEnabled':
                      providerRequest['providerCallsEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'provider_call_started') {
          log(
            '[NATIVE-PROVIDER-LIVE] provider call started: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': decoded['provider'],
                  'requestHash': decoded['requestHash'],
                  'requestBodyBytes': decoded['requestBodyBytes'],
                  'providerBillingSurfaceReached':
                      decoded['providerBillingSurfaceReached'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'provider_response') {
          log(
            '[NATIVE-PROVIDER-LIVE] response: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': decoded['provider'],
                  'statusCode': decoded['statusCode'],
                  'contentType': decoded['contentType'],
                  'firstByteMs': decoded['firstByteMs'],
                })}',
          );
        }

        if (decoded['event'] == 'provider_gate') {
          final gate = decoded['gate'] is Map
              ? Map<String, dynamic>.from(decoded['gate'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-PROVIDER-LIVE] gate: ${jsonEncode({
                  'runId': decoded['runId'],
                  'enabled': gate['enabled'] == true,
                  'status': gate['status'],
                  'reason': gate['reason'],
                  'blockedBefore': gate['blockedBefore'],
                })}',
          );
        }

        if (decoded['event'] == 'provider_error') {
          final error = decoded['error'];
          log(
            '[NATIVE-PROVIDER-LIVE] provider error: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': decoded['provider'],
                  'statusCode': decoded['statusCode'],
                  'error': error,
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeProviderLiveSkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
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
      'source': report.dryRun?['source'],
      'canaryMode': report.dryRun?['canaryMode'],
      'directCanary': report.dryRun?['directCanary'],
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
    return _postChatSendToNativeProbe(
      frame,
      endpoint: '/gateway/chat-send-dry-run',
      label: 'native dry-run',
    );
  }

  static Future<Map<String, dynamic>> _directCanaryWithNativeProbe(
    Map<String, dynamic> frame,
  ) async {
    return _postChatSendToNativeProbe(
      frame,
      endpoint: '/gateway/chat-send-canary',
      label: 'native direct canary',
      timeout: const Duration(milliseconds: 1500),
    );
  }

  static Future<Map<String, dynamic>> _postChatSendToNativeProbe(
    Map<String, dynamic> frame, {
    required String endpoint,
    required String label,
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(
              '${AppConstants.nativeGatewaySmokeUrl}$endpoint',
            ),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(frame),
          )
          .timeout(timeout);

      if (response.statusCode != 202) {
        throw StateError('$label HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('$label response was not an object');
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
      'routeStatus': response['routeStatus'] ?? ack['routeStatus'],
      'source': response['source'] ?? ack['source'],
      'canaryMode': response['canaryMode'] ?? ack['canaryMode'],
      'directCanary':
          response['directCanary'] == true || ack['directCanary'] == true,
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
      'provider': ack['provider'],
      'requestedModel': ack['requestedModel'],
      'providerModel': ack['providerModel'],
      'transport': ack['transport'],
      'envelopeHash': ack['envelopeHash'],
      'headersHash': ack['headersHash'],
      'bodyHash': ack['bodyHash'],
      'requestHash': ack['requestHash'],
      'transportHash': ack['transportHash'],
      'validationOk': ack['validationOk'] == true,
      'endpointHost': ack['endpointHost'],
      'endpointPath': ack['endpointPath'],
      'maxTokens': ack['maxTokens'],
      'promptChars': ack['promptChars'],
      'requestBodyBytes': ack['requestBodyBytes'],
      'providerCallStarted': ack['providerCallStarted'] == true,
      'abortStage': ack['abortStage'],
      'abortedLocally': ack['abortedLocally'] == true,
      'dnsLookupStarted': ack['dnsLookupStarted'] == true,
      'tlsHandshakeStarted': ack['tlsHandshakeStarted'] == true,
      'socketOpened': ack['socketOpened'] == true,
      'requestBytesWritten': ack['requestBytesWritten'],
      'providerBillingSurfaceReached':
          ack['providerBillingSurfaceReached'] == true,
      'transportInvocationEnabled':
          response['transportInvocationEnabled'] == true ||
              ack['transportInvocationEnabled'] == true,
      'providerConfigStatus': ack['providerConfigStatus'],
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

  static void _logNativeDirectCanarySkip(
    void Function(String message) log,
    Object error,
  ) {
    final now = DateTime.now();
    final last = _lastNativeDirectCanarySkipLogAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastNativeDirectCanarySkipLogAt = now;
    log(
      '[NATIVE-CANARY-DIRECT] native direct canary unavailable; '
      'PRoot remains primary (${error.runtimeType})',
    );
  }

  static void _logNativePrimaryCanarySkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-PRIMARY-CANARY] native primary canary failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeStreamCanarySkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-STREAM-CANARY] native stream canary failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeRouteSkeletonSkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-ROUTE-SKELETON] native routing skeleton failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeProviderShellSkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-PROVIDER-SHELL] native provider shell failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeProviderBuilderSkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-PROVIDER-BUILDER] native provider request builder failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeTransportShimSkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-TRANSPORT-SHIM] native transport shim failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeProviderLiveSkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-PROVIDER-LIVE] native provider live canary failed '
      '(${error.runtimeType})',
    );
  }
}
