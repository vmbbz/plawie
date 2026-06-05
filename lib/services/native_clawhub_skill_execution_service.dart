import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'native_bridge.dart';
import 'openclaw_service.dart';

typedef NativePythonRunner = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);

class NativeClawHubSkillExecution {
  final String toolName;
  final Map<String, dynamic> input;
  final Map<String, dynamic> result;
  final bool ok;
  final String visibleText;

  const NativeClawHubSkillExecution({
    required this.toolName,
    required this.input,
    required this.result,
    required this.ok,
    required this.visibleText,
  });

  String get toolUseChunk => '\x00TOOL_USE:$toolName:${jsonEncode(input)}\x00';

  String get toolResultChunk =>
      '\x00TOOL_RESULT:$toolName:${jsonEncode(result)}\x00';
}

class NativeSkillAction {
  final String label;
  final String method;
  final Map<String, String> args;

  const NativeSkillAction({
    required this.label,
    required this.method,
    required this.args,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'method': method,
        'args': args,
      };
}

class NativeStocksIntent {
  final List<NativeSkillAction> actions;

  const NativeStocksIntent(this.actions);

  Map<String, dynamic> toJson() => {
        'skill': 'stocks',
        'actions': actions.map((action) => action.toJson()).toList(),
      };
}

class NativeClawHubSkillExecutionService {
  static final NativeClawHubSkillExecutionService instance =
      NativeClawHubSkillExecutionService._internal();

  final NativePythonRunner _pythonRunner;
  final Future<String> Function() _filesDirProvider;
  final Future<bool> Function() _nativeOwnerProvider;

  NativeClawHubSkillExecutionService._internal()
      : _pythonRunner = NativeBridge.runNativePython,
        _filesDirProvider = NativeBridge.getFilesDir,
        _nativeOwnerProvider = OpenClawCommandService.isNativeOwnerSelected;

  @visibleForTesting
  NativeClawHubSkillExecutionService.test({
    required NativePythonRunner pythonRunner,
    required Future<String> Function() filesDirProvider,
    Future<bool> Function()? nativeOwnerProvider,
  })  : _pythonRunner = pythonRunner,
        _filesDirProvider = filesDirProvider,
        _nativeOwnerProvider =
            nativeOwnerProvider ?? (() async => true);

  Future<NativeClawHubSkillExecution?> tryExecuteRequiredIntent(
    String message,
  ) async {
    final intent = parseStocksIntent(message);
    if (intent == null) return null;

    final nativeOwner = await _nativeOwnerProvider();
    if (!nativeOwner) {
      return _failure(
        input: intent.toJson(),
        code: 'native_owner_not_selected',
        message:
            'The stocks skill is installed for the Native owner. PRoot is manual only and was not used.',
      );
    }

    return executeStocks(intent);
  }

  Future<NativeClawHubSkillExecution> executeStocks(
    NativeStocksIntent intent,
  ) async {
    final filesDir = await _filesDirProvider();
    final skillDir = Directory(
      '$filesDir/native-node-embedded/native-home/.openclaw/workspace/skills/stocks',
    );
    final script = File('${skillDir.path}/scripts/yfinance_ai.py');
    final sitePackages =
        '$filesDir/native-node-embedded/native-home/.openclaw/runtimes/python/site-packages';
    final pythonHome =
        '$filesDir/native-node-embedded/native-home/.openclaw/runtimes/python';
    final input = {
      ...intent.toJson(),
      'runtime': 'native-clawhub-python',
      'source': 'workspace/skills/stocks/scripts/yfinance_ai.py',
    };

    if (!await script.exists()) {
      return _failure(
        input: input,
        code: 'skill_script_missing',
        message: 'stocks/scripts/yfinance_ai.py was not found in Native workspace.',
      );
    }

    final payload = <String, dynamic>{
      'cwd': skillDir.path,
      'args': ['-c', _stocksPythonProgram(intent)],
      'pythonPaths': [sitePackages, '${skillDir.path}/scripts'],
      'env': {
        'OPENCLAW_NATIVE_PYTHON_HOME': pythonHome,
        'OPENCLAW_NATIVE_PYTHON_SITE_PACKAGES': sitePackages,
      },
    };
    final startedAt = DateTime.now();
    final raw = await _pythonRunner(payload).timeout(
      const Duration(seconds: 90),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'exitCode': 124,
        'stdout': '',
        'stderr': 'Native stocks skill timed out after 90 seconds.',
      },
    );
    final completedAt = DateTime.now();
    final ok = raw['ok'] == true || raw['exitCode'] == 0;
    final decoded = _decodeJsonFromStdout(raw['stdout']);
    final result = <String, dynamic>{
      'ok': ok && decoded != null,
      'skill': 'stocks',
      'runtime': 'native-clawhub-python',
      'source': 'workspace/skills/stocks/scripts/yfinance_ai.py',
      'durationMs': completedAt.difference(startedAt).inMilliseconds,
      'actions': intent.actions.map((action) => action.toJson()).toList(),
      if (decoded != null) 'data': decoded,
      if (raw['exitCode'] != null) 'exitCode': raw['exitCode'],
      if ((raw['stderr']?.toString().trim() ?? '').isNotEmpty)
        'stderr': _trimForDiagnostics(raw['stderr'].toString()),
      if (!ok || decoded == null)
        'error': _nativePythonError(raw, decodedMissing: decoded == null),
    };

    if (result['ok'] == true) {
      return NativeClawHubSkillExecution(
        toolName: 'stocks',
        input: input,
        result: result,
        ok: true,
        visibleText: _formatStocksVisibleText(decoded!),
      );
    }

    return NativeClawHubSkillExecution(
      toolName: 'stocks',
      input: input,
      result: result,
      ok: false,
      visibleText:
          'The stocks skill ran but failed: ${result['error'] ?? 'unknown error'}',
    );
  }

  @visibleForTesting
  static NativeStocksIntent? parseStocksIntent(String message) {
    final lower = message.toLowerCase();
    final isFinanceIntent = RegExp(
      r'\b(stock|stocks|ticker|quote|market|finance|financial|crypto|bitcoin|btc|ethereum|eth|price|prices|nvda|nvidia)\b',
    ).hasMatch(lower);
    if (!isFinanceIntent) return null;

    final actions = <NativeSkillAction>[];
    final seen = <String>{};
    void addStock(String ticker) {
      final normalized = ticker.trim().toUpperCase();
      if (normalized.isEmpty || !seen.add('stock:$normalized')) return;
      actions.add(NativeSkillAction(
        label: normalized,
        method: 'get_stock_price',
        args: {'ticker': normalized},
      ));
    }

    void addCrypto(String symbol) {
      final normalized = symbol.trim().toUpperCase();
      if (normalized.isEmpty || !seen.add('crypto:$normalized')) return;
      actions.add(NativeSkillAction(
        label: normalized,
        method: 'get_crypto_price',
        args: {'symbol': normalized},
      ));
    }

    final nameMap = <String, void Function()>{
      'nvidia': () => addStock('NVDA'),
      'bitcoin': () => addCrypto('BTC'),
      'ethereum': () => addCrypto('ETH'),
    };
    for (final entry in nameMap.entries) {
      if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(lower)) {
        entry.value();
      }
    }
    for (final match in RegExp(r'\b[A-Z]{2,6}(?:[-=][A-Z]{2,5})?\b')
        .allMatches(message)) {
      final token = match.group(0)!.toUpperCase();
      if (_ignoredUppercaseTokens.contains(token)) continue;
      if (_cryptoSymbols.contains(token)) {
        addCrypto(token);
      } else {
        addStock(token);
      }
    }

    if (actions.isEmpty && lower.contains('market')) {
      actions.add(const NativeSkillAction(
        label: 'market status',
        method: 'get_market_status',
        args: {},
      ));
    }

    return actions.isEmpty ? null : NativeStocksIntent(actions);
  }

  static const Set<String> _cryptoSymbols = {
    'BTC',
    'ETH',
    'DOGE',
    'SOL',
    'ADA',
    'XRP',
    'DOT',
    'AVAX',
    'LINK',
    'LTC',
    'SHIB',
    'MATIC',
    'UNI',
  };

  static const Set<String> _ignoredUppercaseTokens = {
    'AI',
    'API',
    'USD',
    'US',
    'USA',
    'ETF',
    'CEO',
    'CFO',
    'SEC',
    'PE',
    'P',
    'Q',
  };

  static String _stocksPythonProgram(NativeStocksIntent intent) {
    final actionsJson = jsonEncode(
      intent.actions.map((action) => action.toJson()).toList(),
    );
    return '''
import asyncio, json, os, sys
sys.path.insert(0, os.path.join(os.getcwd(), "scripts"))
from yfinance_ai import Tools

actions = json.loads(${jsonEncode(actionsJson)})

async def main():
    tools = Tools()
    output = {}
    for action in actions:
        method_name = action["method"]
        args = action.get("args") or {}
        method = getattr(tools, method_name)
        output[action["label"]] = await method(**args)
    print(json.dumps(output, ensure_ascii=False))

asyncio.run(main())
''';
  }

  static Map<String, dynamic>? _decodeJsonFromStdout(dynamic stdoutValue) {
    final stdout = stdoutValue?.toString().trim() ?? '';
    if (stdout.isEmpty) return null;
    for (final line in stdout.split('\n').reversed) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static String _formatStocksVisibleText(Map<String, dynamic> data) {
    final buffer = StringBuffer('Stocks skill result:\n\n');
    var first = true;
    for (final entry in data.entries) {
      if (!first) buffer.writeln();
      first = false;
      buffer.writeln('${entry.key}:');
      buffer.writeln(entry.value?.toString().trim() ?? 'No result returned.');
    }
    return buffer.toString().trimRight();
  }

  static String _nativePythonError(
    Map<String, dynamic> raw, {
    required bool decodedMissing,
  }) {
    final stderr = raw['stderr']?.toString().trim() ?? '';
    final stdout = raw['stdout']?.toString().trim() ?? '';
    if (stderr.isNotEmpty) return _trimForDiagnostics(stderr, maxChars: 1200);
    if (stdout.isNotEmpty && decodedMissing) {
      return 'Skill returned non-JSON output: ${_trimForDiagnostics(stdout)}';
    }
    return 'Native Python exited with code ${raw['exitCode'] ?? 'unknown'}.';
  }

  static String _trimForDiagnostics(String value, {int maxChars = 1600}) {
    final compact = value.trim();
    if (compact.length <= maxChars) return compact;
    return '${compact.substring(0, maxChars)}...';
  }

  static NativeClawHubSkillExecution _failure({
    required Map<String, dynamic> input,
    required String code,
    required String message,
  }) {
    return NativeClawHubSkillExecution(
      toolName: 'stocks',
      input: input,
      result: {
        'ok': false,
        'skill': 'stocks',
        'runtime': 'native-clawhub-python',
        'errorCode': code,
        'error': message,
      },
      ok: false,
      visibleText: 'The stocks skill could not run: $message',
    );
  }
}
