import 'package:flutter_test/flutter_test.dart';
import 'package:clawa/services/skill_workspace.dart';

void main() {
  test('relativeDoc returns workspace-safe path', () {
    expect(SkillWorkspace.relativeDoc('canvas'), 'skills/canvas/SKILL.md');
    expect(SkillWorkspace.relativeDoc('Stocks'), 'skills/stocks/SKILL.md');
  });

  test('repairLeakedReadPath fixes bundle absolute paths', () {
    const leaked =
        './data/data/com.openclaw.plawie/files/native-node-embedded/'
        'full-openclaw/lib/node_modules/openclaw/skills/canvas/SKILL.md';
    expect(
      SkillWorkspace.repairLeakedReadPath(leaked),
      'skills/canvas/SKILL.md',
    );
  });

  test('isBundleOrAbsoluteLeak detects unsafe paths', () {
    expect(
      SkillWorkspace.isBundleOrAbsoluteLeak(
        'full-openclaw/lib/node_modules/openclaw/skills/canvas/SKILL.md',
      ),
      isTrue,
    );
    expect(SkillWorkspace.isBundleOrAbsoluteLeak('skills/canvas/SKILL.md'),
        isFalse);
  });
}
