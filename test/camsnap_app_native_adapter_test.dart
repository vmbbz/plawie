import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('camsnap is classified as an app-native ready optional skill', () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('camsnap')!;

    expect(entry.status, AndroidSkillSupportStatus.readyOptional);
    expect(entry.ownerLayer, AndroidSkillOwnerLayer.appNativeCapability);
    expect(entry.executionMode, AndroidSkillExecutionMode.appNativeTool);
    expect(entry.requiredPacks, isEmpty);
    expect(entry.launchCritical, isFalse);
    expect(entry.smokePrompt, contains('camera still'));
  });

  test('camsnap is advertised in native tools catalog with camera schema',
      () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog = SkillsService().getToolsCatalog();
    final camsnap = catalog
        .cast<Map<String, dynamic>>()
        .singleWhere((tool) => tool['name'] == 'camsnap');
    final schema = camsnap['input_schema'] as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;
    final facing = properties['facing'] as Map<String, dynamic>;

    expect(camsnap['description'], contains('camera'));
    expect(facing['enum'], containsAll(['back', 'front']));
    expect(schema['required'], isEmpty);
  });

  test('explicit camsnap prompt keeps skill identity while routing camera snap',
      () {
    final target = AppNativeChatToolRouter.instance.requiredGatewayNodeTarget(
      'camsnap with the front camera',
    );

    expect(target, isNotNull);
    expect(target!['appNativeToolName'], 'camsnap');
    expect(target['command'], 'camera.snap');

    final nodesInput = target['nodesInput'] as Map<String, dynamic>;
    expect(nodesInput['action'], 'camera_snap');
    expect(nodesInput['facing'], 'front');
  });

  test('AgentSkillServer routes camsnap tool execution to CameraCapability',
      () async {
    final source =
        await File('lib/services/agent_skill_server.dart').readAsString();

    expect(source, contains("case 'camsnap':"));
    expect(source, contains("'camsnap': 'camera.snap'"));
    expect(source, contains("_cameraCapability.handleWithPermission("));
    expect(source, contains("_sanitizeNodePayload(payload)"));
    expect(source, contains("copy.remove('base64')"));
    expect(source, contains("base64Omitted"));
  });
}
