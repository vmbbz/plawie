import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'native_bridge.dart';

/// Service for detecting OpenClaw version and adapting command syntax.
///
/// SYNTAX (Grok-verified 2026-03-27):
///   Modern (≥2026.1.30): `openclaw skills install <name>`   ← PLURAL
///   Legacy  (<2026.1.30): `openclaw skill  install <name>`  ← singular
class OpenClawCommandService {
  // ── Version cache — avoids a `runInProot` call on every tap ──────────────
  static String? _cachedVersion;
  static DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 5);

  /// Detect the running gateway version, with 5-minute cache.
  static Future<String> detectOpenClawVersion() async {
    final now = DateTime.now();
    if (_cachedVersion != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheTtl) {
      return _cachedVersion!;
    }
    try {
      final result = await NativeBridge.runInProot(
        'openclaw --version',
        timeout: 10,
      );
      // Handles: "2026.3.27", "v2026.3.27", "OpenClaw v2026.3.27-alpha"
      final match = RegExp(r'(\d{4}\.\d+\.\d+)').firstMatch(result);
      _cachedVersion = match?.group(1) ?? '0.0.0';
    } catch (_) {
      _cachedVersion = '0.0.0';
    }
    _cacheTime = now;
    return _cachedVersion!;
  }

  /// True if the gateway is modern (≥2026.1.30) and uses PLURAL `skills` syntax.
  static Future<bool> isModernSyntax() async {
    final version = await detectOpenClawVersion();
    final parts = version.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length < 3) return false;
    if (parts[0] > 2026) return true;
    if (parts[0] == 2026 && parts[1] > 1) return true;
    if (parts[0] == 2026 && parts[1] == 1 && parts[2] >= 30) return true;
    return false;
  }

  /// Returns the correct install command for the detected gateway version.
  static Future<String> getSkillInstallCommand(
    String skillName, {
    String? version,
  }) async {
    final modern = await isModernSyntax();
    final versionStr = version != null ? '@$version' : '';
    return modern
        ? 'openclaw skills install $skillName$versionStr'
        : 'openclaw skill install $skillName$versionStr';
  }

  /// Returns the correct uninstall command for the detected gateway version.
  static Future<String> getSkillUninstallCommand(String skillName) async {
    final modern = await isModernSyntax();
    return modern
        ? 'openclaw skills uninstall $skillName'
        : 'openclaw skill uninstall $skillName';
  }

  /// Normalises any hardcoded `openclaw skill(s) …` command string.
  static Future<String> adaptSkillCommand(String baseCommand) async {
    final modern = await isModernSyntax();
    if (modern) {
      return baseCommand.replaceAllMapped(
        RegExp(r'openclaw skill (?!s)'),
        (m) => 'openclaw skills ',
      );
    } else {
      return baseCommand.replaceAll('openclaw skills ', 'openclaw skill ');
    }
  }

  /// Returns the list of tool IDs in `tools.allow` from openclaw.json.
  static Future<List<String>> getCoreTools() async {
    final config = await getOpenClawConfig();
    final allow = config?['tools']?['allow'];
    if (allow is List) return allow.map((e) => e.toString()).toList();
    return [];
  }

  static String getSkillListCommand() => 'openclaw skills list';

  // ── Extended service methods ──────────────────────────────────────────────

  /// Reads /root/.openclaw/openclaw.json from PRoot.
  static Future<Map<String, dynamic>?> getOpenClawConfig() async {
    try {
      final result = await NativeBridge.runInProot(
        'cat /root/.openclaw/openclaw.json 2>/dev/null || echo "{}"',
        timeout: 5,
      );
      final decoded = jsonDecode(result.trim());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Returns the list of installed skill IDs.
  static Future<List<String>> getInstalledSkills() async {
    try {
      final result = await NativeBridge.runInProot(
        'openclaw skills list --json 2>/dev/null '
        '|| openclaw skill list --json 2>/dev/null '
        '|| echo "[]"',
        timeout: 15,
      );
      final trimmed = result.trim();
      final jsonStart = trimmed.indexOf('[');
      if (jsonStart == -1) return [];
      final decoded = jsonDecode(trimmed.substring(jsonStart));
      if (decoded is List) {
        return decoded
            .map((e) {
              if (e is Map) return (e['id'] ?? e['name'])?.toString() ?? '';
              return e?.toString() ?? '';
            })
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Asks the running gateway to rescan and hot-reload skills.
  static Future<void> reloadGateway() async {
    try {
      await NativeBridge.runInProot(
        'openclaw reload 2>/dev/null || true',
        timeout: 10,
      );
    } catch (_) {}
  }

  /// Lists models currently available in the local Ollama instance.
  static Future<List<Map<String, String>>> getOllamaModels({
    String baseUrl = 'http://127.0.0.1:11434',
  }) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['models'] is List) {
          return (data['models'] as List).map((m) {
            final name = m['name']?.toString() ?? 'unknown';
            return {
              'id': name,
              'name': name.split(':').first.toUpperCase(),
            };
          }).toList();
        }
      }
    } catch (_) {}

    try {
      final result = await NativeBridge.runInProot(
        'openclaw models list --json 2>/dev/null || echo "[]"',
        timeout: 10,
      );
      final decoded = jsonDecode(result.trim());
      if (decoded is List) {
        return decoded
            .where((m) => m['provider'] == 'ollama')
            .map((m) => {
              'id': m['id']?.toString() ?? '',
              'name': m['name']?.toString() ?? '',
            })
            .where((m) => m['id']!.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    return [];
  }

  static void invalidateVersionCache() {
    _cachedVersion = null;
    _cacheTime = null;
  }
}
