import 'package:clawa/services/legacy_evm_key_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3dart/web3dart.dart';

void main() {
  const canonical =
      '8000000000000000000000000000000000000000000000000000000000000001';

  test('removes the historical ASN.1 zero sign byte', () {
    final normalized = LegacyEvmKeyNormalizer.normalize('00$canonical');
    expect(normalized, hasLength(32));
    expect(
      EthPrivateKey(normalized).address.hexEip55,
      EthPrivateKey.fromHex('00$canonical').address.hexEip55,
    );
  });

  test('left pads short historical scalar bytes', () {
    final normalized = LegacyEvmKeyNormalizer.normalize('01');
    expect(normalized, hasLength(32));
    expect(normalized.take(31), everyElement(0));
    expect(normalized.last, 1);
  });

  test('retains a canonical 32-byte scalar', () {
    expect(
      LegacyEvmKeyNormalizer.normalize(canonical),
      orderedEquals(EthPrivateKey.fromHex(canonical).privateKey),
    );
  });

  test('rejects formats outside the historical contract', () {
    final invalid = <String>[
      '',
      '0',
      'xyz0',
      '01$canonical',
      '0000$canonical',
      '00',
      'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    ];
    for (final value in invalid) {
      expect(
        () => LegacyEvmKeyNormalizer.normalize(value),
        throwsFormatException,
        reason: 'value length ${value.length}',
      );
    }
  });
}
