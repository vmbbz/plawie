import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'bridge_models.dart';

final class SolanaTransactionInspection {
  const SolanaTransactionInspection({
    required this.transactionBytes,
    required this.messageBytes,
    required this.messageSha256,
    required this.firstRequiredSigner,
    required this.recentBlockhash,
  });

  final Uint8List transactionBytes;
  final Uint8List messageBytes;
  final String messageSha256;
  final String firstRequiredSigner;
  final String recentBlockhash;
}

final class SolanaVerifiedTransaction {
  const SolanaVerifiedTransaction({
    required this.transactionBytes,
    required this.signature,
  });

  final Uint8List transactionBytes;
  final String signature;
}

final class SolanaTransactionEnvelope {
  const SolanaTransactionEnvelope();

  static const int maximumTransactionBytes = 1232;
  static const int _signatureBytes = 64;
  static const int _publicKeyBytes = 32;
  static const int _maximumBase58Bytes = 128;
  static const int _maximumBase58Chars = 180;
  static const String _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  SolanaTransactionInspection inspect(SolanaBridgeExecutionPayload reviewed) {
    final transaction = _decodeCanonicalTransaction(
      reviewed.base64Transaction,
    );
    final parsed = _parseTransaction(transaction);
    final expectedSigner = base58Decode(
      reviewed.from,
      expectedLength: _publicKeyBytes,
    );
    if (!_constantTimeEqual(parsed.firstRequiredSigner, expectedSigner)) {
      throw const BridgeValidationException('solana_signer_changed');
    }
    return SolanaTransactionInspection(
      transactionBytes: Uint8List.fromList(transaction),
      messageBytes: Uint8List.fromList(parsed.message),
      messageSha256: sha256.convert(parsed.message).toString(),
      firstRequiredSigner: base58Encode(parsed.firstRequiredSigner),
      recentBlockhash: base58Encode(parsed.recentBlockhash),
    );
  }

  Future<SolanaVerifiedTransaction> verifySigned({
    required SolanaBridgeExecutionPayload reviewed,
    required Uint8List signedTransaction,
  }) async {
    final inspected = inspect(reviewed);
    final parsedSigned = _parseTransaction(signedTransaction);
    if (!_constantTimeEqual(inspected.messageBytes, parsedSigned.message)) {
      throw const BridgeValidationException('solana_message_changed');
    }
    final expectedSigner = base58Decode(
      reviewed.from,
      expectedLength: _publicKeyBytes,
    );
    if (!_constantTimeEqual(
      parsedSigned.firstRequiredSigner,
      expectedSigner,
    )) {
      throw const BridgeValidationException('solana_signer_changed');
    }
    final signature = parsedSigned.signatures.first;
    if (signature.every((byte) => byte == 0)) {
      throw const BridgeValidationException('solana_signature_missing');
    }
    if (!await _verifySignature(
      message: parsedSigned.message,
      signer: parsedSigned.firstRequiredSigner,
      signature: signature,
    )) {
      throw const BridgeValidationException('solana_signature_invalid');
    }
    return SolanaVerifiedTransaction(
      transactionBytes: Uint8List.fromList(signedTransaction),
      signature: base58Encode(signature),
    );
  }

  Future<String> verifySubmittedSignature({
    required SolanaBridgeExecutionPayload reviewed,
    required String signature,
  }) async {
    final inspected = inspect(reviewed);
    final signatureBytes = base58Decode(
      signature,
      expectedLength: _signatureBytes,
    );
    final signer = base58Decode(
      inspected.firstRequiredSigner,
      expectedLength: _publicKeyBytes,
    );
    if (!await _verifySignature(
      message: inspected.messageBytes,
      signer: signer,
      signature: signatureBytes,
    )) {
      throw const BridgeValidationException('solana_signature_invalid');
    }
    return base58Encode(signatureBytes);
  }

  Future<SolanaVerifiedTransaction> verifyRecovered({
    required Uint8List transactionBytes,
    required String expectedSigner,
    required String expectedMessageSha256,
  }) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedMessageSha256)) {
      throw const BridgeValidationException('invalid_reviewed_payload_hash');
    }
    final parsed = _parseTransaction(transactionBytes);
    final signer = base58Decode(
      expectedSigner,
      expectedLength: _publicKeyBytes,
    );
    if (!_constantTimeEqual(parsed.firstRequiredSigner, signer)) {
      throw const BridgeValidationException('solana_signer_changed');
    }
    if (sha256.convert(parsed.message).toString() != expectedMessageSha256) {
      throw const BridgeValidationException('solana_message_changed');
    }
    final signature = parsed.signatures.first;
    if (signature.every((byte) => byte == 0)) {
      throw const BridgeValidationException('solana_signature_missing');
    }
    if (!await _verifySignature(
      message: parsed.message,
      signer: parsed.firstRequiredSigner,
      signature: signature,
    )) {
      throw const BridgeValidationException('solana_signature_invalid');
    }
    return SolanaVerifiedTransaction(
      transactionBytes: Uint8List.fromList(transactionBytes),
      signature: base58Encode(signature),
    );
  }

  String base58Encode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > _maximumBase58Bytes) {
      throw const BridgeValidationException('invalid_solana_base58');
    }
    var value = BigInt.zero;
    for (final byte in bytes) {
      if (byte < 0 || byte > 255) {
        throw const BridgeValidationException('invalid_solana_base58');
      }
      value = (value << 8) | BigInt.from(byte);
    }
    final encoded = <String>[];
    while (value > BigInt.zero) {
      final remainder = (value % BigInt.from(58)).toInt();
      encoded.add(_base58Alphabet[remainder]);
      value ~/= BigInt.from(58);
    }
    for (final byte in bytes) {
      if (byte != 0) break;
      encoded.add(_base58Alphabet[0]);
    }
    return encoded.reversed.join();
  }

  Uint8List base58Decode(String encoded, {int? expectedLength}) {
    if (encoded.isEmpty ||
        encoded.length > _maximumBase58Chars ||
        (expectedLength != null &&
            (expectedLength < 1 || expectedLength > _maximumBase58Bytes))) {
      throw const BridgeValidationException('invalid_solana_base58');
    }
    var value = BigInt.zero;
    for (final character in encoded.codeUnits) {
      final index = _base58Alphabet.indexOf(String.fromCharCode(character));
      if (index < 0) {
        throw const BridgeValidationException('invalid_solana_base58');
      }
      value = value * BigInt.from(58) + BigInt.from(index);
    }
    final decoded = <int>[];
    while (value > BigInt.zero) {
      decoded.add((value & BigInt.from(0xff)).toInt());
      value >>= 8;
      if (decoded.length > _maximumBase58Bytes) {
        throw const BridgeValidationException('invalid_solana_base58');
      }
    }
    for (final character in encoded.codeUnits) {
      if (character != _base58Alphabet.codeUnitAt(0)) break;
      decoded.add(0);
    }
    final bytes = Uint8List.fromList(decoded.reversed.toList());
    if (bytes.isEmpty ||
        bytes.length > _maximumBase58Bytes ||
        (expectedLength != null && bytes.length != expectedLength)) {
      throw const BridgeValidationException('invalid_solana_base58');
    }
    return bytes;
  }

  Uint8List _decodeCanonicalTransaction(String encoded) {
    try {
      final decoded = base64Decode(encoded);
      if (decoded.isEmpty ||
          decoded.length > maximumTransactionBytes ||
          base64Encode(decoded) != encoded) {
        throw const BridgeValidationException('invalid_solana_transaction');
      }
      return Uint8List.fromList(decoded);
    } on BridgeValidationException {
      rethrow;
    } on FormatException {
      throw const BridgeValidationException('invalid_solana_transaction');
    }
  }

  _ParsedSolanaTransaction _parseTransaction(List<int> bytes) {
    try {
      if (bytes.isEmpty || bytes.length > maximumTransactionBytes) {
        throw const BridgeValidationException('invalid_solana_transaction');
      }
      final cursor = _Cursor(bytes);
      final signatureCount = cursor.compactU16();
      if (signatureCount < 1 || signatureCount > 255) {
        throw const BridgeValidationException('invalid_solana_transaction');
      }
      final signatures = <Uint8List>[
        for (var index = 0; index < signatureCount; index += 1)
          cursor.bytes(_signatureBytes),
      ];
      final message = cursor.remainingBytes();
      if (message.isEmpty) {
        throw const BridgeValidationException('invalid_solana_transaction');
      }
      final messageCursor = _Cursor(message);
      final first = messageCursor.byte();
      final versioned = (first & 0x80) != 0;
      int requiredSignatures;
      if (versioned) {
        if ((first & 0x7f) != 0) {
          throw const BridgeValidationException('invalid_solana_transaction');
        }
        requiredSignatures = messageCursor.byte();
      } else {
        requiredSignatures = first;
      }
      final readOnlySigned = messageCursor.byte();
      final readOnlyUnsigned = messageCursor.byte();
      final accountCount = messageCursor.compactU16();
      if (requiredSignatures < 1 ||
          signatureCount != requiredSignatures ||
          accountCount < requiredSignatures ||
          readOnlySigned > requiredSignatures ||
          readOnlyUnsigned > accountCount - requiredSignatures) {
        throw const BridgeValidationException('invalid_solana_transaction');
      }
      final accounts = <Uint8List>[
        for (var index = 0; index < accountCount; index += 1)
          messageCursor.bytes(_publicKeyBytes),
      ];
      final recentBlockhash = messageCursor.bytes(_publicKeyBytes);
      final instructionCount = messageCursor.compactU16();
      for (var index = 0; index < instructionCount; index += 1) {
        messageCursor.byte();
        final accountIndexes = messageCursor.compactU16();
        messageCursor.skip(accountIndexes);
        final dataLength = messageCursor.compactU16();
        messageCursor.skip(dataLength);
      }
      if (versioned) {
        final lookupCount = messageCursor.compactU16();
        for (var index = 0; index < lookupCount; index += 1) {
          messageCursor.skip(_publicKeyBytes);
          messageCursor.skip(messageCursor.compactU16());
          messageCursor.skip(messageCursor.compactU16());
        }
      }
      if (!messageCursor.isAtEnd) {
        throw const BridgeValidationException('invalid_solana_transaction');
      }
      return _ParsedSolanaTransaction(
        signatures: signatures,
        message: message,
        firstRequiredSigner: accounts.first,
        recentBlockhash: recentBlockhash,
      );
    } on BridgeValidationException {
      rethrow;
    } on RangeError {
      throw const BridgeValidationException('invalid_solana_transaction');
    }
  }

  Future<bool> _verifySignature({
    required List<int> message,
    required List<int> signer,
    required List<int> signature,
  }) =>
      Ed25519().verify(
        message,
        signature: Signature(
          signature,
          publicKey: SimplePublicKey(signer, type: KeyPairType.ed25519),
        ),
      );
}

final class _ParsedSolanaTransaction {
  const _ParsedSolanaTransaction({
    required this.signatures,
    required this.message,
    required this.firstRequiredSigner,
    required this.recentBlockhash,
  });

  final List<Uint8List> signatures;
  final Uint8List message;
  final Uint8List firstRequiredSigner;
  final Uint8List recentBlockhash;
}

final class _Cursor {
  _Cursor(this._bytes);

  final List<int> _bytes;
  int _offset = 0;

  bool get isAtEnd => _offset == _bytes.length;

  int byte() {
    if (_offset >= _bytes.length) {
      throw const BridgeValidationException('invalid_solana_transaction');
    }
    return _bytes[_offset++];
  }

  Uint8List bytes(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw const BridgeValidationException('invalid_solana_transaction');
    }
    final result = Uint8List.fromList(
      _bytes.sublist(_offset, _offset + length),
    );
    _offset += length;
    return result;
  }

  void skip(int length) {
    bytes(length);
  }

  Uint8List remainingBytes() => bytes(_bytes.length - _offset);

  int compactU16() {
    var value = 0;
    var shift = 0;
    var length = 0;
    while (true) {
      if (length == 3) {
        throw const BridgeValidationException('invalid_solana_transaction');
      }
      final current = byte();
      final payload = current & 0x7f;
      if (shift == 14 && payload > 3) {
        throw const BridgeValidationException('invalid_solana_transaction');
      }
      value |= payload << shift;
      length += 1;
      if ((current & 0x80) == 0) {
        if (length > 1 && payload == 0) {
          throw const BridgeValidationException('invalid_solana_transaction');
        }
        return value;
      }
      shift += 7;
    }
  }
}

bool _constantTimeEqual(List<int> left, List<int> right) {
  var difference = left.length ^ right.length;
  final maximum = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < maximum; index += 1) {
    final leftByte = index < left.length ? left[index] : 0;
    final rightByte = index < right.length ? right[index] : 0;
    difference |= leftByte ^ rightByte;
  }
  return difference == 0;
}
