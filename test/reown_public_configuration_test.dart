import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/bridge/reown_evm_wallet_adapter.dart';

void main() {
  test('reviewed Reown public metadata is production-shaped', () {
    expect(reownProjectId, 'b20414538d1c91f0697cc92149003107');
    expect(plawieDappUrl, 'https://plawie.app');
    expect(walletRedirect, 'plawie://wallet-callback');
    expect(reownReleaseConfigured, isTrue);
  });
}
