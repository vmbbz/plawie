import 'dart:typed_data';

import 'package:web3dart/crypto.dart';

/// Converts only historically possible Web3dart private-key encodings into a
/// canonical 32-byte secp256k1 scalar.
final class LegacyEvmKeyNormalizer {
  static final BigInt _curveOrder = BigInt.parse(
    'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
    radix: 16,
  );

  static Uint8List normalize(String serialized) {
    var clean = serialized;
    if (clean.startsWith('0x')) clean = clean.substring(2);
    if (clean.isEmpty ||
        clean.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]+$').hasMatch(clean)) {
      throw const FormatException('Legacy wallet key encoding is invalid.');
    }

    if (clean.length == 66) {
      if (!clean.startsWith('00')) {
        throw const FormatException('Legacy wallet key encoding is invalid.');
      }
      clean = clean.substring(2);
    }
    if (clean.length > 64) {
      throw const FormatException('Legacy wallet key encoding is invalid.');
    }

    clean = clean.padLeft(64, '0');
    final scalar = BigInt.parse(clean, radix: 16);
    if (scalar <= BigInt.zero || scalar >= _curveOrder) {
      throw const FormatException('Legacy wallet key scalar is invalid.');
    }
    return Uint8List.fromList(hexToBytes(clean));
  }
}
