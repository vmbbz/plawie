import 'dart:io';

import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/gateway_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('healthcheck is a required mobile tool intent', () {
    final gateway = GatewayService();

    expect(
      gateway
          .debugRequiredToolIntentCommandForTesting('device healthcheck now'),
      'device.health',
    );
    expect(
      gateway.debugRequiredToolIntentCommandForTesting(
        'check the phone health status',
      ),
      'device.health',
    );
  });

  test('required healthcheck intent produces device-node tool chips', () async {
    final temp = await Directory.systemTemp.createTemp('device_health_route_');
    addTearDown(() => temp.delete(recursive: true));
    const nativeChannel = MethodChannel('com.openclaw.plawie/native');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeChannel, (call) async {
      return switch (call.method) {
        'getFilesDir' => temp.path,
        'getDeviceId' => 'test-device',
        'getDeviceBrand' => 'OpenClaw',
        'getDeviceModel' => 'Unit',
        'getAppVersion' => 'test',
        'getArch' => 'arm64-v8a',
        'getTotalMemoryMb' => 4096,
        'getBatteryLevel' => 88,
        'isCharging' => true,
        _ => null,
      };
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativeChannel, null);
    });

    final execution =
        await AppNativeChatToolRouter.instance.tryExecuteRequiredToolIntent(
      'device healthcheck now',
    );

    expect(execution, isNotNull);
    expect(execution!.toolName, 'device-node');
    expect(execution.input['action'], 'device_health');
    expect(
      execution.input['routingSource'],
      'gateway-required-tool-intent',
    );
    expect(execution.toolUseChunk, startsWith('\x00TOOL_USE:device-node:'));
    expect(
      execution.toolResultChunk,
      startsWith('\x00TOOL_RESULT:device-node:'),
    );
  });

  test('sendMessage keeps required mobile command execution before chat.send',
      () async {
    final source =
        await File('lib/services/gateway_service.dart').readAsString();
    final methodStart = source.indexOf('Stream<String> sendMessage(');
    expect(methodStart, isNonNegative);
    final methodEnd = source.indexOf(
        '  Future<Map<String, dynamic>> '
        '_syncModelToConfig',
        methodStart);
    expect(methodEnd, isNonNegative);

    final sendMessageSource = source.substring(methodStart, methodEnd);
    final requiredIntentCalls =
        RegExp(r'_executeRequiredToolContinuation\(message\)')
            .allMatches(sendMessageSource)
            .length;

    expect(
      requiredIntentCalls,
      greaterThanOrEqualTo(2),
      reason: 'sendMessage must execute required mobile commands after the '
          'initial WS connection and after WS repair, before provider chat.',
    );

    final firstRequiredIntent =
        sendMessageSource.indexOf('_executeRequiredToolContinuation(message)');
    final firstProviderSend = sendMessageSource.indexOf('final chatSendFrame');
    expect(firstRequiredIntent, isNonNegative);
    expect(firstProviderSend, isNonNegative);
    expect(
      firstRequiredIntent,
      lessThan(firstProviderSend),
      reason: 'Required health/device/avatar commands must not fall through to '
          'provider freestyle before the tool/result chips are emitted.',
    );
  });
}
