import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:clawa/services/skill_parity_audit_service.dart';
import 'package:clawa/services/skill_provisioning_service.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('provisioning plans concrete native gates without PRoot auto fallback',
      () async {
    final temp = await Directory.systemTemp.createTemp('skill_provision_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeSkills = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      'skills',
    ));
    final prootBin = Directory(path.join(
      temp.path,
      'rootfs',
      'ubuntu',
      'usr',
      'bin',
    ));
    await nativeSkills.create(recursive: true);
    await prootBin.create(recursive: true);
    await File(path.join(prootBin.path, 'ffmpeg')).writeAsString('proot-bin');

    await File(path.join(nativeSkills.path, 'market-data', 'SKILL.md'))
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

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.planSnapshot(
      snapshot,
      skillId: 'market-data',
    );

    expect(report.changed, isFalse);
    expect(report.reloadRecommended, isFalse);
    expect(report.results, hasLength(1));
    final result = report.results.single;
    expect(result.status, SkillProvisioningStatus.missingBinary);
    expect(
      result.actions.map((action) => action.status),
      containsAll([
        SkillProvisioningActionStatus.needsUserConfig,
        SkillProvisioningActionStatus.missingBinary,
        SkillProvisioningActionStatus.missingPlugin,
      ]),
    );
    expect(
      result.actions
          .where((action) =>
              action.status == SkillProvisioningActionStatus.missingBinary)
          .single
          .message,
      contains('will not be used automatically'),
    );
  });

  test('provisioning can apply supplied native env and config values',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_apply_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeSkills = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      'skills',
    ));
    await nativeSkills.create(recursive: true);
    await File(path.join(nativeSkills.path, 'finance', 'SKILL.md'))
        .create(recursive: true)
        .then((file) => file.writeAsString('''
---
requirements:
  env:
    - FINANCE_API_KEY
  config:
    - skills.finance.region
---
# Finance
'''));

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.provisionSnapshot(
      snapshot,
      skillId: 'finance',
      envValues: const {'FINANCE_API_KEY': 'test-key'},
      configValues: const {'skills.finance.region': 'us'},
    );

    expect(report.changed, isTrue);
    expect(report.reloadRecommended, isTrue);
    expect(report.results.single.status, SkillProvisioningStatus.satisfied);

    final envFile = File(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      '.env',
    ));
    expect(await envFile.readAsString(), contains('FINANCE_API_KEY=test-key'));

    final configFile = File(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      'openclaw.json',
    ));
    final config = jsonDecode(await configFile.readAsString()) as Map;
    expect(config['skills']['finance']['region'], 'us');
  });

  test('provisioning reports Python runtime and package gates precisely',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_python_');
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
    final report = await SkillProvisioningService.instance.planSnapshot(
      snapshot,
      skillId: 'stocks',
    );
    final result = report.results.single;

    expect(result.status, SkillProvisioningStatus.missingDependency);
    expect(
      result.actions.map((action) => action.status),
      containsAll([
        SkillProvisioningActionStatus.missingBinary,
        SkillProvisioningActionStatus.missingDependency,
      ]),
    );
    expect(
      result.actions.map((action) => action.key),
      containsAll(
        ['pip', 'python3', 'pandas', 'pydantic', 'requests', 'yfinance'],
      ),
    );
    expect(
      result.actions.map((action) => action.type),
      contains(SkillProvisioningActionType.pythonPackage),
    );
  });

  test('provisioning installs verified Python dependency packs idempotently',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_python_pack_');
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

    final archive = Archive();
    const packageVersions = {
      'yfinance': '0.2.66',
      'pandas': '2.2.3',
      'pydantic': '2.0.0',
      'requests': '2.28.0',
    };
    for (final entry in packageVersions.entries) {
      final metadata = utf8.encode(
        'Name: ${entry.key}\nVersion: ${entry.value}\n',
      );
      archive.addFile(ArchiveFile(
        '${entry.key}-${entry.value}.dist-info/METADATA',
        metadata.length,
        metadata,
      ));
    }
    final packBytes = ZipEncoder().encode(archive);
    final packFile = File(path.join(temp.path, 'python-stocks-test.zip'));
    await packFile.writeAsBytes(packBytes, flush: true);
    final manifestFile = File(path.join(
      nativeRoot,
      'dependencies',
      'dependency_packs.json',
    ));
    await manifestFile.create(recursive: true);
    await manifestFile.writeAsString(jsonEncode({
      'packs': [
        {
          'id': 'python-stocks-test',
          'version': '1.0.0',
          'source': 'remote',
          'url': Uri.file(packFile.path).toString(),
          'sha256': crypto.sha256.convert(packBytes).toString(),
          'archiveType': 'zip',
          'installPath': 'runtimes/python/site-packages',
          'provides': {
            'pythonPackages': packageVersions.keys.toList(),
          },
        },
      ],
    }));

    final before = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final first = await SkillProvisioningService.instance.provisionSnapshot(
      before,
      skillId: 'stocks',
    );

    expect(first.changed, isTrue);
    expect(first.reloadRecommended, isTrue);
    expect(first.results.single.status, SkillProvisioningStatus.satisfied);
    expect(
      first.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      containsAll(['python-core', 'python-stocks-test']),
    );
    expect(
      await File(path.join(nativeRoot, 'runtimes', 'python', 'bridge.json'))
          .exists(),
      isTrue,
    );
    expect(
      await Directory(path.join(
        nativeRoot,
        'runtimes',
        'python',
        'site-packages',
        'yfinance.dist-info',
      )).exists(),
      isTrue,
    );
    expect(
      await File(path.join(stocks.path, '.venv', 'bin', 'python3')).exists(),
      isTrue,
    );

    final after = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final matrix = {
      for (final entry in after.executionMatrix) entry.skillId: entry,
    };
    expect(matrix['stocks']?.status, SkillExecutionStatus.ready);

    final second = await SkillProvisioningService.instance.provisionSnapshot(
      after,
      skillId: 'stocks',
    );
    expect(second.changed, isFalse);
    expect(second.results.single.status, SkillProvisioningStatus.ready);
  });

  test('provisioning does not hide missing transitive Python dependencies',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_transitive_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final stocks = Directory(path.join(
      nativeRoot,
      'workspace',
      'skills',
      'stocks',
    ));
    final pythonBin = Directory(path.join(
      nativeRoot,
      'runtimes',
      'python',
      'bin',
    ));
    final sitePackages = Directory(path.join(
      nativeRoot,
      'runtimes',
      'python',
      'site-packages',
    ));
    await stocks.create(recursive: true);
    await pythonBin.create(recursive: true);
    await sitePackages.create(recursive: true);

    await File(path.join(stocks.path, 'SKILL.md')).writeAsString('''
# Stocks

Setup:
python3 -m pip install -r requirements.txt
''');
    await File(path.join(stocks.path, 'requirements.txt')).writeAsString('''
yfinance>=1.0.0
''');
    for (final bin in ['python3', 'pip']) {
      await File(path.join(pythonBin.path, bin)).writeAsString('shim');
    }
    await File(path.join(nativeRoot, 'runtimes', 'python', 'bridge.json'))
        .writeAsString(jsonEncode({
      'python': '3.13',
      'version': '3.13-chaquopy-17.0.0',
    }));
    await File(path.join(
      sitePackages.path,
      'yfinance-1.4.1.dist-info',
      'METADATA',
    )).create(recursive: true).then((file) => file.writeAsString('''
Name: yfinance
Version: 1.4.1
Requires-Dist: curl_cffi>=0.15

Body text that must not be parsed as headers.
'''));

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    expect(
      snapshot.executionMatrix
          .singleWhere((entry) => entry.skillId == 'stocks')
          .status,
      SkillExecutionStatus.ready,
    );

    final report = await SkillProvisioningService.instance.planSnapshot(
      snapshot,
      skillId: 'stocks',
    );
    final result = report.results.single;

    expect(result.status, SkillProvisioningStatus.missingDependency);
    expect(
      result.actions.map((action) => action.key),
      contains('dependency-closure'),
    );
    expect(
      result.actions.map((action) => action.key),
      contains('yfinance'),
    );
    expect(
      result.actions.map((action) => action.message).join('\n'),
      contains('curl-cffi'),
    );
  });

  test('provisioning installs Native npm packages with transitive deps',
      () async {
    final temp = await Directory.systemTemp.createTemp('skill_provision_npm_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    await _writeNodeShim(nativeRoot);
    await _writeNodeSkill(
      nativeRoot,
      skillId: 'node-skill',
      dependencies: const {'left-pad': '^1.0.0'},
    );

    final leftPad = await _createNpmTarball(
      temp,
      name: 'left-pad',
      version: '1.3.0',
      dependencies: const {'pad-core': '~2.0.0'},
    );
    final padCore = await _createNpmTarball(
      temp,
      name: 'pad-core',
      version: '2.0.1',
    );
    await _writeNodePackageManifest(nativeRoot, [leftPad, padCore]);

    final before = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    expect(
      before.executionMatrix
          .singleWhere((entry) => entry.skillId == 'node-skill')
          .gates,
      contains('missing_native_node_package'),
    );

    final first = await SkillProvisioningService.instance.provisionSnapshot(
      before,
      skillId: 'node-skill',
    );

    expect(first.changed, isTrue);
    expect(first.reloadRecommended, isTrue);
    expect(first.results.single.status, SkillProvisioningStatus.satisfied);
    expect(
      first.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.nodePackage)
          .map((action) => action.key),
      containsAll(['left-pad', 'pad-core']),
    );
    expect(
      await File(path.join(
        nativeRoot,
        'node_modules',
        'left-pad',
        'package.json',
      )).exists(),
      isTrue,
    );
    expect(
      await File(path.join(
        nativeRoot,
        'dependencies',
        'receipts',
        'node-packages',
        'left-pad.json',
      )).exists(),
      isTrue,
    );

    final after = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    expect(
      after.executionMatrix
          .singleWhere((entry) => entry.skillId == 'node-skill')
          .status,
      SkillExecutionStatus.ready,
    );

    final second = await SkillProvisioningService.instance.provisionSnapshot(
      after,
      skillId: 'node-skill',
    );
    expect(second.changed, isFalse);
    expect(second.results.single.status, SkillProvisioningStatus.ready);
  });

  test('provisioning rejects bad npm package integrity without PRoot fallback',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_npm_bad_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    await _writeNodeShim(nativeRoot);
    await _writeNodeSkill(
      nativeRoot,
      skillId: 'bad-node-skill',
      dependencies: const {'bad-pkg': '^1.0.0'},
    );

    final badPkg = await _createNpmTarball(
      temp,
      name: 'bad-pkg',
      version: '1.0.0',
    );
    await _writeNodePackageManifest(nativeRoot, [
      {...badPkg, 'integrity': 'sha512-${base64.encode(List.filled(64, 7))}'},
    ]);

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.provisionSnapshot(
      snapshot,
      skillId: 'bad-node-skill',
    );
    final result = report.results.single;

    expect(result.status, SkillProvisioningStatus.missingDependency);
    expect(
      result.actions.map((action) => action.status),
      contains(SkillProvisioningActionStatus.failedVerification),
    );
    expect(
      result.actions.map((action) => action.message).join('\n'),
      contains('PRoot was not used'),
    );
    expect(
      await File(path.join(
        nativeRoot,
        'node_modules',
        'bad-pkg',
        'package.json',
      )).exists(),
      isFalse,
    );
  });
}

Future<void> _writeNodeShim(String nativeRoot) async {
  final node = File(path.join(nativeRoot, 'bin', 'node'));
  await node.create(recursive: true);
  await node.writeAsString('native node shim');
}

Future<void> _writeNodeSkill(
  String nativeRoot, {
  required String skillId,
  required Map<String, String> dependencies,
}) async {
  final skill =
      Directory(path.join(nativeRoot, 'workspace', 'skills', skillId));
  await skill.create(recursive: true);
  await File(path.join(skill.path, 'SKILL.md')).writeAsString('# $skillId\n');
  await File(path.join(skill.path, 'index.js')).writeAsString(
    'export function execute(input) { return input; }\n',
  );
  await File(path.join(skill.path, 'package.json')).writeAsString(jsonEncode({
    'name': skillId,
    'version': '1.0.0',
    'main': 'index.js',
    'dependencies': dependencies,
  }));
}

Future<Map<String, dynamic>> _createNpmTarball(
  Directory root, {
  required String name,
  required String version,
  Map<String, String> dependencies = const <String, String>{},
}) async {
  final packageJson = utf8.encode(jsonEncode({
    'name': name,
    'version': version,
    'main': 'index.js',
    if (dependencies.isNotEmpty) 'dependencies': dependencies,
  }));
  final index = utf8.encode('module.exports = {};\n');
  final archive = Archive()
    ..addFile(
        ArchiveFile('package/package.json', packageJson.length, packageJson))
    ..addFile(ArchiveFile('package/index.js', index.length, index));
  final tarBytes = TarEncoder().encode(archive);
  final tgzBytes = GZipEncoder().encode(tarBytes);
  final file = File(path.join(root.path, '$name-$version.tgz'));
  await file.writeAsBytes(tgzBytes, flush: true);
  return {
    'name': name,
    'version': version,
    'url': Uri.file(file.path).toString(),
    'integrity':
        'sha512-${base64.encode(crypto.sha512.convert(tgzBytes).bytes)}',
    if (dependencies.isNotEmpty) 'dependencies': dependencies,
  };
}

Future<void> _writeNodePackageManifest(
  String nativeRoot,
  List<Map<String, dynamic>> packages,
) async {
  final manifest =
      File(path.join(nativeRoot, 'dependencies', 'node_packages.json'));
  await manifest.create(recursive: true);
  await manifest.writeAsString(jsonEncode({'packages': packages}));
}
