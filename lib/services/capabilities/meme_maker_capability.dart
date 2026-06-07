import 'dart:convert';

import 'package:image/image.dart' as img;

import '../../models/node_frame.dart';
import '../tool_media_event_bus.dart';
import 'capability_handler.dart';

/// Pure-Dart Android meme renderer.
///
/// This intentionally avoids Node canvas, sharp, browser automation, and PRoot.
/// It produces a simple captioned PNG suitable for the Android GTM launch gate.
class MemeMakerCapability extends CapabilityHandler {
  @override
  String get name => 'meme-maker';

  @override
  List<String> get commands => ['create'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command);
    if (canonical != 'meme-maker.create') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown meme-maker command: $command',
      });
    }

    final topText = _caption(params['topText'] ?? params['top'] ?? '');
    final bottomText =
        _caption(params['bottomText'] ?? params['bottom'] ?? params['text']);
    if (topText.isEmpty && bottomText.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_TEXT',
        'message': 'meme-maker.create requires topText or bottomText.',
      });
    }

    final width =
        _intValue(params['width'], fallback: 1024).clamp(512, 1600).toInt();
    final height =
        _intValue(params['height'], fallback: 1024).clamp(512, 1600).toInt();
    final image = img.Image(width: width, height: height);
    _paintBackground(image);
    _paintCaptionBand(image, top: true);
    _paintCaptionBand(image, top: false);
    _drawCaption(image, topText, top: true);
    _drawCaption(image, bottomText, top: false);

    final pngBytes = img.encodePng(image, level: 6);
    final base64 = base64Encode(pngBytes);
    ToolMediaEventBus.instance.publish(ToolMediaEvent(
      source: 'meme-maker.create',
      base64: base64,
      mimeType: 'image/png',
    ));

    return NodeFrame.response('', payload: {
      'provider': 'meme-maker',
      'runtime': 'app-native-dart-image',
      'mimeType': 'image/png',
      'width': width,
      'height': height,
      'base64': base64,
      'base64Bytes': base64.length,
      'pngBytes': pngBytes.length,
      'attachedImage': true,
      'summary': 'Generated a captioned PNG meme.',
    });
  }

  static String _canonicalCommand(String command) {
    final trimmed = command.trim().toLowerCase();
    return switch (trimmed) {
      'create' ||
      'meme_maker_create' ||
      'meme-maker_create' =>
        'meme-maker.create',
      _ => trimmed,
    };
  }

  static String _caption(Object? value) {
    final normalized = value
            ?.toString()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .toUpperCase() ??
        '';
    return normalized.length <= 140 ? normalized : normalized.substring(0, 140);
  }

  static void _paintBackground(img.Image image) {
    img.fill(image, color: img.ColorRgb8(34, 39, 52));
    final stripe = (image.height / 8).round();
    for (var i = 0; i < 8; i++) {
      final color =
          i.isEven ? img.ColorRgb8(44, 52, 68) : img.ColorRgb8(30, 35, 48);
      img.fillRect(
        image,
        x1: 0,
        y1: i * stripe,
        x2: image.width - 1,
        y2: ((i + 1) * stripe).clamp(0, image.height - 1).toInt(),
        color: color,
      );
    }
    img.fillRect(
      image,
      x1: 40,
      y1: 40,
      x2: image.width - 41,
      y2: image.height - 41,
      color: img.ColorRgb8(58, 73, 88),
      radius: 36,
    );
    img.fillRect(
      image,
      x1: 64,
      y1: 64,
      x2: image.width - 65,
      y2: image.height - 65,
      color: img.ColorRgb8(92, 124, 142),
      radius: 28,
    );
  }

  static void _paintCaptionBand(img.Image image, {required bool top}) {
    final bandHeight = (image.height * 0.24).round();
    img.fillRect(
      image,
      x1: 0,
      y1: top ? 0 : image.height - bandHeight,
      x2: image.width - 1,
      y2: top ? bandHeight : image.height - 1,
      color: img.ColorRgba8(0, 0, 0, 185),
    );
  }

  static void _drawCaption(
    img.Image image,
    String caption, {
    required bool top,
  }) {
    if (caption.isEmpty) return;
    final font = img.arial48;
    final maxWidth = image.width - 96;
    final lines = _wrapCaption(caption, font, maxWidth).take(4).toList();
    if (lines.isEmpty) return;
    final lineHeight = font.lineHeight + 8;
    final blockHeight = lines.length * lineHeight;
    final startY = top
        ? 44
        : (image.height - 44 - blockHeight).clamp(0, image.height - 1).toInt();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final textWidth = _textWidth(line, font);
      final x = ((image.width - textWidth) / 2)
          .round()
          .clamp(12, image.width)
          .toInt();
      final y = startY + (i * lineHeight);
      _drawOutlinedString(image, line, x: x, y: y, font: font);
    }
  }

  static void _drawOutlinedString(
    img.Image image,
    String text, {
    required int x,
    required int y,
    required img.BitmapFont font,
  }) {
    final black = img.ColorRgb8(0, 0, 0);
    final white = img.ColorRgb8(255, 255, 255);
    for (final dx in const [-3, 0, 3]) {
      for (final dy in const [-3, 0, 3]) {
        if (dx == 0 && dy == 0) continue;
        img.drawString(
          image,
          text,
          font: font,
          x: x + dx,
          y: y + dy,
          color: black,
        );
      }
    }
    img.drawString(image, text, font: font, x: x, y: y, color: white);
  }

  static List<String> _wrapCaption(
    String caption,
    img.BitmapFont font,
    int maxWidth,
  ) {
    final words = caption.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (_textWidth(candidate, font) <= maxWidth) {
        current = candidate;
        continue;
      }
      if (current.isNotEmpty) lines.add(current);
      current = word;
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  static int _textWidth(String text, img.BitmapFont font) {
    var width = 0;
    for (final rune in text.runes) {
      width += font.characterXAdvance(String.fromCharCode(rune));
    }
    return width;
  }

  static int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
