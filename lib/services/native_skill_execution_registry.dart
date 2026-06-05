import 'dart:convert';
import 'dart:io';

import 'adapters/http_endpoint_adapter.dart';
import 'adapters/node_module_adapter.dart';
import 'adapters/python_tools_class_adapter.dart';
import 'native_skill_adapter.dart';
import 'skill_execution_descriptor.dart';

class NativeSkillExecutionRegistry {
  final NativePythonRunner pythonRunner;
  final NativeNodeRunner? nodeRunner;
  final Future<String> Function() filesDirProvider;

  const NativeSkillExecutionRegistry({
    required this.pythonRunner,
    this.nodeRunner,
    required this.filesDirProvider,
  });

  Future<SkillExecutionDescriptor?> descriptorForSkill(String skillId) async {
    final normalized = skillId.trim().toLowerCase();
    switch (normalized) {
      case 'stocks':
        return _stocksDescriptor();
      default:
        final pythonDescriptor = await _pythonToolsClassDescriptor(normalized);
        if (pythonDescriptor != null) return pythonDescriptor;
        final nodeDescriptor = await _nodeModuleDescriptor(normalized);
        if (nodeDescriptor != null) return nodeDescriptor;
        return _httpEndpointDescriptor(normalized);
    }
  }

  Future<NativeSkillAdapterResult> execute({
    required SkillExecutionDescriptor descriptor,
    required List<SkillExecutionAction> actions,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final filesDir = await filesDirProvider();
    final pythonHome = _nativePythonHome(filesDir);
    final adapter = PythonToolsClassAdapter(
      pythonRunner: pythonRunner,
      pythonHome: pythonHome,
      sitePackages: '$pythonHome/site-packages',
    );
    final httpAdapter = const HttpEndpointAdapter();
    final nodeAdapter = NodeModuleAdapter(nodeRunner: nodeRunner);

    final selectedAdapter = adapter.canExecute(descriptor)
        ? adapter
        : httpAdapter.canExecute(descriptor)
            ? httpAdapter
            : nodeAdapter.canExecute(descriptor)
                ? nodeAdapter
                : null;

    if (selectedAdapter == null) {
      return NativeSkillAdapterResult(
        ok: false,
        raw: const <String, dynamic>{},
        durationMs: 0,
        error:
            'No Native adapter for ${descriptor.runtime.name}/${descriptor.mode.name}.',
      );
    }

    return selectedAdapter.execute(
      NativeSkillExecutionRequest(
        descriptor: descriptor,
        actions: actions,
        timeout: timeout,
      ),
    );
  }

  Future<SkillExecutionDescriptor?> _stocksDescriptor() async {
    final filesDir = await filesDirProvider();
    final rootPath = _skillRoot(filesDir, 'stocks');
    final entrypoint = 'scripts/yfinance_ai.py';
    final script = File('$rootPath/$entrypoint');
    if (!await script.exists()) return null;

    return SkillExecutionDescriptor(
      skillId: 'stocks',
      rootPath: rootPath,
      source: 'workspace/skills/stocks/$entrypoint',
      runtime: SkillExecutionRuntime.python,
      mode: SkillExecutionMode.pythonToolsClass,
      entrypoint: entrypoint,
      className: 'Tools',
      dependencies: const SkillDependencyDescriptor(
        runtimes: ['python'],
        bins: ['python3', 'pip'],
        pythonPackages: ['yfinance', 'pandas', 'pydantic', 'requests'],
      ),
      methods: const [
        SkillExecutionMethodDescriptor(
          name: 'get_stock_price',
          description: 'Fetch a stock quote by ticker.',
          parameters: {'ticker': 'Stock ticker symbol'},
          requiredParameters: ['ticker'],
        ),
        SkillExecutionMethodDescriptor(
          name: 'get_crypto_price',
          description: 'Fetch a crypto quote by symbol.',
          parameters: {'symbol': 'Cryptocurrency symbol'},
          requiredParameters: ['symbol'],
        ),
        SkillExecutionMethodDescriptor(
          name: 'get_market_status',
          description: 'Fetch current market status.',
        ),
      ],
    );
  }

  Future<SkillExecutionDescriptor?> _pythonToolsClassDescriptor(
    String skillId,
  ) async {
    final filesDir = await filesDirProvider();
    final rootPath = await _resolveSkillRoot(filesDir, skillId);
    if (rootPath == null) return null;

    final entrypoint = await _findPythonToolsEntrypoint(rootPath);
    if (entrypoint == null) return null;

    final script = File('$rootPath/$entrypoint');
    final body = await script.readAsString();
    final pythonRequirements = await _readPythonRequirements(rootPath);
    final methods = _parseToolsMethods(body);

    return SkillExecutionDescriptor(
      skillId: skillId,
      rootPath: rootPath,
      source: _sourceForSkillRoot(rootPath, entrypoint),
      runtime: SkillExecutionRuntime.python,
      mode: SkillExecutionMode.pythonToolsClass,
      entrypoint: entrypoint,
      className: 'Tools',
      dependencies: SkillDependencyDescriptor(
        runtimes: const ['python'],
        bins: const ['python3', 'pip'],
        pythonPackages: pythonRequirements.keys.toList()..sort(),
      ),
      methods: methods,
    );
  }

  Future<SkillExecutionDescriptor?> _httpEndpointDescriptor(
    String skillId,
  ) async {
    final filesDir = await filesDirProvider();
    final rootPath = await _resolveSkillRoot(filesDir, skillId);
    if (rootPath == null) return null;
    final body = await _readSkillDocument(rootPath);
    if (body.trim().isEmpty) return null;
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
    return SkillExecutionDescriptor(
      skillId: skillId,
      rootPath: rootPath,
      source: _sourceForSkillRoot(rootPath, _skillDocumentName(rootPath)),
      runtime: SkillExecutionRuntime.http,
      mode: SkillExecutionMode.httpEndpoint,
      entrypoint: url,
      methods: [
        SkillExecutionMethodDescriptor(
          name: _safeMethodName('${httpMethod}_$skillId'),
          description: '$httpMethod $url',
          parameters: {
            ..._queryParameterDescriptors(url),
            ..._jsonBodyParameterDescriptors(commandWindow),
          },
        ),
      ],
    );
  }

  Future<SkillExecutionDescriptor?> _nodeModuleDescriptor(
    String skillId,
  ) async {
    final filesDir = await filesDirProvider();
    final rootPath = await _resolveSkillRoot(filesDir, skillId);
    if (rootPath == null) return null;
    final packageJsonFile = File('$rootPath/package.json');
    if (!await packageJsonFile.exists()) return null;
    final packageJson = await _readJsonFile(packageJsonFile);
    final entrypoint = await _resolveNodeEntrypoint(rootPath, packageJson);
    if (entrypoint == null) return null;
    return SkillExecutionDescriptor(
      skillId: skillId,
      rootPath: rootPath,
      source: _sourceForSkillRoot(rootPath, entrypoint),
      runtime: SkillExecutionRuntime.node,
      mode: SkillExecutionMode.nodeModule,
      entrypoint: entrypoint,
      dependencies: SkillDependencyDescriptor(
        runtimes: const ['node'],
        bins: const ['node'],
        nodePackages: _nodeDependencyNames(packageJson),
      ),
      methods: _nodeMethods(packageJson),
    );
  }

  static String _skillRoot(String filesDir, String skillId) {
    return '$filesDir/native-node-embedded/native-home/.openclaw/workspace/skills/$skillId';
  }

  static Future<String?> _resolveSkillRoot(
    String filesDir,
    String skillId,
  ) async {
    final candidates = [
      '$filesDir/native-node-embedded/native-home/.openclaw/workspace/skills/$skillId',
      '$filesDir/native-node-embedded/native-home/.openclaw/skills/$skillId',
    ];
    for (final candidate in candidates) {
      if (await Directory(candidate).exists()) return candidate;
    }
    return null;
  }

  static String _nativePythonHome(String filesDir) {
    return '$filesDir/native-node-embedded/native-home/.openclaw/runtimes/python';
  }

  static Future<String?> _findPythonToolsEntrypoint(String rootPath) async {
    final candidates = <String>[];
    final preferred = [
      'main.py',
      'skill.py',
      'tools.py',
      'scripts/main.py',
      'scripts/skill.py',
      'scripts/tools.py',
    ];
    for (final relative in preferred) {
      if (await File('$rootPath/$relative').exists()) {
        candidates.add(relative);
      }
    }
    final scripts = Directory('$rootPath/scripts');
    if (await scripts.exists()) {
      await for (final entity in scripts.list(recursive: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.py')) {
          final relative = 'scripts/${_basename(entity.path)}';
          if (!candidates.contains(relative)) candidates.add(relative);
        }
      }
    }
    final root = Directory(rootPath);
    await for (final entity in root.list(recursive: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.py')) {
        final relative = _basename(entity.path);
        if (!candidates.contains(relative)) candidates.add(relative);
      }
    }

    for (final relative in candidates) {
      final body = await File('$rootPath/$relative').readAsString();
      if (RegExp(r'class\s+Tools\b').hasMatch(body)) return relative;
    }
    return null;
  }

  static Future<Map<String, String>> _readPythonRequirements(
    String rootPath,
  ) async {
    final files = [
      File('$rootPath/requirements.txt'),
      File('$rootPath/scripts/requirements.txt'),
    ];
    final requirements = <String, String>{};
    for (final file in files) {
      if (!await file.exists()) continue;
      for (final line in await file.readAsLines()) {
        final parsed = _parsePythonRequirement(line);
        if (parsed == null) continue;
        requirements[parsed.name] = parsed.raw;
      }
    }
    return requirements;
  }

  static Future<String> _readSkillDocument(String rootPath) async {
    for (final name in const [
      'SKILL.md',
      'skill.md',
      'skills.md',
      'SKILL.yaml',
      'skill.yaml',
      'package.json',
    ]) {
      final file = File('$rootPath/$name');
      if (await file.exists()) return file.readAsString();
    }
    return '';
  }

  static Future<Map<String, dynamic>> _readJsonFile(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const <String, dynamic>{};
  }

  static Future<String?> _resolveNodeEntrypoint(
    String rootPath,
    Map<String, dynamic> packageJson,
  ) async {
    final candidates = <String>[];
    final main = packageJson['main']?.toString().trim();
    if (main != null && main.isNotEmpty) candidates.add(main);
    for (final fallback in const [
      'index.js',
      'main.js',
      'skill.js',
      'tools.js',
      'src/index.js',
      'dist/index.js',
    ]) {
      if (!candidates.contains(fallback)) candidates.add(fallback);
    }
    for (final candidate in candidates) {
      final normalized = candidate.replaceAll('\\', '/');
      if (normalized.contains('..')) continue;
      if (await File('$rootPath/$normalized').exists()) return normalized;
    }
    return null;
  }

  static List<String> _nodeDependencyNames(Map<String, dynamic> packageJson) {
    final names = <String>{};
    for (final key in const ['dependencies', 'optionalDependencies']) {
      final section = packageJson[key];
      if (section is! Map) continue;
      for (final name in section.keys) {
        final normalized = _normalizeNodePackageName(name.toString());
        if (normalized.isNotEmpty) names.add(normalized);
      }
    }
    return names.toList()..sort();
  }

  static List<SkillExecutionMethodDescriptor> _nodeMethods(
    Map<String, dynamic> packageJson,
  ) {
    final methods = _openClawMap(packageJson)['methods'];
    if (methods is List) {
      final parsed = methods
          .whereType<Map>()
          .map((method) => SkillExecutionMethodDescriptor(
                name: method['name']?.toString() ?? '',
                description: method['description']?.toString() ?? '',
                parameters: _stringMap(method['parameters']),
                requiredParameters: _stringList(method['requiredParameters']),
              ))
          .where((method) => method.name.trim().isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }
    return const [
      SkillExecutionMethodDescriptor(
        name: 'execute',
        description: 'Execute the Node skill module.',
      ),
    ];
  }

  static Map<String, dynamic> _openClawMap(Map<String, dynamic> packageJson) {
    final direct = packageJson['openclaw'];
    if (direct is Map) return Map<String, dynamic>.from(direct);
    final nested = packageJson['metadata'];
    if (nested is Map && nested['openclaw'] is Map) {
      return Map<String, dynamic>.from(nested['openclaw'] as Map);
    }
    return const <String, dynamic>{};
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const <String, String>{};
    return {
      for (final entry in value.entries)
        entry.key.toString(): entry.value?.toString() ?? 'value',
    };
  }

  static List<String> _stringList(dynamic value) {
    if (value is String) return [value];
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  static String _normalizeNodePackageName(String value) {
    return value.trim().toLowerCase();
  }

  static String _skillDocumentName(String rootPath) {
    for (final name in const [
      'SKILL.md',
      'skill.md',
      'skills.md',
      'SKILL.yaml',
      'skill.yaml',
      'package.json',
    ]) {
      if (File('$rootPath/$name').existsSync()) return name;
    }
    return '';
  }

  static _ParsedPythonRequirement? _parsePythonRequirement(String raw) {
    var line = raw.trim();
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
    final name = match?.group(1)?.trim().toLowerCase().replaceAll('_', '-');
    if (name == null || name.isEmpty) return null;
    return _ParsedPythonRequirement(name: name, raw: line);
  }

  static List<SkillExecutionMethodDescriptor> _parseToolsMethods(String body) {
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

  static String _sourceForSkillRoot(String rootPath, String entrypoint) {
    final normalized = rootPath.replaceAll('\\', '/');
    final marker = '/.openclaw/';
    final index = normalized.indexOf(marker);
    if (index < 0) return entrypoint;
    return '${normalized.substring(index + marker.length)}/$entrypoint';
  }

  static String _basename(String value) {
    final normalized = value.replaceAll('\\', '/');
    return normalized.split('/').last;
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

  static String _safeMethodName(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'execute' : normalized;
  }
}

class _ParsedPythonRequirement {
  final String name;
  final String raw;

  const _ParsedPythonRequirement({
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
