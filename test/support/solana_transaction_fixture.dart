import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

final class SolanaTransactionFixture {
  const SolanaTransactionFixture({
    required this.signer,
    required this.blockhash,
    required this.message,
    required this.unsignedTransaction,
    required this.signedTransaction,
    required this.signature,
  });

  final String signer;
  final String blockhash;
  final Uint8List message;
  final Uint8List unsignedTransaction;
  final Uint8List signedTransaction;
  final String signature;

  String get unsignedBase64 => base64Encode(unsignedTransaction);

  static Future<SolanaTransactionFixture> create({
    bool versioned = false,
    int instructionDataLength = 0,
  }) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 1),
    );
    final publicKey = await keyPair.extractPublicKey();
    final blockhashBytes = Uint8List.fromList(
      List<int>.generate(32, (index) => 255 - index),
    );
    final instructions = instructionDataLength == 0
        ? const <int>[0]
        : <int>[
            1,
            0,
            0,
            ...compactU16(instructionDataLength),
            ...List<int>.filled(instructionDataLength, 7),
          ];
    final message = Uint8List.fromList(<int>[
      if (versioned) 0x80,
      1,
      0,
      0,
      1,
      ...publicKey.bytes,
      ...blockhashBytes,
      ...instructions,
      if (versioned) 0,
    ]);
    final signedMessage = await algorithm.sign(message, keyPair: keyPair);
    final unsigned = Uint8List.fromList(<int>[
      1,
      ...List<int>.filled(64, 0),
      ...message,
    ]);
    final signed = Uint8List.fromList(<int>[
      1,
      ...signedMessage.bytes,
      ...message,
    ]);
    return SolanaTransactionFixture(
      signer: base58Encode(publicKey.bytes),
      blockhash: base58Encode(blockhashBytes),
      message: message,
      unsignedTransaction: unsigned,
      signedTransaction: signed,
      signature: base58Encode(signedMessage.bytes),
    );
  }
}

List<int> compactU16(int value) {
  if (value < 0 || value > 0xffff) {
    throw RangeError.range(value, 0, 0xffff, 'value');
  }
  final bytes = <int>[];
  var remaining = value;
  do {
    var byte = remaining & 0x7f;
    remaining >>= 7;
    if (remaining != 0) byte |= 0x80;
    bytes.add(byte);
  } while (remaining != 0);
  return bytes;
}

String base58Encode(List<int> bytes) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  if (bytes.isEmpty) return '';
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  final encoded = <String>[];
  while (value > BigInt.zero) {
    final remainder = (value % BigInt.from(58)).toInt();
    encoded.add(alphabet[remainder]);
    value ~/= BigInt.from(58);
  }
  for (final byte in bytes) {
    if (byte != 0) break;
    encoded.add(alphabet[0]);
  }
  return encoded.reversed.join();
}
