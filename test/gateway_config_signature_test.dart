import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/gateway_config_signature.dart';

void main() {
  test('object insertion order does not create a false config change', () {
    final persisted = <String, dynamic>{
      'models': <String, dynamic>{
        'providers': <String, dynamic>{
          'blockrun': <String, dynamic>{
            'api': 'openai-completions',
            'apiKey': 'private-loopback-capability',
            'baseUrl': 'http://127.0.0.1:11436/blockrun/v1',
            'models': <dynamic>[],
          },
        },
      },
    };
    final rebuiltByNativePolicy = <String, dynamic>{
      'models': <String, dynamic>{
        'providers': <String, dynamic>{
          'blockrun': <String, dynamic>{
            'api': 'openai-completions',
            'baseUrl': 'http://127.0.0.1:11436/blockrun/v1',
            'models': <dynamic>[],
            'apiKey': 'private-loopback-capability',
          },
        },
      },
    };

    expect(
      canonicalGatewayConfigSignature(rebuiltByNativePolicy),
      canonicalGatewayConfigSignature(persisted),
    );
  });

  test('array order and scalar changes remain meaningful', () {
    final first = <String, dynamic>{
      'tools': <String, dynamic>{
        'allow': <String>['nodes', 'canvas']
      },
    };
    final reordered = <String, dynamic>{
      'tools': <String, dynamic>{
        'allow': <String>['canvas', 'nodes']
      },
    };
    final changed = <String, dynamic>{
      'tools': <String, dynamic>{
        'allow': <String>['nodes']
      },
    };

    expect(
      canonicalGatewayConfigSignature(first),
      isNot(canonicalGatewayConfigSignature(reordered)),
    );
    expect(
      canonicalGatewayConfigSignature(first),
      isNot(canonicalGatewayConfigSignature(changed)),
    );
  });
}
