import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/avatar_gesture_catalog.dart';
import 'package:clawa/services/gateway_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sit resolves to neutral repaired limb VRMA', () {
    final resolved = AvatarGestureCatalog.resolve('sit 30 seconds');

    expect(resolved.gesture, 'sit');
    expect(
      resolved.assetPath,
      'assets/vrm/animations/limbs/Sitting_Both_Wave_01.vrma',
    );
    expect(resolved.isLimb, isTrue);
  });

  test('specific limb requests stay specific', () {
    expect(
      AvatarGestureCatalog.resolve('cross leg sit').assetPath,
      'assets/vrm/animations/limbs/Cross_Leg_Sitting_Wave_01.vrma',
    );
    expect(
      AvatarGestureCatalog.resolve('chill sit').assetPath,
      'assets/vrm/animations/limbs/Chill_Sit_Wave_01.vrma',
    );
    expect(
      AvatarGestureCatalog.resolve('wave right').assetPath,
      'assets/vrm/animations/limbs/Wave_Right_01.vrma',
    );
  });

  test('bow number shorthand resolves to numbered limb gesture', () {
    final resolved = AvatarGestureCatalog.resolve('bow 2');

    expect(resolved.gesture, 'bowing 2');
    expect(
      resolved.assetPath,
      'assets/vrm/animations/limbs/Bowing_02.vrma',
    );
  });

  test('avatar gesture duration parser supports seconds and minutes', () {
    final router = AppNativeChatToolRouter.instance;

    expect(
      router.parseDurationMsForTesting(
        'sit 30 seconds',
        minMs: 250,
        maxMs: 120000,
      ),
      30000,
    );
    expect(
      router.parseDurationMsForTesting(
        'sit 1 minute',
        minMs: 250,
        maxMs: 120000,
      ),
      60000,
    );
  });

  test('avatar sequence parser preserves ordered gestures and durations', () {
    final router = AppNativeChatToolRouter.instance;
    final steps = router.parseAvatarSequenceForTesting(
      'try cross leg sit for 30 seconds then after, bow 2',
    );

    expect(steps, isNotNull);
    expect(steps, hasLength(2));
    expect(steps![0]['gesture'], 'cross leg sit');
    expect(steps[0]['durationMs'], 30000);
    expect(steps[1]['gesture'], 'bowing 2');
    expect(
      steps[1]['assetPath'],
      'assets/vrm/animations/limbs/Bowing_02.vrma',
    );
  });

  test('normal chat is not app-native fallback without explicit prefix', () {
    final gateway = GatewayService();

    expect(
      gateway.debugIsExplicitAppNativeFallbackForTesting(
        'turn on the flashlight',
      ),
      isFalse,
    );
    expect(
      gateway.debugIsExplicitAppNativeFallbackForTesting(
        '/local-tool turn on the flashlight',
      ),
      isTrue,
    );
  });

  test('limb VRMAs have humanoid mappings after repair', () {
    final dir = Directory('assets/vrm/animations/limbs');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.vrma'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    expect(files.length, 30);
    for (final file in files) {
      final json = _readGlbJson(file);
      final extensions = json['extensions'] as Map?;
      final vrma = extensions?['VRMC_vrm_animation'] as Map?;
      final humanoid = vrma?['humanoid'] as Map?;
      final humanBones = humanoid?['humanBones'] as Map?;
      expect(
        humanBones?.length ?? 0,
        greaterThanOrEqualTo(15),
        reason: file.path,
      );
      for (final bone in const [
        'hips',
        'spine',
        'head',
        'leftUpperLeg',
        'rightUpperLeg',
        'leftUpperArm',
        'rightUpperArm',
      ]) {
        expect(humanBones, contains(bone), reason: file.path);
      }
    }
  });
}

Map<String, dynamic> _readGlbJson(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'glTF');
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final length = data.getUint32(offset, Endian.little);
    final type = data.getUint32(offset + 4, Endian.little);
    offset += 8;
    if (type == 0x4e4f534a) {
      final jsonBytes = bytes.sublist(offset, offset + length);
      return jsonDecode(utf8.decode(jsonBytes).trimRight())
          as Map<String, dynamic>;
    }
    offset += length;
  }
  throw StateError('No JSON chunk found in ${file.path}');
}
