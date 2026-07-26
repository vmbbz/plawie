import 'package:clawa/services/gateway_tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native mobile policy remains wildcard-first', () {
    expect(
      GatewayToolCatalog.defaultMobileAllowList,
      const [GatewayToolCatalog.wildcard],
    );
    expect(
      GatewayToolCatalog.defaultMobileToolsConfig(),
      {
        'profile': 'full',
        'allow': ['*'],
      },
    );
  });

  test('wildcard UI normalization preserves the full mobile capability view',
      () {
    expect(
      GatewayToolCatalog.normalizeAllowList(const ['*']),
      GatewayToolCatalog.primitiveIds,
    );
    expect(
      GatewayToolCatalog.normalizeAllowList(
        const ['*'],
        expandWildcard: false,
      ),
      const ['*'],
    );
  });
}
