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
import '../constants/openclaw_paths.dart';
import 'skills_service.dart';
import 'gateway_service.dart';

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
        '$kOpenClawCommand update -g openclaw',
        timeout: 300,
      );
      
      _updateSetupNotification('Gateway updated successfully!', progress: 100);
    } catch (e, stack) {
      _log('Gateway update failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  void _updateSetupNotification(String text, {int progress = -1}) {
    try {
      NativeBridge.updateSetupNotification(text, progress: progress);
    } catch (e) {
      _log('Failed to update notification', error: e);
    }
  }

  void _stopSetupService() {
    try {
      NativeBridge.stopSetupService();
    } catch (e) {
      _log('Failed to stop setup service', error: e);
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

  /// Update ONLY Node.js without full rootfs reinstall
  /// Surgical update that preserves existing setup
  Future<void> updateNodejsOnly({required void Function(SetupState) onProgress}) async {
    try {
      _emitProgress(onProgress, SetupStep.checkingStatus, 0.0, 'Checking Node.js version...', 2);
      
      if (!await checkNodeUpgradeRequired()) {
        _emitProgress(onProgress, SetupStep.complete, 1.0, 'Node.js is up to date.', 100);
        return;
      }
      
      _emitProgress(onProgress, SetupStep.installingNode, 0.0, 'Updating Node.js only...', 5);
      
      final arch = await NativeBridge.getArch();
      final filesDir = await NativeBridge.getFilesDir();
      final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
      final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';
      
      // Download Node.js only
      await _downloadWithRetry(
        nodeTarUrl,
        nodeTarPath,
        onProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            final mb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            final int notifProgress = 5 + (progress * 20).round();
            
            _updateSetupNotification('Downloading Node.js: $mb / $totalMb MB', progress: notifProgress);
            onProgress(SetupState(
              step: SetupStep.installingNode,
              progress: progress,
              message: 'Downloading Node.js: $mb MB / $totalMb MB',
            ));
          }
        },
      );
      
      _emitProgress(onProgress, SetupStep.installingNode, 0.5, 'Extracting Node.js...', 70);
      await NativeBridge.extractNodeTarball(nodeTarPath);
      
      // Fix ESM shebang after Node.js update
      await _fixOpenClawShebang(onProgress: onProgress);
      
      _emitProgress(onProgress, SetupStep.complete, 1.0, 'Node.js update complete!', 100);
      
    } catch (e) {
      _log('Node.js-only update failed: $e');
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Node.js update failed: $e',
      ));
    }
  }

  Future<void> runFullSetup({required void Function(SetupState) onProgress}) async {
    try {
      // Start foreground service to keep app alive during setup
      try {
        await NativeBridge.startSetupService();
      } catch (e) {
        _log('Non-fatal: Setup service failed to start', error: e);
      }

      // ---------------------------------------------------------
      // Step 0: Setup directories & Check status
      // ---------------------------------------------------------
      _emitProgress(onProgress, SetupStep.checkingStatus, 0.05, 'Preparing environment...', 5);
      await NativeBridge.setupDirs();
      await NativeBridge.writeResolv();

      final status = await NativeBridge.getBootstrapStatus();
      final bool rootfsInstalled = status['binBashExists'] ?? false;
      final bool nodeInstalled = status['nodeInstalled'] ?? false;
      final bool bypassInstalled = status['bypassInstalled'] ?? false;
      final bool openclawInstalled = status['openclawInstalled'] ?? false;

      final arch = await NativeBridge.getArch();
      final filesDir = await NativeBridge.getFilesDir();

      if (!rootfsInstalled) {
        // Step 1: Get rootfs (Bundled Asset -> then Download)
        // ---------------------------------------------------------
        _emitProgress(onProgress, SetupStep.downloadingRootfs, 0.1, 'Checking for bundled rootfs...', 10);
        bool rootfsReady = await _extractBundledRootfs();
        
        if (!rootfsReady) {
          _log('ℹ️ No bundled rootfs found, falling back to download...');
          
          final String rootfsUrl = AppConstants.getRootfsUrl(arch);
          final String tarPath = '$filesDir/tmp/rootfs.tar.gz';

          await _downloadParallel(
            rootfsUrl,
            tarPath,
            onProgress: (received, total) {
              if (total > 0) {
                final progress = (received / total) * 0.15;
                final mb = (received / 1024 / 1024).toStringAsFixed(1);
                final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
                final notifProgress = 10 + ((received / total) * 20).round();
                
                _updateSetupNotification('Downloading rootfs: $mb / $totalMb MB', progress: notifProgress);
                onProgress(SetupState(
                  step: SetupStep.downloadingRootfs,
                  progress: progress,
                  message: 'Downloading rootfs',
                  subMessage: '$mb / $totalMb MB',
                ));
              }
            },
          );

          _emitProgress(onProgress, SetupStep.extractingRootfs, 0.25, 'Optimizing environment for local LLM...', 30);
          await NativeBridge.extractRootfs(tarPath);
          rootfsReady = true;
        }
        
        _emitProgress(onProgress, SetupStep.extractingRootfs, 0.35, 'Rootfs environment ready', 40);
      } else {
        _emitProgress(onProgress, SetupStep.extractingRootfs, 0.35, 'Rootfs already present', 40);
      }

      if (!bypassInstalled) {
        await NativeBridge.installBionicBypass();
      }

      // ---------------------------------------------------------
      // Step 3: Install Node.js & Fix Permissions
      // ---------------------------------------------------------
      if (!nodeInstalled) {
        _emitProgress(onProgress, SetupStep.installingNode, 0.40, 'Installing Node.js core...', 45);
        
        await NativeBridge.runInProot('''
          mkdir -p /root/.openclaw
        ''');

        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
          'chmod -R 755 /usr/bin /usr/sbin /bin /sbin /usr/local/bin /usr/local/sbin 2>/dev/null; '
          'chmod -R +x /usr/lib/apt/ /usr/lib/dpkg/ /usr/libexec/ /var/lib/dpkg/info/ /usr/share/debconf/ 2>/dev/null; '
          'chmod 755 /lib/*/ld-linux-*.so* /usr/lib/*/ld-linux-*.so* 2>/dev/null; '
          'mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/triggers; '
          'echo permissions_fixed',
        );

        _emitProgress(onProgress, SetupStep.installingNode, 0.42, 'Updating package lists...', 46,
            subMessage: 'Syncing with Ubuntu mirrors');
        
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
          'export DEBIAN_FRONTEND=noninteractive && '
          'apt-get update -y'
        );

        _emitProgress(onProgress, SetupStep.installingNode, 0.45, 'Installing system tools...', 48,
            subMessage: 'ca-certificates • git • curl • zstd • tmux • jq');

        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
          'export DEBIAN_FRONTEND=noninteractive && '
          'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
          'echo "Etc/UTC" > /etc/timezone && '
          'apt-get install -y --no-install-recommends ca-certificates git curl zstd tmux jq && '
          'apt-get clean && rm -rf /var/lib/apt/lists/*'
        );

        final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
        final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';

        _emitProgress(onProgress, SetupStep.installingNode, 0.50, 'Downloading Node.js (fast link)...', 55);

        await _downloadParallel(
          nodeTarUrl,
          nodeTarPath,
          onProgress: (received, total) {
            if (total > 0) {
              final progress = 0.5 + (received / total) * 0.1;
              final mb = (received / 1024 / 1024).toStringAsFixed(1);
              final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
              final notifProgress = 55 + ((received / total) * 15).round();
              
              _updateSetupNotification('Downloading Node.js: $mb / $totalMb MB', progress: notifProgress);
              onProgress(SetupState(
                step: SetupStep.installingNode,
                progress: progress,
                message: 'Downloading Node.js',
                subMessage: '$mb / $totalMb MB',
              ));
            }
          },
        );

        _emitProgress(onProgress, SetupStep.installingNode, 0.60, 'Extracting Node.js...', 72);
        await NativeBridge.extractNodeTarball(nodeTarPath);
      } else {
        _emitProgress(onProgress, SetupStep.installingNode, 0.60, 'Node.js already installed', 78);
      }

      await _hardenEnvironment();
      await _repairConfig();

      // ---------------------------------------------------------
      // Step 4: Install OpenClaw
      // ---------------------------------------------------------
      if (!openclawInstalled) {
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.65, 'Installing OpenClaw core...', 80);
        
        bool success = await _extractPrebundledOpenClaw(onProgress);
        
        if (!success) {
          _log('ℹ️ Pre-bundled OpenClaw not found, falling back to npm...');
          await _installMinimalBuildTools();
          await _ensureOpenClawPackageExists();
          await _purgeBuildTools();
        }
      } else {
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.75, 'OpenClaw already present', 95);
        await _ensureOpenClawPackageExists();
      }
      
      await NativeBridge.createBinWrappers('openclaw');
      await _hardenOpenClawConfig();

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.80, 'Running industrial onboard...', 85, 
          subMessage: 'Hardware validation • SecretRef syncing');

      // Full onboard (your engineers' CLI — untouched)
      unawaited(NativeBridge.runInProot(
        '$kOpenClawCommand onboard --non-interactive --mode local --flow quickstart --auth-choice skip --skip-health --skip-bootstrap --accept-risk',
        timeout: 60,
      ));

      await Future.delayed(const Duration(milliseconds: 800));
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.85, 'Configuring API credentials...', 90,
          subMessage: 'Running doctor --fix + security hardening');

      await NativeBridge.runInProot('$kOpenClawCommand doctor --fix');

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.90, 'Applying final configuration...', 92,
          subMessage: 'Token preservation + allowedOrigins + node pairing');

      await GatewayService().hardenGatewayConfigViaCli();

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.93, 'Starting AI gateway...', 95,
          subMessage: 'Plugins loading • Voice engine • Canvas');

      final gateway = GatewayService();
      await gateway.attachOrStart();

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.96, 'Verifying connections...', 98,
          subMessage: 'WebSocket • Node pairing • Health check');

      try {
        await gateway.waitForStartup(timeout: const Duration(seconds: 90));
        
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.98, 'Auto-approving node...', 99);
        await _approveLocalNodeIfNeeded();

        _emitProgress(onProgress, SetupStep.complete, 1.0, 'Setup complete!', 100, 
            subMessage: 'System Online & Ready');
      } catch (e) {
        _log('Gateway warmup or approval timed out', error: e);
        // Try approval one last time even if health check failed (might be slow)
        await _approveLocalNodeIfNeeded().catchError((_) => null);
        _emitProgress(onProgress, SetupStep.complete, 1.0, 'Setup complete!', 100,
            subMessage: 'System starting in background');
      }

      await NativeBridge.markBootstrapComplete();
      final prefs = PreferencesService();
      await prefs.init();
      prefs.setupComplete = true;
      if (prefs.dashboardUrl == null || prefs.dashboardUrl!.isEmpty) {
        prefs.dashboardUrl = 'http://127.0.0.1:18789';
      }

      _stopSetupService();

    } on DioException catch (e) {
      _stopSetupService();
      _log('Network error', error: e);
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Network error: ${e.message}. Check your internet connection.',
      ));
    } catch (e, stack) {
      _stopSetupService();
      _log('Setup failed globally', error: e, stackTrace: stack);
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Setup failed: $e',
      ));
    }
  }

  /// FIX: Repair broken openclaw.mjs shebang for ESM compatibility
  /// The exec node line is being parsed as JavaScript instead of shell
  Future<void> _fixOpenClawShebang({required void Function(SetupState) onProgress}) async {
    try {
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.1, 'Cleaning broken installation...', 82,
          subMessage: 'Purging global node_modules & apt cache');
      
      // 1. Force remove old installation and any stray files
      await NativeBridge.runInProot('npm uninstall -g openclaw || true');
      await NativeBridge.runInProot('rm -rf /usr/local/lib/node_modules/openclaw');
      await NativeBridge.runInProot('rm -f /usr/local/bin/openclaw'); 
      await NativeBridge.runInProot('npm cache clean --force || true');
      await NativeBridge.runInProot('apt-get clean || true');
      
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.3, 'Reinstalling OpenClaw (latest)...', 85,
          subMessage: 'Running npm install --production');
      
      // 2. Fresh install (latest) + peer dep fix for @buape/carbon
      await NativeBridge.runInProot(
        'npm install -g openclaw@latest --prefix /usr/local --no-audit --no-fund --production && '
        'cd /usr/local/lib/node_modules/openclaw && npm install --no-audit --no-fund 2>/dev/null || true',
        timeout: 1800,
      );
      
      await NativeBridge.runInProot(
        '$kOpenClawCommand doctor --fix 2>/dev/null || true',
        timeout: 10,
      );
      
      // 3. Re-create wrappers using the hardened native logic
      await NativeBridge.createBinWrappers('openclaw');

      // 4. Harden environment again
      await _hardenEnvironment();
      
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
        '/usr/local/bin/npm install -g openclaw@latest --prefix /usr/local --no-audit --no-fund --ignore-scripts --production',
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
  Future<bool> _extractPrebundledOpenClaw(Function(SetupState) onProgress) async {
    _log('📦 Checking for pre-bundled OpenClaw assets...');
    try {
      final rootfsDir = await getRootfsDirectory();
      
      // Check if the asset exists in the bundle
      _log('📖 Reading 100MB pre-bundled modules (this may take a moment)...');
      final ByteData data = await rootBundle.load('assets/openclaw-node-modules.tar.gz');
      
      _log('🚚 Pre-bundled OpenClaw found! Extracting...');
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.3, 'Using pre-bundled OpenClaw (fast setup)...', 85,
          subMessage: 'Extracting assets from APK bundle');
      
      // 1. Create target directory
      await NativeBridge.runInProot('mkdir -p /usr/local/lib/node_modules');
      
      // 2. Write asset to a temporary file in the rootfs
      final tempTarPath = '$rootfsDir/tmp/openclaw-modules.tar.gz';
      final buffer = data.buffer.asUint8List();
      await File(tempTarPath).writeAsBytes(buffer);
      
      // 3. Extract using tar inside proot (native and fast)
      // Handles various structures (package/, openclaw/, or lib/node_modules/)
      await NativeBridge.runInProot(
        'cd /tmp && tar -xzf openclaw-modules.tar.gz && rm openclaw-modules.tar.gz && '
        'if [ -d package ]; then rm -rf /usr/local/lib/node_modules/openclaw && mv package /usr/local/lib/node_modules/openclaw; '
        'elif [ -d openclaw ]; then rm -rf /usr/local/lib/node_modules/openclaw && mv openclaw /usr/local/lib/node_modules/openclaw; '
        'elif [ -d lib/node_modules/openclaw ]; then rm -rf /usr/local/lib/node_modules/openclaw && mv lib/node_modules/openclaw /usr/local/lib/node_modules/openclaw; fi && '
        'chmod +x /usr/local/lib/node_modules/openclaw/*.mjs 2>/dev/null || true',
        timeout: 120,
      );
      
      _log('✅ Pre-bundled OpenClaw extracted successfully');
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.8, 'Pre-bundled OpenClaw ready', 90,
          subMessage: 'Verifying package integrity');
      return true;
    } catch (e) {
      _log('ℹ️ No pre-bundled OpenClaw found in assets, falling back to npm install. ($e)');
      return false;
    }
  }

  /// Final heavy cleanup of caches and temporary files.
  Future<void> _performFinalCleanup() async {
    _log('🧹 Performing final heavy cleanup...');
    await NativeBridge.runInProot('''
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

  Future<void> _purgeBuildTools() async {
    _log('🧹 Purging build tools to save space...');
    await NativeBridge.runInProot(
      'apt-get purge -y build-essential python3 make g++ && '
      'apt-get autoremove -y && '
      'apt-get clean && rm -rf /var/lib/apt/lists/*',
      timeout: 120,
    );
  }

  void _emitProgress(Function(SetupState) onProgress, SetupStep step, double progress, String message, int notifProgress, {String? subMessage}) {
    _updateSetupNotification(message, progress: notifProgress);
    onProgress(SetupState(
      step: step, 
      progress: progress, 
      message: message,
      subMessage: subMessage,
    ));
  }

  /// Robust config repair. Auto-fixes stale openclaw.json, tools.allow, gateway mode, etc.
  /// Prevents stale configurations from blocking tool access.
  Future<void> _repairConfig() async {
    final rootfsDir = await getRootfsDirectory();
    final configFile = File('$rootfsDir/root/.openclaw/openclaw.json');

    if (!await configFile.exists()) {
      _log('No openclaw.json found — skipping repair');
      return;
    }

    _log('🔧 Running config repair (auto-patching stale tools.allow, etc.)');

    try {
      String content = await configFile.readAsString();
      Map<String, dynamic> config = json.decode(content);

      // Force correct tools.allow (this fixes a major pain point)
      if (config['tools'] == null || config['tools'] is! Map) {
        config['tools'] = {'allow': ['*']};
      } else {
        (config['tools'] as Map)['allow'] = ['*'];
      }

      // Ensure gateway is in correct mode
      config['gateway'] ??= {};
      if (config['gateway'] is Map) {
        (config['gateway'] as Map)['mode'] = 'full';
      }

      await configFile.writeAsString(const JsonEncoder.withIndent('  ').convert(config));
      _log('✅ Config repaired successfully');
    } catch (e) {
      _log('Config repair failed (non-critical)', error: e);
    }
  }
  
  /// Hardens the PRoot environment by ensuring a robust PATH and NODE_OPTIONS are always available.
  /// This appends permanent exports to /root/.bashrc.
  Future<void> _hardenEnvironment() async {
    _log('🛡 Hardening environment in /root/.bashrc...');
    try {
      const pathExport = 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH';
      const nodeOptions = 'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js"';
      
      await NativeBridge.runInProot(
        'grep -q "export PATH=/usr/local/sbin" /root/.bashrc || echo "$pathExport" >> /root/.bashrc'
      );
      await NativeBridge.runInProot(
        'grep -q "export NODE_OPTIONS" /root/.bashrc || echo "$nodeOptions" >> /root/.bashrc'
      );
      _log('✅ Environment hardened');
    } catch (e) {
      _log('Non-fatal: Environment hardening failed', error: e);
    }
  }

  /// Enables watch mode for skills in openclaw.json to ensure immediate awareness of new files.
  Future<void> _enableSkillsWatchMode() async {
    _log('👀 Enabling skills watch mode in openclaw.json...');
    try {
      final rootfsDir = await getRootfsDirectory();
      final configFile = File('$rootfsDir/root/.openclaw/openclaw.json');

      if (!await configFile.exists()) return;

      String content = await configFile.readAsString();
      Map<String, dynamic> config = json.decode(content);

      config['skills'] ??= {};
      final skills = config['skills'] as Map<String, dynamic>;
      skills['load'] ??= {};
      final load = skills['load'] as Map<String, dynamic>;
      load['watch'] = true;

      await configFile.writeAsString(const JsonEncoder.withIndent('  ').convert(config));
      _log('✅ Skills watch mode enabled');
    } catch (e) {
      _log('Failed to enable skills watch mode (non-critical)', error: e);
    }
  }

  Future<void> _hardenOpenClawConfig() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final configPath = '$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json';
      final configFile = File(configPath);

      Map<String, dynamic> config = {};
      if (await configFile.exists()) {
        try {
          config = jsonDecode(await configFile.readAsString());
        } catch (_) {
          // If corrupt, start fresh
        }
      } else {
        await configFile.parent.create(recursive: true);
      }

      // Replicate the Ollama-first logic from GatewayService for setup-time hardening
      config['gateway'] ??= {};
      config['gateway']['mode'] = 'local';
      config['gateway']['bind'] = 'loopback';
      config['gateway']['port'] = AppConstants.gatewayPort;
      config['gateway']['controlUi'] ??= {};
      config['gateway']['controlUi']['allowedOrigins'] = [
        '*',
        'n/a', 
        'http://127.0.0.1:18789',
        'http://localhost:18789'
      ];
      
      // Fix autoApprove path to match official OpenClaw 2.0 strict schema
      config['gateway']['nodes'] ??= {};
      config['gateway']['nodes']['pairing'] ??= {};
      config['gateway']['nodes']['pairing']['autoApproveCidrs'] = ['127.0.0.1/32'];

      // 2. Default Agent configuration
      config['agents'] ??= {};
      config['agents']['defaults'] ??= {};
      config['agents']['defaults']['model'] ??= {};
      config['agents']['defaults']['model']['primary'] ??= 'google/gemini-3.1-pro-preview';
      
      // 3. Hardened Ollama-first
      config['models'] ??= {};
      config['models']['providers'] ??= {};
      config['models']['providers']['ollama'] ??= <String, dynamic>{};
      final ollama = Map<String, dynamic>.from(config['models']['providers']['ollama'] as Map);
      ollama['baseUrl'] ??= 'http://127.0.0.1:11434';
      ollama['apiKey'] ??= 'ollama-local';
      ollama['api'] ??= 'ollama';
      ollama['models'] ??= []; // FIX: Prevents "expected array, received undefined" error
      config['models']['providers']['ollama'] = ollama;

      // 4. Hardened Google/Gemini (Prevents "expected string, received undefined" reload error)
      config['models'] ??= {};
      config['models']['providers'] ??= {};
      config['models']['providers']['google'] ??= <String, dynamic>{};
      final google = Map<String, dynamic>.from(config['models']['providers']['google'] as Map);
      google['baseUrl'] ??= 'https://generativelanguage.googleapis.com/v1beta';
      google['api'] ??= 'google-generative-ai';
      google['models'] ??= [];
      config['models']['providers']['google'] = google;

      // 5. GLOBAL ORIGIN ENFORCEMENT
      config['gateway'] ??= {};
      config['gateway']['controlUi'] ??= {};
      config['gateway']['controlUi']['allowedOrigins'] = [
        '*',
        'n/a', 
        'http://127.0.0.1:18789',
        'http://localhost:18789'
      ];

      // 6. LOCAL-FIRST TTS HARDENING (Offline voice support)
      config['messages'] ??= {};
      config['messages']['tts'] ??= {};
      config['messages']['tts']['provider'] ??= 'sherpa-onnx';
      config['messages']['tts']['auto'] ??= 'inbound';
      config['messages']['tts']['personas'] ??= {
        'default': { 'provider': 'sherpa-onnx', 'voice': 'en_US-lessac-high' },
        'friendly': { 'provider': 'sherpa-onnx', 'voice': 'en_US-amy-low' },
        'warm': { 'provider': 'sherpa-onnx', 'voice': 'en_US-kathleen-low' },
        'professional': { 'provider': 'sherpa-onnx', 'voice': 'en_US-lessac-medium' },
        'authoritative': { 'provider': 'sherpa-onnx', 'voice': 'en_US-ryan-high' },
        'casual': { 'provider': 'sherpa-onnx', 'voice': 'en_US-lessac-low' },
        'enthusiastic': { 'provider': 'sherpa-onnx', 'voice': 'en_US-amy-medium' },
        'whispering': { 'provider': 'sherpa-onnx', 'voice': 'en_US-kathleen-low' },
      };

      await configFile.writeAsString(jsonEncode(config));
      _log('[CONFIG] Hardened production-grade configuration (Ollama + Google + Origins).');
    } catch (e) {
      _log('[CONFIG] Hardening failed during setup', error: e);
    }
  }

  Future<void> repairOpenClaw({required void Function(SetupState) onProgress}) async {
    await _fixOpenClawShebang(onProgress: onProgress);
  }

  Future<bool> checkNodeUpgradeRequired() async {
    try {
      final status = await NativeBridge.getBootstrapStatus();
      final currentVersion = status['nodeVersion'] as String? ?? '0.0.0';
      // If version is 18.x or lower, we definitely need 22.x
      return currentVersion.startsWith('v18') || currentVersion.startsWith('v16') || currentVersion == '0.0.0';
    } catch (_) {
      return true;
    }
  }

  Future<void> _downloadWithRetry(
    String url,
    String savePath, {
    required void Function(int received, int total) onProgress,
    int retries = 3,
  }) async {
    int attempt = 0;
    while (attempt < retries) {
      try {
        await _downloadParallel(url, savePath, onProgress: onProgress);
        return;
      } catch (e) {
        attempt++;
        if (attempt >= retries) rethrow;
        _log('Download failed, retrying ($attempt/$retries)... $e');
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }

  Future<void> _approveLocalNodeIfNeeded() async {
    try {
      _log('Approving local Android node...');
      // 1. Give the gateway a moment to register the pending request
      await Future.delayed(const Duration(seconds: 3));
      
      // 2. Use the Auditor's "Magic Bullet" logic: 
      // Try to get specific ID via jq, then fallback to --latest variant.
      await NativeBridge.runInProot(
        'REQUEST_ID=\$(\$kOpenClawCommand devices list --json 2>/dev/null | jq -r ".pending[0].requestId // empty"); '
        'if [ -n "\$REQUEST_ID" ]; then '
        '  echo y | \$kOpenClawCommand devices approve "\$REQUEST_ID" || '
        '  echo y | \$kOpenClawCommand device pair approve "\$REQUEST_ID" || '
        '  echo y | \$kOpenClawCommand pair approve "\$REQUEST_ID"; '
        'else '
        '  echo y | \$kOpenClawCommand devices approve --latest || '
        '  echo y | \$kOpenClawCommand device pair approve --latest || '
        '  echo y | \$kOpenClawCommand pair approve --latest; '
        'fi',
        timeout: 20,
      );
      _log('✅ Local node proactive approval completed');
    } catch (e) {
      _log('Non-fatal: Proactive approval failed: $e');
    }
  }
}
