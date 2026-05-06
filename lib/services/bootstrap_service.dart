import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';
import 'package:flutter/services.dart';
import 'preferences_service.dart';
import 'dart:io';

class BootstrapService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10), // Rootfs can be large
  ));

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: 'BootstrapService', error: error, stackTrace: stackTrace);
  }

  /// Update OpenClaw gateway to the latest version
  /// This fixes WebSocket handshake issues and other bugs
  Future<void> updateGateway() async {
    try {
      _updateSetupNotification('Updating OpenClaw gateway...', progress: 50);
      
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'npm update -g openclaw',
        timeout: 300,
      );
      
      _updateSetupNotification('Gateway updated successfully!', progress: 100);
    } catch (e, stack) {
      _log('Gateway update failed', error: e, stackTrace: stack);
      rethrow;
    }
  }


  Future<SetupState> checkStatus() async {
    try {
      final complete = await NativeBridge.isBootstrapComplete();
      if (complete) {
        return const SetupState(
          step: SetupStep.complete,
          progress: 1.0,
          message: 'Setup complete',
        );
      }
      return const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setup required',
      );
    } catch (e, stack) {
      _log('Status check failed', error: e, stackTrace: stack);
      return SetupState(
        step: SetupStep.error,
        error: 'Failed to check status: $e',
      );
    }
  }

  /// Helper for high-speed multi-threaded downloading using Range headers.
  /// Shaves off ~20-30 seconds on the initial rootfs/node download.
  Future<void> _downloadParallel(
    String url,
    String savePath, {
    required void Function(int received, int total) onProgress,
    int concurrency = 4,
  }) async {
    try {
      // 1. Get file size
      final head = await _dio.head(url);
      final total = int.tryParse(head.headers.value('content-length') ?? '0') ?? 0;
      final acceptRanges = head.headers.value('accept-ranges') == 'bytes';

      if (total <= 5 * 1024 * 1024 || !acceptRanges) {
        // Too small or no ranges support -> fallback to single thread
        await _dio.download(url, savePath, onReceiveProgress: onProgress);
        return;
      }

      _log('🚀 Starting parallel download for $url ($concurrency threads)');

      // 2. Prepare chunks
      final int chunkSize = (total / concurrency).ceil();
      final List<Future> downloads = [];
      final List<int> receivedBytes = List.filled(concurrency, 0);

      final tempDir = Directory('${File(savePath).parent.path}/chunks');
      if (!tempDir.existsSync()) tempDir.createSync(recursive: true);

      for (int i = 0; i < concurrency; i++) {
        final start = i * chunkSize;
        final end = (i == concurrency - 1) ? total - 1 : (i + 1) * chunkSize - 1;
        final chunkPath = '${tempDir.path}/chunk_$i';

        downloads.add(_dio.download(
          url,
          chunkPath,
          options: Options(headers: {'Range': 'bytes=$start-$end'}),
          onReceiveProgress: (received, _) {
            receivedBytes[i] = received;
            final currentTotalReceived = receivedBytes.reduce((a, b) => a + b);
            onProgress(currentTotalReceived, total);
          },
        ));
      }

      // 3. Wait for all chunks
      await Future.wait(downloads);

      // 4. Merge chunks
      final outputFile = File(savePath);
      final sink = outputFile.openWrite();
      for (int i = 0; i < concurrency; i++) {
        final chunkFile = File('${tempDir.path}/chunk_$i');
        await sink.addStream(chunkFile.openRead());
        await chunkFile.delete();
      }
      await sink.close();
      await tempDir.delete();
      
      _log('✅ Parallel download complete: $savePath');
    } catch (e) {
      _log('❌ Parallel download failed, falling back to standard download', error: e);
      await _dio.download(url, savePath, onReceiveProgress: onProgress);
    }
  }

  /// HYBRID PHASE 1 — glibc + Node.js wrapper (AidanPark style)
  Future<void> runFullSetup({required void Function(SetupState) onProgress}) async {
    try {
      // Start foreground service to keep app alive during setup
      try {
        await NativeBridge.startSetupService();
      } catch (e) {
        _log('Non-fatal: Setup service failed to start', error: e);
      }

      _emitProgress(onProgress, SetupStep.checkingStatus, 0.0, '🚀 Project Aegis: Initializing Hybrid Engine...', 5);

      // 1. Install glibc-runner + Node.js wrapper via Kotlin
      _emitProgress(onProgress, SetupStep.installingNode, 0.1, 'Deploying glibc + Node.js wrapper...', 20);
      final wrapperSuccess = await NativeBridge.installGlibcAndNodeWrapper();
      if (!wrapperSuccess) {
        throw Exception('Failed to deploy native glibc + Node.js infrastructure.');
      }
      _emitProgress(onProgress, SetupStep.installingNode, 0.4, 'Native Infrastructure ready', 40);

      // 2. The Great Purge (Legacy PRoot Cleanup)
      final bool hasLegacy = await NativeBridge.isBootstrapComplete();
      if (hasLegacy) {
        _emitProgress(onProgress, SetupStep.cleanup, 0.5, 'Reclaiming 1.5GB of storage (Purging Legacy)...', 50);
        final reclaimed = await NativeBridge.purgeLegacyRootfs();
        _log('🔥 Reclaimed storage from legacy rootfs');
      }

      // 3. Extract pre-bundled OpenClaw (Atomic Extraction)
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.6, 'Extracting Atomic OpenClaw bundle...', 70);
      final filesDir = await NativeBridge.getFilesDir();
      final String glibcLibPath = '$filesDir/glibc/lib/node_modules';
      
      await _extractPrebundledOpenClawAegis(onProgress, glibcLibPath);

      // 4. Repair config & Finalize
      _emitProgress(onProgress, SetupStep.cleanup, 0.9, 'Hardening Aegis configuration...', 90);
      await _repairConfigAegis(filesDir);
      
      // Mark as complete
      final prefs = PreferencesService();
      await prefs.init();
      prefs.setupComplete = true;

      if (prefs.dashboardUrl == null || prefs.dashboardUrl!.isEmpty) {
        prefs.dashboardUrl = 'http://127.0.0.1:18789';
      }

      _emitProgress(onProgress, SetupStep.complete, 1.0, 'Aegis Migration Complete! Ready to launch.', 100);
      NativeBridge.stopSetupService();

    } catch (e, stack) {
      NativeBridge.stopSetupService();
      _log('Aegis Setup failed', error: e, stackTrace: stack);
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Aegis Setup failed: $e',
      ));
    }
  }

  /// Programmatically repairs a corrupted OpenClaw installation.
  /// This deletes the broken library files and triggers a fresh global install.
  Future<void> repairOpenClaw({required void Function(SetupState) onProgress}) async {
    try {
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.1, 'Cleaning broken installation...', 82);
      
      // 1. Force remove old installation and any stray files
      await NativeBridge.runInProot('npm uninstall -g openclaw || true');
      await NativeBridge.runInProot('rm -rf /usr/local/lib/node_modules/openclaw');
      await NativeBridge.runInProot('rm -f /usr/local/bin/openclaw'); 
      await NativeBridge.runInProot('npm cache clean --force || true');
      await NativeBridge.runInProot('apt-get clean || true');
      
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.3, 'Reinstalling OpenClaw (latest)...', 85);
      
      // 2. Fresh install (latest) + peer dep fix for @buape/carbon
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'npm install -g openclaw@latest --no-audit --no-fund && '
        'cd /usr/local/lib/node_modules/openclaw && npm install --no-audit --no-fund 2>/dev/null || true && '
        'openclaw doctor --fix 2>/dev/null || true',
        timeout: 1800,
      );
      
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.8, 'Recreating binary wrappers...', 90);
      
      // 3. Re-create wrappers using the hardened native logic
      await NativeBridge.createBinWrappers('openclaw');
      
      _emitProgress(onProgress, SetupStep.complete, 1.0, 'Repair complete! Restarting gateway...', 100);
      
    } catch (e, stack) {
      _log('Repair failed', error: e, stackTrace: stack);
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Repair failed: $e. Check your internet connection.',
      ));
    }
  }


  Future<String> getRootfsDirectory() async {
    final filesDir = await NativeBridge.getFilesDir();
    return '$filesDir/rootfs/ubuntu';
  }

  Future<void> _ensureOpenClawPackageExists() async {
    final rootfsDir = await getRootfsDirectory();
    final openclawDir = Directory('$rootfsDir/usr/local/lib/node_modules/openclaw');

    if (await openclawDir.exists()) {
      _log('✅ OpenClaw already present (pre-bundled or previously installed)');
      return;
    }

    _log('🚨 Installing OpenClaw (this may take 30-60s)...');

    try {
      // 1. Install with minimal flags
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'npm install -g openclaw@latest --prefix /usr/local --no-audit --no-fund --ignore-scripts --production',
        timeout: 600,
      );

      // 2. AGGRESSIVE CLEANUP (Save ~300-400 MB)
      await _performFinalCleanup();

      _log('✅ OpenClaw installed + heavy caches cleaned');
    } catch (e) {
      throw PlatformException(
        code: 'BIN_WRAPPER_ERROR',
        message: 'Failed to install openclaw: $e',
      );
    }
  }

  Future<void> _installMinimalBuildTools() async {
    _log('🛠 Installing temporary build tools (python3, g++)...');
    await NativeBridge.runInProot(
      'export DEBIAN_FRONTEND=noninteractive && '
      'apt-get update -qq && '
      'apt-get install -y --no-install-recommends build-essential python3 make g++ && '
      'apt-get clean && rm -rf /var/lib/apt/lists/*',
      timeout: 300,
    );
  }

  /// Extracts a pre-bundled openclaw-node-modules.tar.gz from app assets to the rootfs.
  /// This bypasses the need for a 10-minute 'npm install' on the user's device.
  Future<void> _extractPrebundledOpenClaw(Function(SetupState) onProgress) async {
    _log('📦 Checking for pre-bundled OpenClaw assets...');
    try {
      final rootfsDir = await getRootfsDirectory();
      
      // Check if the asset exists in the bundle
      // Note: We use a try/catch because rootBundle.load throws if the asset is missing
      final ByteData data = await rootBundle.load('assets/openclaw-node-modules.tar.gz');
      
      _log('🚚 Pre-bundled OpenClaw found! Extracting...');
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.3, 'Using pre-bundled OpenClaw (fast setup)...', 85);
      
      // 1. Create target directory
      await NativeBridge.runInProot('mkdir -p /usr/local/lib/node_modules');
      
      // 2. Write asset to a temporary file in the rootfs
      final tempTarPath = '$rootfsDir/tmp/openclaw-modules.tar.gz';
      final buffer = data.buffer.asUint8List();
      await File(tempTarPath).writeAsBytes(buffer);
      
      // 3. Extract using tar inside proot (native and fast)
      await NativeBridge.runInProot(
        'tar -xzf /tmp/openclaw-modules.tar.gz -C /usr/local/lib/node_modules && rm /tmp/openclaw-modules.tar.gz',
        timeout: 120,
      );
      
      _log('✅ Pre-bundled OpenClaw extracted successfully');
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.8, 'Pre-bundled OpenClaw ready', 90);
    } catch (e) {
      _log('ℹ️ No pre-bundled OpenClaw found in assets, falling back to npm install. ($e)');
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.1, 'Installing OpenClaw (slower path)...', 82);
    }
  }

  /// Final heavy cleanup of caches and temporary files.
  Future<void> _performFinalCleanup() async {
    _log('🧹 Performing final heavy cleanup...');
    await NativeBridge.runInProot('''
      npm cache clean --force &&
      rm -rf /root/.npm/_cacache /root/.npm/_logs &&
      apt-get clean &&
      rm -rf /var/lib/apt/lists/* /var/cache/apt/*
    ''');
  }

  /// Extracts a bundled rootfs.tar.gz from assets if present.
  /// Returns true if the extraction was successful.
  Future<bool> _extractBundledRootfs() async {
    _log('📦 Checking for bundled rootfs asset...');
    try {
      final ByteData data = await rootBundle.load('assets/rootfs.tar.gz');
      _log('🚚 Bundled rootfs found! Extracting...');
      
      final filesDir = await NativeBridge.getFilesDir();
      final tarPath = '$filesDir/tmp/rootfs_bundled.tar.gz';
      
      final buffer = data.buffer.asUint8List();
      await File(tarPath).writeAsBytes(buffer);
      
      await NativeBridge.extractRootfs(tarPath);
      await File(tarPath).delete();
      
      _log('✅ Bundled rootfs extracted successfully');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _extractPrebundledOpenClawAegis(Function(SetupState) onProgress, String targetPath) async {
    _log('📦 Deploying pre-bundled OpenClaw to $targetPath');
    try {
      final ByteData data = await rootBundle.load('assets/openclaw-node-modules.tar.gz');
      final filesDir = await NativeBridge.getFilesDir();
      final tempPath = '$filesDir/tmp/openclaw-aegis.tar.gz';
      
      await Directory('$filesDir/tmp').create(recursive: true);
      await File(tempPath).writeAsBytes(data.buffer.asUint8List());
      
      await NativeBridge.extractGlibcBridge(tempPath);
      await File(tempPath).delete();
      
      _log('✅ OpenClaw extracted to Aegis lib path');
    } catch (e) {
      _log('❌ Failed to extract Aegis pre-bundled asset: $e');
      throw Exception('Aegis asset deployment failed.');
    }
  }

  Future<void> _repairConfigAegis(String filesDir) async {
    final configFile = File('$filesDir/glibc/lib/node_modules/openclaw/config/openclaw.json');
    final standardConfig = File('$filesDir/home/.openclaw/openclaw.json');
    final targetFile = await standardConfig.exists() ? standardConfig : configFile;

    if (!await targetFile.exists()) return;

    try {
      String content = await targetFile.readAsString();
      Map<String, dynamic> config = json.decode(content);
      config['tools'] ??= {'allow': ['*']};
      (config['tools'] as Map)['allow'] = ['*'];
      await targetFile.writeAsString(const JsonEncoder.withIndent('  ').convert(config));
      _log('✅ Aegis config hardened');
    } catch (e) {
      _log('Aegis config repair failed: $e');
    }
  }

  void _updateSetupNotification(String message, {int progress = -1}) {
    NativeBridge.updateSetupNotification(message, progress: progress);
  }

  void _emitProgress(Function(SetupState) onProgress, SetupStep step, double progress, String message, int notifProgress) {
    _updateSetupNotification(message, progress: notifProgress);
    onProgress(SetupState(step: step, progress: progress, message: message));
  }
}
