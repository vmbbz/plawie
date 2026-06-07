import '../../models/node_frame.dart';
import 'capability_handler.dart';

class SummarizeCapability extends CapabilityHandler {
  static const int _defaultMaxSentences = 3;
  static const int _defaultMaxChars = 600;
  static const int _maxInputChars = 20000;

  @override
  String get name => 'summarize';

  @override
  List<String> get commands => const ['text'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command);
    if (canonical != 'summarize.text') {
      return NodeFrame.response('', error: {
        'code': 'UNKNOWN_COMMAND',
        'message': 'Unknown summarize command: $command',
      });
    }

    final rawText = _textFromParams(params);
    if (rawText == null || rawText.trim().isEmpty) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_TEXT',
        'message': 'summarize.text requires provided text.',
      });
    }

    final normalized = _normalizeWhitespace(rawText);
    final truncatedInput = normalized.length > _maxInputChars;
    final input = truncatedInput
        ? normalized.substring(0, _maxInputChars).trim()
        : normalized;
    final maxSentences =
        _intParam(params['maxSentences'], _defaultMaxSentences, 1, 8);
    final maxChars = _intParam(params['maxChars'], _defaultMaxChars, 80, 2000);
    final sentences = _sentences(input);
    final selected = _selectSentences(sentences, maxSentences);
    final summary = _fitToMaxChars(selected, maxChars);

    return NodeFrame.response('', payload: {
      'runtime': 'app-native-extractive-summary',
      'mode': 'extractive',
      'summary': summary,
      'sentenceCount': summary.isEmpty ? 0 : selected.length,
      'inputChars': normalized.length,
      'summaryChars': summary.length,
      'truncatedInput': truncatedInput,
      'maxSentences': maxSentences,
      'maxChars': maxChars,
    });
  }

  static String _canonicalCommand(String command) {
    final normalized = command.trim().toLowerCase().replaceAll('_', '.');
    return switch (normalized) {
      'summarize' || 'text' || 'summarize.text' => 'summarize.text',
      _ => normalized,
    };
  }

  static String? _textFromParams(Map<String, dynamic> params) {
    final value = params['text'] ?? params['content'] ?? params['input'];
    return value?.toString();
  }

  static String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int _intParam(dynamic value, int fallback, int min, int max) {
    final parsed = switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()),
      _ => null,
    };
    return (parsed ?? fallback).clamp(min, max).toInt();
  }

  static List<String> _sentences(String text) {
    final sentences = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);
      if (char == '.' || char == '!' || char == '?') {
        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) sentences.add(sentence);
        buffer.clear();
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) sentences.add(tail);
    return sentences.isEmpty ? <String>[text] : sentences;
  }

  static List<String> _selectSentences(List<String> sentences, int maxCount) {
    if (sentences.length <= maxCount) return sentences;
    final frequencies = <String, int>{};
    for (final sentence in sentences) {
      for (final token in _tokens(sentence)) {
        frequencies[token] = (frequencies[token] ?? 0) + 1;
      }
    }

    final scored = <_ScoredSentence>[];
    for (var i = 0; i < sentences.length; i++) {
      final score = _tokens(sentences[i]).fold<int>(0, (sum, token) {
        final frequency = frequencies[token] ?? 0;
        return sum + (frequency > 1 ? frequency * 4 : 1);
      });
      scored.add(_ScoredSentence(index: i, score: score));
    }
    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      return scoreCompare != 0 ? scoreCompare : a.index.compareTo(b.index);
    });

    final selectedIndexes = scored
        .take(maxCount)
        .map((item) => item.index)
        .toList(growable: false)
      ..sort();
    return selectedIndexes.map((index) => sentences[index]).toList();
  }

  static Iterable<String> _tokens(String sentence) {
    return RegExp(r'[A-Za-z0-9]+')
        .allMatches(sentence.toLowerCase())
        .map((match) => match.group(0)!)
        .where((token) => token.length >= 3 && !_stopWords.contains(token));
  }

  static String _fitToMaxChars(List<String> sentences, int maxChars) {
    final joined = sentences.join(' ').trim();
    if (joined.length <= maxChars) return joined;

    final kept = <String>[];
    for (final sentence in sentences) {
      final candidate = [...kept, sentence].join(' ').trim();
      if (candidate.length > maxChars) break;
      kept.add(sentence);
    }
    if (kept.isNotEmpty) return kept.join(' ');

    if (maxChars <= 3) return joined.substring(0, maxChars);
    return '${joined.substring(0, maxChars - 3).trimRight()}...';
  }

  static const Set<String> _stopWords = {
    'the',
    'and',
    'for',
    'that',
    'this',
    'with',
    'from',
    'into',
    'only',
    'are',
    'was',
    'were',
    'have',
    'has',
    'had',
    'not',
    'but',
    'can',
    'will',
    'should',
    'would',
    'could',
    'about',
    'after',
    'before',
    'through',
    'using',
  };
}

class _ScoredSentence {
  final int index;
  final int score;

  const _ScoredSentence({
    required this.index,
    required this.score,
  });
}
