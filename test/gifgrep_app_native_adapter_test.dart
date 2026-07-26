import 'dart:convert';
import 'dart:io';

import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/capabilities/gifgrep_capability.dart';
import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:clawa/services/native_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gifgrep search runs through bounded managed CLI adapter', () async {
    final calls = <Map<String, Object?>>[];
    final capability = GifgrepCapability(
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
  });
}
