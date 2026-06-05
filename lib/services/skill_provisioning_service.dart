import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'native_bridge.dart';
import 'skill_parity_audit_service.dart';

class SkillProvisioningService {
  SkillProvisioningService._();
  static final SkillProvisioningService instance = SkillProvisioningService._();

  Future<SkillProvisioningReport> planSnapshot(
    SkillParitySnapshot snapshot, {
    String? skillId,
  }) {
    return _evaluateSnapshot(
      snapshot,
      skillId: skillId,
      applyValues: false,
      installBundledBinaries: false,
    );
  }

  Future<SkillProvisioningReport> provisionSnapshot(
    SkillParitySnapshot snapshot, {
    String? skillId,
    Map<String, String> envValues = const <String, String>{},
    Map<String, dynamic> configValues = const <String, dynamic>{},
    bool applyValues = true,
    bool installBundledBinaries = true,
  }) {
    return _evaluateSnapshot(
      snapshot,
      skillId: skillId,
      envValues: envValues,
      configValues: configValues,
      applyValues: applyValues,
      installBundledBinaries: installBundledBinaries,
    );
  }

  Future<SkillProvisioningReport> auditAndProvision({
    String? filesDir,
    String? skillId,
    Map<String, String> envValues = const <String, String>{},
    Map<String, dynamic> configValues = const <String, dynamic>{},
    bool repairNativeFromProot = false,
    bool applyValues = true,
    bool installBundledBinaries = true,
  }) async {
    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: filesDir ?? await NativeBridge.getFilesDir(),
      repairNativeFromProot: repairNativeFromProot,
      cacheTtl: Duration.zero,
    );
    return provisionSnapshot(
      snapshot,
      skillId: skillId,
      envValues: envValues,
      configValues: configValues,
      applyValues: applyValues,
      installBundledBinaries: installBundledBinaries,
    );
  }

  Future<SkillProvisioningReport> _evaluateSnapshot(
    SkillParitySnapshot snapshot, {
    String? skillId,
    Map<String, String> envValues = const <String, String>{},
    Map<String, dynamic> configValues = const <String, dynamic>{},
    required bool applyValues,
    required bool installBundledBinaries,
  }) async {
    final targetSkill = _normalizeSkillId(skillId);
    final layout = _SkillProvisioningLayout(snapshot.filesDir);
    final entries = snapshot.executionMatrix.where((entry) {
      return targetSkill == null ||
          _normalizeSkillId(entry.skillId) == targetSkill;
    }).toList();

    final results = <SkillProvisioningSkillResult>[];
    var changed = false;
    var reloadRecommended = false;

    for (final entry in entries) {
      final result = await _evaluateEntry(
        snapshot,
        entry,
        layout,
        envValues: envValues,
        configValues: configValues,
        applyValues: applyValues,
        installBundledBinaries: installBundledBinaries,
      );
      results.add(result);
      changed = changed || result.changed;
      reloadRecommended = reloadRecommended || result.reloadRecommended;
    }

    return SkillProvisioningReport(
      filesDir: snapshot.filesDir,
      skillId: targetSkill,
      auditedAt: snapshot.auditedAt,
      generatedAt: DateTime.now(),
      results: results,
      changed: changed,
      reloadRecommended: reloadRecommended,
    );
  }

  Future<SkillProvisioningSkillResult> _evaluateEntry(
    SkillParitySnapshot snapshot,
    SkillExecutionMatrixEntry entry,
    _SkillProvisioningLayout layout, {
    required Map<String, String> envValues,
    required Map<String, dynamic> configValues,
    required bool applyValues,
    required bool installBundledBinaries,
  }) async {
    final actions = <SkillProvisioningAction>[];
    final missingEnv = _gateValues(
      snapshot,
      entry,
      'missing_native_env',
      fallback: entry.requiredEnv,
    );
    final missingConfig = _gateValues(
      snapshot,
      entry,
      'missing_native_config',
      fallback: entry.requiredConfig,
    );
    final missingBins = _gateValues(
      snapshot,
      entry,
      'missing_native_bin',
      fallback: entry.requiredBins,
    );
    final missingPlugins = _gateValues(
      snapshot,
      entry,
      'missing_native_plugin',
      fallback: entry.requiredPlugins,
    );
    final gates = entry.gates.toSet();

    var changed = false;
    var reloadRecommended = false;
    var envFullySatisfied = true;
    var configFullySatisfied = true;
    var binaryFullySatisfied = true;

    for (final envName in missingEnv) {
      final supplied = envValues[envName];
      if (applyValues && supplied != null && _envKeyLooksSafe(envName)) {
        await _writeDotEnvValues(layout.nativeEnvFile, {envName: supplied});
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.env,
          key: envName,
          status: SkillProvisioningActionStatus.satisfied,
          message: 'Native .env value applied.',
          changed: true,
        ));
        changed = true;
        reloadRecommended = true;
      } else {
        envFullySatisfied = false;
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.env,
          key: envName,
          status: SkillProvisioningActionStatus.needsUserConfig,
          message: 'Set $envName in the Native OpenClaw environment.',
        ));
      }
    }

    for (final configKey in missingConfig) {
      final supplied = configValues[configKey];
      if (applyValues && configValues.containsKey(configKey)) {
        await _writeConfigValue(layout.nativeConfigFile, configKey, supplied);
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.config,
          key: configKey,
          status: SkillProvisioningActionStatus.satisfied,
          message: 'Native openclaw.json value applied.',
          changed: true,
        ));
        changed = true;
        reloadRecommended = true;
      } else {
        configFullySatisfied = false;
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.config,
          key: configKey,
          status: SkillProvisioningActionStatus.needsUserConfig,
          message: 'Set $configKey in Native openclaw.json.',
        ));
      }
    }

    for (final bin in missingBins) {
      final target = File(path.join(layout.nativeManagedBinDir.path, bin));
      final source = await _findBundledNativeBinary(layout, bin);
      if (installBundledBinaries && source != null) {
        await layout.nativeManagedBinDir.create(recursive: true);
        await source.copy(target.path);
        if (!Platform.isWindows) {
          try {
            await Process.run('chmod', ['755', target.path]);
          } catch (_) {}
        }
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.binary,
          key: bin,
          status: SkillProvisioningActionStatus.satisfied,
          message: 'Bundled native binary installed into managed bin.',
          changed: true,
        ));
        changed = true;
        reloadRecommended = true;
      } else {
        binaryFullySatisfied = false;
        final prootHas = snapshot.prootBins.contains(bin);
        actions.add(SkillProvisioningAction(
          type: SkillProvisioningActionType.binary,
          key: bin,
          status: SkillProvisioningActionStatus.missingBinary,
          message: prootHas
              ? '$bin exists in PRoot, but Native has no bundled/mobile-safe binary to install. PRoot will not be used automatically.'
              : '$bin is not available in Native and no bundled/mobile-safe binary was found.',
        ));
      }
    }

    for (final plugin in missingPlugins) {
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.plugin,
        key: plugin,
        status: SkillProvisioningActionStatus.missingPlugin,
        message:
            'Install or mirror the $plugin plugin into the Native OpenClaw workspace.',
      ));
    }

    if (gates.contains('disabled')) {
      actions.add(const SkillProvisioningAction(
        type: SkillProvisioningActionType.config,
        key: 'skills.disabled',
        status: SkillProvisioningActionStatus.disabled,
        message: 'Skill is disabled by Native OpenClaw config.',
      ));
    }

    if (gates.contains('missing_manifest') ||
        gates.contains('missing_native_skill')) {
      actions.add(const SkillProvisioningAction(
        type: SkillProvisioningActionType.manifest,
        key: 'SKILL.md',
        status: SkillProvisioningActionStatus.unsupportedNative,
        message: 'Skill is missing a Native-readable manifest or skill files.',
      ));
    }

    if (gates.contains('manual_proot_required')) {
      actions.add(SkillProvisioningAction(
        type: SkillProvisioningActionType.runtime,
        key: entry.requiredRuntimes.isEmpty
            ? 'full-linux-runtime'
            : entry.requiredRuntimes.join(','),
        status: SkillProvisioningActionStatus.manualProotRequired,
        message:
            'Skill requires a full Linux runtime. Native will not silently switch to PRoot; user must choose PRoot/manual compatibility mode.',
      ));
    }

    final status = _statusFor(
      entry,
      gates: gates,
      envFullySatisfied: envFullySatisfied,
      configFullySatisfied: configFullySatisfied,
      binaryFullySatisfied: binaryFullySatisfied,
      missingPlugins: missingPlugins,
      changed: changed,
    );

    if (actions.isEmpty && status == SkillProvisioningStatus.ready) {
      actions.add(const SkillProvisioningAction(
        type: SkillProvisioningActionType.none,
        key: 'native',
        status: SkillProvisioningActionStatus.ready,
        message: 'Skill is ready in Native.',
      ));
    }

    return SkillProvisioningSkillResult(
      skillId: entry.skillId,
      readiness: _executionStatusName(entry.status),
      status: status,
      primaryGate: entry.primaryGate,
      actions: actions,
      changed: changed,
      reloadRecommended: reloadRecommended,
    );
  }

  SkillProvisioningStatus _statusFor(
    SkillExecutionMatrixEntry entry, {
    required Set<String> gates,
    required bool envFullySatisfied,
    required bool configFullySatisfied,
    required bool binaryFullySatisfied,
    required List<String> missingPlugins,
    required bool changed,
  }) {
    if (gates.isEmpty) return SkillProvisioningStatus.ready;
    if (gates.contains('disabled')) return SkillProvisioningStatus.disabled;
    if (gates.contains('missing_manifest') ||
        gates.contains('missing_native_skill')) {
      return SkillProvisioningStatus.unsupportedNative;
    }
    if (gates.contains('manual_proot_required')) {
      return SkillProvisioningStatus.manualProotRequired;
    }
    if (!binaryFullySatisfied) return SkillProvisioningStatus.missingBinary;
    if (missingPlugins.isNotEmpty) return SkillProvisioningStatus.missingPlugin;
    if (!envFullySatisfied || !configFullySatisfied) {
      return SkillProvisioningStatus.needsUserConfig;
    }
    return changed
        ? SkillProvisioningStatus.satisfied
        : _statusFromExecution(entry.status);
  }

  static SkillProvisioningStatus _statusFromExecution(
    SkillExecutionStatus status,
  ) {
    return switch (status) {
      SkillExecutionStatus.ready => SkillProvisioningStatus.ready,
      SkillExecutionStatus.needsConfig =>
        SkillProvisioningStatus.needsUserConfig,
      SkillExecutionStatus.missingDependency =>
        SkillProvisioningStatus.missingBinary,
      SkillExecutionStatus.disabled => SkillProvisioningStatus.disabled,
      SkillExecutionStatus.unsupportedNative =>
        SkillProvisioningStatus.unsupportedNative,
      SkillExecutionStatus.manualProotRequired =>
        SkillProvisioningStatus.manualProotRequired,
    };
  }

  static String? _normalizeSkillId(String? value) {
    final trimmed = value?.trim().toLowerCase();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _executionStatusName(SkillExecutionStatus status) {
    return switch (status) {
      SkillExecutionStatus.ready => 'ready',
      SkillExecutionStatus.needsConfig => 'needs_config',
      SkillExecutionStatus.missingDependency => 'missing_dependency',
      SkillExecutionStatus.disabled => 'disabled',
      SkillExecutionStatus.unsupportedNative => 'unsupported_native',
      SkillExecutionStatus.manualProotRequired => 'manual_proot_required',
    };
  }

  static List<String> _gateValues(
    SkillParitySnapshot snapshot,
    SkillExecutionMatrixEntry entry,
    String gate, {
    required List<String> fallback,
  }) {
    final values = <String>{};
    for (final parityGate in snapshot.gates) {
      if (_normalizeSkillId(parityGate.skillId) !=
          _normalizeSkillId(entry.skillId)) {
        continue;
      }
      if (parityGate.gate != gate) continue;
      final parsed = _parseGateValue(parityGate.detail);
      if (parsed != null && parsed.isNotEmpty) values.add(parsed);
    }
    if (values.isEmpty) values.addAll(fallback);
    return values.toList()..sort();
  }

  static String? _parseGateValue(String detail) {
    final match = RegExp(r'^([A-Za-z0-9_.@/-]+)\b').firstMatch(detail.trim());
    return match?.group(1);
  }

  static Future<File?> _findBundledNativeBinary(
    _SkillProvisioningLayout layout,
    String bin,
  ) async {
    if (bin.trim().isEmpty || bin.contains('/') || bin.contains(r'\')) {
      return null;
    }
    for (final root in layout.bundledBinaryRoots) {
      final candidate = File(path.join(root.path, bin));
      try {
        if (await candidate.exists()) return candidate;
      } catch (_) {}
    }
    return null;
  }

  static bool _envKeyLooksSafe(String key) {
    return RegExp(r'^[A-Z][A-Z0-9_]{1,80}$').hasMatch(key);
  }

  static Future<void> _writeDotEnvValues(
    File file,
    Map<String, String> values,
  ) async {
    await file.parent.create(recursive: true);
    final lines =
        await file.exists() ? await file.readAsLines() : const <String>[];
    final pending = Map<String, String>.from(values);
    final updated = <String>[];
    for (final line in lines) {
      final match = RegExp(r'^\s*([A-Z][A-Z0-9_]{1,80})\s*=').firstMatch(line);
      final key = match?.group(1);
      if (key != null && pending.containsKey(key)) {
        updated.add('$key=${_formatDotEnvValue(pending.remove(key)!)}');
      } else {
        updated.add(line);
      }
    }
    for (final entry in pending.entries) {
      updated.add('${entry.key}=${_formatDotEnvValue(entry.value)}');
    }
    await file.writeAsString('${updated.join('\n')}\n', flush: true);
  }

  static String _formatDotEnvValue(String value) {
    if (value.isEmpty ||
        value.contains(RegExp(r'\s')) ||
        value.contains('#') ||
        value.contains('"') ||
        value.contains("'")) {
      return jsonEncode(value);
    }
    return value;
  }

  static Future<void> _writeConfigValue(
    File file,
    String key,
    dynamic value,
  ) async {
    final config = await _readJson(file) ?? <String, dynamic>{};
    _setNestedConfigValue(config, key, value);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(config)}\n',
      flush: true,
    );
  }

  static Future<Map<String, dynamic>?> _readJson(File file) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      debugPrint('[SkillProvisioning] config read failed ${file.path}: $error');
    }
    return null;
  }

  static void _setNestedConfigValue(
    Map<String, dynamic> config,
    String key,
    dynamic value,
  ) {
    final parts = key
        .split('.')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty ||
        parts.any((part) => !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(part))) {
      throw ArgumentError('Unsafe config key: $key');
    }
    Map<String, dynamic> current = config;
    for (final part in parts.take(parts.length - 1)) {
      final next = current[part];
      if (next is Map<String, dynamic>) {
        current = next;
      } else if (next is Map) {
        final converted = Map<String, dynamic>.from(next);
        current[part] = converted;
        current = converted;
      } else {
        final created = <String, dynamic>{};
        current[part] = created;
        current = created;
      }
    }
    current[parts.last] = value;
  }
}

class SkillProvisioningReport {
  final String filesDir;
  final String? skillId;
  final DateTime auditedAt;
  final DateTime generatedAt;
  final List<SkillProvisioningSkillResult> results;
  final bool changed;
  final bool reloadRecommended;

  const SkillProvisioningReport({
    required this.filesDir,
    required this.skillId,
    required this.auditedAt,
    required this.generatedAt,
    required this.results,
    required this.changed,
    required this.reloadRecommended,
  });

  Map<String, int> get summaryCounts {
    final counts = <String, int>{};
    for (final result in results) {
      counts.update(result.status.wireName, (value) => value + 1,
          ifAbsent: () => 1);
    }
    return counts;
  }

  int get blockedCount =>
      results.where((result) => result.status.isBlocking).length;

  String get compactLogLine {
    final counts = summaryCounts.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
    return '[SKILL-PROVISION] skills=${results.length} changed=$changed reloadRecommended=$reloadRecommended blocked=$blockedCount status=${counts.isEmpty ? 'none' : counts}';
  }

  String toPromptBlock({int maxSkills = 12}) {
    if (results.isEmpty) return '';
    final counts = summaryCounts.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    final lines = results
        .where((result) => result.status != SkillProvisioningStatus.ready)
        .take(maxSkills)
        .map((result) {
      final actions = result.actions
          .where((action) =>
              action.status != SkillProvisioningActionStatus.ready &&
              action.status != SkillProvisioningActionStatus.satisfied)
          .take(4)
          .map((action) => '${action.key}: ${action.status.wireName}')
          .join('; ');
      return '- ${result.skillId}: ${result.status.wireName}${actions.isEmpty ? '' : ' ($actions)'}';
    }).join('\n');

    return '''
Native skill provisioning:
- Counts: ${counts.isEmpty ? 'none' : counts}.
- Changed files: $changed; Gateway reload recommended: $reloadRecommended.
- PRoot is manual fallback only; Native never silently switches owners for blocked skills.
${lines.isEmpty ? '' : lines}
''';
  }

  Map<String, dynamic> toHealthJson({int maxResults = 20}) => {
        'counts': summaryCounts,
        'blockedCount': blockedCount,
        'changed': changed,
        'reloadRecommended': reloadRecommended,
        'generatedAt': generatedAt.toIso8601String(),
        'results':
            results.take(maxResults).map((result) => result.toJson()).toList(),
      };

  Map<String, dynamic> toJson() => {
        'filesDir': filesDir,
        if (skillId != null) 'skillId': skillId,
        'auditedAt': auditedAt.toIso8601String(),
        'generatedAt': generatedAt.toIso8601String(),
        'changed': changed,
        'reloadRecommended': reloadRecommended,
        'blockedCount': blockedCount,
        'summaryCounts': summaryCounts,
        'results': results.map((result) => result.toJson()).toList(),
      };
}

class SkillProvisioningSkillResult {
  final String skillId;
  final String readiness;
  final SkillProvisioningStatus status;
  final String? primaryGate;
  final List<SkillProvisioningAction> actions;
  final bool changed;
  final bool reloadRecommended;

  const SkillProvisioningSkillResult({
    required this.skillId,
    required this.readiness,
    required this.status,
    required this.primaryGate,
    required this.actions,
    required this.changed,
    required this.reloadRecommended,
  });

  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'readiness': readiness,
        'status': status.wireName,
        if (primaryGate != null) 'primaryGate': primaryGate,
        'changed': changed,
        'reloadRecommended': reloadRecommended,
        'actions': actions.map((action) => action.toJson()).toList(),
      };
}

class SkillProvisioningAction {
  final SkillProvisioningActionType type;
  final String key;
  final SkillProvisioningActionStatus status;
  final String message;
  final bool changed;

  const SkillProvisioningAction({
    required this.type,
    required this.key,
    required this.status,
    required this.message,
    this.changed = false,
  });

  Map<String, dynamic> toJson() => {
        'type': type.wireName,
        'key': key,
        'status': status.wireName,
        'message': message,
        'changed': changed,
      };
}

enum SkillProvisioningStatus {
  ready,
  satisfied,
  needsUserConfig,
  missingBinary,
  missingPlugin,
  disabled,
  unsupportedNative,
  manualProotRequired,
}

extension SkillProvisioningStatusName on SkillProvisioningStatus {
  String get wireName {
    return switch (this) {
      SkillProvisioningStatus.ready => 'ready',
      SkillProvisioningStatus.satisfied => 'satisfied',
      SkillProvisioningStatus.needsUserConfig => 'needs_user_config',
      SkillProvisioningStatus.missingBinary => 'missing_binary',
      SkillProvisioningStatus.missingPlugin => 'missing_plugin',
      SkillProvisioningStatus.disabled => 'disabled',
      SkillProvisioningStatus.unsupportedNative => 'unsupported_native',
      SkillProvisioningStatus.manualProotRequired => 'manual_proot_required',
    };
  }

  bool get isBlocking {
    return switch (this) {
      SkillProvisioningStatus.ready ||
      SkillProvisioningStatus.satisfied =>
        false,
      _ => true,
    };
  }
}

enum SkillProvisioningActionType {
  none,
  env,
  config,
  binary,
  plugin,
  manifest,
  runtime,
}

extension SkillProvisioningActionTypeName on SkillProvisioningActionType {
  String get wireName {
    return switch (this) {
      SkillProvisioningActionType.none => 'none',
      SkillProvisioningActionType.env => 'env',
      SkillProvisioningActionType.config => 'config',
      SkillProvisioningActionType.binary => 'binary',
      SkillProvisioningActionType.plugin => 'plugin',
      SkillProvisioningActionType.manifest => 'manifest',
      SkillProvisioningActionType.runtime => 'runtime',
    };
  }
}

enum SkillProvisioningActionStatus {
  ready,
  satisfied,
  needsUserConfig,
  missingBinary,
  missingPlugin,
  disabled,
  unsupportedNative,
  manualProotRequired,
}

extension SkillProvisioningActionStatusName on SkillProvisioningActionStatus {
  String get wireName {
    return switch (this) {
      SkillProvisioningActionStatus.ready => 'ready',
      SkillProvisioningActionStatus.satisfied => 'satisfied',
      SkillProvisioningActionStatus.needsUserConfig => 'needs_user_config',
      SkillProvisioningActionStatus.missingBinary => 'missing_binary',
      SkillProvisioningActionStatus.missingPlugin => 'missing_plugin',
      SkillProvisioningActionStatus.disabled => 'disabled',
      SkillProvisioningActionStatus.unsupportedNative => 'unsupported_native',
      SkillProvisioningActionStatus.manualProotRequired =>
        'manual_proot_required',
    };
  }
}

class _SkillProvisioningLayout {
  final String filesDir;

  _SkillProvisioningLayout(this.filesDir);

  String get nativeStateRoot =>
      path.join(filesDir, 'native-node-embedded', 'native-home', '.openclaw');
  File get nativeEnvFile => File(path.join(nativeStateRoot, '.env'));
  File get nativeConfigFile =>
      File(path.join(nativeStateRoot, 'openclaw.json'));
  Directory get nativeManagedBinDir =>
      Directory(path.join(nativeStateRoot, 'bin'));

  List<Directory> get bundledBinaryRoots => [
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'provisioning',
          'bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'bundled-bin',
        )),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'full-openclaw',
          'provisioning',
          'bin',
        )),
      ];
}
