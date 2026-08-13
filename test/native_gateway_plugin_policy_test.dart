import 'package:clawa/services/model_provider_catalog.dart';
import 'package:clawa/services/native_gateway_plugin_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const filesDir = '/data/user/0/com.openclaw.plawie/files';
  const verifiedId = 'plawie-venice-compat';
  const verifiedPath =
      '$filesDir/native-node-embedded/full-openclaw/verified-plugins/$verifiedId';

  test('rejects arbitrary plugin paths and install records without Venice', () {
    final config = <String, dynamic>{
      'plugins': <String, dynamic>{
        'allow': <String>['malicious'],
        'load': <String, dynamic>{
          'paths': <String>['/data/local/tmp/attacker-plugin'],
        },
        'installs': <String, dynamic>{
          'malicious': <String, dynamic>{'source': 'npm'},
        },
        'entries': <String, dynamic>{
          'malicious': <String, dynamic>{'enabled': true},
        },
        'slots': <String, dynamic>{'memory': 'malicious'},
      },
    };

    NativeGatewayPluginPolicy.apply(
      config,
      retainedProviderIds: const <String>{'openai'},
      filesDir: filesDir,
    );

    final plugins = config['plugins']! as Map<String, dynamic>;
    expect(plugins['allow'],
        ModelProviderCatalog.nativeGatewayBundledPluginIds.toList()..sort());
    expect(plugins, isNot(contains('load')));
    expect(plugins, isNot(contains('installs')));
    expect(plugins, isNot(contains('entries')));
    expect(plugins, isNot(contains('slots')));
  });

  test('enables only the fixed verified Venice plugin path', () {
    final config = <String, dynamic>{
      'plugins': <String, dynamic>{
        'load': <String, dynamic>{
          'paths': <String>['/sdcard/unverified'],
        },
        'entries': <String, dynamic>{
          'venice': <String, dynamic>{'enabled': true},
          'plawie-venice-compat': <String, dynamic>{
            'enabled': false,
            'config': <String, dynamic>{'unexpected': true},
          },
        },
      },
    };

    NativeGatewayPluginPolicy.apply(
      config,
      retainedProviderIds: const <String>{'venice'},
      filesDir: '$filesDir///',
    );

    final plugins = config['plugins']! as Map<String, dynamic>;
    final allow = plugins['allow']! as List<dynamic>;
    expect(allow, contains(verifiedId));
    expect(
      plugins['load'],
      <String, dynamic>{
        'paths': <String>[verifiedPath],
      },
    );
    expect(
      plugins['entries'],
      <String, dynamic>{
        verifiedId: const <String, dynamic>{'enabled': true},
      },
    );
    expect(plugins, isNot(contains('installs')));
  });
}
