import 'dart:convert';
import 'dart:typed_data';

import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/solana_transaction_envelope.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/solana_transaction_fixture.dart';

void main() {
  const envelope = SolanaTransactionEnvelope();

  test('inspects exact legacy and versioned messages', () async {
    for (final versioned in <bool>[false, true]) {
      final fixture =
          await SolanaTransactionFixture.create(versioned: versioned);
      final inspection = envelope.inspect(
        SolanaBridgeExecutionPayload(
          from: fixture.signer,
          base64Transaction: fixture.unsignedBase64,
        ),
      );

      expect(inspection.messageBytes, fixture.message);
      expect(
        inspection.messageSha256,
        sha256.convert(fixture.message).toString(),
      );
      expect(inspection.firstRequiredSigner, fixture.signer);
      expect(inspection.recentBlockhash, fixture.blockhash);
    }
  });

  test('verifies exact signed bytes and derives the first signature', () async {
    final fixture = await SolanaTransactionFixture.create();
    final reviewed = SolanaBridgeExecutionPayload(
      from: fixture.signer,
      base64Transaction: fixture.unsignedBase64,
    );

    final verified = await envelope.verifySigned(
      reviewed: reviewed,
      signedTransaction: fixture.signedTransaction,
    );

    expect(verified.transactionBytes, fixture.signedTransaction);
    expect(verified.signature, fixture.signature);
  });

  test('rejects a changed message, signer, missing or invalid signature',
      () async {
    final fixture = await SolanaTransactionFixture.create();
    final reviewed = SolanaBridgeExecutionPayload(
      from: fixture.signer,
      base64Transaction: fixture.unsignedBase64,
    );
    final changedMessage = Uint8List.fromList(fixture.signedTransaction);
    changedMessage[101] ^= 1;
    final wrongSignature = Uint8List.fromList(fixture.signedTransaction);
    wrongSignature[1] ^= 1;

    await expectLater(
      envelope.verifySigned(
        reviewed: reviewed,
        signedTransaction: changedMessage,
      ),
      throwsA(_bridgeCode('solana_message_changed')),
    );
    await expectLater(
      envelope.verifySigned(
        reviewed: reviewed,
        signedTransaction: fixture.unsignedTransaction,
      ),
      throwsA(_bridgeCode('solana_signature_missing')),
    );
    await expectLater(
      envelope.verifySigned(
        reviewed: reviewed,
        signedTransaction: wrongSignature,
      ),
      throwsA(_bridgeCode('solana_signature_invalid')),
    );
    expect(
      () => envelope.inspect(
        SolanaBridgeExecutionPayload(
          from: base58Encode(List<int>.filled(32, 9)),
          base64Transaction: fixture.unsignedBase64,
        ),
      ),
      throwsA(_bridgeCode('solana_signer_changed')),
    );
  });

  test('verifies a sign-and-send signature over the frozen message', () async {
    final fixture = await SolanaTransactionFixture.create(versioned: true);
    final reviewed = SolanaBridgeExecutionPayload(
      from: fixture.signer,
      base64Transaction: fixture.unsignedBase64,
    );

    expect(
      await envelope.verifySubmittedSignature(
        reviewed: reviewed,
        signature: fixture.signature,
      ),
      fixture.signature,
    );

    final changed = Uint8List.fromList(base64Decode(fixture.unsignedBase64));
    changed[102] ^= 1;
    await expectLater(
      envelope.verifySubmittedSignature(
        reviewed: SolanaBridgeExecutionPayload(
          from: fixture.signer,
          base64Transaction: base64Encode(changed),
        ),
        signature: fixture.signature,
      ),
      throwsA(_bridgeCode('solana_signature_invalid')),
    );
  });

  test('verifies recovered bytes against the persisted signer and message hash',
      () async {
    final fixture = await SolanaTransactionFixture.create(versioned: true);

    final recovered = await envelope.verifyRecovered(
      transactionBytes: fixture.signedTransaction,
      expectedSigner: fixture.signer,
      expectedMessageSha256: sha256.convert(fixture.message).toString(),
    );

    expect(recovered.signature, fixture.signature);
    expect(recovered.transactionBytes, fixture.signedTransaction);
    await expectLater(
      envelope.verifyRecovered(
        transactionBytes: fixture.signedTransaction,
        expectedSigner: fixture.signer,
        expectedMessageSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      throwsA(_bridgeCode('solana_message_changed')),
    );
  });

  test('accepts the 1232-byte boundary and rejects larger transactions',
      () async {
    final fixture = await SolanaTransactionFixture.create(
      instructionDataLength: 1094,
    );
    expect(fixture.unsignedTransaction, hasLength(1232));
    expect(
      envelope
          .inspect(
            SolanaBridgeExecutionPayload(
              from: fixture.signer,
              base64Transaction: fixture.unsignedBase64,
            ),
          )
          .messageBytes,
      fixture.message,
    );

    final oversized = Uint8List.fromList(<int>[
      ...fixture.unsignedTransaction,
      0,
    ]);
    expect(
      () => envelope.inspect(
        SolanaBridgeExecutionPayload(
          from: fixture.signer,
          base64Transaction: base64Encode(oversized),
        ),
      ),
      throwsA(_bridgeCode('invalid_solana_transaction')),
    );
  });

  test('base58 is bounded and compact-u16 must be canonical', () async {
    const bytes = <int>[0, 0, 1, 2, 3, 254, 255];
    final encoded = envelope.base58Encode(bytes);
    expect(envelope.base58Decode(encoded, expectedLength: bytes.length), bytes);
    expect(
      () => envelope.base58Decode('0OIl'),
      throwsA(_bridgeCode('invalid_solana_base58')),
    );
    expect(
      () => envelope.base58Decode('1' * 1000),
      throwsA(_bridgeCode('invalid_solana_base58')),
    );

    final fixture = await SolanaTransactionFixture.create();
    final nonCanonical = Uint8List.fromList(<int>[
      0x81,
      0x00,
      ...fixture.unsignedTransaction.skip(1),
    ]);
    expect(
      () => envelope.inspect(
        SolanaBridgeExecutionPayload(
          from: fixture.signer,
          base64Transaction: base64Encode(nonCanonical),
        ),
      ),
      throwsA(_bridgeCode('invalid_solana_transaction')),
    );
  });
}

Matcher _bridgeCode(String code) => isA<BridgeValidationException>()
    .having((error) => error.code, 'code', code);
