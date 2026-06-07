import 'package:path/path.dart' as path;

class DependencyPackManifestPolicy {
  final Set<String> supportedAbis;

  const DependencyPackManifestPolicy({
    required this.supportedAbis,
  });

  static const androidArm64 = DependencyPackManifestPolicy(
    supportedAbis: {'arm64-v8a'},
  );
}

class DependencyPackManifestEntry {
  final String id;
  final String version;
  final String source;
  final String? url;
  final Set<String> abis;
  final int? sizeBytes;
  final String? sha256;
  final DependencyPackSignature? signature;
  final String? archiveType;
  final String? installPath;
  final List<DependencyPackFileEntry> files;
  final DependencyPackSmokeCommand? smokeCommand;
  final DependencyPackRollbackPlan? rollback;
  final Map<String, dynamic> provides;

  const DependencyPackManifestEntry({
    required this.id,
    required this.version,
    required this.source,
    required this.url,
    required this.abis,
    required this.sizeBytes,
    required this.sha256,
    required this.signature,
    required this.archiveType,
    required this.installPath,
    required this.files,
    required this.smokeCommand,
    required this.rollback,
    required this.provides,
  });

  factory DependencyPackManifestEntry.fromJson(Map<String, dynamic> json) {
    return DependencyPackManifestEntry(
      id: json['id']?.toString().trim() ?? '',
      version: json['version']?.toString().trim() ?? '',
      source: (json['source']?.toString().trim().toLowerCase() ?? 'remote'),
      url: json['url']?.toString().trim(),
      abis: _stringSet(json['abis'] ?? json['abi']),
      sizeBytes: _intValue(json['sizeBytes']),
      sha256: json['sha256']?.toString().trim().toLowerCase(),
      signature: json['signature'] is Map
          ? DependencyPackSignature.fromJson(
              Map<String, dynamic>.from(json['signature'] as Map),
            )
          : null,
      archiveType: json['archiveType']?.toString().trim(),
      installPath: json['installPath']?.toString().trim(),
      files: json['files'] is List
          ? (json['files'] as List)
              .whereType<Map>()
              .map((item) => DependencyPackFileEntry.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <DependencyPackFileEntry>[],
      smokeCommand: json['smokeCommand'] is Map
          ? DependencyPackSmokeCommand.fromJson(
              Map<String, dynamic>.from(json['smokeCommand'] as Map),
            )
          : null,
      rollback: json['rollback'] is Map
          ? DependencyPackRollbackPlan.fromJson(
              Map<String, dynamic>.from(json['rollback'] as Map),
            )
          : null,
      provides: json['provides'] is Map
          ? Map<String, dynamic>.from(json['provides'] as Map)
          : const <String, dynamic>{},
    );
  }

  DependencyPackManifestValidation validate(
    DependencyPackManifestPolicy policy,
  ) {
    final errors = <DependencyPackManifestIssue>[];
    void add(String code, String message) {
      errors.add(DependencyPackManifestIssue(code: code, message: message));
    }

    if (!_idLooksSafe(id)) {
      add('invalid_id', 'Pack id is required and must be slug-safe.');
    }
    if (version.isEmpty) {
      add('missing_version', 'Pack version is required.');
    }
    final remote = source != 'apk';
    if (source != 'apk' && source != 'remote') {
      add('invalid_source', 'Pack source must be apk or remote.');
    }
    if (remote && (url == null || url!.isEmpty)) {
      add('missing_url', 'Remote packs require a URL.');
    }
    if (abis.isEmpty) {
      add('missing_abi', 'Pack ABI list is required.');
    } else if (!abis.any(policy.supportedAbis.contains)) {
      add('unsupported_abi', 'Pack ABI does not match this Android build.');
    }
    if (sizeBytes == null || sizeBytes! <= 0) {
      add('missing_size_bytes', 'Pack sizeBytes must be a positive integer.');
    }
    if (remote && !_shaLooksValid(sha256)) {
      add('missing_sha256', 'Remote packs require a valid SHA-256 digest.');
    }
    if (archiveType == null || archiveType!.isEmpty) {
      add('missing_archive_type', 'Pack archiveType is required.');
    }
    if (!_relativePathLooksSafe(installPath)) {
      add('unsafe_install_path',
          'Pack installPath must be a safe relative path.');
    }
    if (files.isEmpty) {
      add('missing_files', 'Pack files list is required.');
    }
    for (final file in files) {
      if (!_relativePathLooksSafe(file.pathValue)) {
        add('unsafe_file_path', 'Pack file path is unsafe: ${file.pathValue}');
      }
      if (!_shaLooksValid(file.sha256)) {
        add('missing_file_sha256',
            'Pack file ${file.pathValue} requires SHA-256.');
      }
      if (file.sizeBytes == null || file.sizeBytes! <= 0) {
        add('missing_file_size',
            'Pack file ${file.pathValue} requires positive sizeBytes.');
      }
    }
    if (smokeCommand == null || smokeCommand!.command.isEmpty) {
      add('missing_smoke_command', 'Pack smokeCommand is required.');
    }
    if (rollback == null || rollback!.strategy.isEmpty) {
      add('missing_rollback', 'Pack rollback plan is required.');
    }
    final remoteExecutable = remote && _containsExecutablePayload();
    if (remoteExecutable && signature?.isComplete != true) {
      add('missing_signature',
          'Remote executable packs require a complete signature block.');
    }

    return DependencyPackManifestValidation(errors: errors);
  }

  bool _containsExecutablePayload() {
    if (files.any((file) => file.executable)) return true;
    final bins = provides['bins'];
    return bins is List && bins.isNotEmpty;
  }

  static bool _idLooksSafe(String value) {
    return RegExp(r'^[a-z0-9][a-z0-9_.-]{1,80}$').hasMatch(value);
  }
}

class DependencyPackFileEntry {
  final String pathValue;
  final String? sha256;
  final int? sizeBytes;
  final bool executable;

  const DependencyPackFileEntry({
    required this.pathValue,
    required this.sha256,
    required this.sizeBytes,
    required this.executable,
  });

  factory DependencyPackFileEntry.fromJson(Map<String, dynamic> json) {
    return DependencyPackFileEntry(
      pathValue: json['path']?.toString().trim() ?? '',
      sha256: json['sha256']?.toString().trim().toLowerCase(),
      sizeBytes: _intValue(json['sizeBytes']),
      executable: json['executable'] == true,
    );
  }
}

class DependencyPackSignature {
  final String type;
  final String value;
  final String keyId;

  const DependencyPackSignature({
    required this.type,
    required this.value,
    required this.keyId,
  });

  factory DependencyPackSignature.fromJson(Map<String, dynamic> json) {
    return DependencyPackSignature(
      type: json['type']?.toString().trim() ?? '',
      value: json['value']?.toString().trim() ?? '',
      keyId: json['keyId']?.toString().trim() ?? '',
    );
  }

  bool get isComplete =>
      type.isNotEmpty && value.isNotEmpty && keyId.isNotEmpty;
}

class DependencyPackSmokeCommand {
  final String command;
  final List<String> args;

  const DependencyPackSmokeCommand({
    required this.command,
    required this.args,
  });

  factory DependencyPackSmokeCommand.fromJson(Map<String, dynamic> json) {
    return DependencyPackSmokeCommand(
      command: json['command']?.toString().trim() ?? '',
      args: _stringList(json['args']),
    );
  }
}

class DependencyPackRollbackPlan {
  final String strategy;

  const DependencyPackRollbackPlan({required this.strategy});

  factory DependencyPackRollbackPlan.fromJson(Map<String, dynamic> json) {
    return DependencyPackRollbackPlan(
      strategy: json['strategy']?.toString().trim() ?? '',
    );
  }
}

class DependencyPackManifestValidation {
  final List<DependencyPackManifestIssue> errors;

  const DependencyPackManifestValidation({required this.errors});

  bool get ok => errors.isEmpty;

  List<String> get errorCodes =>
      errors.map((issue) => issue.code).toList(growable: false);
}

class DependencyPackManifestIssue {
  final String code;
  final String message;

  const DependencyPackManifestIssue({
    required this.code,
    required this.message,
  });
}

bool _shaLooksValid(String? value) {
  return value != null && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
}

bool _relativePathLooksSafe(String? value) {
  if (value == null || value.isEmpty) return false;
  if (path.isAbsolute(value)) return false;
  final normalized = path.normalize(value).replaceAll(r'\', '/');
  if (normalized == '.' || normalized.startsWith('../')) return false;
  if (normalized.contains('/../') || normalized == '..') return false;
  return RegExp(r'^[A-Za-z0-9._+\-/]+$').hasMatch(normalized);
}

Set<String> _stringSet(dynamic value) => _stringList(value).toSet();

List<String> _stringList(dynamic value) {
  if (value is String) {
    return [value.trim()].where((v) => v.isNotEmpty).toList();
  }
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

int? _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
