import 'dart:convert';

import 'package:clawa/services/capabilities/meme_maker_capability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('meme-maker.create generates a captioned PNG payload', () async {
    final frame = await MemeMakerCapability().handle(
      'meme-maker.create',
      {
        'topText': 'Native Android',
        'bottomText': 'No PRoot needed',
        'width': 640,
        'height': 640,
      },
    );

    expect(frame.isError, isFalse);
    expect(frame.payload?['runtime'], 'app-native-dart-image');
    expect(frame.payload?['mimeType'], 'image/png');
    expect(frame.payload?['attachedImage'], isTrue);

    final base64 = frame.payload?['base64']?.toString() ?? '';
    expect(base64, isNotEmpty);
    final decoded = img.decodePng(base64Decode(base64));
    expect(decoded, isNotNull);
    expect(decoded!.width, 640);
    expect(decoded.height, 640);
  });

  test('meme-maker.create rejects empty captions', () async {
    final frame = await MemeMakerCapability().handle(
      'meme-maker.create',
      const <String, dynamic>{},
    );

    expect(frame.isError, isTrue);
    expect(frame.error?['code'], 'MISSING_TEXT');
  });
}
