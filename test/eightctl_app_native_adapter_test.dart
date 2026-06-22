import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/android_skill_support_manifest.dart';
import 'package:clawa/services/capabilities/eightctl_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/native_bridge.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eightctl rejects missing account config without running CLI', () async {
    final capability = EightCtlCapability(
      credentialsProvider: () async => const {
        'EIGHTCTL_EMAIL': null,
        'EIGHTCTL_PASSWORD': null,
      },
      runner: (binName, args, {required env, required timeoutSeconds}) async {
        fail('missing Eight Sleep credentials must not execute eightctl');
      },
    );

    final frame = await capability.handle('eightctl.status', const {});

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_EIGHTCTL_CONFIG');
  });

  test('eightctl status runs managed CLI with saved env and safe summary',
      () async {
    const email = 'user@example.test';
    const password = 'eight-secret-password';
    List<String>? capturedArgs;
    Map<String, String>? capturedEnv;

    final capability = EightCtlCapability(
      credentialsProvider: () async => const {
        'EIGHTCTL_EMAIL': email,
        'EIGHTCTL_PASSWORD': password,
      },
      runner: (binName, args, {required env, required timeoutSeconds}) async {
        expect(binName, 'eightctl');
        expect(timeoutSeconds, 25);
        capturedArgs = List<String>.from(args);
        capturedEnv = Map<String, String>.from(env);
        return NativeManagedCliRunResult(
          exitCode: 0,
          stdout: jsonEncode({
            'online': true,
            'targets': [
              {'side': 'left'},
              {'side': 'right'},
            ],
          }),
          stderr: '',
          binaryPath:
              '/data/user/0/app/files/native-node-embedded/native-home/.openclaw/bin/eightctl',
        );
      },
    );

    final frame = await capability.handle('eightctl', const {
      'action': 'status',
    });

    expect(capturedArgs, ['status', '--output', 'json', '--quiet']);
    expect(capturedEnv, {
      'EIGHTCTL_EMAIL': email,
      'EIGHTCTL_PASSWORD': password,
    });
    expect(frame.isOk, isTrue);
    expect(frame.payload?['runtime'], 'app-native-eightctl-cli');
    expect(frame.payload?['status'], 'READY');
    expect(frame.payload?['configured'], isTrue);
    expect(frame.payload?['connected'], isTrue);
    expect(frame.payload?['itemCount'], 2);
    expect(frame.payload?['remoteOnline'], isTrue);
    expect(jsonEncode(frame.payload), isNot(contains(password)));
    expect(jsonEncode(frame.payload), isNot(contains(email)));
  });

  test('eightctl CLI failures redact credentials and emails', () async {
    const email = 'user@example.test';
    const password = 'eight-secret-password';
    final capability = EightCtlCapability(
      credentialsProvider: () async => const {
        'EIGHTCTL_EMAIL': email,
        'EIGHTCTL_PASSWORD': password,
      },
      runner: (binName, args, {required env, required timeoutSeconds}) async {
        return const NativeManagedCliRunResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'login failed for user@example.test with eight-secret-password',
          binaryPath: '',
        );
      },
    );

    final frame = await capability.handle('eightctl.status', const {});

    expect(frame.isError, isTrue);
    final encoded = jsonEncode(frame.error);
    expect(encoded, isNot(contains(password)));
    expect(encoded, isNot(contains(email)));
    expect(encoded, contains('[secret]'));
    expect(encoded, contains('[email]'));
  });

  test('eightctl remains a pack-gated config skill with live adapter smoke',
      () {
    final entry = AndroidSkillSupportManifest.instance.entryFor('eightctl')!;

    expect(entry.status, AndroidSkillSupportStatus.needsPack);
    expect(entry.requiredPacks, ['android-cli-core-pack']);
    expect(entry.smokePrompt, contains('eightctl status'));
    expect(entry.smokePrompt, contains('EIGHTCTL_EMAIL'));
  });

  test('eightctl is advertised in native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();

    final catalog =
        SkillsService().getToolsCatalog().cast<Map<String, dynamic>>();
    final tool = catalog.singleWhere((tool) => tool['name'] == 'eightctl');
    final schema = tool['input_schema'] as Map<String, dynamic>;

    expect(tool['description'], contains('Eight Sleep'));
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties.keys, contains('action'));
    expect(
        properties['action'],
        containsPair('enum', [
          'status',
          'whoami',
          'device-info',
        ]));
  });

  test('AgentSkillServer, native bridge, and node allowlist route eightctl',
      () async {
    final server =
        await File('lib/services/agent_skill_server.dart').readAsString();
    final bridge = await File('lib/services/native_bridge.dart').readAsString();
    final activity = await File(
      'android/app/src/main/kotlin/com/nxg/openclawproot/MainActivity.kt',
    ).readAsString();

    expect(server, contains("case 'eightctl':"));
    expect(server, contains('_eightCtlCapability.handle('));
    expect(bridge, contains('runManagedCli'));
    expect(activity, contains('"runManagedCli"'));
    expect(activity, contains('managedCliAllowlist'));
    expect(activity, contains('"eightctl"'));
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      contains('eightctl.status'),
    );
  });
}
