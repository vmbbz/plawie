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
            final notifProgress = 5 + (progress * 20).round();
            
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
      await _fixOpenClawShebang();
      
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
      _emitProgress(onProgress, SetupStep.checkingStatus, 0.0, 'Checking system status...', 2);
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
                final progress = (received / total) * 0.3;
                final mb = (received / 1024 / 1024).toStringAsFixed(1);
                final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
                final notifProgress = ((received / total) * 30).round();
                
                _updateSetupNotification('Downloading rootfs: $mb / $totalMb MB', progress: notifProgress);
                onProgress(SetupState(
                  step: SetupStep.downloadingRootfs,
                  progress: progress,
                  message: 'Downloading: $mb MB / $totalMb MB',
                ));
              }
            },
          );

          _emitProgress(onProgress, SetupStep.extractingRootfs, 0.05, 'Optimizing environment for local LLM...', 30);
          await NativeBridge.extractRootfs(tarPath);
          rootfsReady = true;
        }
        
        _emitProgress(onProgress, SetupStep.extractingRootfs, 1.0, 'Rootfs extracted', 40);
      } else {
        _emitProgress(onProgress, SetupStep.extractingRootfs, 1.0, 'Rootfs already present, skipping...', 40);
      }

      if (!bypassInstalled) {
        await NativeBridge.installBionicBypass();
      }

      // ---------------------------------------------------------
      // Step 3: Install Node.js & Fix Permissions
      // ---------------------------------------------------------
      if (!nodeInstalled) {
        _emitProgress(onProgress, SetupStep.installingNode, 0.05, 'Fixing rootfs permissions...', 45);

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

        _emitProgress(onProgress, SetupStep.installingNode, 0.1, 'Updating package lists...', 48);
        
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
          'export DEBIAN_FRONTEND=noninteractive && '
          'apt-get update -y && '
          'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
          'echo "Etc/UTC" > /etc/timezone && '
          'apt-get install -y --no-install-recommends ca-certificates git curl zstd tmux jq && '
          'apt-get clean && rm -rf /var/lib/apt/lists/*'
        );

        final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
        final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';

        _emitProgress(onProgress, SetupStep.installingNode, 0.3, 'Downloading Node.js (fast link)...', 55);

        await _downloadParallel(
          nodeTarUrl,
          nodeTarPath,
          onProgress: (received, total) {
            if (total > 0) {
              final progress = 0.3 + (received / total) * 0.4;
              final mb = (received / 1024 / 1024).toStringAsFixed(1);
              final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
              final notifProgress = 55 + ((received / total) * 15).round();
              
              _updateSetupNotification('Downloading Node.js: $mb / $totalMb MB', progress: notifProgress);
              onProgress(SetupState(
                step: SetupStep.installingNode,
                progress: progress,
                message: 'Downloading Node.js: $mb MB / $totalMb MB',
              ));
            }
          },
        );

        _emitProgress(onProgress, SetupStep.installingNode, 0.75, 'Extracting Node.js...', 72);
        await NativeBridge.extractNodeTarball(nodeTarPath);

        _emitProgress(onProgress, SetupStep.installingNode, 0.9, 'Verifying Node.js...', 78);
        
        const wrapper = '/root/.openclaw/node-wrapper.js';
        const nodeRun = 'node $wrapper';
        const npmCli = '/usr/local/lib/node_modules/npm/bin/npm-cli.js';
        await NativeBridge.runInProot('export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && node --version && $nodeRun $npmCli --version');
      } else {
        _emitProgress(onProgress, SetupStep.installingNode, 1.0, 'Node.js already installed, skipping...', 78);
      }

      // ---------------------------------------------------------
      // Step 3.5: Repair Config (Fix stale tools.allow, etc.)
      // ---------------------------------------------------------
      await _repairConfig();

      // ---------------------------------------------------------
      // Step 4: Install OpenClaw
      // ---------------------------------------------------------
      if (!openclawInstalled) {
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.05, 'Installing OpenClaw Gateway...', 80);
        
        // 1. Try FAST path first (Pre-bundled assets)
        bool success = await _extractPrebundledOpenClaw(onProgress);
        
        if (!success) {
          _log('ℹ️ Pre-bundled OpenClaw not found or failed, falling back to slow path (compilation)...');
          
          // Phase 2: Install temporary build tools for native module compilation
          await _installMinimalBuildTools();
          
          // Phase 2.6: Install OpenClaw via NPM
          await _ensureOpenClawPackageExists();
          
          // Phase 3: Purge build tools immediately after success to save ~500MB
          _emitProgress(onProgress, SetupStep.cleanup, 0.5, 'Slimming system (purging tools)...', 96);
          await _purgeBuildTools();
        }
        
        // Final heavy cleanup
        _emitProgress(onProgress, SetupStep.cleanup, 0.9, 'Final cache optimization...', 98);
        await _performFinalCleanup();
        
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 1.0, 'OpenClaw Gateway installed', 95);
      } else {
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 1.0, 'OpenClaw already present, verifying...', 95);
        // Force verification even if status says installed (redundant but robust)
        await _ensureOpenClawPackageExists();
      }
      await NativeBridge.createBinWrappers('openclaw');
      
      // FIX: Repair broken openclaw.mjs shebang for ESM compatibility
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.75, 'Fixing OpenClaw ESM shebang...', 87);
      await _fixOpenClawShebang();

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.9, 'Verifying OpenClaw...', 90);
      await NativeBridge.runInProot('export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && /usr/local/bin/openclaw --version || echo openclaw_installed');

      // Seed official onboarding config (Advanced)
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.95, 'Initializing environment...', 95);
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        '/usr/local/bin/openclaw onboard --non-interactive --mode local --flow quickstart --skip-health --skip-bootstrap --accept-risk',
        timeout: 60,
      );

      // ---------------------------------------------------------
      // Step 5: Install Native Android Skills
      // ---------------------------------------------------------
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.95, 'Installing Android native skills...', 95);
      
      try {
        final prootRoot = '$filesDir/rootfs/ubuntu/root';
        final openclawSkillsDir = Directory('$prootRoot/.openclaw/skills');
        final openclawExtDir = Directory('$prootRoot/.openclaw/extensions');
        
        if (!openclawSkillsDir.existsSync()) openclawSkillsDir.createSync(recursive: true);
        if (!openclawExtDir.existsSync()) openclawExtDir.createSync(recursive: true);

        // Copy android bridge tools JS script to extensions so skills can require it or OpenClaw can load it
        final bridgeJs = await rootBundle.loadString('assets/openclaw/android_bridge_tools.js');
        File('${openclawExtDir.path}/android_bridge_tools.js').writeAsStringSync(bridgeJs);

        // Copy the SKILL markdown files
        final skills = ['battery.md', 'vibrate.md', 'sensors.md', 'avatar_forge.md'];
        for (final skill in skills) {
          final content = await rootBundle.loadString('assets/openclaw/skills/$skill');
          File('${openclawSkillsDir.path}/$skill').writeAsStringSync(content);
        }
      } catch (e) {
        _log('Non-fatal: Failed to copy native skills', error: e);
      }

      // ---------------------------------------------------------
      // Step 6: Finalize
      // ---------------------------------------------------------
      await NativeBridge.markBootstrapComplete();
      final prefs = PreferencesService();
      await prefs.init();
      prefs.setupComplete = true;

      // Ensure a default dashboard URL exists so SplashScreen can transition to Dashboard
      if (prefs.dashboardUrl == null || prefs.dashboardUrl!.isEmpty) {
        prefs.dashboardUrl = 'http://127.0.0.1:18789';
      }

      _emitProgress(onProgress, SetupStep.complete, 1.0, 'Setup complete! Ready to start the gateway.', 100);
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
  Future<void> _fixOpenClawShebang() async {
    try {
      // Read the current openclaw.mjs file
      final filesDir = await NativeBridge.getFilesDir();
      final openclawMjs = File('$filesDir/rootfs/ubuntu/root/usr/local/lib/node_modules/openclaw/openclaw.mjs');
      
      // 1. Force remove old installation and any stray files
      await NativeBridge.runInProot('/usr/local/bin/node /usr/local/bin/npm uninstall -g openclaw || true');
      await NativeBridge.runInProot('rm -rf /usr/local/lib/node_modules/openclaw');
      await NativeBridge.runInProot('rm -f /usr/local/bin/openclaw'); 
      await NativeBridge.runInProot('npm cache clean --force || true');
      await NativeBridge.runInProot('apt-get clean || true');
      
      String content = await openclawMjs.readAsString();
      
      // 2. Fresh install (latest) + peer dep fix for @buape/carbon
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'npm install -g openclaw@latest --prefix /usr/local --no-audit --no-fund --production && '
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
  Future<bool> _extractPrebundledOpenClaw(Function(SetupState) onProgress) async {
    _log('📦 Checking for pre-bundled OpenClaw assets...');
    try {
      final rootfsDir = await getRootfsDirectory();
      
      // Check if the asset exists in the bundle
      _log('📖 Reading 100MB pre-bundled modules (this may take a moment)...');
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

  void _emitProgress(Function(SetupState) onProgress, SetupStep step, double progress, String message, int notifProgress) {
    _updateSetupNotification(message, progress: notifProgress);
    onProgress(SetupState(step: step, progress: progress, message: message));
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
}
