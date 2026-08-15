// Canonical, non-custodial AvatarForge asset validation primitives.
//
// These types validate an asset package before it can be treated as a verified
// companion. They do not mint, rent, fetch, or establish ownership.

enum AvatarAssetState {
  local,
  unverified,
  verified,
  minted,
  rented,
  expired,
}

class AvatarAssetManifest {
  factory AvatarAssetManifest({
    required String assetId,
    required String fileName,
    required String assetSha256,
    required String runtimeVersion,
    required Uri licenseUrl,
    List<String> permittedActions = const <String>[],
    String? previewSha256,
    String? creatorId,
  }) {
    final normalizedAssetId = assetId.trim();
    final normalizedFileName = fileName.trim();
    final normalizedRuntimeVersion = runtimeVersion.trim();
    final normalizedHash = assetSha256.trim().toLowerCase();
    final normalizedPreviewHash = previewSha256?.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$').hasMatch(normalizedAssetId)) {
      throw ArgumentError.value(assetId, 'assetId', 'has an invalid format');
    }
    if (normalizedFileName.isEmpty ||
        normalizedFileName.length > 160 ||
        normalizedFileName.contains('/') ||
        normalizedFileName.contains('\\') ||
        !RegExp(r'\.(vrm|glb|gltf)$', caseSensitive: false)
            .hasMatch(normalizedFileName)) {
      throw ArgumentError.value(
        fileName,
        'fileName',
        'must be a safe VRM/glTF filename',
      );
    }
    if (!_isSha256(normalizedHash)) {
      throw ArgumentError.value(assetSha256, 'assetSha256', 'must be SHA-256');
    }
    if (normalizedPreviewHash != null && !_isSha256(normalizedPreviewHash)) {
      throw ArgumentError.value(
        previewSha256,
        'previewSha256',
        'must be SHA-256 when supplied',
      );
    }
    if (normalizedRuntimeVersion.isEmpty ||
        normalizedRuntimeVersion.length > 32) {
      throw ArgumentError.value(
        runtimeVersion,
        'runtimeVersion',
        'must be 1-32 chars',
      );
    }
    if (licenseUrl.scheme.toLowerCase() != 'https' || licenseUrl.host.isEmpty) {
      throw ArgumentError.value(
        licenseUrl,
        'licenseUrl',
        'must be an HTTPS URL',
      );
    }
    final actions = <String>[];
    for (final action in permittedActions) {
      final normalizedAction = action.trim();
      if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$').hasMatch(normalizedAction)) {
        throw ArgumentError.value(
          action,
          'permittedActions',
          'contains an invalid action',
        );
      }
      if (!actions.contains(normalizedAction)) actions.add(normalizedAction);
    }

    return AvatarAssetManifest._(
      assetId: normalizedAssetId,
      fileName: normalizedFileName,
      assetSha256: normalizedHash,
      previewSha256: normalizedPreviewHash,
      runtimeVersion: normalizedRuntimeVersion,
      licenseUrl: licenseUrl,
      permittedActions: List<String>.unmodifiable(actions),
      creatorId: _bounded(creatorId, maxLength: 128),
    );
  }

  const AvatarAssetManifest._({
    required this.assetId,
    required this.fileName,
    required this.assetSha256,
    required this.previewSha256,
    required this.runtimeVersion,
    required this.licenseUrl,
    required this.permittedActions,
    required this.creatorId,
  });

  final String assetId;
  final String fileName;
  final String assetSha256;
  final String? previewSha256;
  final String runtimeVersion;
  final Uri licenseUrl;
  final List<String> permittedActions;
  final String? creatorId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'assetId': assetId,
        'fileName': fileName,
        'assetSha256': assetSha256,
        if (previewSha256 != null) 'previewSha256': previewSha256,
        'runtimeVersion': runtimeVersion,
        'licenseUrl': licenseUrl.toString(),
        'permittedActions': permittedActions,
        if (creatorId != null) 'creatorId': creatorId,
      };

  factory AvatarAssetManifest.fromJson(Map<String, dynamic> json) {
    final actions = json['permittedActions'];
    if (actions != null && actions is! List) {
      throw const FormatException('Avatar actions must be a list.');
    }
    final licenseUrl = Uri.tryParse(json['licenseUrl']?.toString() ?? '');
    if (licenseUrl == null) {
      throw const FormatException('Avatar license URL is invalid.');
    }
    return AvatarAssetManifest(
      assetId: json['assetId']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      assetSha256: json['assetSha256']?.toString() ?? '',
      previewSha256: json['previewSha256']?.toString(),
      runtimeVersion: json['runtimeVersion']?.toString() ?? '',
      licenseUrl: licenseUrl,
      permittedActions: actions == null
          ? const <String>[]
          : List<String>.from(
              actions.map((value) => value.toString()),
            ),
      creatorId: json['creatorId']?.toString(),
    );
  }
}

class AvatarAssetRecord {
  factory AvatarAssetRecord({
    required AvatarAssetManifest manifest,
    required AvatarAssetState state,
    DateTime? expiresAt,
    String? chain,
    String? tokenId,
  }) {
    if (state == AvatarAssetState.rented && expiresAt == null) {
      throw ArgumentError('A rented avatar requires an expiry time.');
    }
    if (state == AvatarAssetState.expired && expiresAt == null) {
      throw ArgumentError('An expired avatar requires an expiry time.');
    }
    if (tokenId != null && (chain == null || chain.trim().isEmpty)) {
      throw ArgumentError('A token ID requires a chain identifier.');
    }
    return AvatarAssetRecord._(
      manifest: manifest,
      state: state,
      expiresAt: expiresAt?.toUtc(),
      chain: _bounded(chain, maxLength: 64),
      tokenId: _bounded(tokenId, maxLength: 160),
    );
  }

  const AvatarAssetRecord._({
    required this.manifest,
    required this.state,
    required this.expiresAt,
    required this.chain,
    required this.tokenId,
  });

  final AvatarAssetManifest manifest;
  final AvatarAssetState state;
  final DateTime? expiresAt;
  final String? chain;
  final String? tokenId;

  bool isExpiredAt(DateTime now) =>
      state == AvatarAssetState.expired ||
      (expiresAt != null && !expiresAt!.isAfter(now.toUtc()));

  /// Only verified or contract-backed states may be equipped. Local previews
  /// must be promoted through manifest/hash validation first.
  bool canEquipAt(DateTime now) {
    if (isExpiredAt(now)) return false;
    return state == AvatarAssetState.verified ||
        state == AvatarAssetState.minted ||
        state == AvatarAssetState.rented;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'manifest': manifest.toJson(),
        'state': state.name,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (chain != null) 'chain': chain,
        if (tokenId != null) 'tokenId': tokenId,
      };

  factory AvatarAssetRecord.fromJson(Map<String, dynamic> json) {
    final manifest = json['manifest'];
    final state = _enumByName(AvatarAssetState.values, json['state']);
    final expiresAt = json['expiresAt'] == null
        ? null
        : DateTime.tryParse(json['expiresAt'].toString());
    if (manifest is! Map ||
        state == null ||
        (json['expiresAt'] != null && expiresAt == null)) {
      throw const FormatException('Invalid avatar asset record.');
    }
    return AvatarAssetRecord(
      manifest: AvatarAssetManifest.fromJson(
        manifest.map((key, value) => MapEntry(key.toString(), value)),
      ),
      state: state,
      expiresAt: expiresAt,
      chain: json['chain']?.toString(),
      tokenId: json['tokenId']?.toString(),
    );
  }
}

bool _isSha256(String value) => RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

String? _bounded(String? value, {required int maxLength}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > maxLength) {
    throw ArgumentError.value(value, 'value', 'exceeds $maxLength characters');
  }
  return normalized;
}

T? _enumByName<T extends Enum>(List<T> values, dynamic raw) {
  final name = raw?.toString();
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
