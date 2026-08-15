import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/avatar_asset_contract.dart';

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final now = DateTime.utc(2026, 8, 15, 14);

  AvatarAssetManifest manifest() => AvatarAssetManifest(
        assetId: 'gemini-default',
        fileName: 'gemini.vrm',
        assetSha256: hash,
        runtimeVersion: 'vrm-runtime-1',
        licenseUrl: Uri.parse('https://plawie.app/licenses/gemini'),
        permittedActions: const <String>['avatar.gesture', 'avatar.status'],
      );

  test('validates and round-trips a canonical avatar manifest', () {
    final original = manifest();
    final restored = AvatarAssetManifest.fromJson(original.toJson());

    expect(restored.assetId, 'gemini-default');
    expect(restored.fileName, 'gemini.vrm');
    expect(restored.assetSha256, hash);
    expect(restored.permittedActions, <String>[
      'avatar.gesture',
      'avatar.status',
    ]);
  });

  test('rejects unsafe files, non-HTTPS licenses, and invalid hashes', () {
    expect(
      () => AvatarAssetManifest(
        assetId: 'avatar',
        fileName: '../avatar.vrm',
        assetSha256: hash,
        runtimeVersion: '1',
        licenseUrl: Uri.parse('https://example.com/license'),
      ),
      throwsArgumentError,
    );
    expect(
      () => AvatarAssetManifest(
        assetId: 'avatar',
        fileName: 'avatar.vrm',
        assetSha256: 'bad',
        runtimeVersion: '1',
        licenseUrl: Uri.parse('https://example.com/license'),
      ),
      throwsArgumentError,
    );
    expect(
      () => AvatarAssetManifest(
        assetId: 'avatar',
        fileName: 'avatar.vrm',
        assetSha256: hash,
        runtimeVersion: '1',
        licenseUrl: Uri.parse('http://example.com/license'),
      ),
      throwsArgumentError,
    );
  });

  test('only verified and active rented states can be equipped', () {
    final verified = AvatarAssetRecord(
      manifest: manifest(),
      state: AvatarAssetState.verified,
    );
    final rented = AvatarAssetRecord(
      manifest: manifest(),
      state: AvatarAssetState.rented,
      expiresAt: now.add(const Duration(hours: 1)),
      chain: 'planned-chain',
      tokenId: 'planned-token',
    );
    final expired = AvatarAssetRecord(
      manifest: manifest(),
      state: AvatarAssetState.expired,
      expiresAt: now.subtract(const Duration(minutes: 1)),
    );

    expect(verified.canEquipAt(now), isTrue);
    expect(rented.canEquipAt(now), isTrue);
    expect(expired.canEquipAt(now), isFalse);
    expect(rented.canEquipAt(now.add(const Duration(hours: 2))), isFalse);
  });

  test('rented and token-backed records require their required metadata', () {
    expect(
      () => AvatarAssetRecord(
        manifest: manifest(),
        state: AvatarAssetState.rented,
      ),
      throwsArgumentError,
    );
    expect(
      () => AvatarAssetRecord(
        manifest: manifest(),
        state: AvatarAssetState.minted,
        tokenId: 'token-without-chain',
      ),
      throwsArgumentError,
    );
  });
}
