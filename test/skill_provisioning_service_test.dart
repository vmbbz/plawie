import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/skill_parity_audit_service.dart';
import 'package:clawa/services/skill_provisioning_service.dart';
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
}
