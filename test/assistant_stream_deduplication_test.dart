import 'package:clawa/services/gateway_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merges cumulative Gateway assistant snapshots once', () {
    expect(
      mergeAssistantStreamChunksForTesting([
        'The skill is ready',
        'The skill is ready and configured.',
        'The skill is ready and configured.',
      ]),
      'The skill is ready and configured.',
    );
  });

  test('does not duplicate a cumulative final after raw deltas', () {
    expect(
      mergeAssistantStreamChunksForTesting([
        'The skill',
        ' is ready.',
        'The skill is ready.',
      ]),
      'The skill is ready.',
    );
  });

  test('keeps genuine post-tool assistant segments', () {
    expect(
      mergeAssistantStreamChunksForTesting([
        'Checking now. ',
        'Found three results.',
      ]),
      'Checking now. Found three results.',
    );
  });

  test('deduplicates cumulative snapshots restarted after a tool phase', () {
    final merged = mergeAssistantStreamChunksForTesting([
      'The',
      'The top story titles were cut off. Let me fetch them properly.',
      'Here are',
      'Here are the current top stories on **Hacker News**',
      'Here are the current top stories on **Hacker News** '
          '(August 16, 2026):',
      'Here are the current top stories on **Hacker News** '
          '(August 16, 2026):\n\n1. First story',
    ]);

    expect(
      merged,
      'The top story titles were cut off. Let me fetch them properly.'
      'Here are the current top stories on **Hacker News** '
      '(August 16, 2026):\n\n1. First story',
    );
    expect(RegExp('Here are').allMatches(merged), hasLength(1));
  });

  test('ignores repeated and shrinking snapshots within a restarted segment', () {
    expect(
      mergeAssistantStreamChunksForTesting([
        'Checking the source. ',
        'The result',
        'The result is ready.',
        'The result is ready.',
        'The result',
      ]),
      'Checking the source. The result is ready.',
    );
  });
}
