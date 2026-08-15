import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/paid_provider_proxy_models.dart';

void main() {
  test('paid routes preserve Gateway context history tools and metadata', () {
    final original = <String, dynamic>{
      'model': 'vendor/model-id',
      'messages': <Map<String, dynamic>>[
        {'role': 'system', 'content': 'mobile system prompt'},
        {'role': 'user', 'content': 'first turn'},
        {
          'role': 'assistant',
          'content': null,
          'tool_calls': <Map<String, dynamic>>[
            {
              'id': 'call_1',
              'type': 'function',
              'function': {
                'name': 'device.status',
                'arguments': '{"detail":true}',
              },
            },
          ],
        },
        {
          'role': 'tool',
          'tool_call_id': 'call_1',
          'content': '{"ok":true}',
        },
        {'role': 'user', 'content': 'continue'},
      ],
      'tools': <Map<String, dynamic>>[
        {
          'type': 'function',
          'function': {
            'name': 'device.status',
            'description': 'Read bounded device status',
            'parameters': {
              'type': 'object',
              'properties': {
                'detail': {'type': 'boolean'},
              },
            },
          },
        },
      ],
      'tool_choice': 'auto',
      'stream': true,
      'stream_options': {'include_usage': true},
      'temperature': 0.1,
      'metadata': {
        'sessionId': 'mobile:chat:stable-session',
        'conversationId': 'conversation-1',
      },
    };
    final snapshot = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;

    for (final provider in PaidProviderId.values) {
      final mapped = PaidProviderRequestMapper.mapChatRequest(
        original,
        provider: provider,
      );
      expect(mapped, snapshot);
      expect(identical(mapped, original), isFalse);
    }
    expect(original, snapshot);
  });
}
