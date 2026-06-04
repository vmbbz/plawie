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
    await File(path.join(nativeSkills.path, 'weather', 'SKILL.md'))
        .create(recursive: true)
        .then((file) => file.writeAsString('# Local Weather Override'));

    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: temp.path,
      repairNativeFromProot: true,
      cacheTtl: Duration.zero,
    );

    expect(snapshot.nativeSkillNames, contains('stocks'));
    expect(snapshot.prootSkillNames, containsAll(['stocks', 'weather']));
    expect(snapshot.repair.copied, 1);
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
  });
}
