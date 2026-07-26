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

  test('provisioning plans the remote Android CLI-core dependency pack',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_cli_missing_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    final bundledBinDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'bin',
    ));
    await nativeSkills.create(recursive: true);
    await bundledBinDir.create(recursive: true);

    final openhue = Directory(path.join(nativeSkills.path, 'openhue'));
    await openhue.create(recursive: true);
    await File(path.join(openhue.path, 'SKILL.md')).writeAsString('''
---
requirements:
  bins:
    - openhue
---
# OpenHue
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.planSnapshot(
      snapshot,
      skillId: 'openhue',
    );

    expect(report.changed, isFalse);
    expect(report.results.single.status, SkillProvisioningStatus.missingBinary);
    final packAction = report.results.single.actions.singleWhere(
      (action) =>
          action.type == SkillProvisioningActionType.dependencyPack &&
          action.key == 'android-cli-core-pack',
    );
    expect(packAction.status, SkillProvisioningActionStatus.missingDependency);
    expect(packAction.message, contains('can satisfy this skill'));
  });

  test('provisioning plans the remote vision media pack for ffmpeg', () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_vision_media_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    final bundledBinDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'bin',
    ));
    await nativeSkills.create(recursive: true);
    await bundledBinDir.create(recursive: true);

    final videoFrames = Directory(path.join(nativeSkills.path, 'video-frames'));
    await videoFrames.create(recursive: true);
    await File(path.join(videoFrames.path, 'SKILL.md')).writeAsString('''
---
requirements:
  bins:
    - ffmpeg
---
# Video Frames
''');
    await File(path.join(bundledBinDir.path, 'ffmpeg')).writeAsString(
      '#!/system/bin/sh\nprintf "ffmpeg test\\n"\n',
      flush: true,
    );

    final before = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    expect(
      before.executionMatrix
          .singleWhere((entry) => entry.skillId == 'video-frames')
          .gates,
      contains('missing_native_bin'),
    );

    final report = await SkillProvisioningService.instance.planSnapshot(
      before,
      skillId: 'video-frames',
    );

    expect(report.changed, isFalse);
    expect(report.reloadRecommended, isFalse);
    expect(report.results.single.status, SkillProvisioningStatus.missingBinary);
    expect(
      report.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      contains('android-vision-media-pack'),
    );
    expect(
      report.results.single.actions
          .where((action) => action.type == SkillProvisioningActionType.binary)
          .map((action) => action.key),
      contains('ffmpeg'),
    );
    expect(
        await File(path.join(nativeRoot, 'bin', 'ffmpeg')).exists(), isFalse);
  });

  test('provisioning plans the remote vision media pack when ffmpeg is absent',
      () async {
    final temp = await Directory.systemTemp
        .createTemp('skill_provision_ffmpeg_missing_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    final bundledBinDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'bin',
    ));
    await nativeSkills.create(recursive: true);
    await bundledBinDir.create(recursive: true);

    final videoFrames = Directory(path.join(nativeSkills.path, 'video-frames'));
    await videoFrames.create(recursive: true);
    await File(path.join(videoFrames.path, 'SKILL.md')).writeAsString('''
---
requirements:
  bins:
    - ffmpeg
---
# Video Frames
''');

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.planSnapshot(
      snapshot,
      skillId: 'video-frames',
    );

    expect(report.changed, isFalse);
    expect(report.results.single.status, SkillProvisioningStatus.missingBinary);
    final packAction = report.results.single.actions.singleWhere(
      (action) =>
          action.type == SkillProvisioningActionType.dependencyPack &&
          action.key == 'android-vision-media-pack',
    );
    expect(packAction.status, SkillProvisioningActionStatus.missingDependency);
    expect(packAction.message, contains('can satisfy this skill'));
  });

  test('gifgrep plans the remote vision media pack when binary is absent',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_gifgrep_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    final bundledBinDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'bin',
    ));
    await nativeSkills.create(recursive: true);
    await bundledBinDir.create(recursive: true);

    final gifgrep = Directory(path.join(nativeSkills.path, 'gifgrep'));
    await gifgrep.create(recursive: true);
    await File(path.join(gifgrep.path, 'SKILL.md')).writeAsString('''
---
requirements:
  bins:
    - gifgrep
---
# Gifgrep
''');
    await File(path.join(bundledBinDir.path, 'ffmpeg')).writeAsString(
      '#!/system/bin/sh\nprintf "ffmpeg test\\n"\n',
      flush: true,
    );

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.planSnapshot(
      snapshot,
      skillId: 'gifgrep',
    );

    expect(report.changed, isFalse);
    expect(report.results.single.status, SkillProvisioningStatus.missingBinary);
    expect(
      report.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      contains('android-vision-media-pack'),
    );
    expect(
        await File(path.join(nativeRoot, 'bin', 'gifgrep')).exists(), isFalse);
  });

  test('provisioning plans the remote vision media pack for gifgrep', () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_gifgrep_pack_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    final bundledBinDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'bin',
    ));
    await nativeSkills.create(recursive: true);
    await bundledBinDir.create(recursive: true);

    final gifgrep = Directory(path.join(nativeSkills.path, 'gifgrep'));
    await gifgrep.create(recursive: true);
    await File(path.join(gifgrep.path, 'SKILL.md')).writeAsString('''
---
requirements:
  bins:
    - gifgrep
---
# Gifgrep
''');
    await File(path.join(bundledBinDir.path, 'gifgrep')).writeAsString(
      '#!/system/bin/sh\nprintf "gifgrep test\\n"\n',
      flush: true,
    );

    final before = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    expect(
      before.executionMatrix
          .singleWhere((entry) => entry.skillId == 'gifgrep')
          .gates,
      contains('missing_native_bin'),
    );

    final report = await SkillProvisioningService.instance.planSnapshot(
      before,
      skillId: 'gifgrep',
    );

    expect(report.changed, isFalse);
    expect(report.reloadRecommended, isFalse);
    expect(report.results.single.status, SkillProvisioningStatus.missingBinary);
    expect(
      report.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      contains('android-vision-media-pack'),
    );
    expect(
      report.results.single.actions
          .where((action) => action.type == SkillProvisioningActionType.binary)
          .map((action) => action.key),
      contains('gifgrep'),
    );
    expect(
        await File(path.join(nativeRoot, 'bin', 'gifgrep')).exists(), isFalse);
  });

  test('provisioning plans the remote audio runtime pack for songsee',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_songsee_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    final bundledAudioBinDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'audio-runtime',
      'bin',
    ));
    await nativeSkills.create(recursive: true);
    await bundledAudioBinDir.create(recursive: true);

    final songsee = Directory(path.join(nativeSkills.path, 'songsee'));
    await songsee.create(recursive: true);
    await File(path.join(songsee.path, 'SKILL.md')).writeAsString('''
---
requirements:
  bins:
    - songsee
---
# Songsee
''');
    await File(path.join(bundledAudioBinDir.path, 'songsee')).writeAsString(
      '#!/system/bin/sh\nprintf "songsee test\\n"\n',
      flush: true,
    );

    final before = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    expect(
      before.executionMatrix
          .singleWhere((entry) => entry.skillId == 'songsee')
          .gates,
      contains('missing_native_bin'),
    );

    final report = await SkillProvisioningService.instance.planSnapshot(
      before,
      skillId: 'songsee',
    );

    expect(report.changed, isFalse);
    expect(report.reloadRecommended, isFalse);
    expect(report.results.single.status, SkillProvisioningStatus.missingBinary);
    expect(
      report.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      contains('android-audio-runtime-pack'),
    );
    expect(
        await File(path.join(nativeRoot, 'bin', 'songsee')).exists(), isFalse);
  });

  test('spotify-player remains blocked when only songsee audio payload exists',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_spotify_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    final bundledAudioBinDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'audio-runtime',
      'bin',
    ));
    await nativeSkills.create(recursive: true);
    await bundledAudioBinDir.create(recursive: true);

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
''');
    await File(path.join(bundledAudioBinDir.path, 'songsee')).writeAsString(
      '#!/system/bin/sh\nprintf "songsee test\\n"\n',
      flush: true,
    );

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.provisionSnapshot(
      snapshot,
      skillId: 'spotify-player',
    );

    expect(report.changed, isFalse);
    expect(report.results.single.status, SkillProvisioningStatus.missingBinary);
    expect(
      report.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      isNot(contains('android-audio-runtime-pack')),
    );
    expect(
      await File(path.join(nativeRoot, 'bin', 'spotify_player')).exists(),
      isFalse,
    );
    expect(await File(path.join(nativeRoot, 'bin', 'spogo')).exists(), isFalse);
  });

  test('provisioning plans the remote terminal pack for tmux', () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_terminal_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    final bundledBinDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'terminal',
      'bin',
    ));
    final bundledLibDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'terminal',
      'lib',
    ));
    await nativeSkills.create(recursive: true);
    await bundledBinDir.create(recursive: true);
    await bundledLibDir.create(recursive: true);

    final tmuxSkill = Directory(path.join(nativeSkills.path, 'tmux'));
    await tmuxSkill.create(recursive: true);
    await File(path.join(tmuxSkill.path, 'SKILL.md')).writeAsString('''
---
requirements:
  bins:
    - tmux
---
# Tmux
''');
    await File(path.join(bundledBinDir.path, 'tmux')).writeAsString(
      '#!/system/bin/sh\nprintf "tmux 3.5a\\n"\n',
      flush: true,
    );
    await File(path.join(bundledLibDir.path, 'libevent-2.1.so'))
        .writeAsString('fake libevent payload', flush: true);

    final before = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    expect(
      before.executionMatrix
          .singleWhere((entry) => entry.skillId == 'tmux')
          .gates,
      contains('missing_native_bin'),
    );

    final report = await SkillProvisioningService.instance.planSnapshot(
      before,
      skillId: 'tmux',
    );

    expect(report.changed, isFalse);
    expect(report.reloadRecommended, isFalse);
    expect(report.results.single.status, SkillProvisioningStatus.missingBinary);
    expect(
      report.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      contains('android-terminal-pack'),
    );
    expect(await File(path.join(nativeRoot, 'bin', 'tmux')).exists(), isFalse);
  });

  test('provisioning does not advertise diagram-maker as CLI-core binary',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_diagram_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final nativeSkills =
        Directory(path.join(nativeRoot, 'workspace', 'skills'));
    final bundledBinDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'bin',
    ));
    await nativeSkills.create(recursive: true);
    await bundledBinDir.create(recursive: true);

    final diagram = Directory(path.join(nativeSkills.path, 'diagram-maker'));
    await diagram.create(recursive: true);
    await File(path.join(diagram.path, 'SKILL.md')).writeAsString('''
---
requirements:
  bins:
    - diagram-maker
---
# Diagram Maker
''');
    await File(path.join(bundledBinDir.path, 'diagram-maker')).writeAsString(
      '#!/system/bin/sh\nprintf "diagram-maker test\\n"\n',
      flush: true,
    );

    final before = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.provisionSnapshot(
      before,
      skillId: 'diagram-maker',
    );

    expect(report.changed, isTrue);
    expect(report.results.single.status, SkillProvisioningStatus.satisfied);
    expect(
      report.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      isNot(contains('android-cli-core-pack')),
    );
    expect(
      report.results.single.actions
          .where((action) => action.type == SkillProvisioningActionType.binary)
          .map((action) => action.key),
      contains('diagram-maker'),
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

  test('provisioning applies supplied config when skill has no matrix entry',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_config_only_');
    addTearDown(() => temp.delete(recursive: true));

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    expect(snapshot.executionMatrix, isEmpty);

    final report = await SkillProvisioningService.instance.provisionSnapshot(
      snapshot,
      skillId: 'slack',
      envValues: const {'SLACK_BOT_TOKEN': 'xoxb-dummy'},
      configValues: const {'channels.slack': 'C123'},
    );

    expect(report.changed, isTrue);
    expect(report.reloadRecommended, isTrue);
    expect(report.results, hasLength(1));
    expect(report.results.single.skillId, 'slack');
    expect(report.results.single.status, SkillProvisioningStatus.satisfied);
    expect(
      report.results.single.actions.map((action) => action.key),
      containsAll(['SLACK_BOT_TOKEN', 'channels.slack']),
    );

    final envFile = File(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      '.env',
    ));
    expect(
        await envFile.readAsString(), contains('SLACK_BOT_TOKEN=xoxb-dummy'));

    final configFile = File(path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
      'openclaw.json',
    ));
    final config = jsonDecode(await configFile.readAsString()) as Map;
    expect(config['channels']['slack'], 'C123');
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
        SkillProvisioningActionStatus.missingDependency,
        SkillProvisioningActionStatus.missingPack,
      ]),
    );
    expect(
      result.actions.map((action) => action.key),
      containsAll(
        ['python-core', 'pandas', 'pydantic', 'requests', 'yfinance'],
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
          'abi': ['arm64-v8a'],
          'sizeBytes': packBytes.length,
          'sha256': crypto.sha256.convert(packBytes).toString(),
          'archiveType': 'zip',
          'installPath': 'runtimes/python/site-packages',
          'files': [
            {
              'path': 'yfinance-0.2.66.dist-info/METADATA',
              'sha256': crypto.sha256
                  .convert(utf8.encode(
                    'Name: yfinance\nVersion: 0.2.66\n',
                  ))
                  .toString(),
              'sizeBytes':
                  utf8.encode('Name: yfinance\nVersion: 0.2.66\n').length,
            }
          ],
          'smokeCommand': {
            'command': 'python3',
            'args': ['-c', 'import yfinance'],
          },
          'rollback': {
            'strategy': 'remove_install_path',
          },
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
        'yfinance-0.2.66.dist-info',
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

  test('provisioning installs APK-provided debugpy wheel pack', () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_debugpy_pack_');
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

    final debugpySkill =
        Directory(path.join(nativeSkills.path, 'python-debugpy'));
    await debugpySkill.create(recursive: true);
    await File(path.join(debugpySkill.path, 'SKILL.md')).writeAsString('''
---
metadata: { "openclaw": { "requires": { "bins": ["python3"] } } }
---
# Python Debugpy

```bash
python3 -c "import debugpy"
python3 -m debugpy --listen 127.0.0.1:5678 path/to/script.py
```
''');

    const debugpyVersion = '1.8.21';
    final wheelBytes = _debugpyWheelFixture(debugpyVersion);
    final wheelDir = Directory(path.join(
      temp.path,
      'native-node-embedded',
      'provisioning',
      'python-debug',
      'wheels',
    ));
    await wheelDir.create(recursive: true);
    await File(path.join(
      wheelDir.path,
      'debugpy-$debugpyVersion-py2.py3-none-any.whl',
    )).writeAsBytes(wheelBytes, flush: true);

    final before = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final first = await SkillProvisioningService.instance.provisionSnapshot(
      before,
      skillId: 'python-debugpy',
    );

    expect(first.changed, isTrue);
    expect(first.reloadRecommended, isTrue);
    expect(first.results.single.status, SkillProvisioningStatus.satisfied);
    expect(
      first.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      containsAll(['python-core', 'android-python-debug-runtime']),
    );

    final sitePackages =
        path.join(nativeRoot, 'runtimes', 'python', 'site-packages');
    expect(
        await Directory(path.join(sitePackages, 'debugpy')).exists(), isTrue);
    expect(
      await File(path.join(
        sitePackages,
        'debugpy-$debugpyVersion.dist-info',
        'METADATA',
      )).exists(),
      isTrue,
    );
    expect(
      await File(path.join(
        nativeRoot,
        'dependencies',
        'receipts',
        'android-python-debug-runtime.json',
      )).exists(),
      isTrue,
    );
    expect(
      await File(path.join(
        nativeRoot,
        'dependencies',
        'receipts',
        'python-wheels',
        'debugpy.json',
      )).exists(),
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
    expect(matrix['python-debugpy']?.status, SkillExecutionStatus.ready);

    final second = await SkillProvisioningService.instance.provisionSnapshot(
      after,
      skillId: 'python-debugpy',
    );
    expect(second.changed, isFalse);
    expect(second.results.single.status, SkillProvisioningStatus.ready);
  });

  test('provisioning rejects invalid dependency pack manifests before install',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_bad_pack_');
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
    await stocks.create(recursive: true);
    await File(path.join(stocks.path, 'SKILL.md')).writeAsString('''
# Stocks

Setup:
python3 -m pip install -r requirements.txt
''');
    await File(path.join(stocks.path, 'requirements.txt')).writeAsString('''
yfinance>=0.2.66
''');

    final archive = Archive();
    final metadata = utf8.encode('Name: yfinance\nVersion: 0.2.66\n');
    archive.addFile(ArchiveFile(
      'yfinance-0.2.66.dist-info/METADATA',
      metadata.length,
      metadata,
    ));
    final packBytes = ZipEncoder().encode(archive);
    final packFile = File(path.join(temp.path, 'unsafe-yfinance.zip'));
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
          'id': 'unsafe-yfinance-pack',
          'version': '1.0.0',
          'source': 'remote',
          'url': Uri.file(packFile.path).toString(),
          'abi': ['arm64-v8a'],
          'sizeBytes': packBytes.length,
          // Intentionally missing top-level sha256: this must be rejected.
          'archiveType': 'zip',
          'installPath': 'runtimes/python/site-packages',
          'files': [
            {
              'path': 'yfinance-0.2.66.dist-info/METADATA',
              'sha256': crypto.sha256.convert(metadata).toString(),
              'sizeBytes': metadata.length,
            }
          ],
          'smokeCommand': {
            'command': 'python3',
            'args': ['-c', 'import yfinance'],
          },
          'rollback': {
            'strategy': 'remove_install_path',
          },
          'provides': {
            'pythonPackages': ['yfinance'],
          },
        },
      ],
    }));

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.planSnapshot(
      snapshot,
      skillId: 'stocks',
    );

    expect(report.results.single.status, isNot(SkillProvisioningStatus.ready));
    expect(
      report.results.single.actions
          .where((action) =>
              action.type == SkillProvisioningActionType.dependencyPack)
          .map((action) => action.key),
      isNot(contains('unsafe-yfinance-pack')),
    );
  });

  test('provisioning rejects binary dependency pack when command smoke fails',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('skill_provision_bin_smoke_');
    addTearDown(() => temp.delete(recursive: true));

    final nativeRoot = path.join(
      temp.path,
      'native-node-embedded',
      'native-home',
      '.openclaw',
    );
    final skill = Directory(path.join(
      nativeRoot,
      'workspace',
      'skills',
      'video-smoke',
    ));
    await skill.create(recursive: true);

    const commandName = 'video-smoke';
    final fileName = Platform.isWindows ? '$commandName.exe' : commandName;
    await File(path.join(skill.path, 'SKILL.md')).writeAsString('''
---
requirements:
  bins:
    - $commandName
---
# Video Smoke
''');

    final payloadBytes = Platform.isWindows
        ? await File(Platform.environment['ComSpec'] ??
                r'C:\Windows\System32\cmd.exe')
            .readAsBytes()
        : utf8.encode(
            '#!/system/bin/sh\n'
            'echo command smoke failed >&2\n'
            'exit 17\n',
          );
    final smokeArgs = Platform.isWindows
        ? <String>['/c', 'echo command smoke failed 1>&2 & exit /b 17']
        : <String>['--smoke'];
    final archive = Archive()
      ..addFile(ArchiveFile(fileName, payloadBytes.length, payloadBytes));
    final packBytes = ZipEncoder().encode(archive);
    final packFile =
        File(path.join(temp.path, 'android-command-smoke-fail-test.zip'));
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
          'id': 'android-command-smoke-fail-test',
          'version': '1.0.0',
          'source': 'remote',
          'url': Uri.file(packFile.path).toString(),
          'abi': ['arm64-v8a'],
          'sizeBytes': packBytes.length,
          'sha256': crypto.sha256.convert(packBytes).toString(),
          'signature': {
            'type': 'test-ed25519',
            'value': 'test-signature',
            'keyId': 'test-key',
          },
          'archiveType': 'zip',
          'installPath': 'bin',
          'files': [
            {
              'path': fileName,
              'sha256': crypto.sha256.convert(payloadBytes).toString(),
              'sizeBytes': payloadBytes.length,
              'executable': true,
            }
          ],
          'smokeCommand': {
            'command': commandName,
            'args': smokeArgs,
          },
          'rollback': {
            'strategy': 'remove_install_path',
          },
          'provides': {
            'bins': [commandName],
          },
        },
      ],
    }));

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: false,
      cacheTtl: Duration.zero,
    );
    final report = await SkillProvisioningService.instance.provisionSnapshot(
      snapshot,
      skillId: 'video-smoke',
    );

    expect(report.changed, isFalse);
    expect(report.results.single.status, SkillProvisioningStatus.missingBinary);
    final failedSmoke = report.results.single.actions.singleWhere(
      (action) =>
          action.type == SkillProvisioningActionType.dependencyPack &&
          action.key == 'android-command-smoke-fail-test' &&
          action.status == SkillProvisioningActionStatus.failedSmoke,
    );
    expect(failedSmoke.status, SkillProvisioningActionStatus.failedSmoke);
    expect(failedSmoke.message, contains('failed smoke verification'));
    expect(
      await File(path.join(nativeRoot, 'bin', fileName)).exists(),
      isFalse,
    );
    expect(
      await File(path.join(
        nativeRoot,
        'dependencies',
        'receipts',
        'android-command-smoke-fail-test.json',
      )).exists(),
      isFalse,
    );

    final archiveCache = Directory(path.join(
      nativeRoot,
      'dependencies',
      'archive-cache',
    ));
    final cachedArchives = await archiveCache
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    expect(cachedArchives, hasLength(1));
    expect(await cachedArchives.single.readAsBytes(), packBytes);

    // A smoke failure must remain retryable without spending data again.
    await packFile.delete();
    final retry = await SkillProvisioningService.instance.provisionSnapshot(
      snapshot,
      skillId: 'video-smoke',
    );
    expect(
      retry.results.single.actions.any(
        (action) =>
            action.key == 'android-command-smoke-fail-test' &&
            action.status == SkillProvisioningActionStatus.failedSmoke,
      ),
      isTrue,
    );
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
      SkillExecutionStatus.missingDependency,
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

List<int> _debugpyWheelFixture(String version) {
  final metadata = utf8.encode('''
Metadata-Version: 2.1
Name: debugpy
Version: $version
Summary: Debugger for Python
''');
  final init = utf8.encode("__version__ = '$version'\n");
  final serverInit = utf8.encode('');
  final record = utf8.encode('''
debugpy/__init__.py,,
debugpy/server/__init__.py,,
debugpy-$version.dist-info/METADATA,,
debugpy-$version.dist-info/RECORD,,
''');
  final archive = Archive()
    ..addFile(ArchiveFile('debugpy/__init__.py', init.length, init))
    ..addFile(
      ArchiveFile('debugpy/server/__init__.py', serverInit.length, serverInit),
    )
    ..addFile(
      ArchiveFile(
        'debugpy-$version.dist-info/METADATA',
        metadata.length,
        metadata,
      ),
    )
    ..addFile(
      ArchiveFile('debugpy-$version.dist-info/RECORD', record.length, record),
    );
  return ZipEncoder().encode(archive);
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
