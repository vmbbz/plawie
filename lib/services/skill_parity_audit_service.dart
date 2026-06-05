import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

import 'gateway_tool_catalog.dart';
import 'native_bridge.dart';
import 'skill_execution_descriptor.dart';

class SkillParityAuditService {
  SkillParityAuditService._();
  static final SkillParityAuditService instance = SkillParityAuditService._();

  static const _mirrorMarkerName = '.plawie-native-mirror.json';
  static const _nativePythonRuntimeVersion = '3.13';
  static final _skillNamePattern = RegExp(r'^@?[a-zA-Z0-9][a-zA-Z0-9._@-]*$');
  static final _envPattern = RegExp(
    r'\b[A-Z][A-Z0-9_]{2,}(?:API_KEY|TOKEN|SECRET|CLIENT_ID|CLIENT_SECRET|AUTH|KEY|URL|HOST|PASSWORD)\b'
    r'|\b(?:[A-Z][A-Z0-9_]{2,}_(?:API_KEY|TOKEN|SECRET|CLIENT_ID|CLIENT_SECRET|AUTH|KEY|URL|HOST|PASSWORD))\b',
  );
  static const _knownBins = <String>{
    'bash',
    'bun',
    'curl',
    'ffmpeg',
    'git',
    'jq',
    'magick',
    'node',
    'npm',
    'npx',
    'pip',
    'pip3',
    'python',
    'python3',
    'rg',
    'sh',
    'sqlite3',
    'tar',
    'unzip',
    'yt-dlp',
  };
  static const _knownPythonPackageNames = <String>{
    'annotated-types',
    'beautifulsoup4',
    'bs4',
    'certifi',
    'charset-normalizer',
    'curl-cffi',
    'dateutils',
    'frozendict',
    'html5lib',
    'idna',
    'multitasking',
    'numpy',
    'pandas',
    'peewee',
    'platformdirs',
    'pydantic',
    'pydantic-core',
    'python-dateutil',
    'pytz',
    'requests',
    'six',
    'soupsieve',
    'typing-extensions',
    'typing-inspection',
    'tzdata',
    'urllib3',
    'websockets',
    'yfinance',
  };

  SkillParitySnapshot? _cachedSnapshot;
  DateTime? _cachedAt;
  Future<SkillParitySnapshot>? _inFlight;

  Future<SkillParitySnapshot> audit({
    String? filesDir,
    bool repairNativeFromProot = false,
    Duration cacheTtl = const Duration(seconds: 45),
  }) {
    final now = DateTime.now();
    final cached = _cachedSnapshot;
    final cachedAt = _cachedAt;
    if (!repairNativeFromProot &&
        cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < cacheTtl) {
      return Future.value(cached);
    }
    final pending = _inFlight;
    if (pending != null && !repairNativeFromProot) return pending;

    final future = _auditUncached(
      filesDir: filesDir,
      repairNativeFromProot: repairNativeFromProot,
    );
    _inFlight = future;
    future.then((snapshot) {
      _cachedSnapshot = snapshot;
      _cachedAt = DateTime.now();
    }).whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<SkillParitySnapshot> _auditUncached({
    String? filesDir,
    required bool repairNativeFromProot,
  }) async {
    final root = filesDir ?? await NativeBridge.getFilesDir();
    final layout = _SkillParityLayout(root);
    final repair = repairNativeFromProot
        ? await _mirrorProotSkillsIntoNative(layout)
        : const SkillMirrorRepairResult();

    final nativeSkills = await _scanSkillRoots(layout.nativeSkillRoots);
    final prootSkills = await _scanSkillRoots(layout.prootSkillRoots);
    final nativeConfig = await _readJson(layout.nativeConfigFile);
    final prootConfig = await _readJson(layout.prootConfigFile);
    final nativeEnv = {
      ..._readConfigEnv(nativeConfig),
      ...await _readDotEnv(layout.nativeEnvFile),
    };
    final prootEnv = {
      ..._readConfigEnv(prootConfig),
      ...await _readDotEnv(layout.prootEnvFile),
    };
    final nativeToolsAllow =
        GatewayToolCatalog.normalizeAllowList(nativeConfig?['tools']?['allow']);
    final prootToolsAllow =
        GatewayToolCatalog.normalizeAllowList(prootConfig?['tools']?['allow']);
    final nativeDisabled = _readDisabledSkills(nativeConfig);
    final prootDisabled = _readDisabledSkills(prootConfig);
    final nativePlugins = await _scanPluginRoots(layout.nativePluginRoots);
    final prootPlugins = await _scanPluginRoots(layout.prootPluginRoots);
    final nativeBins = await _scanBins(layout.nativeBinRoots);
    final prootBins = await _scanBins(layout.prootBinRoots);
    final nativePluginIds =
        nativePlugins.map((name) => name.toLowerCase()).toSet();

    final nativeIds = nativeSkills.keys.toSet();
    final prootIds = prootSkills.keys.toSet();
    final missingInNative = (prootIds.difference(nativeIds)).toList()..sort();
    final missingInProot = (nativeIds.difference(prootIds)).toList()..sort();
    final gates = <SkillParityGate>[];
    final matrix = <SkillExecutionMatrixEntry>[];

    for (final skill in nativeSkills.values) {
      final id = skill.id.toLowerCase();
      final skillGates = <SkillParityGate>[];
      if (!skill.hasSkillDocument && !skill.hasPackageJson) {
        skillGates.add(SkillParityGate(
          skillId: skill.id,
          gate: 'missing_manifest',
          owner: 'native',
          detail: 'No SKILL.md, skill.md, SKILL.yaml, or package.json found.',
        ));
      }
      if (nativeDisabled.contains(id)) {
        skillGates.add(SkillParityGate(
          skillId: skill.id,
          gate: 'disabled',
          owner: 'native',
          detail: 'Native openclaw.json marks this skill disabled.',
        ));
      }

      final body = await _readSkillBody(skill);
      final requirements = await _detectSkillRequirements(skill, body);
      final executionDescriptor =
          await _detectExecutionDescriptor(skill, requirements, body);
      final descriptorDependencies = executionDescriptor?.dependencies;
      final requiredBins = {
        ...requirements.bins,
        ...?descriptorDependencies?.bins,
      };
      if (executionDescriptor?.runtime == SkillExecutionRuntime.http &&
          executionDescriptor?.mode == SkillExecutionMode.httpEndpoint) {
        requiredBins.remove('curl');
      }
      final requiredEnv = {
        ...requirements.env,
        ...?descriptorDependencies?.env,
      };
      final requiredRuntimes = {
        ...requirements.runtimes,
        ...?descriptorDependencies?.runtimes,
      };
      final requiredPythonPackages = {
        ...requirements.pythonPackages,
        ...?descriptorDependencies?.pythonPackages.map(
          _normalizePythonPackageName,
        ),
      };
      final requiredPythonRequirements = {
        ...requirements.pythonRequirements,
        for (final package
            in descriptorDependencies?.pythonPackages ?? const <String>[])
          _normalizePythonPackageName(package): requirements
                  .pythonRequirements[_normalizePythonPackageName(package)] ??
              package,
      };
      final requiredPlugins = {
        ...requirements.plugins,
        ...?descriptorDependencies?.plugins,
      };
      final requiredConfig = {
        ...requirements.configKeys,
        ...?descriptorDependencies?.config,
      };

      for (final bin in requiredBins) {
        if (!nativeBins.contains(bin)) {
          final prootHas = prootBins.contains(bin);
          skillGates.add(SkillParityGate(
            skillId: skill.id,
            gate: 'missing_native_bin',
            owner: 'native',
            detail: prootHas
                ? '$bin exists in PRoot but was not found in Native runtime paths.'
                : '$bin was referenced by the skill but was not found in Native runtime paths.',
          ));
        }
      }

      for (final envName in requiredEnv) {
        if (!_envValueLooksSet(nativeEnv[envName])) {
          final prootHas = _envValueLooksSet(prootEnv[envName]);
          skillGates.add(SkillParityGate(
            skillId: skill.id,
            gate: 'missing_native_env',
            owner: 'native',
            detail: prootHas
                ? '$envName is configured in PRoot but not Native.'
                : '$envName is referenced by the skill but not configured in Native.',
          ));
        }
      }
      for (final configKey in requiredConfig) {
        if (!_configValueLooksSet(nativeConfig, configKey)) {
          skillGates.add(SkillParityGate(
            skillId: skill.id,
            gate: 'missing_native_config',
            owner: 'native',
            detail:
                '$configKey is declared as required config but was not found in Native openclaw.json.',
          ));
        }
      }
      for (final plugin in requiredPlugins) {
        if (!nativePluginIds.contains(plugin.toLowerCase())) {
          skillGates.add(SkillParityGate(
            skillId: skill.id,
            gate: 'missing_native_plugin',
            owner: 'native',
            detail:
                '$plugin is declared as a required plugin but was not found in Native plugin roots.',
          ));
        }
      }
      if (requiredPythonPackages.isNotEmpty) {
        final nativePythonPackages =
            await _scanPythonPackages(layout.nativeStateRoot, skill);
        final nativeHasPython =
            nativeBins.contains('python3') || nativeBins.contains('python');
        if (!nativeHasPython) {
          skillGates.add(SkillParityGate(
            skillId: skill.id,
            gate: 'missing_native_runtime',
            owner: 'native',
            detail:
                'python3 is required for requirements.txt but was not found in Native runtime paths.',
          ));
        }
        for (final requirement in requiredPythonRequirements.entries) {
          final package = requirement.key;
          final installedVersion = nativePythonPackages[package];
          if (installedVersion == null) {
            skillGates.add(SkillParityGate(
              skillId: skill.id,
              gate: 'missing_native_python_package',
              owner: 'native',
              detail:
                  '$package is required by requirements.txt (${requirement.value}) but was not found in a Native Python environment.',
            ));
          } else if (!_pythonRequirementSatisfied(
                installedVersion,
                requirement.value,
              ) &&
              !await _pythonCompatibilityReceiptSatisfied(
                layout.nativeStateRoot,
                package,
                requirement.value,
                installedVersion,
              )) {
            skillGates.add(SkillParityGate(
              skillId: skill.id,
              gate: 'missing_native_python_package',
              owner: 'native',
              detail:
                  '$package version $installedVersion does not satisfy requirements.txt (${requirement.value}).',
            ));
          }
        }
      }
      if (requiredRuntimes.any(_looksLikeExtendedRuntime)) {
        skillGates.add(SkillParityGate(
          skillId: skill.id,
          gate: 'manual_proot_required',
          owner: 'native',
          detail:
              'Skill declares or strongly implies a full Linux runtime dependency (${requiredRuntimes.join(', ')}). Native will not silently fall back to PRoot.',
        ));
      }

      gates.addAll(skillGates);
      matrix.add(SkillExecutionMatrixEntry.fromGates(
        skillId: skill.id,
        gates: skillGates,
        requiredBins: {
          ...requiredBins,
        }.toList()
          ..sort(),
        requiredEnv: {
          ...requiredEnv,
        }.toList()
          ..sort(),
        requiredRuntimes: {
          ...requiredRuntimes,
        }.toList()
          ..sort(),
        requiredPythonPackages: {
          ...requiredPythonPackages,
        }.toList()
          ..sort(),
        requiredPythonRequirements: requiredPythonRequirements,
        requiredPlugins: {
          ...requiredPlugins,
        }.toList()
          ..sort(),
        requiredConfig: {
          ...requiredConfig,
        }.toList()
          ..sort(),
        executionDescriptor: executionDescriptor,
      ));
    }

    for (final id in missingInNative) {
      gates.add(SkillParityGate(
        skillId: id,
        gate: 'missing_native_skill',
        owner: 'native',
        detail: 'Skill exists in PRoot but not in Native skill roots.',
      ));
    }
    for (final id in prootDisabled) {
      if (!nativeDisabled.contains(id) && prootSkills.containsKey(id)) {
        gates.add(SkillParityGate(
          skillId: id,
          gate: 'disabled_in_proot_only',
          owner: 'proot',
          detail:
              'PRoot config marks the skill disabled; Native does not mirror that disabled gate.',
        ));
      }
    }

    matrix.sort((a, b) => a.skillId.compareTo(b.skillId));

    return SkillParitySnapshot(
      filesDir: root,
      nativeSkillCount: nativeSkills.length,
      prootSkillCount: prootSkills.length,
      nativeSkillNames: nativeSkills.keys.toList()..sort(),
      prootSkillNames: prootSkills.keys.toList()..sort(),
      missingInNative: missingInNative,
      missingInProot: missingInProot,
      nativePluginCount: nativePlugins.length,
      prootPluginCount: prootPlugins.length,
      nativePluginNames: nativePlugins,
      prootPluginNames: prootPlugins,
      nativeToolsAllow: nativeToolsAllow,
      prootToolsAllow: prootToolsAllow,
      nativeEnvKeys: nativeEnv.keys.toList()..sort(),
      prootEnvKeys: prootEnv.keys.toList()..sort(),
      nativeBins: nativeBins.toList()..sort(),
      prootBins: prootBins.toList()..sort(),
      gates: gates,
      executionMatrix: matrix,
      repair: repair,
      auditedAt: DateTime.now(),
    );
  }

  Future<SkillMirrorRepairResult> _mirrorProotSkillsIntoNative(
    _SkillParityLayout layout,
  ) async {
    final errors = <String>[];
    var copied = 0;
    var updated = 0;
    var skippedConflicts = 0;

    final pairs = <({Directory source, Directory target})>[
      (source: layout.prootSkillsRoot, target: layout.nativeSkillsRoot),
      (
        source: layout.prootWorkspaceSkillsRoot,
        target: layout.nativeWorkspaceSkillsRoot,
      ),
      (source: layout.prootPluginsRoot, target: layout.nativePluginsRoot),
      (
        source: layout.prootWorkspacePluginsRoot,
        target: layout.nativeWorkspacePluginsRoot,
      ),
    ];

    for (final pair in pairs) {
      try {
        if (!await pair.source.exists()) continue;
        await pair.target.create(recursive: true);
        await for (final entity in pair.source.list(recursive: false)) {
          final name = path.basename(entity.path);
          if (!_isSafeSkillName(name)) continue;
          final targetPath = path.join(pair.target.path, name);
          try {
            if (entity is Directory) {
              final target = Directory(targetPath);
              final marker = File(path.join(target.path, _mirrorMarkerName));
              if (await target.exists()) {
                final markerData = await _readJson(marker);
                final sourceSignature = await _directorySignature(entity);
                if (markerData?['sourcePath'] == entity.path &&
                    markerData?['sourceSignature'] != sourceSignature) {
                  await target.delete(recursive: true);
                  await _copyDirectory(entity, target);
                  await _writeMirrorMarker(
                    marker,
                    sourcePath: entity.path,
                    sourceSignature: sourceSignature,
                  );
                  updated += 1;
                } else if (markerData?['sourcePath'] != entity.path) {
                  skippedConflicts += 1;
                }
                continue;
              }
              await _copyDirectory(entity, target);
              await _writeMirrorMarker(
                marker,
                sourcePath: entity.path,
                sourceSignature: await _directorySignature(entity),
              );
              copied += 1;
            } else if (entity is File) {
              final target = File(targetPath);
              if (await target.exists()) {
                skippedConflicts += 1;
                continue;
              }
              await target.parent.create(recursive: true);
              await entity.copy(target.path);
              copied += 1;
            }
          } catch (error) {
            errors.add('$name:$error');
          }
        }
      } catch (error) {
        errors.add('${pair.source.path}:$error');
      }
    }

    return SkillMirrorRepairResult(
      copied: copied,
      updated: updated,
      skippedConflicts: skippedConflicts,
      errors: errors,
    );
  }

  static bool _isSafeSkillName(String value) {
    if (value.isEmpty || value.startsWith('.')) return false;
    if (value.contains('/') || value.contains(r'\') || value.contains('..')) {
      return false;
    }
    return _skillNamePattern.hasMatch(value);
  }

  static Future<Map<String, _SkillDiskEntry>> _scanSkillRoots(
    List<Directory> roots,
  ) async {
    final result = <String, _SkillDiskEntry>{};
    for (final root in roots) {
      try {
        if (!await root.exists()) continue;
        await for (final entity in root.list(recursive: false)) {
          final name = path.basename(entity.path);
          if (!_isSafeSkillName(name)) continue;
          if (entity is Directory) {
            final entry = await _SkillDiskEntry.fromDirectory(name, entity);
            if (entry.hasAnyManifest) {
              result.putIfAbsent(name.toLowerCase(), () => entry);
            }
          } else if (entity is File) {
            final lower = name.toLowerCase();
            if (lower.endsWith('.md') || lower.endsWith('.yaml')) {
              final id = name.replaceFirst(RegExp(r'\.(md|yaml)$'), '');
              if (_isSafeSkillName(id)) {
                result.putIfAbsent(
                  id.toLowerCase(),
                  () => _SkillDiskEntry.file(id, entity),
                );
              }
            }
          }
        }
      } catch (_) {}
    }
    return result;
  }

  static Future<List<String>> _scanPluginRoots(List<Directory> roots) async {
    final names = <String>{};
    for (final root in roots) {
      try {
        if (!await root.exists()) continue;
        await for (final entity in root.list(recursive: false)) {
          final name = path.basename(entity.path);
          if (name.isEmpty || name.startsWith('.')) continue;
          if (entity is Directory || entity is File) names.add(name);
        }
      } catch (_) {}
    }
    return names.toList()..sort();
  }

  static Future<Set<String>> _scanBins(List<Directory> roots) async {
    final bins = <String>{};
    for (final root in roots) {
      try {
        if (!await root.exists()) continue;
        final validPythonBridge =
            await _validNativePythonBridgeForBinRoot(root);
        if (validPythonBridge) {
          bins.addAll(const ['python', 'python3', 'pip', 'pip3']);
        }
        await for (final entity in root.list(recursive: false)) {
          if (entity is File && await _fileLooksExecutable(entity)) {
            final name = path.basename(entity.path);
            if (_isPythonCommandBin(name) && !validPythonBridge) continue;
            bins.add(name);
          }
        }
      } catch (_) {}
    }
    return bins;
  }

  static Future<bool> _validNativePythonBridgeForBinRoot(Directory root) async {
    final candidates = [
      File(path.join(root.parent.path, 'bridge.json')),
      File(path.join(root.parent.path, 'runtimes', 'python', 'bridge.json')),
    ];
    for (final candidate in candidates) {
      if (await _validNativePythonBridge(candidate)) return true;
    }
    return false;
  }

  static Future<bool> _validNativePythonBridge(File marker) async {
    final json = await _readJson(marker);
    return json?['runtime']?.toString() == 'chaquopy' &&
        json?['python']?.toString() == _nativePythonRuntimeVersion;
  }

  static bool _isPythonCommandBin(String value) {
    final normalized = path.basename(value).trim().toLowerCase();
    return normalized == 'python' ||
        normalized == 'python3' ||
        normalized == 'pip' ||
        normalized == 'pip3';
  }

  static Future<bool> _fileLooksExecutable(File file) async {
    if (Platform.isWindows) return true;
    try {
      final stat = await file.stat();
      return stat.type == FileSystemEntityType.file && (stat.mode & 0x49) != 0;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _readSkillBody(_SkillDiskEntry skill) async {
    for (final file in skill.documentCandidates) {
      try {
        if (await file.exists()) return await file.readAsString();
      } catch (_) {}
    }
    return '';
  }

  static Future<_SkillRequirements> _detectSkillRequirements(
    _SkillDiskEntry skill,
    String body,
  ) async {
    final frontmatter = _parseYamlFrontmatter(body);
    final fromYaml = _requirementsFromYaml(frontmatter);
    final pythonRequirements = await _readPythonRequirements(skill);
    final pythonRequirementNames = pythonRequirements.keys.toSet();
    final bins = {
      ...fromYaml.bins.map(_normalizeRequiredBin).whereType<String>(),
      ..._detectRequiredBins(body),
    }..removeWhere((bin) {
        final normalized = _normalizePythonPackageName(bin);
        return pythonRequirementNames.contains(normalized) ||
            _knownPythonPackageNames.contains(normalized);
      });
    return _SkillRequirements(
      bins: bins,
      env: {...fromYaml.env, ..._detectRequiredEnv(body)},
      runtimes: {
        ...fromYaml.runtimes,
        if (pythonRequirements.isNotEmpty) 'python',
      },
      pythonRequirements: pythonRequirements,
      plugins: fromYaml.plugins,
      configKeys: fromYaml.configKeys,
    );
  }

  static Future<SkillExecutionDescriptor?> _detectExecutionDescriptor(
    _SkillDiskEntry skill,
    _SkillRequirements requirements,
    String body,
  ) async {
    final frontmatter = _parseYamlFrontmatter(body);
    final yamlDescriptor = _executionDescriptorFromYaml(
      skill,
      requirements,
      frontmatter,
    );
    if (yamlDescriptor != null) return yamlDescriptor;

    final pythonDescriptor =
        await _pythonToolsClassExecutionDescriptor(skill, requirements);
    if (pythonDescriptor != null) return pythonDescriptor;

    return _httpEndpointExecutionDescriptor(skill, requirements, body);
  }

  static SkillExecutionDescriptor? _executionDescriptorFromYaml(
    _SkillDiskEntry skill,
    _SkillRequirements requirements,
    Map<String, dynamic> yaml,
  ) {
    final candidates = <dynamic>[
      yaml['execution'],
      _mapPath(yaml, const ['openclaw', 'execution']),
      _mapPath(yaml, const ['metadata', 'openclaw', 'execution']),
      _mapPath(yaml, const ['metadata', 'execution']),
      _mapPath(yaml, const ['skill', 'execution']),
    ].where((value) => value != null).toList();
    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final execution = Map<String, dynamic>.from(candidate);
      final runtime = _runtimeFromString(execution['runtime']?.toString());
      final mode = _modeFromString(execution['mode']?.toString());
      final entrypoint = execution['entrypoint']?.toString().trim() ??
          execution['command']?.toString().trim() ??
          execution['url']?.toString().trim() ??
          '';
      if (runtime == SkillExecutionRuntime.unknown ||
          mode == SkillExecutionMode.unknown ||
          entrypoint.isEmpty) {
        continue;
      }
      return SkillExecutionDescriptor(
        skillId: skill.id,
        rootPath: _skillRootPath(skill),
        source: _skillSource(skill, entrypoint),
        runtime: runtime,
        mode: mode,
        entrypoint: entrypoint,
        className: execution['className']?.toString(),
        dependencies: _dependencyDescriptorFromRequirements(requirements),
      );
    }
    return null;
  }

  static Future<SkillExecutionDescriptor?> _pythonToolsClassExecutionDescriptor(
    _SkillDiskEntry skill,
    _SkillRequirements requirements,
  ) async {
    if (skill.entity is! Directory) return null;
    final root = skill.entity as Directory;
    final entrypoint = await _findPythonToolsEntrypoint(root);
    if (entrypoint == null) return null;
    final body = await File(path.join(root.path, entrypoint)).readAsString();
    return SkillExecutionDescriptor(
      skillId: skill.id,
      rootPath: root.path,
      source: _skillSource(skill, entrypoint),
      runtime: SkillExecutionRuntime.python,
      mode: SkillExecutionMode.pythonToolsClass,
      entrypoint: entrypoint,
      className: 'Tools',
      dependencies: _dependencyDescriptorFromRequirements(
        requirements,
        forceRuntimes: const ['python'],
        forceBins: const ['python3', 'pip'],
      ),
      methods: _parsePythonToolsMethods(body),
    );
  }

  static SkillExecutionDescriptor? _httpEndpointExecutionDescriptor(
    _SkillDiskEntry skill,
    _SkillRequirements requirements,
    String body,
  ) {
    final match = RegExp(
      r'https?://(?:127\.0\.0\.1|localhost):8765/[^\s`"\\)]+',
    ).firstMatch(body);
    final rawUrl = match?.group(0);
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final url = rawUrl.replaceFirst(RegExp(r'[),.]+$'), '');
    final start = (match!.start - 160).clamp(0, body.length);
    final end = (match.end + 160).clamp(0, body.length);
    final commandWindow = body.substring(start, end);
    final upper = commandWindow.toUpperCase();
    final httpMethod = RegExp(r'-X\s+POST\b').hasMatch(upper) ||
            upper.contains('--DATA') ||
            RegExp(r'(^|\s)-D\s').hasMatch(upper)
        ? 'POST'
        : 'GET';
    final parameters = {
      ..._queryParameterDescriptors(url),
      ..._jsonBodyParameterDescriptors(commandWindow),
    };
    return SkillExecutionDescriptor(
      skillId: skill.id,
      rootPath: _skillRootPath(skill),
      source: _skillSource(skill, path.basename(skill.entity.path)),
      runtime: SkillExecutionRuntime.http,
      mode: SkillExecutionMode.httpEndpoint,
      entrypoint: url,
      dependencies: _dependencyDescriptorFromRequirements(
        requirements,
        excludeBins: const ['curl'],
      ),
      methods: [
        SkillExecutionMethodDescriptor(
          name: _safeMethodName('${httpMethod}_${skill.id}'),
          description: '$httpMethod $url',
          parameters: parameters,
        ),
      ],
    );
  }

  static Future<Map<String, String>> _readPythonRequirements(
    _SkillDiskEntry skill,
  ) async {
    if (skill.entity is! Directory) return const <String, String>{};
    final file =
        File(path.join((skill.entity as Directory).path, 'requirements.txt'));
    try {
      if (!await file.exists()) return const <String, String>{};
      final requirements = <String, String>{};
      for (final rawLine in await file.readAsLines()) {
        final parsed = _parsePythonRequirement(rawLine);
        if (parsed != null) requirements[parsed.name] = parsed.raw;
      }
      return requirements;
    } catch (error) {
      debugPrint('[SkillParity] requirements read failed ${file.path}: $error');
      return const <String, String>{};
    }
  }

  static _PythonRequirementLine? _parsePythonRequirement(String rawLine) {
    var line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) return null;
    final hash = line.indexOf('#');
    if (hash >= 0) line = line.substring(0, hash).trim();
    if (line.isEmpty ||
        line.startsWith('-') ||
        line.startsWith('git+') ||
        line.startsWith('http://') ||
        line.startsWith('https://') ||
        line == '.') {
      return null;
    }
    final match = RegExp(r'^([A-Za-z0-9_.-]+)(?:\[[^\]]+\])?').firstMatch(line);
    final value = match?.group(1);
    if (value == null || value.isEmpty) return null;
    return _PythonRequirementLine(
      name: _normalizePythonPackageName(value),
      raw: line,
    );
  }

  static SkillDependencyDescriptor _dependencyDescriptorFromRequirements(
    _SkillRequirements requirements, {
    List<String> forceRuntimes = const <String>[],
    List<String> forceBins = const <String>[],
    List<String> excludeBins = const <String>[],
  }) {
    final excludedBins =
        excludeBins.map(_normalizeRequiredBin).whereType<String>().toSet();
    return SkillDependencyDescriptor(
      runtimes: {
        ...requirements.runtimes,
        ...forceRuntimes,
      }.toList()
        ..sort(),
      bins: {
        ...requirements.bins,
        ...forceBins,
      }.where((bin) => !excludedBins.contains(bin)).toList()
        ..sort(),
      pythonPackages: requirements.pythonPackages.toList()..sort(),
      env: requirements.env.toList()..sort(),
      config: requirements.configKeys.toList()..sort(),
      plugins: requirements.plugins.toList()..sort(),
    );
  }

  static Future<String?> _findPythonToolsEntrypoint(Directory root) async {
    final candidates = <String>[];
    final preferred = [
      'main.py',
      'skill.py',
      'tools.py',
      path.join('scripts', 'main.py'),
      path.join('scripts', 'skill.py'),
      path.join('scripts', 'tools.py'),
    ];
    for (final relative in preferred) {
      if (await File(path.join(root.path, relative)).exists()) {
        candidates.add(relative);
      }
    }
    final scripts = Directory(path.join(root.path, 'scripts'));
    if (await scripts.exists()) {
      await for (final entity in scripts.list(recursive: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.py')) {
          final relative = path.join('scripts', path.basename(entity.path));
          if (!candidates.contains(relative)) candidates.add(relative);
        }
      }
    }
    await for (final entity in root.list(recursive: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.py')) {
        final relative = path.basename(entity.path);
        if (!candidates.contains(relative)) candidates.add(relative);
      }
    }
    for (final relative in candidates) {
      final body = await File(path.join(root.path, relative)).readAsString();
      if (RegExp(r'class\s+Tools\b').hasMatch(body)) {
        return relative.replaceAll('\\', '/');
      }
    }
    return null;
  }

  static List<SkillExecutionMethodDescriptor> _parsePythonToolsMethods(
    String body,
  ) {
    final classStart = RegExp(r'class\s+Tools\b[^\n]*:').firstMatch(body)?.end;
    if (classStart == null) return const <SkillExecutionMethodDescriptor>[];
    final classBody = body.substring(classStart);
    final methods = <SkillExecutionMethodDescriptor>[];
    for (final match in RegExp(
      r'^\s+(?:async\s+)?def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*:',
      multiLine: true,
    ).allMatches(classBody)) {
      final name = match.group(1)!;
      if (name.startsWith('_')) continue;
      final parameters = _parsePythonParameters(match.group(2) ?? '');
      methods.add(SkillExecutionMethodDescriptor(
        name: name,
        parameters: {
          for (final parameter in parameters) parameter.name: 'value',
        },
        requiredParameters: parameters
            .where((parameter) => parameter.required)
            .map((parameter) => parameter.name)
            .toList(),
      ));
    }
    return methods;
  }

  static List<_ParsedPythonParameter> _parsePythonParameters(String raw) {
    final parameters = <_ParsedPythonParameter>[];
    for (final part in raw.split(',')) {
      var parameter = part.trim();
      if (parameter.isEmpty ||
          parameter == 'self' ||
          parameter.startsWith('*')) {
        continue;
      }
      final required = !parameter.contains('=');
      parameter = parameter.split('=').first.trim();
      parameter = parameter.split(':').first.trim();
      if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(parameter)) {
        parameters.add(_ParsedPythonParameter(
          name: parameter,
          required: required,
        ));
      }
    }
    return parameters;
  }

  static Map<String, String> _queryParameterDescriptors(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.queryParameters.isEmpty) {
      return const <String, String>{};
    }
    return {
      for (final key in parsed.queryParameters.keys) key: 'query parameter',
    };
  }

  static Map<String, String> _jsonBodyParameterDescriptors(String command) {
    final match =
        RegExp(r'''(['"])\{(.+?)\}\1''', dotAll: true).firstMatch(command);
    final jsonText = match == null ? null : '{${match.group(2)}}';
    if (jsonText == null) return const <String, String>{};
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return const <String, String>{};
      return {
        for (final key in decoded.keys) key.toString(): 'json body field',
      };
    } catch (_) {
      return const <String, String>{};
    }
  }

  static SkillExecutionRuntime _runtimeFromString(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('-', '_') ?? '';
    return switch (normalized) {
      'python' || 'py' => SkillExecutionRuntime.python,
      'node' || 'nodejs' || 'javascript' || 'js' => SkillExecutionRuntime.node,
      'shell' || 'bash' || 'sh' || 'command' => SkillExecutionRuntime.shell,
      'mcp' => SkillExecutionRuntime.mcp,
      'http' || 'https' || 'rest' => SkillExecutionRuntime.http,
      _ => SkillExecutionRuntime.unknown,
    };
  }

  static SkillExecutionMode _modeFromString(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('-', '_') ?? '';
    return switch (normalized) {
      'python_tools_class' ||
      'tools_class' ||
      'python_tools' =>
        SkillExecutionMode.pythonToolsClass,
      'python_script' || 'script' => SkillExecutionMode.pythonScript,
      'node_module' || 'module' => SkillExecutionMode.nodeModule,
      'shell_recipe' || 'shell' || 'command' => SkillExecutionMode.shellRecipe,
      'mcp_server' || 'mcp' => SkillExecutionMode.mcpServer,
      'http_endpoint' || 'http' || 'rest' => SkillExecutionMode.httpEndpoint,
      _ => SkillExecutionMode.unknown,
    };
  }

  static String _skillRootPath(_SkillDiskEntry skill) {
    final entity = skill.entity;
    if (entity is Directory) return entity.path;
    return path.dirname(entity.path);
  }

  static String _skillSource(_SkillDiskEntry skill, String entrypoint) {
    final root = _skillRootPath(skill).replaceAll('\\', '/');
    final normalizedEntry = entrypoint.replaceAll('\\', '/');
    final marker = '/.openclaw/';
    final index = root.indexOf(marker);
    if (index < 0) return normalizedEntry;
    return '${root.substring(index + marker.length)}/$normalizedEntry';
  }

  static String _safeMethodName(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'execute' : normalized;
  }

  static Future<Map<String, String>> _scanPythonPackages(
    String nativeStateRoot,
    _SkillDiskEntry skill,
  ) async {
    final roots = <Directory>[];
    final managedPythonRoot = Directory(path.join(
      nativeStateRoot,
      'runtimes',
      'python',
    ));
    if (await _validNativePythonBridge(
      File(path.join(managedPythonRoot.path, 'bridge.json')),
    )) {
      roots.add(Directory(path.join(managedPythonRoot.path, 'site-packages')));
    }
    roots.add(Directory(path.join(nativeStateRoot, 'python', 'site-packages')));
    if (skill.entity is Directory) {
      final skillDir = skill.entity as Directory;
      roots.addAll(await _findSitePackagesRoots(skillDir));
      roots
          .add(Directory(path.join(skillDir.path, '.python', 'site-packages')));
      roots.add(Directory(path.join(skillDir.path, 'site-packages')));
    }
    final packages = <String, String>{};
    for (final root in roots) {
      try {
        if (!await root.exists()) continue;
        await for (final entity in root.list(recursive: false)) {
          final name = path.basename(entity.path);
          if (name.startsWith('.') || name.isEmpty) continue;
          final lower = name.toLowerCase();
          if (entity is Directory || entity is File) {
            if (lower.endsWith('.dist-info') || lower.endsWith('.egg-info')) {
              final metadata = entity is Directory
                  ? await _readPythonPackageMetadata(entity)
                  : const <String, String>{};
              final parsed = _parsePythonDistInfoName(lower);
              final packageName =
                  metadata['name'] ?? parsed?.name ?? lower.split('-').first;
              final version = metadata['version'] ?? parsed?.version ?? '';
              packages[_normalizePythonPackageName(packageName)] = version;
            } else if (!lower.contains('.')) {
              packages.putIfAbsent(_normalizePythonPackageName(name), () => '');
            }
          }
        }
      } catch (_) {}
    }
    return packages;
  }

  static Future<bool> _pythonCompatibilityReceiptSatisfied(
    String nativeStateRoot,
    String packageName,
    String requirement,
    String installedVersion,
  ) async {
    final normalized = _normalizePythonPackageName(packageName);
    final file = File(path.join(
      nativeStateRoot,
      'dependencies',
      'receipts',
      'python-wheels',
      '$normalized.json',
    ));
    try {
      if (!await file.exists()) return false;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return false;
      final receipt = Map<String, dynamic>.from(decoded);
      return _normalizePythonPackageName(receipt['id']?.toString() ?? '') ==
              normalized &&
          receipt['version']?.toString() == installedVersion &&
          receipt['python']?.toString() == _nativePythonRuntimeVersion &&
          receipt['requestedRequirement']?.toString() == requirement &&
          receipt['compatibilityOverride'] == true &&
          receipt['smokePassed'] == true;
    } catch (error) {
      debugPrint(
        '[SkillParity] compatibility receipt read failed '
        '$packageName: $error',
      );
      return false;
    }
  }

  static Future<Map<String, String>> _readPythonPackageMetadata(
    Directory distInfo,
  ) async {
    final metadata = File(path.join(distInfo.path, 'METADATA'));
    try {
      if (!await metadata.exists()) return const <String, String>{};
      final result = <String, String>{};
      for (final line in await metadata.readAsLines()) {
        if (line.trim().isEmpty) break;
        final index = line.indexOf(':');
        if (index <= 0) continue;
        final key = line.substring(0, index).trim().toLowerCase();
        if (key != 'name' && key != 'version') continue;
        final value = line.substring(index + 1).trim();
        if (value.isNotEmpty) result.putIfAbsent(key, () => value);
      }
      return result;
    } catch (_) {
      return const <String, String>{};
    }
  }

  static _PythonInstalledPackage? _parsePythonDistInfoName(String name) {
    final cleaned = name.replaceFirst(
        RegExp(r'\.(dist|egg)-info$', caseSensitive: false), '');
    final match =
        RegExp(r'^(.+)-([0-9][A-Za-z0-9.!+_-]*)$').firstMatch(cleaned);
    if (match == null) return null;
    return _PythonInstalledPackage(
      name: _normalizePythonPackageName(match.group(1) ?? ''),
      version: match.group(2) ?? '',
    );
  }

  static Future<List<Directory>> _findSitePackagesRoots(Directory root) async {
    final results = <Directory>[];
    Future<void> visit(Directory dir, int depth) async {
      if (depth > 5) return;
      try {
        if (path.basename(dir.path) == 'site-packages') {
          results.add(dir);
          return;
        }
        await for (final entity in dir.list(recursive: false)) {
          if (entity is Directory) {
            final name = path.basename(entity.path);
            if (name == '.venv' ||
                name == 'lib' ||
                name == 'lib64' ||
                name.startsWith('python') ||
                name == '__pypackages__' ||
                RegExp(r'^\d+\.\d+$').hasMatch(name)) {
              await visit(entity, depth + 1);
            }
          }
        }
      } catch (_) {}
    }

    await visit(Directory(path.join(root.path, '.venv')), 0);
    await visit(Directory(path.join(root.path, '__pypackages__')), 0);
    return results;
  }

  static String _normalizePythonPackageName(String value) =>
      value.trim().toLowerCase().replaceAll('_', '-');

  static String? _normalizeRequiredBin(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) return null;
    normalized = normalized.split(RegExp(r'[/\\]')).last;
    normalized = normalized.replaceFirst(
      RegExp(r'\.(exe|cmd|bat|sh)$', caseSensitive: false),
      '',
    );
    normalized = normalized.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  static bool _pythonRequirementSatisfied(
    String installedVersion,
    String requirement,
  ) {
    final constraints = _pythonVersionConstraints(requirement);
    if (constraints.isEmpty) return true;
    if (installedVersion.trim().isEmpty) return false;

    for (final constraint in constraints) {
      final operator = constraint.operator;
      final required = constraint.version;
      if (operator == '==') {
        if (required.endsWith('.*')) {
          final prefix = required.substring(0, required.length - 2);
          if (!installedVersion.startsWith(prefix)) return false;
        } else if (_compareVersions(installedVersion, required) != 0) {
          return false;
        }
      } else if (operator == '!=') {
        if (_compareVersions(installedVersion, required) == 0) return false;
      } else if (operator == '>=') {
        if (_compareVersions(installedVersion, required) < 0) return false;
      } else if (operator == '>') {
        if (_compareVersions(installedVersion, required) <= 0) return false;
      } else if (operator == '<=') {
        if (_compareVersions(installedVersion, required) > 0) return false;
      } else if (operator == '<') {
        if (_compareVersions(installedVersion, required) >= 0) return false;
      } else if (operator == '~=') {
        if (_compareVersions(installedVersion, required) < 0) return false;
        final upper = _compatibleReleaseUpperBound(required);
        if (upper != null && _compareVersions(installedVersion, upper) >= 0) {
          return false;
        }
      }
    }
    return true;
  }

  static List<_PythonVersionConstraint> _pythonVersionConstraints(
    String requirement,
  ) {
    final markerIndex = requirement.indexOf(';');
    final withoutMarker =
        markerIndex >= 0 ? requirement.substring(0, markerIndex) : requirement;
    final constraints = <_PythonVersionConstraint>[];
    final pattern = RegExp(r'(===|==|~=|!=|<=|>=|<|>)\s*([A-Za-z0-9.!+_*+-]+)');
    for (final match in pattern.allMatches(withoutMarker)) {
      final operator = match.group(1);
      final version = match.group(2);
      if (operator != null && version != null && version.isNotEmpty) {
        constraints.add(_PythonVersionConstraint(operator, version));
      }
    }
    return constraints;
  }

  static String? _compatibleReleaseUpperBound(String version) {
    final parts = version
        .split('.')
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? ''))
        .toList();
    if (parts.isEmpty || parts.any((part) => part == null)) return null;
    final numbers = parts.cast<int>().toList();
    final bumpIndex = numbers.length > 2 ? numbers.length - 2 : 0;
    numbers[bumpIndex] += 1;
    for (var i = bumpIndex + 1; i < numbers.length; i++) {
      numbers[i] = 0;
    }
    return numbers.join('.');
  }

  static int _compareVersions(String left, String right) {
    final a = _versionParts(left);
    final b = _versionParts(right);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final leftPart = i < a.length ? a[i] : 0;
      final rightPart = i < b.length ? b[i] : 0;
      if (leftPart != rightPart) return leftPart.compareTo(rightPart);
    }
    return 0;
  }

  static List<int> _versionParts(String version) {
    final release = version
        .split(RegExp(r'[+!-]'))
        .first
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    return release.isEmpty ? const [0] : release;
  }

  static Set<String> _detectRequiredBins(String body) {
    if (body.trim().isEmpty) return const <String>{};
    final bins = <String>{};
    var inCommandFence = false;
    for (final line in body.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      final fence = trimmed.toLowerCase();
      if (fence.startsWith('```')) {
        if (inCommandFence) {
          inCommandFence = false;
        } else {
          final language = fence.substring(3).trim();
          inCommandFence = language.isEmpty ||
              language == 'bash' ||
              language == 'sh' ||
              language == 'shell' ||
              language == 'console' ||
              language == 'terminal' ||
              language == 'zsh';
        }
        continue;
      }
      if (!inCommandFence && !_looksLikeCommandInvocation(trimmed)) {
        continue;
      }
      final lower = trimmed.toLowerCase();
      for (final bin in _knownBins) {
        final pattern = RegExp(
          r'(^|[^a-z0-9_-])' + RegExp.escape(bin) + r'([^a-z0-9_-]|$)',
        );
        if (pattern.hasMatch(lower)) bins.add(bin);
      }
    }
    return bins;
  }

  static bool _looksLikeCommandInvocation(String line) {
    var trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) return false;
    if (trimmed.startsWith('- ')) trimmed = trimmed.substring(2).trim();
    if (trimmed.startsWith('* ')) trimmed = trimmed.substring(2).trim();
    if (trimmed.startsWith(r'$')) trimmed = trimmed.substring(1).trim();
    if (trimmed.startsWith('> ')) trimmed = trimmed.substring(2).trim();
    if (trimmed.startsWith('`') && trimmed.endsWith('`')) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    }
    if (trimmed.startsWith('sudo ')) trimmed = trimmed.substring(5).trim();
    while (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*=').hasMatch(trimmed)) {
      final index = trimmed.indexOf(' ');
      if (index < 0) return false;
      trimmed = trimmed.substring(index + 1).trim();
    }
    final match = RegExp(r'^([A-Za-z0-9_./\\-]+)(?:\s|$)').firstMatch(trimmed);
    var command = match?.group(1)?.toLowerCase();
    if (command != null) {
      command = command.split(RegExp(r'[/\\]')).last;
      command = command.replaceFirst(
          RegExp(r'\.(exe|cmd|bat|sh)$', caseSensitive: false), '');
    }
    return command != null && _knownBins.contains(command);
  }

  static Set<String> _detectRequiredEnv(String body) {
    if (body.trim().isEmpty) return const <String>{};
    final lines = body.split(RegExp(r'\r?\n'));
    final vars = <String>{};
    for (final line in lines) {
      final lower = line.toLowerCase();
      final highConfidence = lower.contains('required') ||
          lower.contains('set ') ||
          lower.contains('env') ||
          lower.contains('api key') ||
          lower.contains('token') ||
          lower.contains('secret') ||
          lower.contains('credential');
      if (!highConfidence) continue;
      for (final match in _envPattern.allMatches(line)) {
        final value = match.group(0);
        if (value != null && value.length <= 80) vars.add(value);
      }
    }
    return vars;
  }

  static Map<String, dynamic> _parseYamlFrontmatter(String body) {
    final normalized = body.replaceFirst('\uFEFF', '');
    if (!normalized.startsWith('---')) return const <String, dynamic>{};
    final match = RegExp(
      r'^---\s*\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)',
      multiLine: false,
    ).firstMatch(normalized);
    if (match == null) return const <String, dynamic>{};
    try {
      final decoded = loadYaml(match.group(1) ?? '');
      return _yamlToPlainMap(decoded);
    } catch (error) {
      debugPrint('[SkillParity] YAML frontmatter parse failed: $error');
      return const <String, dynamic>{};
    }
  }

  static _SkillRequirements _requirementsFromYaml(Map<String, dynamic> yaml) {
    final candidates = <dynamic>[
      yaml['requires'],
      yaml['requirements'],
      _mapPath(yaml, const ['openclaw', 'requires']),
      _mapPath(yaml, const ['metadata', 'openclaw', 'requires']),
      _mapPath(yaml, const ['metadata', 'requires']),
      _mapPath(yaml, const ['skill', 'requires']),
    ].where((value) => value != null).toList();

    final bins = <String>{};
    final env = <String>{};
    final runtimes = <String>{};
    final plugins = <String>{};
    final configKeys = <String>{};

    for (final candidate in candidates) {
      if (candidate is Map) {
        bins.addAll(_stringSetFromDynamic(candidate['bins']));
        bins.addAll(_stringSetFromDynamic(candidate['binaries']));
        bins.addAll(_stringSetFromDynamic(candidate['commands']));
        env.addAll(_stringSetFromDynamic(candidate['env']));
        env.addAll(_stringSetFromDynamic(candidate['environment']));
        runtimes.addAll(_stringSetFromDynamic(candidate['runtimes']));
        runtimes.addAll(_stringSetFromDynamic(candidate['runtime']));
        plugins.addAll(_stringSetFromDynamic(candidate['plugins']));
        configKeys.addAll(_stringSetFromDynamic(candidate['config']));
        configKeys.addAll(_stringSetFromDynamic(candidate['configKeys']));
      } else {
        final values = _stringSetFromDynamic(candidate);
        for (final value in values) {
          final lower = value.toLowerCase();
          if (_knownBins.contains(lower)) {
            bins.add(lower);
          } else if (_envPattern.hasMatch(value)) {
            env.add(value);
          } else if (_looksLikeExtendedRuntime(lower)) {
            runtimes.add(lower);
          }
        }
      }
    }

    return _SkillRequirements(
      bins: bins,
      env: env,
      runtimes: runtimes,
      plugins: plugins,
      configKeys: configKeys,
    );
  }

  static Map<String, dynamic> _yamlToPlainMap(dynamic value) {
    if (value is YamlMap) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _yamlToPlainValue(entry.value),
      };
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _yamlToPlainValue(entry.value),
      };
    }
    return const <String, dynamic>{};
  }

  static dynamic _yamlToPlainValue(dynamic value) {
    if (value is YamlMap || value is Map) return _yamlToPlainMap(value);
    if (value is YamlList) {
      return value.map(_yamlToPlainValue).toList(growable: false);
    }
    if (value is List) {
      return value.map(_yamlToPlainValue).toList(growable: false);
    }
    return value;
  }

  static dynamic _mapPath(Map<String, dynamic> root, List<String> keys) {
    dynamic current = root;
    for (final key in keys) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current;
  }

  static Set<String> _stringSetFromDynamic(dynamic value) {
    final result = <String>{};
    void collect(dynamic child) {
      if (child == null) return;
      if (child is String) {
        final trimmed = child.trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
      } else if (child is Iterable) {
        for (final item in child) {
          collect(item);
        }
      } else if (child is Map) {
        for (final entry in child.entries) {
          final entryValue = entry.value;
          if (entryValue == true || entryValue == null) {
            collect(entry.key);
          } else {
            collect(entryValue);
          }
        }
      } else {
        final trimmed = child.toString().trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
      }
    }

    collect(value);
    return result;
  }

  static bool _looksLikeExtendedRuntime(String value) {
    return value.contains('ubuntu') ||
        value.contains('linux') ||
        value.contains('apt') ||
        value.contains('native-addon') ||
        value.contains('node-gyp');
  }

  static Future<Map<String, dynamic>?> _readJson(File file) async {
    try {
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      debugPrint('[SkillParity] JSON read failed ${file.path}: $error');
    }
    return null;
  }

  static Map<String, String> _readConfigEnv(Map<String, dynamic>? config) {
    final env = <String, String>{};
    final vars = config?['env'] is Map ? config!['env']['vars'] : null;
    if (vars is Map) {
      for (final entry in vars.entries) {
        final key = entry.key.toString().trim();
        if (key.isNotEmpty) env[key] = entry.value?.toString() ?? '';
      }
    }
    final models = config?['models'];
    if (models is Map) {
      final providers = models['providers'];
      if (providers is Map) {
        for (final entry in providers.entries) {
          final provider = entry.key.toString().trim().toUpperCase();
          final value = entry.value;
          if (provider.isEmpty || value is! Map) continue;
          final apiKey = value['apiKey'] ?? value['api_key'];
          if (apiKey != null) env['${provider}_API_KEY'] = apiKey.toString();
        }
      }
    }
    return env;
  }

  static Future<Map<String, String>> _readDotEnv(File file) async {
    final env = <String, String>{};
    try {
      if (!await file.exists()) return env;
      for (final rawLine in await file.readAsLines()) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final idx = line.indexOf('=');
        if (idx <= 0) continue;
        env[line.substring(0, idx).trim()] = line
            .substring(idx + 1)
            .trim()
            .replaceAll(RegExp(r'''^["']|["']$'''), '');
      }
    } catch (_) {}
    return env;
  }

  static Set<String> _readDisabledSkills(Map<String, dynamic>? config) {
    final disabled = <String>{};
    if (config == null) return disabled;
    void collect(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        disabled.add(value.trim().toLowerCase());
      } else if (value is List) {
        for (final item in value) {
          collect(item);
        }
      } else if (value is Map) {
        for (final entry in value.entries) {
          final mapValue = entry.value;
          if (mapValue == false ||
              (mapValue is Map &&
                  (mapValue['enabled'] == false ||
                      mapValue['disabled'] == true))) {
            disabled.add(entry.key.toString().toLowerCase());
          }
        }
      }
    }

    final skills = config['skills'];
    if (skills is Map) {
      collect(skills['disabled']);
      collect(skills['disabledSkills']);
      collect(skills['deny']);
      collect(skills['blocked']);
      collect(skills['installed']);
      collect(skills['registry']);
    }
    collect(config['disabledSkills']);
    return disabled;
  }

  static bool _envValueLooksSet(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isNotEmpty &&
        trimmed.toLowerCase() != 'null' &&
        !trimmed.contains('YOUR_') &&
        !trimmed.contains('REPLACE_ME');
  }

  static bool _configValueLooksSet(Map<String, dynamic>? config, String key) {
    if (config == null || key.trim().isEmpty) return false;
    dynamic current = config;
    for (final part in key.split('.')) {
      if (current is! Map) return false;
      current = current[part];
      if (current == null) return false;
    }
    final value = current.toString().trim();
    return value.isNotEmpty &&
        value.toLowerCase() != 'null' &&
        !value.contains('YOUR_') &&
        !value.contains('REPLACE_ME');
  }

  static Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = path.basename(entity.path);
      if (name == _mirrorMarkerName) continue;
      final targetPath = path.join(target.path, name);
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  static Future<String> _directorySignature(Directory dir) async {
    final entries = <String>[];
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (path.basename(entity.path) == _mirrorMarkerName) continue;
        final stat = await entity.stat();
        final rel = path.relative(entity.path, from: dir.path);
        final digest = sha256.convert(await entity.readAsBytes());
        entries.add('$rel:${stat.size}:$digest');
      }
    } catch (error) {
      debugPrint('[SkillParity] signature failed ${dir.path}: $error');
    }
    entries.sort();
    return 'sha256:${sha256.convert(utf8.encode(entries.join('\n')))}';
  }

  static Future<void> _writeMirrorMarker(
    File marker, {
    required String sourcePath,
    required String sourceSignature,
  }) async {
    await marker.parent.create(recursive: true);
    await marker.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({
            'version': 1,
            'sourcePath': sourcePath,
            'sourceSignature': sourceSignature,
            'mirroredAt': DateTime.now().toIso8601String(),
          })}\n',
      flush: true,
    );
  }
}

class SkillParitySnapshot {
  final String filesDir;
  final int nativeSkillCount;
  final int prootSkillCount;
  final List<String> nativeSkillNames;
  final List<String> prootSkillNames;
  final List<String> missingInNative;
  final List<String> missingInProot;
  final int nativePluginCount;
  final int prootPluginCount;
  final List<String> nativePluginNames;
  final List<String> prootPluginNames;
  final List<String> nativeToolsAllow;
  final List<String> prootToolsAllow;
  final List<String> nativeEnvKeys;
  final List<String> prootEnvKeys;
  final List<String> nativeBins;
  final List<String> prootBins;
  final List<SkillParityGate> gates;
  final List<SkillExecutionMatrixEntry> executionMatrix;
  final SkillMirrorRepairResult repair;
  final DateTime auditedAt;

  const SkillParitySnapshot({
    required this.filesDir,
    required this.nativeSkillCount,
    required this.prootSkillCount,
    required this.nativeSkillNames,
    required this.prootSkillNames,
    required this.missingInNative,
    required this.missingInProot,
    required this.nativePluginCount,
    required this.prootPluginCount,
    required this.nativePluginNames,
    required this.prootPluginNames,
    required this.nativeToolsAllow,
    required this.prootToolsAllow,
    required this.nativeEnvKeys,
    required this.prootEnvKeys,
    required this.nativeBins,
    required this.prootBins,
    required this.gates,
    required this.executionMatrix,
    required this.repair,
    required this.auditedAt,
  });

  bool get toolsAllowParity =>
      _listSetEquals(nativeToolsAllow, prootToolsAllow);

  bool get hasHardNativeGate =>
      missingInNative.isNotEmpty ||
      gates.any((gate) =>
          gate.owner == 'native' &&
          (gate.gate == 'disabled' ||
              gate.gate == 'missing_manifest' ||
              gate.gate == 'missing_native_skill' ||
              gate.gate == 'missing_native_bin' ||
              gate.gate == 'missing_native_runtime' ||
              gate.gate == 'missing_native_python_package'));

  String get compactLogLine {
    final parts = <String>[
      '[SKILL-PARITY] native=$nativeSkillCount proot=$prootSkillCount',
      'missingNative=${missingInNative.length}',
      'missingProot=${missingInProot.length}',
      'plugins(native/proot)=$nativePluginCount/$prootPluginCount',
      'toolsAllowParity=$toolsAllowParity',
      'gates=${gates.length}',
      'descriptors=${executionMatrix.where((entry) => entry.executionDescriptor != null).length}',
      'readiness=${_readinessCountsLine(executionMatrix)}',
    ];
    if (repair.changed) {
      parts.add(
        'repair(copied=${repair.copied}, updated=${repair.updated}, conflicts=${repair.skippedConflicts})',
      );
    }
    return parts.join(' ');
  }

  String toPromptBlock({int maxNames = 20, int maxGates = 12}) {
    final missingNative = _preview(missingInNative, maxNames);
    final missingProot = _preview(missingInProot, maxNames);
    final gateLines = gates.take(maxGates).map((gate) {
      return '- ${gate.skillId}: ${gate.gate} (${gate.owner}) ${gate.detail}';
    }).join('\n');
    final readinessCountMap = readinessCounts;
    final readinessLine = readinessCountMap.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    final blockedLines = executionMatrix
        .where((entry) => entry.status != SkillExecutionStatus.ready)
        .take(maxGates)
        .map((entry) =>
            '- ${entry.skillId}: ${entry.status.wireName}${entry.primaryGate == null ? '' : ' (${entry.primaryGate})'}')
        .join('\n');
    final repairLine = repair.changed
        ? 'Repair mirrored copied=${repair.copied}, updated=${repair.updated}, conflicts=${repair.skippedConflicts}. A Gateway reload/restart may be required for newly mirrored skills.'
        : 'Repair made no file changes.';

    return '''
Skill parity audit:
- Native skill files: $nativeSkillCount; PRoot skill files: $prootSkillCount.
- Missing in Native: ${missingInNative.isEmpty ? 'none' : missingNative}.
- Missing in PRoot fallback: ${missingInProot.isEmpty ? 'none' : missingProot}.
- Plugin inventory Native/PRoot: $nativePluginCount/$prootPluginCount.
- tools.allow parity: $toolsAllowParity.
- Native gates found: ${gates.isEmpty ? 'none' : gates.length}.
- Execution descriptors: ${executionMatrix.where((entry) => entry.executionDescriptor != null).length}/${executionMatrix.length}.
- Skill readiness: ${readinessLine.isEmpty ? 'none' : readinessLine}.
$repairLine
${gateLines.isEmpty ? '' : gateLines}
${blockedLines.isEmpty ? '' : 'Readiness blocks:\n$blockedLines'}
''';
  }

  Map<String, int> get readinessCounts {
    final counts = <String, int>{};
    for (final entry in executionMatrix) {
      counts.update(entry.status.wireName, (value) => value + 1,
          ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, dynamic> toReadinessDashboard() => {
        'auditedAt': auditedAt.toIso8601String(),
        'counts': readinessCounts,
        'skills': executionMatrix.map((entry) => entry.toJson()).toList(),
        'gates': gates.map((gate) => gate.toJson()).toList(),
        'repair': repair.toJson(),
      };

  Map<String, dynamic> toJson() => {
        'filesDir': filesDir,
        'nativeSkillCount': nativeSkillCount,
        'prootSkillCount': prootSkillCount,
        'nativeSkillNames': nativeSkillNames,
        'prootSkillNames': prootSkillNames,
        'missingInNative': missingInNative,
        'missingInProot': missingInProot,
        'nativePluginCount': nativePluginCount,
        'prootPluginCount': prootPluginCount,
        'nativePluginNames': nativePluginNames,
        'prootPluginNames': prootPluginNames,
        'nativeToolsAllow': nativeToolsAllow,
        'prootToolsAllow': prootToolsAllow,
        'nativeEnvKeys': nativeEnvKeys,
        'prootEnvKeys': prootEnvKeys,
        'nativeBins': nativeBins,
        'prootBins': prootBins,
        'toolsAllowParity': toolsAllowParity,
        'gates': gates.map((gate) => gate.toJson()).toList(),
        'readinessCounts': readinessCounts,
        'executionMatrix':
            executionMatrix.map((entry) => entry.toJson()).toList(),
        'repair': repair.toJson(),
        'auditedAt': auditedAt.toIso8601String(),
      };

  static bool _listSetEquals(List<String> a, List<String> b) {
    final left = a.toSet();
    final right = b.toSet();
    return left.length == right.length && left.containsAll(right);
  }

  static String _preview(List<String> values, int max) {
    if (values.length <= max) return values.join(', ');
    return '${values.take(max).join(', ')}, ...and ${values.length - max} more';
  }

  static String _readinessCountsLine(List<SkillExecutionMatrixEntry> matrix) {
    if (matrix.isEmpty) return 'none';
    final counts = <String, int>{};
    for (final entry in matrix) {
      counts.update(entry.status.wireName, (value) => value + 1,
          ifAbsent: () => 1);
    }
    return counts.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
  }
}

enum SkillExecutionStatus {
  ready,
  needsConfig,
  missingDependency,
  disabled,
  unsupportedNative,
  manualProotRequired,
}

extension on SkillExecutionStatus {
  String get wireName {
    return switch (this) {
      SkillExecutionStatus.ready => 'ready',
      SkillExecutionStatus.needsConfig => 'needs_config',
      SkillExecutionStatus.missingDependency => 'missing_dependency',
      SkillExecutionStatus.disabled => 'disabled',
      SkillExecutionStatus.unsupportedNative => 'unsupported_native',
      SkillExecutionStatus.manualProotRequired => 'manual_proot_required',
    };
  }
}

class SkillExecutionMatrixEntry {
  final String skillId;
  final SkillExecutionStatus status;
  final String? primaryGate;
  final List<String> gates;
  final List<String> requiredBins;
  final List<String> requiredEnv;
  final List<String> requiredRuntimes;
  final List<String> requiredPythonPackages;
  final Map<String, String> requiredPythonRequirements;
  final List<String> requiredPlugins;
  final List<String> requiredConfig;
  final SkillExecutionDescriptor? executionDescriptor;

  const SkillExecutionMatrixEntry({
    required this.skillId,
    required this.status,
    required this.primaryGate,
    required this.gates,
    required this.requiredBins,
    required this.requiredEnv,
    required this.requiredRuntimes,
    required this.requiredPythonPackages,
    this.requiredPythonRequirements = const <String, String>{},
    required this.requiredPlugins,
    required this.requiredConfig,
    this.executionDescriptor,
  });

  factory SkillExecutionMatrixEntry.fromGates({
    required String skillId,
    required List<SkillParityGate> gates,
    required List<String> requiredBins,
    required List<String> requiredEnv,
    required List<String> requiredRuntimes,
    required List<String> requiredPythonPackages,
    Map<String, String> requiredPythonRequirements = const <String, String>{},
    required List<String> requiredPlugins,
    required List<String> requiredConfig,
    SkillExecutionDescriptor? executionDescriptor,
  }) {
    final gateNames = gates.map((gate) => gate.gate).toList(growable: false);
    final status = _statusForGateNames(gateNames);
    return SkillExecutionMatrixEntry(
      skillId: skillId,
      status: status,
      primaryGate: gateNames.isEmpty ? null : gateNames.first,
      gates: gateNames,
      requiredBins: requiredBins,
      requiredEnv: requiredEnv,
      requiredRuntimes: requiredRuntimes,
      requiredPythonPackages: requiredPythonPackages,
      requiredPythonRequirements:
          Map<String, String>.from(requiredPythonRequirements),
      requiredPlugins: requiredPlugins,
      requiredConfig: requiredConfig,
      executionDescriptor: executionDescriptor,
    );
  }

  static SkillExecutionStatus _statusForGateNames(List<String> gates) {
    if (gates.isEmpty) return SkillExecutionStatus.ready;
    if (gates.contains('disabled')) return SkillExecutionStatus.disabled;
    if (gates.contains('manual_proot_required')) {
      return SkillExecutionStatus.manualProotRequired;
    }
    if (gates.contains('missing_native_env') ||
        gates.contains('missing_native_config')) {
      return SkillExecutionStatus.needsConfig;
    }
    if (gates.contains('missing_native_bin') ||
        gates.contains('missing_native_runtime') ||
        gates.contains('missing_native_python_package') ||
        gates.contains('missing_native_plugin')) {
      return SkillExecutionStatus.missingDependency;
    }
    if (gates.contains('missing_manifest') ||
        gates.contains('missing_native_skill')) {
      return SkillExecutionStatus.unsupportedNative;
    }
    return SkillExecutionStatus.unsupportedNative;
  }

  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'status': status.wireName,
        if (primaryGate != null) 'primaryGate': primaryGate,
        'gates': gates,
        'requiredBins': requiredBins,
        'requiredEnv': requiredEnv,
        'requiredRuntimes': requiredRuntimes,
        'requiredPythonPackages': requiredPythonPackages,
        'requiredPythonRequirements': requiredPythonRequirements,
        'requiredPlugins': requiredPlugins,
        'requiredConfig': requiredConfig,
        if (executionDescriptor != null)
          'executionDescriptor': executionDescriptor!.toJson(),
      };
}

class _SkillRequirements {
  final Set<String> bins;
  final Set<String> env;
  final Set<String> runtimes;
  final Map<String, String> pythonRequirements;
  final Set<String> plugins;
  final Set<String> configKeys;

  const _SkillRequirements({
    this.bins = const <String>{},
    this.env = const <String>{},
    this.runtimes = const <String>{},
    this.pythonRequirements = const <String, String>{},
    this.plugins = const <String>{},
    this.configKeys = const <String>{},
  });

  Set<String> get pythonPackages => pythonRequirements.keys.toSet();

  bool get requiresExtendedRuntime =>
      runtimes.any(SkillParityAuditService._looksLikeExtendedRuntime);
}

class _PythonRequirementLine {
  final String name;
  final String raw;

  const _PythonRequirementLine({
    required this.name,
    required this.raw,
  });
}

class _ParsedPythonParameter {
  final String name;
  final bool required;

  const _ParsedPythonParameter({
    required this.name,
    required this.required,
  });
}

class _PythonInstalledPackage {
  final String name;
  final String version;

  const _PythonInstalledPackage({
    required this.name,
    required this.version,
  });
}

class _PythonVersionConstraint {
  final String operator;
  final String version;

  const _PythonVersionConstraint(this.operator, this.version);
}

class SkillParityGate {
  final String skillId;
  final String gate;
  final String owner;
  final String detail;

  const SkillParityGate({
    required this.skillId,
    required this.gate,
    required this.owner,
    required this.detail,
  });

  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'gate': gate,
        'owner': owner,
        'detail': detail,
      };
}

class SkillMirrorRepairResult {
  final int copied;
  final int updated;
  final int skippedConflicts;
  final List<String> errors;

  const SkillMirrorRepairResult({
    this.copied = 0,
    this.updated = 0,
    this.skippedConflicts = 0,
    this.errors = const <String>[],
  });

  bool get changed => copied > 0 || updated > 0;

  Map<String, dynamic> toJson() => {
        'copied': copied,
        'updated': updated,
        'skippedConflicts': skippedConflicts,
        'errors': errors,
      };
}

class _SkillParityLayout {
  final String filesDir;

  _SkillParityLayout(this.filesDir);

  String get nativeStateRoot =>
      path.join(filesDir, 'native-node-embedded', 'native-home', '.openclaw');
  String get prootStateRoot =>
      path.join(filesDir, 'rootfs', 'ubuntu', 'root', '.openclaw');

  Directory get nativeSkillsRoot =>
      Directory(path.join(nativeStateRoot, 'skills'));
  Directory get nativeWorkspaceSkillsRoot =>
      Directory(path.join(nativeStateRoot, 'workspace', 'skills'));
  Directory get prootSkillsRoot =>
      Directory(path.join(prootStateRoot, 'skills'));
  Directory get prootWorkspaceSkillsRoot =>
      Directory(path.join(prootStateRoot, 'workspace', 'skills'));

  List<Directory> get nativeSkillRoots =>
      [nativeSkillsRoot, nativeWorkspaceSkillsRoot];
  List<Directory> get prootSkillRoots =>
      [prootSkillsRoot, prootWorkspaceSkillsRoot];

  List<Directory> get nativePluginRoots => [
        nativePluginsRoot,
        nativeWorkspacePluginsRoot,
      ];
  List<Directory> get prootPluginRoots => [
        prootPluginsRoot,
        prootWorkspacePluginsRoot,
      ];

  Directory get nativePluginsRoot =>
      Directory(path.join(nativeStateRoot, 'plugins'));
  Directory get nativeWorkspacePluginsRoot =>
      Directory(path.join(nativeStateRoot, 'workspace', 'plugins'));
  Directory get prootPluginsRoot =>
      Directory(path.join(prootStateRoot, 'plugins'));
  Directory get prootWorkspacePluginsRoot =>
      Directory(path.join(prootStateRoot, 'workspace', 'plugins'));

  List<Directory> get nativeBinRoots => [
        Directory(path.join(
            filesDir, 'native-node-embedded', 'full-openclaw', 'bin')),
        Directory(path.join(
          filesDir,
          'native-node-embedded',
          'full-openclaw',
          'lib',
          'node_modules',
          '.bin',
        )),
        Directory(path.join(nativeStateRoot, 'bin')),
        Directory(path.join(nativeStateRoot, 'runtimes', 'python', 'bin')),
        Directory('/system/bin'),
        Directory('/system/xbin'),
      ];
  List<Directory> get prootBinRoots => [
        Directory(path.join(filesDir, 'rootfs', 'ubuntu', 'usr', 'bin')),
        Directory(
            path.join(filesDir, 'rootfs', 'ubuntu', 'usr', 'local', 'bin')),
        Directory(path.join(prootStateRoot, 'bin')),
      ];

  File get nativeConfigFile =>
      File(path.join(nativeStateRoot, 'openclaw.json'));
  File get prootConfigFile => File(path.join(prootStateRoot, 'openclaw.json'));
  File get nativeEnvFile => File(path.join(nativeStateRoot, '.env'));
  File get prootEnvFile => File(path.join(prootStateRoot, '.env'));
}

class _SkillDiskEntry {
  final String id;
  final FileSystemEntity entity;
  final bool hasSkillDocument;
  final bool hasSkillYaml;
  final bool hasPackageJson;

  const _SkillDiskEntry({
    required this.id,
    required this.entity,
    required this.hasSkillDocument,
    required this.hasSkillYaml,
    required this.hasPackageJson,
  });

  factory _SkillDiskEntry.file(String id, File file) => _SkillDiskEntry(
        id: id,
        entity: file,
        hasSkillDocument: file.path.toLowerCase().endsWith('.md'),
        hasSkillYaml: file.path.toLowerCase().endsWith('.yaml'),
        hasPackageJson: false,
      );

  static Future<_SkillDiskEntry> fromDirectory(String id, Directory dir) async {
    final files = <String>[];
    try {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) files.add(path.basename(entity.path).toLowerCase());
      }
    } catch (_) {}
    return _SkillDiskEntry(
      id: id,
      entity: dir,
      hasSkillDocument:
          files.contains('skill.md') || files.contains('skills.md'),
      hasSkillYaml: files.contains('skill.yaml') || files.contains('skill.yml'),
      hasPackageJson: files.contains('package.json'),
    );
  }

  bool get hasAnyManifest => hasSkillDocument || hasSkillYaml || hasPackageJson;

  List<File> get documentCandidates {
    if (entity is File) return [entity as File];
    final dir = entity as Directory;
    return [
      File(path.join(dir.path, 'SKILL.md')),
      File(path.join(dir.path, 'skill.md')),
      File(path.join(dir.path, 'skills.md')),
      File(path.join(dir.path, 'SKILL.yaml')),
      File(path.join(dir.path, 'skill.yaml')),
      File(path.join(dir.path, 'package.json')),
    ];
  }
}
