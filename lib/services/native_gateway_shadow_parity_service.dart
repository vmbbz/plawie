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

  static Stream<Map<String, dynamic>>
      streamProviderStreamParserParityChatSendFrame(
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
          '/gateway/chat-provider-stream-parser-parity-stream',
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
          'native provider stream parser parity HTTP ${response.statusCode}: $body',
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
            '[NATIVE-STREAM-PARITY] ack: ${jsonEncode({
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
                  'fixtureHash': ack['fixtureHash'],
                  'fixtureParityOk': ack['fixtureParityOk'],
                  'validationOk': ack['validationOk'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'transportInvocationEnabled':
                      ack['transportInvocationEnabled'],
                  'executionEnabled': ack['executionEnabled'],
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

        if (decoded['event'] == 'parser_fixture') {
          final fixture = decoded['fixture'] is Map
              ? Map<String, dynamic>.from(decoded['fixture'] as Map)
              : <String, dynamic>{};
          final parsed = fixture['parsed'] is Map
              ? Map<String, dynamic>.from(fixture['parsed'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-STREAM-PARITY] parser fixture: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'text': parsed['text'],
                  'finishReason': parsed['finishReason'],
                  'warningCount': parsed['warningCount'],
                  'parserHash': parsed['parserHash'],
                })}',
          );
        }

        if (decoded['event'] == 'error_fixture' ||
            decoded['event'] == 'timeout_fixture' ||
            decoded['event'] == 'cancellation_fixture') {
          final fixture = decoded['fixture'] is Map
              ? Map<String, dynamic>.from(decoded['fixture'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-STREAM-PARITY] ${decoded['event']}: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'fixture': fixture['fixture'],
                  'parityOk': fixture['parityOk'],
                })}',
          );
        }

        if (decoded['event'] == 'provider_call_started') {
          log(
            '[NATIVE-STREAM-PARITY] provider call started: ${jsonEncode({
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
            '[NATIVE-STREAM-PARITY] response: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': decoded['provider'],
                  'statusCode': decoded['statusCode'],
                  'contentType': decoded['contentType'],
                  'firstByteMs': decoded['firstByteMs'],
                })}',
          );
        }

        if (decoded['event'] == 'live_parser_summary') {
          final summary = decoded['parserSummary'] is Map
              ? Map<String, dynamic>.from(decoded['parserSummary'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-STREAM-PARITY] live summary: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'textChars': summary['textChars'],
                  'finishReason': summary['finishReason'],
                  'warningCount': summary['warningCount'],
                  'fixtureParityOk': decoded['fixtureParityOk'],
                  'liveParityOk': decoded['liveParityOk'],
                  'parityOk': decoded['parityOk'],
                })}',
          );
        }

        if (decoded['event'] == 'provider_gate') {
          final gate = decoded['gate'] is Map
              ? Map<String, dynamic>.from(decoded['gate'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-STREAM-PARITY] gate: ${jsonEncode({
                  'runId': decoded['runId'],
                  'enabled': gate['enabled'] == true,
                  'status': gate['status'],
                  'reason': gate['reason'],
                  'blockedBefore': gate['blockedBefore'],
                })}',
          );
        }

        if (decoded['event'] == 'provider_error') {
          log(
            '[NATIVE-STREAM-PARITY] provider error: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': decoded['provider'],
                  'statusCode': decoded['statusCode'],
                  'error': decoded['error'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeStreamParitySkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>> streamProviderToolPlanCanaryChatSendFrame(
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
          '/gateway/chat-provider-tool-plan-canary-stream',
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
          'native provider tool plan canary HTTP ${response.statusCode}: $body',
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
            '[NATIVE-TOOL-PLAN] ack: ${jsonEncode({
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
                  'providerModel': ack['providerModel'],
                  'requestHash': ack['requestHash'],
                  'toolSelectionHash': ack['toolSelectionHash'],
                  'fixtureHash': ack['fixtureHash'],
                  'fixtureParityOk': ack['fixtureParityOk'],
                  'validationOk': ack['validationOk'],
                  'selectedToolCount': ack['selectedToolCount'],
                  'toolPlanCount': ack['toolPlanCount'],
                  'allowedPlanCount': ack['allowedPlanCount'],
                  'blockedPlanCount': ack['blockedPlanCount'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'transportInvocationEnabled':
                      ack['transportInvocationEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'toolExecutionEnabled': ack['toolExecutionEnabled'],
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

        if (decoded['event'] == 'tool_catalog') {
          log(
            '[NATIVE-TOOL-PLAN] catalog: ${jsonEncode({
                  'runId': decoded['runId'],
                  'selectedToolCount': decoded['selectedToolCount'],
                  'toolFunctionNames': decoded['toolFunctionNames'],
                  'gatewayToolNames': decoded['gatewayToolNames'],
                  'toolSelectionHash': decoded['toolSelectionHash'],
                  'schemaChars': decoded['schemaChars'],
                  'toolExecutionEnabled': decoded['toolExecutionEnabled'],
                })}',
          );
        }

        if (decoded['event'] == 'provider_request') {
          final providerRequest = decoded['providerRequest'] is Map
              ? Map<String, dynamic>.from(decoded['providerRequest'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-TOOL-PLAN] request: ${jsonEncode({
                  'runId': decoded['runId'],
                  'provider': providerRequest['provider'],
                  'providerModel': providerRequest['providerModel'],
                  'requestHash': providerRequest['requestHash'],
                  'bodyHash': providerRequest['bodyHash'],
                  'selectedToolCount': providerRequest['selectedToolCount'],
                  'toolFunctionNames': providerRequest['toolFunctionNames'],
                  'providerCallsEnabled':
                      providerRequest['providerCallsEnabled'] == true,
                  'toolExecutionEnabled':
                      providerRequest['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'streaming_tool_fixture' ||
            decoded['event'] == 'message_tool_fixture' ||
            decoded['event'] == 'unknown_tool_fixture' ||
            decoded['event'] == 'malformed_arguments_fixture') {
          final fixture = decoded['fixture'] is Map
              ? Map<String, dynamic>.from(decoded['fixture'] as Map)
              : <String, dynamic>{};
          final parsed = fixture['parsed'] is Map
              ? Map<String, dynamic>.from(fixture['parsed'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-TOOL-PLAN] ${decoded['event']}: ${jsonEncode({
                  'runId': decoded['runId'],
                  'fixture': fixture['fixture'],
                  'ok': fixture['parityOk'] == true,
                  'toolPlanCount': parsed['toolPlanCount'],
                  'allowedPlanCount': parsed['allowedPlanCount'],
                  'blockedPlanCount': parsed['blockedPlanCount'],
                  'invalidArgumentCount': parsed['invalidArgumentCount'],
                  'unknownToolCount': parsed['unknownToolCount'],
                  'toolPlanHash': parsed['toolPlanHash'],
                })}',
          );
        }

        if (decoded['event'] == 'tool_plan_summary') {
          final summary = decoded['toolPlanSummary'] is Map
              ? Map<String, dynamic>.from(decoded['toolPlanSummary'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-TOOL-PLAN] summary: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'toolPlanCount': summary['toolPlanCount'],
                  'allowedPlanCount': summary['allowedPlanCount'],
                  'blockedPlanCount': summary['blockedPlanCount'],
                  'finishReason': summary['finishReason'],
                  'toolPlanHash': summary['toolPlanHash'],
                  'fixtureParityOk': decoded['fixtureParityOk'] == true,
                  'validationOk': decoded['validationOk'] == true,
                  'toolExecutionEnabled':
                      decoded['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'error') {
          log(
            '[NATIVE-TOOL-PLAN] error: ${jsonEncode({
                  'error': decoded['error'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeToolPlanSkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>> streamToolDispatchDryRunChatSendFrame(
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
          '/gateway/chat-tool-dispatch-dry-run-stream',
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
          'native tool dispatch dry-run HTTP ${response.statusCode}: $body',
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
            '[NATIVE-TOOL-DISPATCH] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'requestHash': ack['requestHash'],
                  'toolSelectionHash': ack['toolSelectionHash'],
                  'dispatchHash': ack['dispatchHash'],
                  'fixtureParityOk': ack['fixtureParityOk'],
                  'dispatchParityOk': ack['dispatchParityOk'],
                  'validationOk': ack['validationOk'],
                  'toolPlanCount': ack['toolPlanCount'],
                  'allowedPlanCount': ack['allowedPlanCount'],
                  'blockedPlanCount': ack['blockedPlanCount'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'toolExecutionEnabled': ack['toolExecutionEnabled'],
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

        if (decoded['event'] == 'tool_plan_summary') {
          final summary = decoded['toolPlanSummary'] is Map
              ? Map<String, dynamic>.from(decoded['toolPlanSummary'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-TOOL-DISPATCH] plan: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'toolPlanCount': summary['toolPlanCount'],
                  'allowedPlanCount': summary['allowedPlanCount'],
                  'blockedPlanCount': summary['blockedPlanCount'],
                  'toolPlanNames': summary['toolPlanNames'],
                  'toolExecutionEnabled':
                      decoded['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'tool_dispatch_plan') {
          final plan = decoded['dispatchPlan'] is Map
              ? Map<String, dynamic>.from(decoded['dispatchPlan'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-TOOL-DISPATCH] dispatch plan: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'callId': plan['callId'],
                  'route': plan['route'],
                  'dispatchHash': plan['dispatchHash'],
                  'toolExecutionEnabled': plan['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'tool_use_frame' ||
            decoded['event'] == 'tool_result_frame') {
          final frame = decoded['frame'] is Map
              ? Map<String, dynamic>.from(decoded['frame'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-TOOL-DISPATCH] ${decoded['event']}: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'type': frame['type'],
                  'name': frame['name'],
                  'id': frame['id'],
                  'executionEnabled': frame['executionEnabled'] == true,
                  'toolExecutionEnabled': frame['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'dispatch_summary') {
          log(
            '[NATIVE-TOOL-DISPATCH] summary: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'toolName': decoded['toolName'],
                  'capability': decoded['capability'],
                  'dartCapability': decoded['dartCapability'],
                  'dispatchHash': decoded['dispatchHash'],
                  'dispatchParityOk': decoded['dispatchParityOk'] == true,
                  'validationOk': decoded['validationOk'] == true,
                  'skippedReason': decoded['skippedReason'],
                  'toolExecutionEnabled':
                      decoded['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'error') {
          log(
            '[NATIVE-TOOL-DISPATCH] error: ${jsonEncode({
                  'error': decoded['error'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeToolDispatchSkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>> streamNativeDartBridgeDryRunChatSendFrame(
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
          '/gateway/chat-native-dart-bridge-dry-run-stream',
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
          'native Dart bridge dry-run HTTP ${response.statusCode}: $body',
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
            '[NATIVE-DART-BRIDGE] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'requestHash': ack['requestHash'],
                  'toolSelectionHash': ack['toolSelectionHash'],
                  'dispatchHash': ack['dispatchHash'],
                  'bridgeRequestHash': ack['bridgeRequestHash'],
                  'fixtureParityOk': ack['fixtureParityOk'],
                  'dispatchParityOk': ack['dispatchParityOk'],
                  'bridgeParityOk': ack['bridgeParityOk'],
                  'validationOk': ack['validationOk'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'toolExecutionEnabled': ack['toolExecutionEnabled'],
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

        if (decoded['event'] == 'tool_dispatch_plan') {
          final plan = decoded['dispatchPlan'] is Map
              ? Map<String, dynamic>.from(decoded['dispatchPlan'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE] dispatch plan: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'callId': plan['callId'],
                  'route': plan['route'],
                  'dispatchHash': plan['dispatchHash'],
                  'bridgeRequestHash': plan['bridgeRequestHash'],
                  'toolExecutionEnabled': plan['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      plan['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'bridge_request') {
          final bridgeRequest = decoded['bridgeRequest'] is Map
              ? Map<String, dynamic>.from(decoded['bridgeRequest'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE] request: ${jsonEncode({
                  'runId': decoded['runId'],
                  'endpoint': decoded['endpoint'],
                  'method': bridgeRequest['method'],
                  'capability': bridgeRequest['capability'],
                  'bridgeRequestHash': bridgeRequest['bridgeRequestHash'],
                  'dryRun': bridgeRequest['dryRun'] == true,
                  'executionEnabled': bridgeRequest['executionEnabled'] == true,
                  'toolExecutionEnabled':
                      bridgeRequest['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      bridgeRequest['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'bridge_ack') {
          final bridgeAck = decoded['bridgeAck'] is Map
              ? Map<String, dynamic>.from(decoded['bridgeAck'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE] bridge ack: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'accepted': bridgeAck['accepted'] == true,
                  'command': bridgeAck['command'],
                  'commandKnown': bridgeAck['commandKnown'] == true,
                  'capability': bridgeAck['capability'],
                  'bridgeAckHash': decoded['bridgeAckHash'],
                  'bridgeParityOk': decoded['bridgeParityOk'] == true,
                  'validationOk': decoded['validationOk'] == true,
                  'skippedReason': bridgeAck['skippedReason'],
                  'executionEnabled': bridgeAck['executionEnabled'] == true,
                  'toolExecutionEnabled':
                      bridgeAck['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      bridgeAck['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'tool_use_frame' ||
            decoded['event'] == 'tool_result_frame') {
          final frame = decoded['frame'] is Map
              ? Map<String, dynamic>.from(decoded['frame'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE] ${decoded['event']}: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'type': frame['type'],
                  'name': frame['name'],
                  'id': frame['id'],
                  'executionEnabled': frame['executionEnabled'] == true,
                  'toolExecutionEnabled': frame['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'bridge_summary') {
          log(
            '[NATIVE-DART-BRIDGE] summary: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'toolName': decoded['toolName'],
                  'capability': decoded['capability'],
                  'dartCapability': decoded['dartCapability'],
                  'dispatchHash': decoded['dispatchHash'],
                  'bridgeRequestHash': decoded['bridgeRequestHash'],
                  'bridgeAckHash': decoded['bridgeAckHash'],
                  'dispatchParityOk': decoded['dispatchParityOk'] == true,
                  'bridgeParityOk': decoded['bridgeParityOk'] == true,
                  'validationOk': decoded['validationOk'] == true,
                  'skippedReason': decoded['skippedReason'],
                  'toolExecutionEnabled':
                      decoded['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      decoded['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'error') {
          log(
            '[NATIVE-DART-BRIDGE] error: ${jsonEncode({
                  'error': decoded['error'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeDartBridgeSkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>>
      streamNativeDartBridgeOrderingCancelChatSendFrame(
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
          '/gateway/chat-native-dart-bridge-ordering-cancel-stream',
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
          'native Dart bridge ordering/cancel HTTP '
          '${response.statusCode}: $body',
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
            '[NATIVE-DART-BRIDGE-ORDER] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'requestHash': ack['requestHash'],
                  'orderingPlanHash': ack['orderingPlanHash'],
                  'orderCount': ack['orderCount'],
                  'cancelOrderIndex': ack['cancelOrderIndex'],
                  'fixtureParityOk': ack['fixtureParityOk'],
                  'dispatchParityOk': ack['dispatchParityOk'],
                  'orderingParityOk': ack['orderingParityOk'],
                  'cancellationParityOk': ack['cancellationParityOk'],
                  'validationOk': ack['validationOk'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'toolExecutionEnabled': ack['toolExecutionEnabled'],
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

        if (decoded['event'] == 'order_plan') {
          log(
            '[NATIVE-DART-BRIDGE-ORDER] plan: ${jsonEncode({
                  'orderingPlanHash': decoded['orderingPlanHash'],
                  'orderCount': decoded['orderCount'],
                  'cancelOrderIndex': decoded['cancelOrderIndex'],
                  'plannedOrder': decoded['plannedOrder'],
                  'toolExecutionEnabled':
                      decoded['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      decoded['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'bridge_request') {
          final bridgeRequest = decoded['bridgeRequest'] is Map
              ? Map<String, dynamic>.from(decoded['bridgeRequest'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-ORDER] request: ${jsonEncode({
                  'runId': decoded['runId'],
                  'orderIndex': decoded['orderIndex'],
                  'method': bridgeRequest['method'],
                  'capability': bridgeRequest['capability'],
                  'bridgeRequestHash': bridgeRequest['bridgeRequestHash'],
                  'cancellationToken': bridgeRequest['cancellationToken'],
                  'dryRun': bridgeRequest['dryRun'] == true,
                  'toolExecutionEnabled':
                      bridgeRequest['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      bridgeRequest['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'bridge_ack') {
          final bridgeAck = decoded['bridgeAck'] is Map
              ? Map<String, dynamic>.from(decoded['bridgeAck'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-ORDER] bridge ack: ${jsonEncode({
                  'runId': decoded['runId'],
                  'orderIndex': decoded['orderIndex'],
                  'ok': decoded['ok'] == true,
                  'accepted': bridgeAck['accepted'] == true,
                  'command': bridgeAck['command'],
                  'commandKnown': bridgeAck['commandKnown'] == true,
                  'bridgeAckHash': decoded['bridgeAckHash'],
                  'bridgeParityOk': decoded['bridgeParityOk'] == true,
                  'skippedReason': bridgeAck['skippedReason'],
                })}',
          );
        }

        if (decoded['event'] == 'tool_use_frame' ||
            decoded['event'] == 'tool_result_frame') {
          final frame = decoded['frame'] is Map
              ? Map<String, dynamic>.from(decoded['frame'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-ORDER] ${decoded['event']}: ${jsonEncode({
                  'runId': decoded['runId'],
                  'orderIndex': decoded['orderIndex'],
                  'ok': decoded['ok'] == true,
                  'type': frame['type'],
                  'name': frame['name'],
                  'id': frame['id'],
                  'toolExecutionEnabled': frame['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'cancel_request') {
          final cancelRequest = decoded['cancelRequest'] is Map
              ? Map<String, dynamic>.from(decoded['cancelRequest'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-ORDER] cancel request: ${jsonEncode({
                  'runId': decoded['runId'],
                  'orderIndex': decoded['orderIndex'],
                  'cancelRequestHash': cancelRequest['cancelRequestHash'],
                  'targetRunId': cancelRequest['targetRunId'],
                  'targetBridgeRequestHash':
                      cancelRequest['targetBridgeRequestHash'],
                  'cancellationToken': cancelRequest['cancellationToken'],
                  'toolExecutionEnabled':
                      cancelRequest['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      cancelRequest['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'cancel_ack') {
          final cancelAck = decoded['cancelAck'] is Map
              ? Map<String, dynamic>.from(decoded['cancelAck'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-ORDER] cancel ack: ${jsonEncode({
                  'runId': decoded['runId'],
                  'orderIndex': decoded['orderIndex'],
                  'ok': decoded['ok'] == true,
                  'cancelAccepted': cancelAck['cancelAccepted'] == true,
                  'cancelApplied': cancelAck['cancelApplied'] == true,
                  'cancellationState': cancelAck['cancellationState'],
                  'cancelAckHash': decoded['cancelAckHash'],
                  'cancellationParityOk':
                      decoded['cancellationParityOk'] == true,
                  'skippedReason': cancelAck['skippedReason'],
                })}',
          );
        }

        if (decoded['event'] == 'ordering_summary') {
          log(
            '[NATIVE-DART-BRIDGE-ORDER] summary: ${jsonEncode({
                  'ok': decoded['ok'] == true,
                  'orderingPlanHash': decoded['orderingPlanHash'],
                  'orderCount': decoded['orderCount'],
                  'expectedOrder': decoded['expectedOrder'],
                  'observedBridgeOrder': decoded['observedBridgeOrder'],
                  'observedResultOrder': decoded['observedResultOrder'],
                  'uniqueRunIds': decoded['uniqueRunIds'],
                  'orderingParityOk': decoded['orderingParityOk'] == true,
                  'cancellationParityOk':
                      decoded['cancellationParityOk'] == true,
                  'validationOk': decoded['validationOk'] == true,
                  'cancellationState': decoded['cancellationState'],
                  'skippedReason': decoded['skippedReason'],
                })}',
          );
        }

        if (decoded['event'] == 'error') {
          log(
            '[NATIVE-DART-BRIDGE-ORDER] error: ${jsonEncode({
                  'error': decoded['error'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      _logNativeDartBridgeOrderingCancelSkip(log, e);
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>>
      streamNativeDartBridgeHapticCanaryChatSendFrame(
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
          '/gateway/chat-native-dart-bridge-haptic-canary-stream',
        ),
      )
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(frame);
      final response = await client
          .send(request)
          .timeout(const Duration(milliseconds: 3000));

      if (response.statusCode != 202) {
        final body = await response.stream.bytesToString();
        throw StateError(
          'native Dart bridge haptic canary HTTP '
          '${response.statusCode}: $body',
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
            '[NATIVE-DART-BRIDGE-HAPTIC] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'requestHash': ack['requestHash'],
                  'bridgeRequestHash': ack['bridgeRequestHash'],
                  'canaryAllowlistOk': ack['canaryAllowlistOk'],
                  'executeParityOk': ack['executeParityOk'],
                  'validationOk': ack['validationOk'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'toolExecutionEnabled': ack['toolExecutionEnabled'],
                  'bridgeExecutionEnabled': ack['bridgeExecutionEnabled'],
                  'durationMs': ack['durationMs'],
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

        if (decoded['event'] == 'tool_plan_summary') {
          log(
            '[NATIVE-DART-BRIDGE-HAPTIC] plan: ${jsonEncode({
                  'runId': decoded['runId'],
                  'fixtureParityOk': decoded['fixtureParityOk'] == true,
                  'dispatchParityOk': decoded['dispatchParityOk'] == true,
                  'canaryAllowlistOk': decoded['canaryAllowlistOk'] == true,
                  'forcedAllowlist': decoded['forcedAllowlist'],
                  'executionEnabled': decoded['executionEnabled'] == true,
                  'toolExecutionEnabled':
                      decoded['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      decoded['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'bridge_execute_request') {
          final bridgeRequest = decoded['bridgeRequest'] is Map
              ? Map<String, dynamic>.from(decoded['bridgeRequest'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-HAPTIC] execute request: ${jsonEncode({
                  'runId': decoded['runId'],
                  'method': bridgeRequest['method'],
                  'capability': bridgeRequest['capability'],
                  'bridgeRequestHash': bridgeRequest['bridgeRequestHash'],
                  'cancellationToken': bridgeRequest['cancellationToken'],
                  'canaryAllowlist': bridgeRequest['canaryAllowlist'],
                  'input': bridgeRequest['input'],
                  'dryRun': bridgeRequest['dryRun'] == true,
                  'providerCallsEnabled':
                      bridgeRequest['providerCallsEnabled'] == true,
                  'executionEnabled': bridgeRequest['executionEnabled'] == true,
                  'toolExecutionEnabled':
                      bridgeRequest['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      bridgeRequest['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'bridge_execute_ack') {
          final executeAck = decoded['executeAck'] is Map
              ? Map<String, dynamic>.from(decoded['executeAck'] as Map)
              : <String, dynamic>{};
          final result = executeAck['result'] is Map
              ? Map<String, dynamic>.from(executeAck['result'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-HAPTIC] execute ack: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'accepted': executeAck['accepted'] == true,
                  'executed': executeAck['executed'] == true,
                  'command': executeAck['command'],
                  'canaryAllowlistOk': executeAck['canaryAllowlistOk'] == true,
                  'durationMs': executeAck['durationMs'],
                  'resultStatus': result['status'],
                  'executeAckHash': decoded['executeAckHash'],
                  'executeParityOk': decoded['executeParityOk'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'tool_use_frame' ||
            decoded['event'] == 'tool_result_frame') {
          final frame = decoded['frame'] is Map
              ? Map<String, dynamic>.from(decoded['frame'] as Map)
              : <String, dynamic>{};
          final result = frame['result'] is Map
              ? Map<String, dynamic>.from(frame['result'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-HAPTIC] ${decoded['event']}: ${jsonEncode({
                  'runId': decoded['runId'],
                  'ok': decoded['ok'] == true,
                  'type': frame['type'],
                  'name': frame['name'],
                  'id': frame['id'],
                  'executed': result['executed'] == true,
                  'status': result['status'],
                  'toolExecutionEnabled': frame['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'haptic_canary_summary') {
          log(
            '[NATIVE-DART-BRIDGE-HAPTIC] summary: ${jsonEncode({
                  'ok': decoded['ok'] == true,
                  'runId': decoded['runId'],
                  'toolName': decoded['toolName'],
                  'durationMs': decoded['durationMs'],
                  'resultStatus': decoded['resultStatus'],
                  'canaryAllowlistOk': decoded['canaryAllowlistOk'] == true,
                  'executeParityOk': decoded['executeParityOk'] == true,
                  'validationOk': decoded['validationOk'] == true,
                  'providerCallsEnabled':
                      decoded['providerCallsEnabled'] == true,
                  'executionEnabled': decoded['executionEnabled'] == true,
                  'toolExecutionEnabled':
                      decoded['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      decoded['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'error') {
          log(
            '[NATIVE-DART-BRIDGE-HAPTIC] error: ${jsonEncode({
                  'error': decoded['error'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      log('[NATIVE-DART-BRIDGE-HAPTIC] native Dart bridge haptic canary '
          'failed or skipped: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  static Stream<Map<String, dynamic>>
      streamNativeDartBridgeReadOnlyCanaryChatSendFrame(
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
          '/gateway/chat-native-dart-bridge-readonly-canary-stream',
        ),
      )
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(frame);
      final response = await client
          .send(request)
          .timeout(const Duration(milliseconds: 3500));

      if (response.statusCode != 202) {
        final body = await response.stream.bytesToString();
        throw StateError(
          'native Dart bridge readonly canary HTTP '
          '${response.statusCode}: $body',
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
          final rawAck = decoded['ack'] is Map
              ? Map<String, dynamic>.from(decoded['ack'] as Map)
              : <String, dynamic>{};
          final hashMatches = local['metadataHash'] == ack['metadataHash'];
          log(
            '[NATIVE-DART-BRIDGE-READONLY] ack: ${jsonEncode({
                  'ok': ack['ok'],
                  'parsed': ack['parsed'],
                  'route': ack['route'],
                  'routeStatus': ack['routeStatus'],
                  'source': ack['source'],
                  'canaryMode': ack['canaryMode'],
                  'localHash': local['metadataHash'],
                  'canaryHash': ack['metadataHash'],
                  'hashMatches': hashMatches,
                  'requestHash': ack['requestHash'],
                  'readOnlyPlanHash': rawAck['readOnlyPlanHash'],
                  'selectedToolCount': ack['selectedToolCount'],
                  'forcedToolNames': rawAck['forcedToolNames'],
                  'canaryAllowlist': rawAck['canaryAllowlist'],
                  'canaryAllowlistOk': ack['canaryAllowlistOk'],
                  'executeParityOk': ack['executeParityOk'],
                  'validationOk': ack['validationOk'],
                  'providerCallsEnabled': ack['providerCallsEnabled'],
                  'executionEnabled': ack['executionEnabled'],
                  'toolExecutionEnabled': ack['toolExecutionEnabled'],
                  'bridgeExecutionEnabled': ack['bridgeExecutionEnabled'],
                  'readOnly': rawAck['readOnly'] == true,
                })}',
          );
          yield {
            ...decoded,
            'ack': {
              ...ack,
              'localHash': local['metadataHash'],
              'hashMatches': hashMatches,
              'readOnlyPlanHash': rawAck['readOnlyPlanHash'],
              'forcedToolNames': rawAck['forcedToolNames'],
              'canaryAllowlist': rawAck['canaryAllowlist'],
            },
          };
          continue;
        }

        if (decoded['event'] == 'tool_plan_summary') {
          log(
            '[NATIVE-DART-BRIDGE-READONLY] plan: ${jsonEncode({
                  'runId': decoded['runId'],
                  'readOnlyPlanHash': decoded['readOnlyPlanHash'],
                  'orderCount': decoded['orderCount'],
                  'expectedOrder': decoded['expectedOrder'],
                  'fixtureParityOk': decoded['fixtureParityOk'] == true,
                  'dispatchParityOk': decoded['dispatchParityOk'] == true,
                  'canaryAllowlistOk': decoded['canaryAllowlistOk'] == true,
                  'executionEnabled': decoded['executionEnabled'] == true,
                  'toolExecutionEnabled':
                      decoded['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      decoded['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'bridge_execute_request') {
          final bridgeRequest = decoded['bridgeRequest'] is Map
              ? Map<String, dynamic>.from(decoded['bridgeRequest'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-READONLY] execute request: ${jsonEncode({
                  'runId': decoded['runId'],
                  'orderIndex': decoded['orderIndex'],
                  'method': bridgeRequest['method'],
                  'capability': bridgeRequest['capability'],
                  'bridgeRequestHash': bridgeRequest['bridgeRequestHash'],
                  'canaryAllowlist': bridgeRequest['canaryAllowlist'],
                  'inputKeys': bridgeRequest['input'] is Map
                      ? (bridgeRequest['input'] as Map).keys.toList()
                      : const [],
                  'dryRun': bridgeRequest['dryRun'] == true,
                  'providerCallsEnabled':
                      bridgeRequest['providerCallsEnabled'] == true,
                  'executionEnabled': bridgeRequest['executionEnabled'] == true,
                  'toolExecutionEnabled':
                      bridgeRequest['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      bridgeRequest['bridgeExecutionEnabled'] == true,
                  'readOnly': bridgeRequest['readOnly'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'bridge_execute_ack') {
          final executeAck = decoded['executeAck'] is Map
              ? Map<String, dynamic>.from(decoded['executeAck'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-READONLY] execute ack: ${jsonEncode({
                  'runId': decoded['runId'],
                  'orderIndex': decoded['orderIndex'],
                  'ok': decoded['ok'] == true,
                  'accepted': executeAck['accepted'] == true,
                  'executed': executeAck['executed'] == true,
                  'command': executeAck['command'],
                  'canaryAllowlistOk': executeAck['canaryAllowlistOk'] == true,
                  'resultStatus':
                      decoded['resultStatus'] ?? executeAck['resultStatus'],
                  'resultShapeOk': decoded['resultShapeOk'] == true,
                  'executeAckHash': decoded['executeAckHash'],
                  'executeParityOk': decoded['executeParityOk'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'tool_use_frame' ||
            decoded['event'] == 'tool_result_frame') {
          final frame = decoded['frame'] is Map
              ? Map<String, dynamic>.from(decoded['frame'] as Map)
              : <String, dynamic>{};
          final result = frame['result'] is Map
              ? Map<String, dynamic>.from(frame['result'] as Map)
              : <String, dynamic>{};
          log(
            '[NATIVE-DART-BRIDGE-READONLY] ${decoded['event']}: ${jsonEncode({
                  'runId': decoded['runId'],
                  'orderIndex': decoded['orderIndex'],
                  'ok': decoded['ok'] == true,
                  'type': frame['type'],
                  'name': frame['name'],
                  'id': frame['id'],
                  'executed': result['executed'] == true,
                  'status': result['status'],
                  'resultShapeOk': decoded['event'] == 'tool_result_frame'
                      ? result['resultShapeOk'] == true
                      : null,
                  'toolExecutionEnabled': frame['toolExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'readonly_canary_summary') {
          log(
            '[NATIVE-DART-BRIDGE-READONLY] summary: ${jsonEncode({
                  'ok': decoded['ok'] == true,
                  'runId': decoded['runId'],
                  'readOnlyPlanHash': decoded['readOnlyPlanHash'],
                  'commandCount': decoded['commandCount'],
                  'expectedOrder': decoded['expectedOrder'],
                  'observedOrder': decoded['observedOrder'],
                  'resultStatuses': decoded['resultStatuses'],
                  'canaryAllowlistOk': decoded['canaryAllowlistOk'] == true,
                  'executeParityOk': decoded['executeParityOk'] == true,
                  'validationOk': decoded['validationOk'] == true,
                  'providerCallsEnabled':
                      decoded['providerCallsEnabled'] == true,
                  'executionEnabled': decoded['executionEnabled'] == true,
                  'toolExecutionEnabled':
                      decoded['toolExecutionEnabled'] == true,
                  'bridgeExecutionEnabled':
                      decoded['bridgeExecutionEnabled'] == true,
                })}',
          );
        }

        if (decoded['event'] == 'error') {
          log(
            '[NATIVE-DART-BRIDGE-READONLY] error: ${jsonEncode({
                  'error': decoded['error'],
                })}',
          );
        }

        yield decoded;
      }
    } catch (e) {
      log('[NATIVE-DART-BRIDGE-READONLY] native Dart bridge readonly canary '
          'failed or skipped: $e');
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
      'toolSelectionHash': ack['toolSelectionHash'],
      'dispatchHash': ack['dispatchHash'],
      'bridgeRequestHash': ack['bridgeRequestHash'],
      'orderingPlanHash': ack['orderingPlanHash'],
      'cancelRequestHash': ack['cancelRequestHash'],
      'cancelAckHash': ack['cancelAckHash'],
      'fixtureHash': ack['fixtureHash'],
      'fixtureParityOk': ack['fixtureParityOk'] == true,
      'dispatchParityOk': ack['dispatchParityOk'] == true,
      'bridgeParityOk': ack['bridgeParityOk'] == true,
      'orderingParityOk': ack['orderingParityOk'] == true,
      'cancellationParityOk': ack['cancellationParityOk'] == true,
      'canaryAllowlistOk': ack['canaryAllowlistOk'] == true,
      'executeParityOk': ack['executeParityOk'] == true,
      'validationOk': ack['validationOk'] == true,
      'orderCount': ack['orderCount'],
      'cancelOrderIndex': ack['cancelOrderIndex'],
      'durationMs': ack['durationMs'] ?? ack['hapticDurationMs'],
      'selectedToolCount': ack['selectedToolCount'],
      'toolPlanCount': ack['toolPlanCount'],
      'allowedPlanCount': ack['allowedPlanCount'],
      'blockedPlanCount': ack['blockedPlanCount'],
      'toolExecutionEnabled': ack['toolExecutionEnabled'] == true,
      'bridgeExecutionEnabled': ack['bridgeExecutionEnabled'] == true,
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

  static void _logNativeStreamParitySkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-STREAM-PARITY] native stream parser parity failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeToolPlanSkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-TOOL-PLAN] native tool plan canary failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeToolDispatchSkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-TOOL-DISPATCH] native tool dispatch dry-run failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeDartBridgeSkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-DART-BRIDGE] native Dart bridge dry-run failed '
      '(${error.runtimeType})',
    );
  }

  static void _logNativeDartBridgeOrderingCancelSkip(
    void Function(String message) log,
    Object error,
  ) {
    log(
      '[NATIVE-DART-BRIDGE-ORDER] native Dart bridge ordering/cancel '
      'dry-run failed (${error.runtimeType})',
    );
  }
}
