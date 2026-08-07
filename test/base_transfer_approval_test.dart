import 'package:decimal/decimal.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/base_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  tearDown(() async {
    await BaseService().setWalletNetwork(WalletNetwork.baseMainnet);
  });

  test('visible transfer approval is exact and one-use', () {
    final service = BaseService();
    final approval = service.issueVisibleTransferApproval(
      action: 'send_usdc',
      destination: '0x0000000000000000000000000000000000000001',
      amount: Decimal.parse('0.25'),
    );

    expect(
      service.consumeVisibleTransferApproval(
        approval,
        action: 'send_usdc',
        destination: '0x0000000000000000000000000000000000000001',
        amount: Decimal.parse('0.25'),
      ),
      isTrue,
    );
    expect(approval.consumed, isTrue);
    expect(
      service.consumeVisibleTransferApproval(
        approval,
        action: 'send_usdc',
        destination: '0x0000000000000000000000000000000000000001',
        amount: Decimal.parse('0.25'),
      ),
      isFalse,
    );
  });

  test('approval cannot be rebound to another transfer', () {
    final service = BaseService();
    final approval = service.issueVisibleTransferApproval(
      action: 'send_eth',
      destination: '0x0000000000000000000000000000000000000002',
      amount: Decimal.parse('0.01'),
    );

    expect(
      service.consumeVisibleTransferApproval(
        approval,
        action: 'send_usdc',
        destination: '0x0000000000000000000000000000000000000002',
        amount: Decimal.parse('0.01'),
      ),
      isFalse,
    );
    expect(
      service.consumeVisibleTransferApproval(
        approval,
        action: 'send_eth',
        destination: '0x0000000000000000000000000000000000000003',
        amount: Decimal.parse('0.01'),
      ),
      isFalse,
    );
    expect(
      service.consumeVisibleTransferApproval(
        approval,
        action: 'send_eth',
        destination: '0x0000000000000000000000000000000000000002',
        amount: Decimal.parse('0.01'),
      ),
      isTrue,
    );
  });

  test('approval is invalid after switching wallet networks', () async {
    final service = BaseService();
    await service.setWalletNetwork(WalletNetwork.baseMainnet);
    final approval = service.issueVisibleTransferApproval(
      action: 'send_eth',
      destination: '0x0000000000000000000000000000000000000002',
      amount: Decimal.parse('0.01'),
    );

    await service.setWalletNetwork(WalletNetwork.robinhoodMainnet);

    expect(
      service.consumeVisibleTransferApproval(
        approval,
        action: 'send_eth',
        destination: '0x0000000000000000000000000000000000000002',
        amount: Decimal.parse('0.01'),
      ),
      isFalse,
    );
  });

  test('USDG approval is distinct from Base USDC approval', () async {
    final service = BaseService();
    await service.setWalletNetwork(WalletNetwork.robinhoodMainnet);
    final approval = service.issueVisibleTransferApproval(
      action: 'send_usdg',
      destination: '0x0000000000000000000000000000000000000002',
      amount: Decimal.parse('1'),
    );

    expect(
      service.consumeVisibleTransferApproval(
        approval,
        action: 'send_usdc',
        destination: '0x0000000000000000000000000000000000000002',
        amount: Decimal.parse('1'),
      ),
      isFalse,
    );
    expect(
      service.consumeVisibleTransferApproval(
        approval,
        action: 'send_usdg',
        destination: '0x0000000000000000000000000000000000000002',
        amount: Decimal.parse('1'),
      ),
      isTrue,
    );
  });
}
