import 'dart:io';
import 'package:flutter/services.dart';

class BootstrapService {
  static final BootstrapService instance = BootstrapService._internal();
  BootstrapService._internal();

  // Progress callback used by UI
  Function(SetupStep step, double progress, String message)? onProgress;

  // ==================== MAIN BOOTSTRAP ENTRY POINT ====================
  Future<void> bootstrap() async {
    _log('🚀 Starting OpenClaw bootstrap...');

    final rootfsDir = await getRootfsDirectory();

    // 1. Ensure minimal rootfs
    await _ensureMinimalRootfs(rootfsDir);

    // 2. Extract pre-bundled openclaw (fast path)
    await _extractPrebundledOpenClaw(rootfsDir);

    // 3. Ensure openclaw package is present
    await _ensureOpenClawPackageExists(rootfsDir);

    // 4. Final cleanup
    await _performFinalCleanup(rootfsDir);

    _log('✅ Bootstrap completed successfully');
  }

  // ==================== MINIMAL ROOTFS ====================
  Future<void> _ensureMinimalRootfs(String rootfsDir) async {
    if (await Directory(rootfsDir).exists() && 
        await File('$rootfsDir/etc/os-release').exists()) {
      _log('✅ Minimal rootfs already present');
      return;
    }

    _updateProgress(SetupStep.downloadingRootfs, 0.0, 'Downloading minimal Ubuntu arm64 rootfs...');

    // You can host this on your GitHub releases or use a public minimal one
    const minimalUrl = 'https://github.com/vmbbz/plawie/releases/download/v2026.5/minimal-ubuntu-24.04-arm64-rootfs.tar.gz';

    final tarFile = File('$rootfsDir/rootfs.tar.gz');
    await _downloadFile(minimalUrl, tarFile);

    await _extractTarGz(tarFile.path, rootfsDir);
    await tarFile.delete();

    _log('✅ Minimal rootfs extracted (~150 MB)');
  }

  // ==================== PRE-BUNDLED OPENCLAW ====================
  Future<void> _extractPrebundledOpenClaw(String rootfsDir) async {
    final bundledTar = File('assets/openclaw-node-modules.tar.gz');
    if (!await bundledTar.exists()) {
      _log('⚠️ No pre-bundled node_modules found (fallback to runtime install)');
      return;
    }

    final targetDir = '$rootfsDir/usr/local/lib/node_modules';
    await Directory(targetDir).create(recursive: true);

    await _extractTarGz(bundledTar.path, targetDir);
    _log('✅ Pre-bundled openclaw node_modules extracted (fast path)');
  }

  // ==================== ENSURE OPENCLAW PACKAGE ====================
  Future<void> _ensureOpenClawPackageExists(String rootfsDir) async {
    final openclawDir = Directory('$rootfsDir/usr/local/lib/node_modules/openclaw');

    if (await openclawDir.exists()) {
      _log('✅ openclaw package ready');
      return;
    }

    _log('🚨 openclaw missing — performing minimal install...');

    // Install build tools only if needed
    await _installMinimalBuildTools(rootfsDir);

    await NativeBridge.runInProot(
      'npm install -g openclaw@latest --prefix /usr/local --no-audit --no-fund --ignore-scripts --production',
      timeout: const Duration(minutes: 2),
    );

    // Purge build tools immediately after
    await _purgeBuildTools(rootfsDir);
  }

  // ==================== BUILD TOOLS (OPTIONAL) ====================
  Future<void> _installMinimalBuildTools(String rootfsDir) async {
    await NativeBridge.runInProot('''
      apt-get update -qq &&
      apt-get install -y --no-install-recommends build-essential python3 &&
      apt-get clean
    ''');
  }

  Future<void> _purgeBuildTools(String rootfsDir) async {
    await NativeBridge.runInProot('''
      apt-get purge -y build-essential python3 &&
      apt-get autoremove -y &&
      apt-get clean &&
      rm -rf /var/lib/apt/lists/*
    ''');
  }

  // ==================== FINAL CLEANUP ====================
  Future<void> _performFinalCleanup(String rootfsDir) async {
    await NativeBridge.runInProot('''
      npm cache clean --force &&
      rm -rf /root/.npm/_cacache /root/.npm/_logs &&
      apt-get clean &&
      rm -rf /var/lib/apt/lists/* /var/cache/apt/*
    ''');
    _log('✅ Heavy caches cleaned (size optimization)');
  }

  // ==================== HELPERS ====================
  Future<Directory> getRootfsDirectory() async {
    // Your existing implementation
    final dir = Directory('/data/user/0/com.nxg.openclawproot/files/rootfs/ubuntu');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _downloadFile(String url, File destination, {Function(double)? onProgress}) async {
    // Your existing download logic (keep it)
    // ...
  }

  Future<void> _extractTarGz(String tarPath, String targetDir) async {
    // Your existing tar extraction logic
    // ...
  }

  void _log(String message, {Object? error}) {
    print('[BootstrapService] $message');
    if (error != null) print(error);
  }

  void _updateProgress(SetupStep step, double progress, String message) {
    onProgress?.call(step, progress, message);
  }
}

enum SetupStep {
  downloadingRootfs,
  extractingRootfs,
  installingOpenClaw,
  cleanup,
  complete,
}