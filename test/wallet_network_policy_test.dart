import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/base_service.dart';

void main() {
  test('wallet network policy keeps exact chain and asset identities', () {
    expect(WalletNetworkPolicy.baseMainnet.chainId, 8453);
    expect(WalletNetworkPolicy.baseMainnet.nativeSymbol, 'ETH');
    expect(WalletNetworkPolicy.baseMainnet.token?.symbol, 'USDC');
    expect(WalletNetworkPolicy.robinhoodMainnet.chainId, 4663);
    expect(WalletNetworkPolicy.robinhoodMainnet.nativeSymbol, 'ETH');
    expect(WalletNetworkPolicy.robinhoodMainnet.token?.symbol, 'USDG');
    expect(
      WalletNetworkPolicy.robinhoodMainnet.token?.contract.toLowerCase(),
      '0x5fc5360d0400a0fd4f2af552add042d716f1d168',
    );
    expect(WalletNetworkPolicy.robinhoodMainnet.supportsX402, isFalse);
    expect(WalletNetworkPolicy.baseMainnet.supportsX402, isTrue);
  });

  test('Base is the default while legacy Sepolia remains recoverable', () {
    expect(
      WalletNetworkPolicy.decodePreference(
        current: null,
        legacySepolia: 'true',
      ),
      WalletNetwork.baseSepolia,
    );
    expect(
      WalletNetworkPolicy.decodePreference(
        current: 'robinhood_mainnet',
        legacySepolia: 'true',
      ),
      WalletNetwork.robinhoodMainnet,
    );
    expect(
      WalletNetworkPolicy.decodePreference(
        current: 'unknown',
        legacySepolia: 'false',
      ),
      WalletNetwork.baseMainnet,
    );
    expect(
      WalletNetworkPolicy.decodePreference(
        current: null,
        legacySepolia: null,
      ),
      WalletNetwork.baseMainnet,
    );
  });

  test('release RPC validation accepts only uncredentialed HTTPS URLs', () {
    expect(
      WalletNetworkPolicy.isValidReleaseRpc(
        'https://robinhood-mainnet.example/v2/project',
      ),
      isTrue,
    );
    expect(
      WalletNetworkPolicy.isValidReleaseRpc('http://rpc.example'),
      isFalse,
    );
    expect(
      WalletNetworkPolicy.isValidReleaseRpc(
        'https://user:password@rpc.example',
      ),
      isFalse,
    );
  });
}
