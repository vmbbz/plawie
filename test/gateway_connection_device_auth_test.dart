import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/gateway_connection.dart';

void main() {
  test(
    'classifies an early device signature rejection without a close code',
    () {
      expect(
        GatewayConnection.isDeviceAuthInvalidClose(
          closeCode: null,
          closeReason: 'Exception: device signature invalid',
        ),
        isTrue,
      );
    },
  );

  test('classifies the final 1008 device-auth close', () {
    expect(
      GatewayConnection.isDeviceAuthInvalidClose(
        closeCode: 1008,
        closeReason: 'device nonce mismatch',
      ),
      isTrue,
    );
  });

  test('does not misclassify pairing or transport failures', () {
    expect(
      GatewayConnection.isDeviceAuthInvalidClose(
        closeCode: 1008,
        closeReason: 'pairing required',
      ),
      isFalse,
    );
    expect(
      GatewayConnection.isDeviceAuthInvalidClose(
        closeCode: 1006,
        closeReason: 'abnormal closure',
      ),
      isFalse,
    );
  });
}
