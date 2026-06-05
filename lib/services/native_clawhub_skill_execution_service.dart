import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'native_bridge.dart';
import 'native_node_skill_runner.dart';
import 'native_skill_adapter.dart';
import 'native_skill_execution_registry.dart';
import 'openclaw_service.dart';
import 'skill_execution_descriptor.dart';

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

class NativeStocksIntent {
  final List<SkillExecutionAction> actions;

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
  final NativeNodeRunner? _nodeRunner;
  final Future<String> Function() _filesDirProvider;
  final Future<bool> Function() _nativeOwnerProvider;

  NativeClawHubSkillExecutionService._internal()
      : _pythonRunner = NativeBridge.runNativePython,
        _nodeRunner = NativeNodeSkillRunner.instance.run,
        _filesDirProvider = NativeBridge.getFilesDir,
        _nativeOwnerProvider = OpenClawCommandService.isNativeOwnerSelected;

  @visibleForTesting
  NativeClawHubSkillExecutionService.test({
    required NativePythonRunner pythonRunner,
    NativeNodeRunner? nodeRunner,
    required Future<String> Function() filesDirProvider,
    Future<bool> Function()? nativeOwnerProvider,
  })  : _pythonRunner = pythonRunner,
        _nodeRunner = nodeRunner,
        _filesDirProvider = filesDirProvider,
        _nativeOwnerProvider = nativeOwnerProvider ?? (() async => true);

  Future<NativeClawHubSkillExecution?> tryExecuteRequiredIntent(
    String message,
  ) async {
    final intent = parseStocksIntent(message);
    if (intent == null) return null;

    final nativeOwner = await _nativeOwnerProvider();
    if (!nativeOwner) {
      return _failure(
        toolName: 'stocks',
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
    return executeSkillActions(
      skillId: 'stocks',
      actions: intent.actions,
      input: intent.toJson(),
      sourceFallback: 'workspace/skills/stocks/scripts/yfinance_ai.py',
      visibleFormatter: _formatStocksVisibleText,
    );
  }

  Future<NativeClawHubSkillExecution> executeDirectSkillMethod({
    required String skillId,
    required String method,
    Map<String, dynamic> params = const <String, dynamic>{},
  }) async {
    final nativeOwner = await _nativeOwnerProvider();
    final input = <String, dynamic>{
      'skill': skillId,
      'method': method,
      'params': params,
      'direct': true,
    };
    if (!nativeOwner) {
      return _failure(
        toolName: skillId,
        input: input,
        code: 'native_owner_not_selected',
        message:
            'Native skill execution requires the Native owner. PRoot is manual only and was not used.',
      );
    }
    return executeSkillActions(
      skillId: skillId,
      actions: [
        SkillExecutionAction(
          label: method,
          method: method,
          args: params,
        ),
      ],
      input: input,
      sourceFallback: skillId,
    );
  }

  Future<NativeClawHubSkillExecution> executeSkillActions({
    required String skillId,
    required List<SkillExecutionAction> actions,
    Map<String, dynamic>? input,
    String? sourceFallback,
    String Function(Map<String, dynamic> data)? visibleFormatter,
  }) async {
    final registry = NativeSkillExecutionRegistry(
      pythonRunner: _pythonRunner,
      nodeRunner: _nodeRunner,
      filesDirProvider: _filesDirProvider,
    );
    final descriptor = await registry.descriptorForSkill(skillId);
    final toolInput = <String, dynamic>{
      'skill': skillId,
      'actions': actions.map((action) => action.toJson()).toList(),
      ...?input,
      'runtime': descriptor == null
          ? 'native-clawhub'
          : 'native-clawhub-${descriptor.runtime.name}',
      if (descriptor != null) 'descriptor': descriptor.toJson(),
      'source': descriptor?.source ?? sourceFallback ?? skillId,
    };

    if (descriptor == null) {
      return _failure(
        toolName: skillId,
        input: toolInput,
        code: 'skill_script_missing',
        message: 'No Native execution descriptor was found for $skillId.',
      );
    }

    final adapterResult = await registry.execute(
      descriptor: descriptor,
      actions: actions,
    );
    final raw = adapterResult.raw;
    final decoded = adapterResult.data;
    final result = <String, dynamic>{
      'ok': adapterResult.ok,
      'skill': skillId,
      'runtime': 'native-clawhub-${descriptor.runtime.name}',
      'source': descriptor.source,
      'descriptor': descriptor.toJson(),
      'durationMs': adapterResult.durationMs,
      'actions': actions.map((action) => action.toJson()).toList(),
      if (decoded != null) 'data': decoded,
      if (raw['exitCode'] != null) 'exitCode': raw['exitCode'],
      if (raw['responses'] != null) 'responses': raw['responses'],
      if ((raw['stderr']?.toString().trim() ?? '').isNotEmpty)
        'stderr': _trimForDiagnostics(raw['stderr'].toString()),
      if (!adapterResult.ok) 'error': adapterResult.error ?? 'unknown error',
    };

    if (result['ok'] == true) {
      return NativeClawHubSkillExecution(
        toolName: skillId,
        input: toolInput,
        result: result,
        ok: true,
        visibleText: (visibleFormatter ?? _formatGenericVisibleText)(decoded!),
      );
    }

    return NativeClawHubSkillExecution(
      toolName: skillId,
      input: toolInput,
      result: result,
      ok: false,
      visibleText:
          'The $skillId skill ran but failed: ${result['error'] ?? 'unknown error'}',
    );
  }

  @visibleForTesting
  static NativeStocksIntent? parseStocksIntent(String message) {
    final lower = message.toLowerCase();
    final isFinanceIntent = RegExp(
      r'\b(stock|stocks|ticker|quote|market|finance|financial|crypto|bitcoin|btc|ethereum|eth|price|prices|nvda|nvidia)\b',
    ).hasMatch(lower);
    if (!isFinanceIntent) return null;

    final actions = <SkillExecutionAction>[];
    final seen = <String>{};
    void addStock(String ticker) {
      final normalized = ticker.trim().toUpperCase();
      if (normalized.isEmpty || !seen.add('stock:$normalized')) return;
      actions.add(SkillExecutionAction(
        label: normalized,
        method: 'get_stock_price',
        args: {'ticker': normalized},
      ));
    }

    void addCrypto(String symbol) {
      final normalized = symbol.trim().toUpperCase();
      if (normalized.isEmpty || !seen.add('crypto:$normalized')) return;
      actions.add(SkillExecutionAction(
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
    for (final match
        in RegExp(r'\b[A-Z]{2,6}(?:[-=][A-Z]{2,5})?\b').allMatches(message)) {
      final token = match.group(0)!.toUpperCase();
      if (_ignoredUppercaseTokens.contains(token)) continue;
      if (_cryptoSymbols.contains(token)) {
        addCrypto(token);
      } else {
        addStock(token);
      }
    }

    if (actions.isEmpty && lower.contains('market')) {
      actions.add(const SkillExecutionAction(
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

  static String _formatGenericVisibleText(Map<String, dynamic> data) {
    final buffer = StringBuffer('Skill result:\n\n');
    var first = true;
    for (final entry in data.entries) {
      if (!first) buffer.writeln();
      first = false;
      buffer.writeln('${entry.key}:');
      final value = entry.value;
      if (value is Map || value is List) {
        buffer.writeln(const JsonEncoder.withIndent('  ').convert(value));
      } else {
        buffer.writeln(value?.toString().trim() ?? 'No result returned.');
      }
    }
    return buffer.toString().trimRight();
  }

  static String _trimForDiagnostics(String value, {int maxChars = 1600}) {
    final compact = value.trim();
    if (compact.length <= maxChars) return compact;
    return '${compact.substring(0, maxChars)}...';
  }

  static NativeClawHubSkillExecution _failure({
    String toolName = 'skill',
    required Map<String, dynamic> input,
    required String code,
    required String message,
  }) {
    return NativeClawHubSkillExecution(
      toolName: toolName,
      input: input,
      result: {
        'ok': false,
        'skill': toolName,
        'runtime': 'native-clawhub',
        'errorCode': code,
        'error': message,
      },
      ok: false,
      visibleText: 'The $toolName skill could not run: $message',
    );
  }
}
