import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'gateway_tool_catalog.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';

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
  static const _nativeVersionFallback = '2026.5.0';
  static Future<void> Function(String reason)? _activeOwnerReloadHandler;

  static void registerActiveOwnerReloadHandler(
    Future<void> Function(String reason) handler,
  ) {
    _activeOwnerReloadHandler = handler;
  }

  /// The 'Golden Path' runner: Bare command + explicit PATH security.
  /// Ensures binaries are found even if the environment is unstable.
  static Future<String> _run(String command, {int timeout = 15}) async {
    return await NativeBridge.runInProot(command, timeout: timeout);
  }

  static Future<bool> _nativeOwnerSelected() async {
    try {
      final prefs = PreferencesService();
      await prefs.init();
      return prefs.gatewayRuntimeOwner ==
          PreferencesService.gatewayRuntimeOwnerNativeProduction;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isNativeOwnerSelected() => _nativeOwnerSelected();

  static Future<String> runCliForActiveOwner(
    String command, {
    int timeout = 15,
  }) async {
    if (await _nativeOwnerSelected()) {
      throw UnsupportedError(
        'The native Node Gateway runtime does not expose an OpenClaw shell. '
        'Use Gateway RPC/config APIs, or switch to PRoot rollback for CLI-only '
        'marketplace/package operations.',
      );
    }
    return _run(command, timeout: timeout);
  }

  static Future<String> _filesDir() => NativeBridge.getFilesDir();

  static Future<File> _prootConfigFile() async {
    return File(
      '${await _filesDir()}/rootfs/ubuntu/root/.openclaw/openclaw.json',
    );
  }

  static Future<File> _nativeConfigFile() async {
    return File(
      '${await _filesDir()}/native-node-embedded/native-home/.openclaw/openclaw.json',
    );
  }

  static Future<File> _nativePackageJsonFile() async {
    return File(
      '${await _filesDir()}/native-node-embedded/full-openclaw/lib/node_modules/openclaw/package.json',
    );
  }

  static Future<List<Directory>> _activeSkillRoots() async {
    final filesDir = await _filesDir();
    final nativeOwner = await _nativeOwnerSelected();
    final prootRoots = <Directory>[
      Directory('$filesDir/rootfs/ubuntu/root/.openclaw/skills'),
      Directory('$filesDir/rootfs/ubuntu/root/.openclaw/workspace/skills'),
      Directory(
        '$filesDir/rootfs/ubuntu/usr/local/lib/node_modules/openclaw/skills',
      ),
    ];
    final nativeRoots = <Directory>[
      Directory('$filesDir/native-node-embedded/native-home/.openclaw/skills'),
      Directory(
        '$filesDir/native-node-embedded/native-home/.openclaw/workspace/skills',
      ),
      Directory(
        '$filesDir/native-node-embedded/full-openclaw/lib/node_modules/openclaw/skills',
      ),
    ];

    // Native full Gateway currently imports the production OpenClaw skill tree
    // from app storage. Reading those files is fine; starting PRoot is not.
    return nativeOwner
        ? <Directory>[...nativeRoots, ...prootRoots]
        : <Directory>[...prootRoots, ...nativeRoots];
  }

  static Future<Map<String, dynamic>?> _readJsonFile(File file) async {
    try {
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Future<void> _writeJsonFile(
    File file,
    Map<String, dynamic> value,
  ) async {
    await Directory(file.parent.path).create(recursive: true);
    final tmp =
        File('${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    final encoded = const JsonEncoder.withIndent('  ').convert(value);
    await tmp.writeAsString(encoded, flush: true);
    try {
      await tmp.rename(file.path);
    } catch (_) {
      await file.writeAsString(encoded, flush: true);
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    }
  }

  static Future<Map<String, dynamic>?> _readActiveConfig() async {
    final nativeOwner = await _nativeOwnerSelected();
    final primary =
        nativeOwner ? await _nativeConfigFile() : await _prootConfigFile();
    final fallback =
        nativeOwner ? await _prootConfigFile() : await _nativeConfigFile();
    return await _readJsonFile(primary) ?? await _readJsonFile(fallback);
  }

  static Future<String?> _nativePackageVersion() async {
    final pkg = await _readJsonFile(await _nativePackageJsonFile());
    return pkg?['version']?.toString();
  }

  /// Detect the running gateway version, with 5-minute cache.
  static Future<String> detectOpenClawVersion() async {
    final now = DateTime.now();
    if (_cachedVersion != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheTtl) {
      return _cachedVersion!;
    }
    try {
      if (await _nativeOwnerSelected()) {
        _cachedVersion =
            await _nativePackageVersion() ?? _nativeVersionFallback;
      } else {
        final result = await _run('openclaw --version', timeout: 10);
        // Handles: "2026.3.27", "v2026.3.27", "OpenClaw v2026.3.27-alpha"
        final match = RegExp(r'(\d{4}\.\d+\.\d+)').firstMatch(result);
        _cachedVersion = match?.group(1) ?? '0.0.0';
      }
    } catch (_) {
      _cachedVersion =
          await _nativeOwnerSelected() ? _nativeVersionFallback : '0.0.0';
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

  /// Normalises any hardcoded `openclaw skill(s) …` command string and applies absolute bypass.
  static Future<String> adaptSkillCommand(String baseCommand) async {
    final modern = await isModernSyntax();
    String cmd = baseCommand;
    if (modern) {
      cmd = baseCommand.replaceAllMapped(
        RegExp(r'openclaw skill (?!s)'),
        (m) => 'openclaw skills ',
      );
    } else {
      cmd = baseCommand.replaceAll('openclaw skills ', 'openclaw skill ');
    }

    return cmd;
  }

  /// Returns the list of tool IDs in `tools.allow` from openclaw.json.
  static Future<List<String>> getCoreTools() async {
    final config = await getOpenClawConfig();
    final allow = config?['tools']?['allow'];
    return GatewayToolCatalog.normalizeAllowList(allow);
  }

  static String getSkillListCommand() => 'openclaw skills list';

  // ── Extended service methods ──────────────────────────────────────────────

  /// Reads the active owner's OpenClaw config without starting a PRoot shell.
  static Future<Map<String, dynamic>?> getOpenClawConfig() async {
    try {
      return await _readActiveConfig();
    } catch (_) {
      return null;
    }
  }

  /// Returns the list of installed skill IDs.
  static Future<List<String>> getInstalledSkills() async {
    try {
      if (await _nativeOwnerSelected()) {
        final scanned = await _scanInstalledSkillIds();
        return scanned;
      }

      final result = await _run(
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

  static Future<List<String>> _scanInstalledSkillIds() async {
    final ids = <String>{};
    for (final root in await _activeSkillRoots()) {
      try {
        if (!await root.exists()) continue;
        await for (final entity in root.list(recursive: false)) {
          final name = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : '';
          if (name.isEmpty) continue;
          if (entity is Directory) {
            final hasManifest =
                await File('${entity.path}/SKILL.md').exists() ||
                    await File('${entity.path}/SKILL.yaml').exists() ||
                    await File('${entity.path}/package.json').exists();
            if (hasManifest) ids.add(name);
          } else if (entity is File) {
            if (name.endsWith('.md') || name.endsWith('.yaml')) {
              ids.add(name.replaceFirst(RegExp(r'\.(md|yaml)$'), ''));
            }
          }
        }
      } catch (_) {}
    }
    return ids.toList()..sort();
  }

  /// Asks the running gateway to rescan and hot-reload skills.
  static Future<void> reloadGateway({
    String reason = 'OpenClaw config reload',
  }) async {
    try {
      if (await _nativeOwnerSelected()) {
        // Native production Gateway has no mobile shell runner. Delegate to the
        // active GatewayService instance so it can restart native with the same
        // socket/settle-window discipline used by provider credential changes.
        final handler = _activeOwnerReloadHandler;
        if (handler != null) {
          await handler(reason);
        }
        return;
      }
      await _run('openclaw reload 2>/dev/null || true', timeout: 10);
    } catch (_) {}
  }

  static void invalidateVersionCache() {
    _cachedVersion = null;
    _cacheTime = null;
  }

  /// Writes [tools] as the new `tools.allow` list in openclaw.json.
  static Future<bool> saveToolsAllow(List<String> tools) async {
    try {
      final allowList = GatewayToolCatalog.toConfigAllowList(tools);
      var wroteAny = false;

      final nativeOwner = await _nativeOwnerSelected();
      final orderedFiles = nativeOwner
          ? <File>[await _nativeConfigFile(), await _prootConfigFile()]
          : <File>[await _prootConfigFile(), await _nativeConfigFile()];

      for (final file in orderedFiles) {
        final config = await _readJsonFile(file);
        if (config == null || config.isEmpty) continue;
        config['tools'] ??= <String, dynamic>{};
        final toolsConfig = config['tools'];
        if (toolsConfig is Map) {
          toolsConfig['allow'] = allowList;
          toolsConfig['profile'] =
              GatewayToolCatalog.profileForAllowList(allowList);
        } else {
          config['tools'] = <String, dynamic>{
            'allow': allowList,
            'profile': GatewayToolCatalog.profileForAllowList(allowList),
          };
        }
        await _writeJsonFile(file, config);
        wroteAny = true;
      }

      return wroteAny;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setConfigValue(String dottedPath, Object? value) async {
    try {
      final parts = dottedPath
          .split('.')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.isEmpty) return false;

      var wroteAny = false;
      final nativeOwner = await _nativeOwnerSelected();
      final orderedFiles = nativeOwner
          ? <File>[await _nativeConfigFile(), await _prootConfigFile()]
          : <File>[await _prootConfigFile(), await _nativeConfigFile()];

      for (final file in orderedFiles) {
        final config = await _readJsonFile(file);
        if (config == null || config.isEmpty) continue;
        _setNestedValue(config, parts, value);
        await _writeJsonFile(file, config);
        wroteAny = true;
      }

      return wroteAny;
    } catch (_) {
      return false;
    }
  }

  static void _setNestedValue(
    Map<String, dynamic> root,
    List<String> path,
    Object? value,
  ) {
    Map<String, dynamic> cursor = root;
    for (final part in path.take(path.length - 1)) {
      final existing = cursor[part];
      if (existing is Map<String, dynamic>) {
        cursor = existing;
      } else if (existing is Map) {
        final casted = Map<String, dynamic>.from(existing);
        cursor[part] = casted;
        cursor = casted;
      } else {
        final next = <String, dynamic>{};
        cursor[part] = next;
        cursor = next;
      }
    }
    cursor[path.last] = value;
  }
}
