import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clawa/services/app_native_chat_tool_router.dart';
import 'package:clawa/services/avatar_gesture_catalog.dart';
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
