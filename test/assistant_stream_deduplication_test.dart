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
}
