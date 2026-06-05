import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/skill_parity_audit_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
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
      'python': '3.13',
      'version': '3.13-chaquopy-17.0.0',
    }));
    final python = File(path.join(pythonBin.path, 'python3'));
    await python.writeAsString('#!/system/bin/sh\nexit 0\n');
    if (!Platform.isWindows) {
      await Process.run('chmod', ['755', python.path]);
    }
    final packageVersions = {
      'yfinance': '0.2.66',
      'pandas': '2.2.3',
      'pydantic': '2.0.0',
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
      'python': '3.13',
      'version': '3.13-chaquopy-17.0.0',
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
        'python': '3.13',
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
}
