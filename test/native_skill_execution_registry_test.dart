import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/native_skill_execution_registry.dart';
import 'package:clawa/services/skill_execution_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stocks descriptor exposes runtime, dependencies, and methods',
      () async {
    final temp = await Directory.systemTemp.createTemp('skill_registry_');
    addTearDown(() => temp.delete(recursive: true));
    await _createStocksScript(temp);

    final registry = NativeSkillExecutionRegistry(
      filesDirProvider: () async => temp.path,
      pythonRunner: (_) async => const <String, dynamic>{},
    );

    final descriptor = await registry.descriptorForSkill('stocks');

    expect(descriptor, isNotNull);
    expect(descriptor!.skillId, 'stocks');
    expect(descriptor.runtime, SkillExecutionRuntime.python);
    expect(descriptor.mode, SkillExecutionMode.pythonToolsClass);
    expect(descriptor.entrypoint, 'scripts/yfinance_ai.py');
    expect(descriptor.className, 'Tools');
    expect(descriptor.dependencies.pythonPackages, contains('yfinance'));
    expect(descriptor.dependencies.pythonPackages, contains('pandas'));
    expect(
      descriptor.methods.map((method) => method.name),
      containsAll(['get_stock_price', 'get_crypto_price', 'get_market_status']),
    );
  });

  test('registry executes python Tools-class descriptor through managed paths',
      () async {
    final temp = await Directory.systemTemp.createTemp('skill_registry_exec_');
    addTearDown(() => temp.delete(recursive: true));
    await _createStocksScript(temp);

    Map<String, dynamic>? capturedPayload;
    final registry = NativeSkillExecutionRegistry(
      filesDirProvider: () async => temp.path,
      pythonRunner: (payload) async {
        capturedPayload = payload;
        return {
          'ok': true,
          'exitCode': 0,
          'stdout': jsonEncode({'NVDA': 'ok'}),
          'stderr': '',
        };
      },
    );
    final descriptor = await registry.descriptorForSkill('stocks');

    final result = await registry.execute(
      descriptor: descriptor!,
      actions: const [
        SkillExecutionAction(
          label: 'NVDA',
          method: 'get_stock_price',
          args: {'ticker': 'NVDA'},
        ),
      ],
    );

    expect(result.ok, isTrue);
    expect(result.data, {'NVDA': 'ok'});
    expect(capturedPayload?['cwd'], contains('/workspace/skills/stocks'));
    expect(
      capturedPayload?['pythonPaths'].toString(),
      contains('/runtimes/python/site-packages'),
    );
    expect(
      capturedPayload?['pythonPaths'].toString(),
      contains('/workspace/skills/stocks/scripts'),
    );
    expect(capturedPayload?['args'].toString(), contains('get_stock_price'));
  });

  test('generic Python Tools-class skill descriptor is discovered from disk',
      () async {
    final temp = await Directory.systemTemp.createTemp('generic_skill_');
    addTearDown(() => temp.delete(recursive: true));
    final skillDir = Directory(
      '${temp.path}/native-node-embedded/native-home/.openclaw/workspace/skills/weatherish',
    );
    await Directory('${skillDir.path}/scripts').create(recursive: true);
    await File('${skillDir.path}/requirements.txt')
        .writeAsString('requests>=2\n');
    await File('${skillDir.path}/scripts/tools.py').writeAsString('''
class Tools:
    async def current_weather(self, city: str, units="metric"):
        return city

    def _helper(self):
        return None
''');

    final registry = NativeSkillExecutionRegistry(
      filesDirProvider: () async => temp.path,
      pythonRunner: (_) async => const <String, dynamic>{},
    );

    final descriptor = await registry.descriptorForSkill('weatherish');

    expect(descriptor, isNotNull);
    expect(descriptor!.runtime, SkillExecutionRuntime.python);
    expect(descriptor.mode, SkillExecutionMode.pythonToolsClass);
    expect(descriptor.entrypoint, 'scripts/tools.py');
    expect(descriptor.dependencies.pythonPackages, ['requests']);
    expect(
        descriptor.methods.map((method) => method.name), ['current_weather']);
    expect(descriptor.methods.single.parameters.keys, ['city', 'units']);
    expect(descriptor.methods.single.requiredParameters, ['city']);
  });

  test('HTTP endpoint skill descriptor is discovered from Markdown curl docs',
      () async {
    final temp = await Directory.systemTemp.createTemp('http_skill_');
    addTearDown(() => temp.delete(recursive: true));
    final skillDir = Directory(
      '${temp.path}/native-node-embedded/native-home/.openclaw/skills/device_vibrate',
    );
    await skillDir.create(recursive: true);
    await File('${skillDir.path}/SKILL.md').writeAsString('''
# Vibrate

```bash
curl -X POST -H "Content-Type: application/json" -d '{"durationMs": 200}' http://127.0.0.1:8765/vibrate
```
''');

    final registry = NativeSkillExecutionRegistry(
      filesDirProvider: () async => temp.path,
      pythonRunner: (_) async => const <String, dynamic>{},
    );

    final descriptor = await registry.descriptorForSkill('device_vibrate');

    expect(descriptor, isNotNull);
    expect(descriptor!.runtime, SkillExecutionRuntime.http);
    expect(descriptor.mode, SkillExecutionMode.httpEndpoint);
    expect(descriptor.entrypoint, 'http://127.0.0.1:8765/vibrate');
    expect(descriptor.methods.single.name, 'post_device_vibrate');
    expect(descriptor.methods.single.parameters,
        {'durationMs': 'json body field'});
  });

  test('Node module skill descriptor is discovered from package json',
      () async {
    final temp = await Directory.systemTemp.createTemp('node_skill_');
    addTearDown(() => temp.delete(recursive: true));
    final skillDir = Directory(
      '${temp.path}/native-node-embedded/native-home/.openclaw/workspace/skills/nodeish',
    );
    await skillDir.create(recursive: true);
    await File('${skillDir.path}/package.json').writeAsString(jsonEncode({
      'main': 'index.js',
      'dependencies': {'left-pad': '^1.3.0'},
      'openclaw': {
        'methods': [
          {
            'name': 'pad',
            'parameters': {'value': 'string'},
            'requiredParameters': ['value'],
          }
        ],
      },
    }));
    await File('${skillDir.path}/index.js')
        .writeAsString('module.exports = {};');

    final registry = NativeSkillExecutionRegistry(
      filesDirProvider: () async => temp.path,
      pythonRunner: (_) async => const <String, dynamic>{},
    );

    final descriptor = await registry.descriptorForSkill('nodeish');

    expect(descriptor, isNotNull);
    expect(descriptor!.runtime, SkillExecutionRuntime.node);
    expect(descriptor.mode, SkillExecutionMode.nodeModule);
    expect(descriptor.entrypoint, 'index.js');
    expect(descriptor.dependencies.nodePackages, ['left-pad']);
    expect(descriptor.methods.single.name, 'pad');
  });
}

Future<void> _createStocksScript(Directory filesDir) async {
  final scripts = Directory(
    '${filesDir.path}/native-node-embedded/native-home/.openclaw/workspace/skills/stocks/scripts',
  );
  await scripts.create(recursive: true);
  await File('${scripts.path}/yfinance_ai.py').writeAsString('# stub');
}
