import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Enhanced SkillProvisioningService
/// - Auto-downloads common static aarch64 binaries
/// - Better handling for more cases
/// - Easier to call automatically on install
class SkillProvisioningService {
  static final SkillProvisioningService instance = SkillProvisioningService._();
  SkillProvisioningService._();

  // Existing fields from your 873a1f1 implementation...
  final String _nativeHome = 'native-node-embedded/native-home';

  Future<SkillProvisioningReport> auditAndProvision({
    String? filesDir,
    String? skillId,
    Map<String, String>? envValues,
    Map<String, dynamic>? configValues,
    bool repairNativeFromProot = true,
    bool applyValues = true,
    bool installBundledBinaries = true,
    bool autoDownloadBinaries = true,
  }) async {
    final snapshot = await SkillParityAuditService.instance.audit(
      filesDir: filesDir,
      repairNativeFromProot: repairNativeFromProot,
    );

    return provisionSnapshot(
      snapshot,
      skillId: skillId,
      envValues: envValues,
      configValues: configValues,
      applyValues: applyValues,
      installBundledBinaries: installBundledBinaries && autoDownloadBinaries,
    );
  }

  Future<bool> _ensureBinary(String binaryName) async {
    final targetDir = Directory('$_nativeHome/.openclaw/bin');
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    final targetPath = '${targetDir.path}/$binaryName';
    if (await File(targetPath).exists()) return true;

    const downloadUrls = {
      'curl': 'https://github.com/stunnel/static-curl/releases/download/8.7.1/curl-linux-aarch64',
      'jq': 'https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-arm64',
    };

    final url = downloadUrls[binaryName];
    if (url == null) return false;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await File(targetPath).writeAsBytes(response.bodyBytes);
        if (!Platform.isWindows) {
          await Process.run('chmod', ['755', targetPath]);
        }
        debugPrint('[SkillProvisioning] Auto-downloaded $binaryName');
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Keep your existing provisionSnapshot and _copyBundledBinaryIfExists logic
  // Just enhance the binary part with the _ensureBinary call as I showed earlier
}