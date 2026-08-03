import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/skill_parity_audit_service.dart';
import 'package:clawa/services/skill_execution_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('merges duplicate Python distributions using the highest version', () {
    final packages = <String, String>{'yfinance': '1.5.2'};

    SkillParityAuditService.mergePythonPackageVersions(
      packages,
      const {
        'yfinance': '0.2.57',
        'pandas': '2.1.3',
      },
    );

    expect(packages, {
      'yfinance': '1.5.2',
      'pandas': '2.1.3',
    });
  });

  test('audit counts OpenClaw package skills on fresh native installs',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_package_root_test_');
    addTearDown(() => temp.delete(recursive: true));

    final packageSkills = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'full-openclaw',
      'lib',
      'node_modules',
      'openclaw',
      'skills',
    ));
    await packageSkills.create(recursive: true);

    for (final id in [
      'skill-creator',
      'spike',
      'taskflow',
      'taskflow-inbox-triage',
    ]) {
      await File(path.join(packageSkills.path, id, 'SKILL.md'))
          .create(recursive: true)
          .then((file) => file.writeAsString('# $id'));
    }

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );

    expect(
      snapshot.nativeSkillNames,
      containsAll([
        'skill-creator',
        'spike',
        'taskflow',
        'taskflow-inbox-triage',
      ]),
    );
    expect(snapshot.nativeSkillCount, 4);
  });

  test(
      'audit repairs missing PRoot skills into Native without overwriting conflicts',
      () async {
    final temp = await Directory.systemTemp.createTemp('skill_parity_test_');
    addTearDown(() => temp.delete(recursive: true));

    final prootSkills = Directory(path.join(
      temp.path,
      'rootfs',
      'ubuntu',
      'root',
      '.openclaw',
      'skills',
    ));
    final nativeSkills = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      'skills',
    ));
    await prootSkills.create(recursive: true);
    await nativeSkills.create(recursive: true);

    await File(path.join(prootSkills.path, 'stocks', 'SKILL.md'))
        .create(recursive: true)
        .then((file) => file.writeAsString('# Stocks\n\nRequires `ffmpeg`.'));
    await File(path.join(prootSkills.path, 'weather', 'SKILL.md'))
        .create(recursive: true)
        .then((file) => file.writeAsString('# Weather'));
    await File(path.join(prootSkills.path, 'market-data', 'SKILL.md'))
        .create(recursive: true)
        .then((file) => file.writeAsString('''
---
requirements:
  env:
    - MARKET_DATA_API_KEY
  bins:
    - ffmpeg
  plugins:
    - market-plugin
  config:
    - skills.marketData.accountId
---
# Market Data
'''));
    await File(path.join(nativeSkills.path, 'weather', 'SKILL.md'))
        .create(recursive: true)
        .then((file) => file.writeAsString('# Local Weather Override'));

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: true,
      cacheTtl: Duration.zero,
    );

    expect(snapshot.nativeSkillNames, containsAll(['stocks', 'market-data']));
    expect(
      snapshot.prootSkillNames,
      containsAll(['stocks', 'weather', 'market-data']),
    );
    expect(snapshot.repair.copied, 2);
    expect(snapshot.repair.skippedConflicts, 1);
    expect(
      await File(path.join(nativeSkills.path, 'weather', 'SKILL.md'))
          .readAsString(),
      '# Local Weather Override',
    );
    expect(
      snapshot.gates.map((gate) => gate.gate),
      contains('missing_native_bin'),
    );
    expect(
      snapshot.gates.map((gate) => gate.gate),
      containsAll([
        'missing_native_env',
        'missing_native_config',
        'missing_native_plugin',
      ]),
    );
    final matrix = {
      for (final entry in snapshot.executionMatrix) entry.skillId: entry,
    };
    expect(matrix['stocks']?.status, SkillExecutionStatus.missingDependency);
    expect(matrix['market-data']?.status, SkillExecutionStatus.needsConfig);
    expect(
      matrix['market-data']?.requiredConfig,
      contains('skills.marketData.accountId'),
    );
  });

  test('audit builds HTTP endpoint descriptors for local bridge skills',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_http_descriptor_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeSkills = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      'skills',
    ));
    await nativeSkills.create(recursive: true);

    final battery = Directory(path.join(nativeSkills.path, 'device_battery'));
    await battery.create(recursive: true);
    await File(path.join(battery.path, 'SKILL.md')).writeAsString('''
# Android Battery Status

Run:
```bash
curl -s http://127.0.0.1:8765/battery
```
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final entry = snapshot.executionMatrix.single;
    final descriptor = entry.executionDescriptor;

    expect(entry.status, SkillExecutionStatus.ready);
    expect(entry.requiredBins, isNot(contains('curl')));
    expect(descriptor, isNotNull);
    expect(descriptor!.runtime, SkillExecutionRuntime.http);
    expect(descriptor.mode, SkillExecutionMode.httpEndpoint);
    expect(descriptor.entrypoint, 'http://127.0.0.1:8765/battery');
    expect(descriptor.methods.single.name, 'get_device_battery');
  });

  test('audit builds Python Tools-class descriptors from skill files',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_python_descriptor_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeSkills = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      'workspace',
      'skills',
    ));
    await nativeSkills.create(recursive: true);

    final skill = Directory(path.join(nativeSkills.path, 'weatherish'));
    await Directory(path.join(skill.path, 'scripts')).create(recursive: true);
    await File(path.join(skill.path, 'SKILL.md')).writeAsString('# Weatherish');
    await File(path.join(skill.path, 'requirements.txt')).writeAsString(
      'requests>=2\n',
    );
    await File(path.join(skill.path, 'scripts', 'tools.py')).writeAsString('''
class Tools:
    async def current_weather(self, city: str, units="metric"):
        return city
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final entry = snapshot.executionMatrix.single;
    final descriptor = entry.executionDescriptor;

    expect(entry.status, SkillExecutionStatus.missingDependency);
    expect(entry.requiredBins, containsAll(['pip', 'python3']));
    expect(entry.requiredPythonPackages, ['requests']);
    expect(descriptor, isNotNull);
    expect(descriptor!.runtime, SkillExecutionRuntime.python);
    expect(descriptor.mode, SkillExecutionMode.pythonToolsClass);
    expect(descriptor.entrypoint, 'scripts/tools.py');
    expect(descriptor.methods.single.name, 'current_weather');
    expect(descriptor.methods.single.requiredParameters, ['city']);
  });

  test('audit builds Node module descriptors and npm dependency gates',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_node_descriptor_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeSkills = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      'workspace',
      'skills',
    ));
    await nativeSkills.create(recursive: true);

    final skill = Directory(path.join(nativeSkills.path, 'nodeish'));
    await skill.create(recursive: true);
    await File(path.join(skill.path, 'package.json')).writeAsString(jsonEncode({
      'main': 'index.js',
      'dependencies': {'left-pad': '^1.3.0'},
      'openclaw': {
        'methods': [
          {'name': 'pad'}
        ],
      },
    }));
    await File(path.join(skill.path, 'index.js')).writeAsString(
      'module.exports = {};',
    );

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final entry = snapshot.executionMatrix.single;
    final descriptor = entry.executionDescriptor;

    expect(entry.status, SkillExecutionStatus.missingDependency);
    expect(entry.gates, contains('missing_native_runtime'));
    expect(entry.gates, contains('missing_native_node_package'));
    expect(entry.requiredRuntimes, contains('node'));
    expect(entry.requiredNodePackages, ['left-pad']);
    expect(descriptor, isNotNull);
    expect(descriptor!.runtime, SkillExecutionRuntime.node);
    expect(descriptor.mode, SkillExecutionMode.nodeModule);
    expect(descriptor.methods.single.name, 'pad');
  });

  test('audit treats Python requirements as native provisionable gates',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_python_parity_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeSkills = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      'workspace',
      'skills',
    ));
    await nativeSkills.create(recursive: true);

    final stocks = Directory(path.join(nativeSkills.path, 'stocks'));
    await stocks.create(recursive: true);
    await File(path.join(stocks.path, 'SKILL.md')).writeAsString('''
# Stocks

Setup:
python3 -m venv .venv
.venv/bin/python3 -m pip install -r requirements.txt
''');
    await File(path.join(stocks.path, 'requirements.txt')).writeAsString('''
yfinance>=0.2.66
pandas>=2.2.0
pydantic>=2.0.0
requests>=2.28.0
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final matrix = {
      for (final entry in snapshot.executionMatrix) entry.skillId: entry,
    };
    final stocksEntry = matrix['stocks'];

    expect(stocksEntry?.status, SkillExecutionStatus.missingDependency);
    expect(stocksEntry?.gates, contains('missing_native_runtime'));
    expect(stocksEntry?.gates, contains('missing_native_python_package'));
    expect(stocksEntry?.gates, isNot(contains('manual_proot_required')));
    expect(
      stocksEntry?.requiredPythonPackages,
      containsAll(['pandas', 'pydantic', 'requests', 'yfinance']),
    );
  });

  test('audit sees managed Native Python runtime and packages', () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_python_ready_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final pythonBin =
        Directory(path.join(nativeRoot, 'runtimes', 'python', 'bin'));
    final sitePackages =
        Directory(path.join(nativeRoot, 'runtimes', 'python', 'site-packages'));
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    await pythonBin.create(recursive: true);
    await sitePackages.create(recursive: true);
    await nativeSkills.create(recursive: true);
    await File(path.join(nativeRoot, 'runtimes', 'python', 'bridge.json'))
        .writeAsString(jsonEncode({
      'runtime': 'chaquopy',
      'python': '3.11',
      'version': '3.11-chaquopy-17.0.0',
    }));
    final python = File(path.join(pythonBin.path, 'python3'));
    await python.writeAsString('#!/system/bin/sh\nexit 0\n');
    if (!Platform.isWindows) {
      await Process.run('chmod', ['755', python.path]);
    }
    final packageVersions = {
      'yfinance': '0.2.66',
      'pandas': '2.1.3',
      'pydantic': '1.10.15',
      'requests': '2.28.0',
    };
    for (final entry in packageVersions.entries) {
      final distInfo = Directory(path.join(
          sitePackages.path, '${entry.key}-${entry.value}.dist-info'));
      await distInfo.create(recursive: true);
      if (entry.key == 'pydantic') {
        await File(path.join(distInfo.path, 'METADATA')).writeAsString('''
Name: pydantic
Version: ${entry.value}

Example:
    Name: str = 'john doe'
''');
      }
    }

    final stocks = Directory(path.join(nativeSkills.path, 'stocks'));
    await stocks.create(recursive: true);
    await File(path.join(stocks.path, 'SKILL.md')).writeAsString('''
# Stocks

Setup:
python3 -m venv .venv
.venv/bin/python3 -m pip install -r requirements.txt
''');
    await File(path.join(stocks.path, 'requirements.txt')).writeAsString('''
yfinance>=0.2.66
pandas>=2.2.0
pydantic>=2.0.0
requests>=2.28.0
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final matrix = {
      for (final entry in snapshot.executionMatrix) entry.skillId: entry,
    };

    expect(matrix['stocks']?.status, SkillExecutionStatus.ready);
    expect(matrix['stocks']?.gates, isEmpty);
  });

  test('audit accepts smoked Android compatibility wheel receipts', () async {
    final temp = await Directory.systemTemp
        .createTemp('skill_python_compat_receipt_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final pythonBin =
        Directory(path.join(nativeRoot, 'runtimes', 'python', 'bin'));
    final sitePackages =
        Directory(path.join(nativeRoot, 'runtimes', 'python', 'site-packages'));
    final receiptDir = Directory(path.join(
      nativeRoot,
      'dependencies',
      'receipts',
      'python-wheels',
    ));
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    await pythonBin.create(recursive: true);
    await sitePackages.create(recursive: true);
    await receiptDir.create(recursive: true);
    await nativeSkills.create(recursive: true);
    await File(path.join(nativeRoot, 'runtimes', 'python', 'bridge.json'))
        .writeAsString(jsonEncode({
      'runtime': 'chaquopy',
      'python': '3.11',
      'version': '3.11-chaquopy-17.0.0',
    }));
    final python = File(path.join(pythonBin.path, 'python3'));
    await python.writeAsString('#!/system/bin/sh\nexit 0\n');
    if (!Platform.isWindows) {
      await Process.run('chmod', ['755', python.path]);
    }

    final pandasDist =
        Directory(path.join(sitePackages.path, 'pandas-2.1.3.dist-info'));
    await pandasDist.create(recursive: true);
    await File(path.join(pandasDist.path, 'METADATA')).writeAsString('''
Name: pandas
Version: 2.1.3
''');
    await File(path.join(receiptDir.path, 'pandas.json')).writeAsString(
      jsonEncode({
        'id': 'pandas',
        'version': '2.1.3',
        'sha256': 'test',
        'python': '3.11',
        'requestedRequirement': 'pandas>=2.2.0',
        'compatibilityOverride': true,
        'smokePassed': true,
      }),
    );

    final stocks = Directory(path.join(nativeSkills.path, 'stocks'));
    await stocks.create(recursive: true);
    await File(path.join(stocks.path, 'SKILL.md')).writeAsString('''
# Stocks

Setup:
python3 -m pip install -r requirements.txt
''');
    await File(path.join(stocks.path, 'requirements.txt')).writeAsString('''
pandas>=2.2.0
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final matrix = {
      for (final entry in snapshot.executionMatrix) entry.skillId: entry,
    };

    expect(matrix['stocks']?.status, SkillExecutionStatus.ready);
    expect(matrix['stocks']?.gates, isEmpty);
  });

  test('audit does not classify Python packages as native binaries', () async {
    final temp = await Directory.systemTemp
        .createTemp('skill_python_package_not_bin_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    await nativeSkills.create(recursive: true);

    final stocks = Directory(path.join(nativeSkills.path, 'stocks'));
    await stocks.create(recursive: true);
    await File(path.join(stocks.path, 'SKILL.md')).writeAsString('''
---
requirements:
  commands:
    - YFinance
    - python3
---
# Stocks
''');
    await File(path.join(stocks.path, 'requirements.txt')).writeAsString('''
yfinance>=0.2.66
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final matrix = {
      for (final entry in snapshot.executionMatrix) entry.skillId: entry,
    };
    final stocksEntry = matrix['stocks'];

    expect(stocksEntry?.requiredBins, contains('python3'));
    expect(stocksEntry?.requiredBins, isNot(contains('yfinance')));
    expect(stocksEntry?.requiredPythonPackages, contains('yfinance'));
    expect(
      stocksEntry?.gates,
      isNot(contains('missing_native_bin:YFinance')),
    );
  });

  test('structured bin requirements suppress noisy command examples', () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_structured_bins_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills = Directory(path.join(nativeRoot, 'skills'));
    final nativeBin = Directory(path.join(nativeRoot, 'bin'));
    await nativeSkills.create(recursive: true);
    await nativeBin.create(recursive: true);
    await File(path.join(nativeRoot, 'runtimes', 'python', 'bridge.json'))
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'runtime': 'chaquopy',
              'python': '3.11',
              'version': '3.11-chaquopy-17.0.0',
            })));
    await File(path.join(nativeBin.path, 'python3')).writeAsString(
      '#!/system/bin/sh\nexit 0\n',
      flush: true,
    );

    final debugpy = Directory(path.join(nativeSkills.path, 'python-debugpy'));
    await debugpy.create(recursive: true);
    await File(path.join(debugpy.path, 'SKILL.md')).writeAsString(r'''
---
metadata: { "openclaw": { "requires": { "bins": ["python3"] } } }
---
# Python Debugpy

Cleanup before commit:

```bash
rg -n 'breakpoint\(|pdb\.set_trace|debugpy\.' --type py
```
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final entry = snapshot.executionMatrix.single;

    expect(entry.requiredBins, ['python3']);
    expect(entry.requiredBins, isNot(contains('rg')));
    expect(entry.gates, isEmpty);
    expect(entry.status, SkillExecutionStatus.ready);
  });

  test('provider-specific API keys in prose do not become hard env gates',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_optional_env_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills = Directory(path.join(nativeRoot, 'skills'));
    final nativeBin = Directory(path.join(nativeRoot, 'bin'));
    await nativeSkills.create(recursive: true);
    await nativeBin.create(recursive: true);
    await File(path.join(nativeBin.path, 'gifgrep')).writeAsString(
      '#!/system/bin/sh\nexit 0\n',
      flush: true,
    );

    final gifgrep = Directory(path.join(nativeSkills.path, 'gifgrep'));
    await gifgrep.create(recursive: true);
    await File(path.join(gifgrep.path, 'SKILL.md')).writeAsString('''
---
metadata:
  openclaw:
    requires:
      bins:
        - gifgrep
---
# gifgrep

Providers

- `GIPHY_API_KEY` required for `--source giphy`
- `TENOR_API_KEY` optional (Tenor demo key used if unset)
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final entry = snapshot.executionMatrix.single;

    expect(entry.requiredBins, ['gifgrep']);
    expect(entry.requiredEnv, isEmpty);
    expect(entry.gates, isEmpty);
    expect(entry.status, SkillExecutionStatus.ready);
  });

  test('account email env vars in high-confidence env lines become gates',
      () async {
    final temp = await Directory.systemTemp.createTemp('skill_email_env_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills = Directory(path.join(nativeRoot, 'skills'));
    final nativeBin = Directory(path.join(nativeRoot, 'bin'));
    await nativeSkills.create(recursive: true);
    await nativeBin.create(recursive: true);
    await File(path.join(nativeBin.path, 'eightctl')).writeAsString(
      '#!/system/bin/sh\nexit 0\n',
      flush: true,
    );

    final eightctl = Directory(path.join(nativeSkills.path, 'eightctl'));
    await eightctl.create(recursive: true);
    await File(path.join(eightctl.path, 'SKILL.md')).writeAsString('''
---
metadata:
  openclaw:
    requires:
      bins:
        - eightctl
---
# eightctl

Auth

- Env: `EIGHTCTL_EMAIL`, `EIGHTCTL_PASSWORD`
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final entry = snapshot.executionMatrix.single;

    expect(entry.requiredBins, ['eightctl']);
    expect(entry.requiredEnv, ['EIGHTCTL_EMAIL', 'EIGHTCTL_PASSWORD']);
    expect(entry.gates, contains('missing_native_env'));
    expect(entry.status, SkillExecutionStatus.needsConfig);
  });

  test('python debugpy commands create a package gate beyond python3',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_debugpy_package_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills = Directory(path.join(nativeRoot, 'skills'));
    final nativeBin = Directory(path.join(nativeRoot, 'bin'));
    await nativeSkills.create(recursive: true);
    await nativeBin.create(recursive: true);
    await File(path.join(nativeRoot, 'runtimes', 'python', 'bridge.json'))
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'runtime': 'chaquopy',
              'python': '3.11',
              'version': '3.11-chaquopy-17.0.0',
            })));
    await File(path.join(nativeBin.path, 'python3')).writeAsString(
      '#!/system/bin/sh\nexit 0\n',
      flush: true,
    );

    final debugpy = Directory(path.join(nativeSkills.path, 'python-debugpy'));
    await debugpy.create(recursive: true);
    await File(path.join(debugpy.path, 'SKILL.md')).writeAsString('''
---
metadata: { "openclaw": { "requires": { "bins": ["python3"] } } }
---
# Python Debugpy

```bash
python3 -c "import debugpy"
python3 -m debugpy --listen 127.0.0.1:5678 path/to/script.py
```
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final entry = snapshot.executionMatrix.single;

    expect(entry.requiredBins, ['python3']);
    expect(entry.requiredPythonPackages, ['debugpy']);
    expect(entry.gates, contains('missing_native_python_package'));
    expect(entry.status, SkillExecutionStatus.missingDependency);
  });

  test('structured anyBins alternatives are enforced without body overreach',
      () async {
    final temp = await Directory.systemTemp.createTemp('skill_any_bins_test_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills = Directory(path.join(nativeRoot, 'skills'));
    await nativeSkills.create(recursive: true);

    final spotify = Directory(path.join(nativeSkills.path, 'spotify-player'));
    await spotify.create(recursive: true);
    await File(path.join(spotify.path, 'SKILL.md')).writeAsString('''
---
metadata:
  openclaw:
    requires:
      anyBins:
        - spogo
        - spotify_player
---
# Spotify Player

Common commands:

```bash
spogo status
spotify_player playback play
```
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final entry = snapshot.executionMatrix.single;

    expect(entry.requiredBins, isEmpty);
    expect(entry.requiredAnyBins, [
      ['spogo', 'spotify_player'],
    ]);
    expect(entry.gates, contains('missing_native_bin'));
    expect(entry.status, SkillExecutionStatus.missingDependency);
    expect(snapshot.gates.single.detail, contains('spogo or spotify_player'));
  });
}
