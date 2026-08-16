import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/device_identity.dart';

void main() {
  Future<({String privateKey, String publicKey, String deviceId})>
  createIdentity(int seedOffset) async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(
      List<int>.generate(32, (index) => (index + seedOffset) % 256),
    );
    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final hash = await Sha256().hash(publicKey.bytes);
    return (
      privateKey: base64Url.encode(privateBytes).replaceAll('=', ''),
      publicKey: base64Url.encode(publicKey.bytes).replaceAll('=', ''),
      deviceId: hash.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(),
    );
  }

  test('accepts one complete Ed25519 identity', () async {
    final identity = await createIdentity(1);

    expect(
      await DeviceIdentity.isStoredMaterialConsistent(
        privateKeyBase64Url: identity.privateKey,
        publicKeyBase64Url: identity.publicKey,
        deviceId: identity.deviceId,
      ),
      isTrue,
    );
  });

  test('rejects private and public keys from different identities', () async {
    final first = await createIdentity(1);
    final second = await createIdentity(17);

    expect(
      await DeviceIdentity.isStoredMaterialConsistent(
        privateKeyBase64Url: second.privateKey,
        publicKeyBase64Url: first.publicKey,
        deviceId: first.deviceId,
      ),
      isFalse,
    );
  });

  test('rejects a device ID not derived from the public key', () async {
    final identity = await createIdentity(1);

    expect(
      await DeviceIdentity.isStoredMaterialConsistent(
        privateKeyBase64Url: identity.privateKey,
        publicKeyBase64Url: identity.publicKey,
        deviceId: '0' * 64,
      ),
      isFalse,
    );
  });

  test('rejects malformed persisted material without throwing', () async {
    expect(
      await DeviceIdentity.isStoredMaterialConsistent(
        privateKeyBase64Url: 'not-base64',
        publicKeyBase64Url: 'also-not-base64',
        deviceId: 'invalid',
      ),
      isFalse,
    );
  });
}
