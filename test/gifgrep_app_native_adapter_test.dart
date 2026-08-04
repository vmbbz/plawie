import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/gifgrep_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/gifgrep_contract.dart';
import 'package:clawa/services/native_bridge.dart';
import 'package:clawa/services/skills_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('gifgrep search runs through bounded managed CLI adapter', () async {
    final calls = <Map<String, Object?>>[];
    final capability = GifgrepCapability(
      useNativeProviderSearch: false,
      credentialsProvider: () async => {
        'GIPHY_API_KEY': 'test-giphy-key',
        'KLIPY_API_KEY': null,
      },
      runner: (
        binName,
        args, {
        required env,
        required timeoutSeconds,
      }) async {
        calls.add({
          'bin': binName,
          'args': args,
          'env': env,
          'timeout': timeoutSeconds,
        });
        return NativeManagedCliRunResult(
          exitCode: 0,
          stdout: jsonEncode([
            {
              'url': 'https://media.example/happy.gif',
              'title': 'Happy',
            }
          ]),
          stderr: '',
          binaryPath: '/managed/gifgrep',
        );
      },
    );

    final frame = await capability.handle('gifgrep.search', {
      'query': 'happy',
      'max': 25,
      'source': 'auto',
    });

    expect(frame.isError, isFalse);
    expect(frame.payload?['runtime'], 'app-native-gifgrep-cli');
    expect(frame.payload?['source'], 'giphy');
    expect(frame.payload?['count'], 1);
    expect(calls, hasLength(1));
    expect(calls.single['bin'], 'gifgrep');
    expect(
      calls.single['args'],
      ['search', 'happy', '--json', '--source', 'giphy', '--max', '10'],
    );
    expect(calls.single['env'], {'GIPHY_API_KEY': 'test-giphy-key'});
    expect(calls.single['timeout'], 25);
  });

  test('missing provider key is configuration, not installation', () async {
    var runnerCalled = false;
    final capability = GifgrepCapability(
      useNativeProviderSearch: false,
      credentialsProvider: () async => {
        'GIPHY_API_KEY': null,
        'KLIPY_API_KEY': null,
      },
      runner: (
        binName,
        args, {
        required env,
        required timeoutSeconds,
      }) async {
        runnerCalled = true;
        throw StateError('runner should not be called');
      },
    );

    final frame = await capability.handle(
      'gifgrep.search',
      {'query': 'happy'},
    );

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'GIFGREP_PROVIDER_CONFIG_REQUIRED');
    expect(frame.error?['runtimeReady'], isTrue);
    expect(frame.error?['installationRequired'], isFalse);
    expect(frame.error?['message'], contains('no reinstall is needed'));
    expect(runnerCalled, isFalse);
  });

  test('provider CLI failures redact keys before reaching chat', () async {
    const providerKey = 'test-giphy-key';
    final capability = GifgrepCapability(
      useNativeProviderSearch: false,
      credentialsProvider: () async => {
        'GIPHY_API_KEY': providerKey,
        'KLIPY_API_KEY': null,
      },
      runner: (
        binName,
        args, {
        required env,
        required timeoutSeconds,
      }) async {
        return const NativeManagedCliRunResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'lookup api.giphy.com: https://api.giphy.com/v1/gifs/search?api_key=test-giphy-key&q=cat',
          binaryPath: '/managed/gifgrep',
        );
      },
    );

    final frame = await capability.handle('gifgrep.search', {'query': 'cat'});

    expect(frame.isError, isTrue);
    final errorText = jsonEncode(frame.error);
    expect(errorText, isNot(contains(providerKey)));
    expect(errorText, contains('api_key=<redacted>'));
  });

  test('gifgrep contract maps local language to native actions', () {
    expect(
      GifgrepContract.localActionForMessage(
        'make a contact sheet storyboard from this gif',
      ),
      'sheet',
    );
    expect(
      GifgrepContract.localActionForMessage('extract the first frame'),
      'still',
    );
    expect(GifgrepContract.inputSchema()['properties'], contains('mediaPath'));
  });

  test('explicit gifgrep request is routed to dotted Android node command', () {
    final target = AppNativeChatToolRouter.instance.requiredGatewayNodeTarget(
      'Use the gifgrep skill to find a happy gif',
    );

    expect(target, isNotNull);
    expect(target?['command'], 'gifgrep.search');
    final nodesInput = target?['nodesInput'] as Map<String, dynamic>;
    expect(nodesInput['invokeCommand'], 'gifgrep.search');
    expect(
        jsonDecode(nodesInput['invokeParamsJson'] as String),
        containsPair(
          'query',
          'happy',
        ));
  });

  test('local still honors the documented atMs parameter', () async {
    final directory = await Directory.systemTemp.createTemp('gifgrep-test-');
    addTearDown(() => directory.delete(recursive: true));
    final input = File(path.join(directory.path, 'input.gif'));
    await input.writeAsBytes([1, 2, 3]);
    int? receivedAtMs;
    final capability = GifgrepCapability(
      filesDirProvider: () async => directory.path,
      runner: (_, __, {required env, required timeoutSeconds}) async =>
          const NativeManagedCliRunResult(
        exitCode: 0,
        stdout: 'gifgrep 0.3.0',
        stderr: '',
        binaryPath: '/managed/gifgrep',
      ),
      localRenderer: (
        bytes, {
        required action,
        required atMs,
        required frames,
        required cols,
      }) async {
        receivedAtMs = atMs;
        return <String, dynamic>{
          'pngBytes': Uint8List.fromList([137, 80, 78, 71]),
          'sourceFrames': 2,
          'renderedFrames': 1,
        };
      },
    );

    final frame = await capability.handle('gifgrep.still', {
      'inputPath': input.path,
      'atMs': 1500,
    });

    expect(frame.isError, isFalse);
    expect(receivedAtMs, 1500);
  });

  test('required gifgrep route preserves provider source and accepts typo',
      () async {
    final router = AppNativeChatToolRouter.forTesting(
      gifgrep: GifgrepCapability(
        credentialsProvider: () async => {
          'GIPHY_API_KEY': null,
          'KLIPY_API_KEY': null,
        },
      ),
    );

    final execution = await router.tryExecuteRequiredToolIntent(
      'Use gigrep to find a happy gif',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'gifgrep');
    expect(execution.input['source'], 'auto');
    expect(
      execution.input['routingSource'],
      'gateway-required-tool-intent',
    );
    expect(
      (execution.result['error'] as Map)['code'],
      'GIFGREP_PROVIDER_CONFIG_REQUIRED',
    );
    expect(execution.visibleText, contains('no reinstall is needed'));
  });

  test('local GIF still and sheet rendering produces bounded PNGs', () {
    final first = image.Image(width: 2, height: 2, numChannels: 4)
      ..clear(image.ColorRgba8(255, 0, 0, 255))
      ..frameDuration = 100;
    final second = image.Image(width: 2, height: 2, numChannels: 4)
      ..clear(image.ColorRgba8(0, 255, 0, 255))
      ..frameDuration = 100;
    first.addFrame(second);
    final gifBytes = image.encodeGif(first);

    final still = renderGifPayloadForTesting({
      'bytes': gifBytes,
      'action': 'still',
      'atMs': 150,
      'frames': 1,
      'cols': 1,
    });
    expect(still['sourceFrames'], 2);
    expect(still['renderedFrames'], 1);
    expect(still['selectedFrame'], 1);
    expect(image.decodePng(still['pngBytes']), isNotNull);

    final sheet = renderGifPayloadForTesting({
      'bytes': gifBytes,
      'action': 'sheet',
      'atMs': 0,
      'frames': 2,
      'cols': 2,
    });
    expect(sheet['sourceFrames'], 2);
    expect(sheet['renderedFrames'], 2);
    final decodedSheet = image.decodePng(sheet['pngBytes']);
    expect(decodedSheet, isNotNull);
    expect(decodedSheet!.width, 16);
    expect(decodedSheet.height, 10);
  });

  test('gifgrep commands are declared but broad shell command is not', () {
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      containsAll(const [
        'gifgrep.status',
        'gifgrep.search',
        'gifgrep.still',
        'gifgrep.sheet',
      ]),
    );
    expect(
      GatewayToolCatalog.mobileNodeAllowCommands,
      isNot(contains('gifgrep search')),
    );
  });

  test('gifgrep is advertised in the native tools catalog', () async {
    SharedPreferences.setMockInitialValues({});
    await SkillsService().initialize();
    final catalog = SkillsService().getToolsCatalog();
    final tool = catalog.firstWhere((entry) => entry['name'] == 'gifgrep');
    final schema = tool['input_schema'] as Map<String, dynamic>;
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties['action'], isNotNull);
    expect(properties['inputPath'], isNotNull);
    expect(schema['required'], contains('action'));
  });

  test('generic native executor keeps gifgrep actions bounded', () async {
    final source = await File(
      'lib/services/agent_skill_server.dart',
    ).readAsString();
    expect(source, contains("case 'gifgrep':"));
    expect(source, contains("'gifgrep.status'"));
    expect(source, contains("'gifgrep.search'"));
    expect(source, contains("'gifgrep.still'"));
    expect(source, contains("'gifgrep.sheet'"));
    expect(source, contains("Unknown gifgrep action"));
  });

  test('Android managed CLI allowlist contains verified gifgrep binary',
      () async {
    final source = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    ).readAsString();
    expect(source, contains('"gifgrep",'));
    expect(source, contains('managedNativeElfCommand(binary, args)'));
  });

  test('completed required tool suppresses a conflicting second node call',
      () async {
    final source =
        await File('lib/services/gateway_service.dart').readAsString();
    expect(
      source,
      contains(
        'requiredToolAlreadyExecuted: requiredToolContinuation != null',
      ),
    );
    expect(
      source,
      contains(
        'final requiredNodeTarget = requiredToolAlreadyExecuted',
      ),
    );
    expect(source, contains('bool get completeWithoutGateway'));
    expect(
      source,
      contains('deterministically without a second model pass.'),
    );
  });
}
