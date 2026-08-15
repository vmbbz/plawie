/// Converts assistant display/Markdown text into natural speech input.
///
/// TTS providers receive plain prose, not the formatting language rendered by
/// the chat bubble. Keeping this policy in one place prevents the normal chat
/// and realtime Talk/PiP paths from speaking different versions of a reply.
class SpeechTextNormalizer {
  const SpeechTextNormalizer._();

  static String normalize(String text) {
    var value = text;
    if (value.trim().isEmpty) return '';

    // Internal assistant controls and model reasoning are never spoken.
    value = value.replaceAll(
      RegExp(
        r'\((?:gesture|image|tool|action)\s*:[^)]*\)\s*',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceAll(
      RegExp(
        r'^\s*(?:gesture|image|tool|action)\s*:\s*.*$',
        caseSensitive: false,
        multiLine: true,
      ),
      '',
    );
    value = value.replaceAll(
      RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false),
      '',
    );

    // Code and media are represented by short spoken labels or omitted.
    value = value.replaceAll(RegExp(r'```[\s\S]*?```'), 'code block. ');
    value = value.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
    value = value.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]*\)'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => match.group(1) ?? '',
    );

    // Remove Markdown structure before stripping residual punctuation. This
    // handles -, *, +, •, ‣, and numbered list markers, including a marker
    // with no following space. The old path missed several of these, allowing
    // speech providers to interpret a bullet as currency or punctuation.
    value = value.replaceAllMapped(
      RegExp(r'(^|\n)\s*[-*+•◦▪▫‣⁃∙·]\s*', multiLine: true),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAll(
      RegExp(r'^\s*\d{1,3}[.)]\s+', multiLine: true),
      '',
    );
    value = value.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
    value = value.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    value = value.replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '');
    value = value.replaceAll(RegExp(r'^\|.*\|$', multiLine: true), '');

    // Markdown emphasis and strike-through.
    value = value.replaceAllMapped(
      RegExp(r'\*{3}([^*\n]+)\*{3}'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAllMapped(
      RegExp(r'\*{2}([^*\n]+)\*{2}'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAllMapped(
      RegExp(r'\*([^*\n]+)\*'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAllMapped(
      RegExp(r'_{2}([^_\n]+)_{2}'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAllMapped(
      RegExp(r'_([^_\n]+)_'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAllMapped(
      RegExp(r'~~([^~]+)~~'),
      (match) => match.group(1) ?? '',
    );

    // URLs and table separators are not useful in spoken output.
    value = value.replaceAll(RegExp(r'https?://\S+'), 'link');
    value = value.replaceAll('|', ' ');
    value = value.replaceAll('[Error]', 'Error:');
    value = value.replaceAll('[Warning]', 'Warning:');
    value = value.replaceAll(RegExp(r'<[^>]+>'), '');

    // Preserve useful spoken equivalents for common symbols, then remove the
    // remaining formatting characters. A standalone '$' is deliberately
    // discarded so a bullet-like symbol cannot become "one dollar".
    value = value.replaceAllMapped(
      RegExp(r'\$(\d+(?:\.\d+)?)'),
      (match) {
        final amount = match.group(1)!;
        return amount == '1' ? '1 dollar' : '$amount dollars';
      },
    );
    value = value.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*%'),
      (match) => '${match.group(1)} percent',
    );
    value = value.replaceAll('&', ' and ');
    value = value.replaceAll('→', ' to ');
    value = value.replaceAll('←', ' ');
    value = value.replaceAll('↑', ' ');
    value = value.replaceAll('↓', ' ');
    value = value.replaceAll(RegExp(r'[—–]'), ', ');
    value = value.replaceAll(
      RegExp(r'[#%$*+=<>@\\^_`{}\[\]|~]'),
      ' ',
    );

    // Emojis and dingbats are visual UI content, not speech content.
    value = value.replaceAll(
      RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true),
      '',
    );
    value = value.replaceAll(
      RegExp(r'[\u{2600}-\u{27BF}]', unicode: true),
      '',
    );

    // Make line-based answers flow as prose and avoid awkward whitespace
    // around punctuation after removing their formatting.
    value = value.replaceAll(RegExp(r'[ \t]+'), ' ');
    value = value.replaceAll(RegExp(r'\s*\n\s*'), ' ');
    value = value.replaceAllMapped(
      RegExp(r'\s+([,.!?;:])'),
      (match) => match.group(1) ?? '',
    );
    return value.trim();
  }

  /// Stable per-turn key used to prevent an identical sentence being spoken
  /// more than once when a Gateway emits a replay/cumulative update.
  static String dedupeKey(String text) {
    final clean = normalize(text).toLowerCase();
    return clean
        .replaceAll(RegExp(r'[.!?,;:]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
