import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'clawhub_service.dart';
import 'native_bridge.dart';
import 'openclaw_service.dart';
import 'skill_parity_audit_service.dart';
import 'skill_provisioning_service.dart';

class NativeClawHubSkillInstaller {
  NativeClawHubSkillInstaller._();
  static final instance = NativeClawHubSkillInstaller._();

  static const _baseUrl = 'https://clawhub.ai';
  static const _maxArchiveBytes = 20 * 1024 * 1024;
  static const _markerFiles = {'skill.md', 'skills.md'};
  static final _slugPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$');

  Future<NativeClawHubSkillResult> install(
    String rawSlug, {
    bool force = false,
    String? version,
  }) async {
    final slug = _normalizeSlug(rawSlug);
    debugPrint('[NativeClawHub] install start slug=$slug force=$force');
    final workspaceDir = await _nativeWorkspaceDir();
    debugPrint('[NativeClawHub] workspace=${workspaceDir.path}');
    final targetDir = Directory(path.join(workspaceDir.path, 'skills', slug));
    final resolvedVersion = await _resolveVersion(slug, version);
    debugPrint('[NativeClawHub] resolved slug=$slug version=$resolvedVersion');

    if (await targetDir.exists() && !force) {
      debugPrint('[NativeClawHub] install no-op already-installed slug=$slug');
      final provisioning = await _auditProvisioningPlan(slug);
      if (provisioning?.reloadRecommended == true) {
        await OpenClawCommandService.reloadGateway(
          reason: 'native ClawHub skill provision: $slug',
        );
        debugPrint('[NativeClawHub] provision reload requested slug=$slug');
      }
      return NativeClawHubSkillResult(
        ok: true,
        slug: slug,
        version: resolvedVersion,
        targetPath: targetDir.path,
        alreadyInstalled: true,
        provisioning: provisioning?.toJson(),
      );
    }

    final archiveBytes = await _downloadArchive(slug, resolvedVersion);
    debugPrint(
      '[NativeClawHub] downloaded slug=$slug bytes=${archiveBytes.length}',
    );
    final stageDir = Directory(
      path.join(
        workspaceDir.path,
        '.clawhub',
        'staging',
        '$slug-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );

    Directory? backupDir;
    try {
      await _extractSkillArchive(archiveBytes, stageDir);
      debugPrint('[NativeClawHub] extracted slug=$slug stage=${stageDir.path}');
      final installedAt = DateTime.now().millisecondsSinceEpoch;
      await _writeSkillMetadata(
        workspaceDir: workspaceDir,
        skillDir: stageDir,
        slug: slug,
        version: resolvedVersion,
        installedAt: installedAt,
      );

      if (await targetDir.exists()) {
        backupDir = Directory(
          path.join(
            workspaceDir.path,
            '.clawhub',
            'backups',
            '$slug-${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
        await backupDir.parent.create(recursive: true);
        await targetDir.rename(backupDir.path);
      }

      await targetDir.parent.create(recursive: true);
      await stageDir.rename(targetDir.path);
      debugPrint('[NativeClawHub] moved slug=$slug target=${targetDir.path}');
      if (backupDir != null && await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }

      await _writeSkillLock(
        workspaceDir,
        slug: slug,
        version: resolvedVersion,
        installedAt: installedAt,
      );
      await _mirrorNativeInstallToProotFallback(
        sourceDir: targetDir,
        slug: slug,
        version: resolvedVersion,
        installedAt: installedAt,
      );
      final provisioning = await _auditProvisioningPlan(slug);
      await OpenClawCommandService.reloadGateway(
        reason: 'native ClawHub skill install: $slug',
      );
      debugPrint('[NativeClawHub] reload requested slug=$slug');

      return NativeClawHubSkillResult(
        ok: true,
        slug: slug,
        version: resolvedVersion,
        targetPath: targetDir.path,
        provisioning: provisioning?.toJson(),
      );
    } catch (error) {
      if (await stageDir.exists()) {
        try {
          await stageDir.delete(recursive: true);
        } catch (_) {}
      }
      if (backupDir != null && await backupDir.exists()) {
        try {
          if (await targetDir.exists()) {
            await targetDir.delete(recursive: true);
          }
          await backupDir.rename(targetDir.path);
        } catch (_) {}
      }
      debugPrint('[NativeClawHub] install failed slug=$slug error=$error');
      return NativeClawHubSkillResult(
        ok: false,
        slug: slug,
        version: resolvedVersion,
        targetPath: targetDir.path,
        error: error.toString(),
      );
    }
  }

  Future<NativeClawHubSkillResult> update(String slug) {
    return install(slug, force: true);
  }

  Future<NativeClawHubSkillResult> uninstall(String rawSlug) async {
    final slug = _normalizeSlug(rawSlug);
    debugPrint('[NativeClawHub] uninstall start slug=$slug');
    final workspaceDir = await _nativeWorkspaceDir();
    final targetDir = Directory(path.join(workspaceDir.path, 'skills', slug));
    if (!await targetDir.exists()) {
      await _removeProotFallbackMirror(slug);
      return NativeClawHubSkillResult(
        ok: false,
        slug: slug,
        targetPath: targetDir.path,
        error: 'Skill is not installed in the native workspace.',
      );
    }

    try {
      await targetDir.delete(recursive: true);
      await _removeFromLock(workspaceDir, slug);
      await _removeProotFallbackMirror(slug);
      await OpenClawCommandService.reloadGateway(
        reason: 'native ClawHub skill uninstall: $slug',
      );
      debugPrint('[NativeClawHub] uninstall reload requested slug=$slug');
      return NativeClawHubSkillResult(
        ok: true,
        slug: slug,
        targetPath: targetDir.path,
      );
    } catch (error) {
      return NativeClawHubSkillResult(
        ok: false,
        slug: slug,
        targetPath: targetDir.path,
        error: error.toString(),
      );
    }
  }

  Future<Directory> _nativeWorkspaceDir() async {
    final filesDir = await NativeBridge.getFilesDir();
    final workspaceDir = Directory(
      path.join(
        filesDir,
        'native-node-embedded',
        'native-home',
        '.openclaw',
        'workspace',
      ),
    );
    await Directory(path.join(workspaceDir.path, 'skills')).create(
      recursive: true,
    );
    return workspaceDir;
  }

  Future<SkillProvisioningReport?> _auditProvisioningPlan(String slug) async {
    try {
      final snapshot = await SkillParityAuditService.instance.audit(
        repairNativeFromProot: false,
        cacheTtl: Duration.zero,
      );
      final report = await SkillProvisioningService.instance.provisionSnapshot(
        snapshot,
        skillId: slug,
      );
      debugPrint('[NativeClawHub] ${report.compactLogLine} slug=$slug');
      for (final result in report.results.take(3)) {
        final blockedActions = result.actions
            .where((action) =>
                action.status != SkillProvisioningActionStatus.ready &&
                action.status != SkillProvisioningActionStatus.satisfied)
            .take(4)
            .map((action) => '${action.key}:${action.status.wireName}')
            .join(',');
        debugPrint(
          '[NativeClawHub] provision skill=${result.skillId} status=${result.status.wireName}${blockedActions.isEmpty ? '' : ' actions=$blockedActions'}',
        );
      }
      return report;
    } catch (error) {
      debugPrint(
          '[NativeClawHub] provisioning audit failed slug=$slug: $error');
      return null;
    }
  }

  Future<Directory?> _prootWorkspaceDirIfPresent() async {
    final filesDir = await NativeBridge.getFilesDir();
    final openClawDir = Directory(
      path.join(filesDir, 'rootfs', 'ubuntu', 'root', '.openclaw'),
    );
    if (!await openClawDir.exists()) return null;
    final workspaceDir = Directory(path.join(openClawDir.path, 'workspace'));
    await Directory(path.join(workspaceDir.path, 'skills')).create(
      recursive: true,
    );
    return workspaceDir;
  }

  Future<void> _mirrorNativeInstallToProotFallback({
    required Directory sourceDir,
    required String slug,
    required String version,
    required int installedAt,
  }) async {
    try {
      final workspaceDir = await _prootWorkspaceDirIfPresent();
      if (workspaceDir == null) return;
      final targetDir = Directory(path.join(workspaceDir.path, 'skills', slug));
      final marker =
          File(path.join(targetDir.path, '.plawie-native-clawhub-mirror.json'));
      if (await targetDir.exists()) {
        if (!await marker.exists()) {
          debugPrint(
            '[NativeClawHub] PRoot mirror skipped existing non-mirrored slug=$slug',
          );
          return;
        }
        await targetDir.delete(recursive: true);
      }
      await _copyDirectory(sourceDir, targetDir);
      await _writeJson(marker, {
        'version': 1,
        'slug': slug,
        'installedVersion': version,
        'mirroredAt': DateTime.now().toIso8601String(),
      });
      await _writeSkillLock(
        workspaceDir,
        slug: slug,
        version: version,
        installedAt: installedAt,
      );
      debugPrint('[NativeClawHub] PRoot fallback mirror updated slug=$slug');
    } catch (error) {
      debugPrint('[NativeClawHub] PRoot fallback mirror failed: $error');
    }
  }

  Future<void> _removeProotFallbackMirror(String slug) async {
    try {
      final workspaceDir = await _prootWorkspaceDirIfPresent();
      if (workspaceDir == null) return;
      final targetDir = Directory(path.join(workspaceDir.path, 'skills', slug));
      final marker =
          File(path.join(targetDir.path, '.plawie-native-clawhub-mirror.json'));
      if (await targetDir.exists() && await marker.exists()) {
        await targetDir.delete(recursive: true);
      }
      await _removeFromLock(workspaceDir, slug);
    } catch (error) {
      debugPrint('[NativeClawHub] PRoot fallback mirror remove failed: $error');
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = path.basename(entity.path);
      final targetPath = path.join(target.path, name);
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  String _normalizeSlug(String raw) {
    final slug = raw.trim().toLowerCase();
    if (!_slugPattern.hasMatch(slug) ||
        slug.contains('..') ||
        slug.contains('/') ||
        slug.contains(r'\')) {
      throw ArgumentError('Invalid ClawHub skill slug: $raw');
    }
    return slug;
  }

  Future<String> _resolveVersion(String slug, String? requestedVersion) async {
    final explicit = requestedVersion?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final detail = await ClawHubService.instance.infoFromApi(slug);
    final version = detail?.version.trim();
    return version == null || version.isEmpty ? 'latest' : version;
  }

  Future<Uint8List> _downloadArchive(String slug, String version) async {
    final query = <String, String>{'slug': slug};
    if (version == 'latest') {
      query['tag'] = 'latest';
    } else {
      query['version'] = version;
    }
    final uri = Uri.parse('$_baseUrl/api/v1/download').replace(
      queryParameters: query,
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'plawie-app/1.0'
    }).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final bodyPreview = utf8
          .decode(response.bodyBytes, allowMalformed: true)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final previewLength = bodyPreview.length.clamp(0, 220).toInt();
      throw HttpException(
        'ClawHub download failed with HTTP ${response.statusCode}'
        '${bodyPreview.isEmpty ? '' : ': ${bodyPreview.substring(0, previewLength)}'}',
        uri: uri,
      );
    }
    final bytes = Uint8List.fromList(response.bodyBytes);
    if (bytes.isEmpty) throw StateError('ClawHub returned an empty archive.');
    if (bytes.length > _maxArchiveBytes) {
      throw StateError(
          'ClawHub skill archive is too large for mobile install.');
    }
    return bytes;
  }

  Future<void> _extractSkillArchive(
    Uint8List archiveBytes,
    Directory stageDir,
  ) async {
    final archive = ZipDecoder().decodeBytes(archiveBytes, verify: true);
    final rootPrefix = _resolveArchiveRootPrefix(archive);
    var wroteSkillDocument = false;
    var fileCount = 0;
    var totalBytes = 0;

    await stageDir.create(recursive: true);
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final normalized = _normalizeArchivePath(file.name);
      if (normalized == null) continue;
      final relative = _stripRootPrefix(normalized, rootPrefix);
      if (relative == null || relative.isEmpty) continue;

      final output = File(path.normalize(path.join(stageDir.path, relative)));
      if (!path.isWithin(stageDir.path, output.path)) {
        throw StateError('Unsafe archive path: ${file.name}');
      }

      final bytes = file.content;
      fileCount += 1;
      totalBytes += bytes.length;
      if (totalBytes > _maxArchiveBytes) {
        throw StateError('ClawHub skill archive expands beyond mobile limit.');
      }

      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes, flush: true);
      if (_isSkillMarker(relative)) wroteSkillDocument = true;
    }

    if (fileCount == 0 || !wroteSkillDocument) {
      throw StateError('ClawHub archive is missing SKILL.md.');
    }
  }

  String _resolveArchiveRootPrefix(Archive archive) {
    final markerPaths = archive.files
        .where((file) => file.isFile)
        .map((file) => _normalizeArchivePath(file.name))
        .whereType<String>()
        .where(_isSkillMarker)
        .toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    if (markerPaths.isEmpty) {
      throw StateError('ClawHub archive is missing SKILL.md.');
    }
    final marker = markerPaths.first;
    final slash = marker.lastIndexOf('/');
    return slash == -1 ? '' : marker.substring(0, slash);
  }

  String? _normalizeArchivePath(String raw) {
    final normalized = raw.replaceAll(r'\', '/').trim();
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
      return null;
    }
    final parts = <String>[];
    for (final part in normalized.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..' || part.contains('\u0000')) return null;
      parts.add(part);
    }
    return parts.isEmpty ? null : parts.join('/');
  }

  String? _stripRootPrefix(String normalized, String rootPrefix) {
    if (rootPrefix.isEmpty) return normalized;
    if (normalized == rootPrefix) return '';
    final prefix = '$rootPrefix/';
    if (!normalized.startsWith(prefix)) return null;
    return normalized.substring(prefix.length);
  }

  bool _isSkillMarker(String normalizedPath) {
    final name = normalizedPath.split('/').last.toLowerCase();
    return _markerFiles.contains(name);
  }

  Future<void> _writeSkillMetadata({
    required Directory workspaceDir,
    required Directory skillDir,
    required String slug,
    required String version,
    required int installedAt,
  }) async {
    final origin = <String, dynamic>{
      'version': 1,
      'registry': _baseUrl,
      'slug': slug,
      'installedVersion': version,
      'installedAt': installedAt,
    };
    await _writeJson(
      File(path.join(skillDir.path, '.clawhub', 'origin.json')),
      origin,
    );

    try {
      final card = await _fetchSkillCard(slug, version);
      if (card.trim().isNotEmpty) {
        await File(path.join(skillDir.path, 'skill-card.md')).writeAsString(
          card,
          flush: true,
        );
      }
    } catch (_) {}
  }

  Future<String> _fetchSkillCard(String slug, String version) async {
    final query = <String, String>{'slug': slug};
    if (version == 'latest') {
      query['tag'] = 'latest';
    } else {
      query['version'] = version;
    }
    final uri = Uri.parse('$_baseUrl/api/v1/skills/$slug/card').replace(
      queryParameters: query,
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'plawie-app/1.0'
    }).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) return '';
    return utf8.decode(response.bodyBytes);
  }

  Future<void> _writeSkillLock(
    Directory workspaceDir, {
    required String slug,
    required String version,
    required int installedAt,
  }) async {
    final lockFile =
        File(path.join(workspaceDir.path, '.clawhub', 'lock.json'));
    final lock = await _readJson(lockFile) ?? <String, dynamic>{};
    lock['version'] = 1;
    final skills = lock['skills'] is Map
        ? Map<String, dynamic>.from(lock['skills'] as Map)
        : <String, dynamic>{};
    skills[slug] = <String, dynamic>{
      'version': version,
      'installedAt': installedAt,
      'registry': _baseUrl,
    };
    lock['skills'] = skills;
    await _writeJson(lockFile, lock);
  }

  Future<void> _removeFromLock(Directory workspaceDir, String slug) async {
    final lockFile =
        File(path.join(workspaceDir.path, '.clawhub', 'lock.json'));
    final lock = await _readJson(lockFile);
    if (lock == null) return;
    final skills = lock['skills'] is Map
        ? Map<String, dynamic>.from(lock['skills'] as Map)
        : <String, dynamic>{};
    skills.remove(slug);
    lock['version'] = 1;
    lock['skills'] = skills;
    await _writeJson(lockFile, lock);
  }

  Future<Map<String, dynamic>?> _readJson(File file) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> _writeJson(File file, Map<String, dynamic> value) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(value)}\n',
      flush: true,
    );
  }
}

class NativeClawHubSkillResult {
  final bool ok;
  final String slug;
  final String? version;
  final String targetPath;
  final String? error;
  final bool alreadyInstalled;
  final Map<String, dynamic>? provisioning;

  const NativeClawHubSkillResult({
    required this.ok,
    required this.slug,
    this.version,
    required this.targetPath,
    this.error,
    this.alreadyInstalled = false,
    this.provisioning,
  });
}
