import 'dart:convert';
import 'dart:typed_data';

import '../../models/node_frame.dart';
import 'capability_handler.dart';

class NanoPdfCapability extends CapabilityHandler {
  static const int _defaultMaxChars = 6000;
  static const int _maxPdfBytes = 1024 * 1024;

  @override
  String get name => 'nano-pdf';

  @override
  List<String> get commands => const ['extract'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command);
    if (canonical != 'nano-pdf.extract') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown nano-pdf command: $command',
      });
    }

    final bytesResult = _pdfBytes(params);
    if (bytesResult.error != null) {
      return NodeFrame.response('', error: bytesResult.error);
    }
    final bytes = bytesResult.bytes!;
    if (bytes.length > _maxPdfBytes) {
      return NodeFrame.response('', error: {
        'code': 'PDF_TOO_LARGE',
        'message': 'nano-pdf accepts PDFs up to $_maxPdfBytes bytes.',
      });
    }

    final raw = latin1.decode(bytes, allowInvalid: true);
    if (!raw.startsWith('%PDF-')) {
      return NodeFrame.response('', error: {
        'code': 'INVALID_PDF',
        'message': 'nano-pdf requires bytes starting with a PDF header.',
      });
    }
    if (RegExp(r'/Encrypt\b').hasMatch(raw)) {
      return NodeFrame.response('', error: {
        'code': 'ENCRYPTED_PDF',
        'message': 'Encrypted PDFs are not supported by app-native nano-pdf.',
      });
    }

    final maxChars = _intParam(params['maxChars'], _defaultMaxChars, 80, 20000);
    final extraction = _extractText(raw, maxChars);
    if (extraction.text.isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'NO_TEXT_FOUND',
        'message':
            'No simple text layer was found. Scanned or complex PDFs need a verified pack/OCR lane.',
        'runtime': 'app-native-pdf-text',
        'warnings': extraction.warnings,
      });
    }

    return NodeFrame.response('', payload: {
      'runtime': 'app-native-pdf-text',
      'mode': 'best-effort-text-pdf',
      'text': extraction.text,
      'chars': extraction.text.length,
      'maxChars': maxChars,
      'truncated': extraction.truncated,
      'bytes': bytes.length,
      'extractedBlockCount': extraction.blockCount,
      'warnings': extraction.warnings,
    });
  }

  static String _canonicalCommand(String command) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '-');
    return switch (normalized) {
      'nano-pdf' ||
      'nano-pdf.extract' ||
      'nano-pdf-extract' ||
      'extract' =>
        'nano-pdf.extract',
      _ => normalized,
    };
  }

  static _PdfBytesResult _pdfBytes(Map<String, dynamic> params) {
    final raw = (params['pdfBase64'] ?? params['base64'] ?? params['pdf'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) {
      return _PdfBytesResult(error: {
        'code': 'MISSING_PDF',
        'message': 'nano-pdf.extract requires pdfBase64 bytes.',
      });
    }
    try {
      return _PdfBytesResult(bytes: base64Decode(raw));
    } on FormatException {
      return _PdfBytesResult(error: {
        'code': 'INVALID_BASE64',
        'message': 'pdfBase64 is not valid base64.',
      });
    }
  }

  static _PdfTextExtraction _extractText(String raw, int maxChars) {
    final warnings = <String>[];
    final blocks = RegExp(
      r'BT\b(.*?)\bET',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(raw).map((match) => match.group(1) ?? '').toList();

    if (blocks.isEmpty) {
      warnings.add('No simple BT/ET text blocks were found.');
    }

    final pieces = <String>[];
    for (final block in blocks) {
      pieces.addAll(_literalStrings(block));
      pieces.addAll(_hexStrings(block));
    }

    final normalized = _normalizeWhitespace(pieces.join(' '));
    final fitted = _fit(normalized, maxChars);
    return _PdfTextExtraction(
      text: fitted.text,
      blockCount: blocks.length,
      truncated: fitted.truncated,
      warnings: [
        ...warnings,
        'Best-effort text-PDF extraction only; complex encodings and OCR are outside this adapter.',
      ],
    );
  }

  static List<String> _literalStrings(String block) {
    final results = <String>[];
    final pattern = RegExp(r'\((?:\\.|[^\\()])*\)', dotAll: true);
    for (final match in pattern.allMatches(block)) {
      final raw = match.group(0);
      if (raw == null || raw.length < 2) continue;
      results.add(_decodeLiteralString(raw.substring(1, raw.length - 1)));
    }
    return results;
  }

  static String _decodeLiteralString(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (char != r'\') {
        buffer.write(char);
        continue;
      }
      if (i + 1 >= value.length) break;
      final next = value[++i];
      switch (next) {
        case 'n':
          buffer.write(' ');
        case 'r':
          buffer.write(' ');
        case 't':
          buffer.write(' ');
        case 'b':
          buffer.write(' ');
        case 'f':
          buffer.write(' ');
        case '(':
        case ')':
        case r'\':
          buffer.write(next);
        default:
          buffer.write(next);
      }
    }
    return buffer.toString();
  }

  static List<String> _hexStrings(String block) {
    final results = <String>[];
    final pattern = RegExp(r'<([0-9A-Fa-f\s]{2,})>');
    for (final match in pattern.allMatches(block)) {
      final start = match.start;
      final end = match.end;
      if (start > 0 && block[start - 1] == '<') continue;
      if (end < block.length && block[end] == '>') continue;
      final raw = match.group(1)?.replaceAll(RegExp(r'\s+'), '') ?? '';
      if (raw.isEmpty) continue;
      final evenRaw = raw.length.isOdd ? '${raw}0' : raw;
      final bytes = <int>[];
      for (var i = 0; i < evenRaw.length; i += 2) {
        final byte = int.tryParse(evenRaw.substring(i, i + 2), radix: 16);
        if (byte != null) bytes.add(byte);
      }
      if (bytes.isNotEmpty) {
        results.add(latin1.decode(bytes, allowInvalid: true));
      }
    }
    return results;
  }

  static _FitResult _fit(String value, int maxChars) {
    if (value.length <= maxChars) {
      return _FitResult(text: value, truncated: false);
    }
    if (maxChars <= 3) {
      return _FitResult(text: value.substring(0, maxChars), truncated: true);
    }
    return _FitResult(
      text: '${value.substring(0, maxChars - 3).trimRight()}...',
      truncated: true,
    );
  }

  static String _normalizeWhitespace(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  static int _intParam(dynamic value, int fallback, int min, int max) {
    final parsed = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };
    return (parsed ?? fallback).clamp(min, max).toInt();
  }
}

class _PdfBytesResult {
  final Uint8List? bytes;
  final Map<String, dynamic>? error;

  const _PdfBytesResult({this.bytes, this.error});
}

class _PdfTextExtraction {
  final String text;
  final int blockCount;
  final bool truncated;
  final List<String> warnings;

  const _PdfTextExtraction({
    required this.text,
    required this.blockCount,
    required this.truncated,
    required this.warnings,
  });
}

class _FitResult {
  final String text;
  final bool truncated;

  const _FitResult({
    required this.text,
    required this.truncated,
  });
}
