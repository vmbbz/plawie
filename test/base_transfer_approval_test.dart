import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/base_service.dart';

void main() {
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
}
