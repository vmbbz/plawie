import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../providers/gateway_provider.dart';

/// GatewaySkillProxy — the single point of contact between SkillsService
/// and the OpenClaw gateway's skills.execute RPC method.
///
/// OpenClaw gateway routing: skills.execute { name, method, ...params }
/// The installed skill's handler on the gateway processes the call and
/// returns { ok, payload, error } — same envelope as all other RPC calls.
///
/// Falls back to a mock payload when the gateway is offline, so skill pages
/// show loading states rather than hard crashes.

class GatewaySkillProxy {
  static final GatewaySkillProxy _instance = GatewaySkillProxy._internal();
  factory GatewaySkillProxy() => _instance;
  GatewaySkillProxy._internal();

  GatewayProvider? _gatewayProvider;

  /// Call this once from your widget tree root or main.dart after
  /// GatewayProvider is initialised.
  void attach(GatewayProvider provider) {
    _gatewayProvider = provider;
  }

  /// Attach from a BuildContext (convenience — use in initState or build).
  static void attachFromContext(BuildContext context) {
    final proxy = GatewaySkillProxy();
    proxy._gatewayProvider =
        Provider.of<GatewayProvider>(context, listen: false);
  }

  bool get isAttached => _gatewayProvider != null;

  /// Execute a skill method via the OpenClaw gateway.
  ///
  /// [skillName]  — the OpenClaw skill id (e.g. 'agent_card', 'twilio_voice')
  /// [method]     — the method within the skill (e.g. 'get_balance')
  /// [params]     — additional parameters passed to the skill handler
  ///
  /// Returns the `payload` map on success, throws [SkillProxyException] on error.
  Future<Map<String, dynamic>> execute(
    String skillName,
    String method, {
    Map<String, dynamic> params = const {},
  }) async {
    if (_gatewayProvider == null) {
      throw const SkillProxyException(
          'GatewaySkillProxy not attached — call attach() first.');
    }

    try {
      final result = await _gatewayProvider!.invoke('skills.execute', {
        'name': skillName,
        'method': method,
        ...params,
      });

      if (result['ok'] == true) {
        final payload = result['payload'];
        if (payload is Map<String, dynamic>) return payload;
        if (payload is Map) return Map<String, dynamic>.from(payload);
        // Skill returned non-map payload — wrap it
        return {'result': payload};
      } else {
        final errMsg = _extractError(result);
        throw SkillProxyException(errMsg);
      }
    } catch (e) {
      if (e is SkillProxyException) rethrow;
      throw SkillProxyException('Gateway error for $skillName.$method: $e');
    }
  }

  String _extractError(Map<String, dynamic> result) {
    final err = result['error'];
    if (err is Map) {
      return (err['message'] ?? err['msg'] ?? err.toString()).toString();
    }
    if (err is String) return err;
    final payload = result['payload'];
    if (payload is Map) {
      return (payload['error'] ?? payload['message'] ?? 'Unknown error')
          .toString();
    }
    return 'Skill execution failed';
  }
}

class SkillProxyException implements Exception {
  final String message;
  const SkillProxyException(this.message);

  @override
  String toString() => 'SkillProxyException: $message';
}
