import 'package:clawa/services/speech_text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes Markdown bullets and standalone symbols from speech', () {
    expect(
      SpeechTextNormalizer.normalize(
        '• First item\n- Second item\n* Third item\n1. Fourth item\n• \u0024',
      ),
      'First item Second item Third item Fourth item',
    );
  });

  test('keeps useful prose while removing formatting wrappers', () {
    expect(
      SpeechTextNormalizer.normalize(
        '## **Ready** → [open the guide](https://example.com)',
      ),
      'Ready to open the guide',
    );
  });

  test('speaks numeric currency and percentages naturally', () {
    expect(
      SpeechTextNormalizer.normalize('The total is \u00241 and the fee is 5%.'),
      'The total is 1 dollar and the fee is 5 percent.',
    );
  });

  test('dedupe keys ignore case and sentence punctuation', () {
    expect(
      SpeechTextNormalizer.dedupeKey('The service is ready!'),
      SpeechTextNormalizer.dedupeKey('the service is ready.'),
    );
  });
}
