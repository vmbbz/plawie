import 'dart:async';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';
import 'package:flutter/services.dart';
import 'preferences_service.dart';
import 'model_provider_catalog.dart';
import 'gateway_tool_catalog.dart';
import 'dart:io';
import '../constants/openclaw_paths.dart';
import 'gateway_service.dart';
import 'package:uuid/uuid.dart';

class BootstrapService {
  static const bool _forceLiveOpenClawInstall = true;
  static const String _latestOpenClawInstallCommand = 'unset NODE_OPTIONS; '
      'env -u NODE_OPTIONS /usr/local/bin/npm install -g openclaw@latest '
      '--prefix /usr/local --no-audit --no-fund --omit=dev';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10), // Rootfs can be large
  ));

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message,
        name: 'BootstrapService', error: error, stackTrace: stackTrace);
  }

  Future<void> _stopGatewayBeforeSetup() async {
    // Setup performs many config writes. If even one old gateway process is
    // still watching openclaw.json, those writes become live reloads and can
    // race the first websocket/node pairing. Stop through both the Dart service
    // and a direct process sweep, then wait until the native detector agrees.
    await GatewayService().stop().catchError((_) => null);

    const gatewayProcessPattern =
        r'[o]penclaw.*gateway|[n]ode .*openclaw.*gateway|[n]ode .*openclaw\.mjs.*gateway';
    await NativeBridge.runInProot(
      "pkill -TERM -f '$gatewayProcessPattern' 2>/dev/null || true; "
      'sleep 1; '
      "pkill -KILL -f '$gatewayProcessPattern' 2>/dev/null || true",
      timeout: 10,
    ).catchError((_) => '');

    for (var attempt = 0; attempt < 12; attempt++) {
      final running =
          await NativeBridge.isGatewayRunning().catchError((_) => false);
      if (!running) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _log(
        '[SETUP] Warning: gateway still appears to be running after stop sweep');
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
      final total =
          int.tryParse(head.headers.value('content-length') ?? '0') ?? 0;
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
        final end =
            (i == concurrency - 1) ? total - 1 : (i + 1) * chunkSize - 1;
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
      _log('❌ Parallel download failed, falling back to standard download',
          error: e);
      await _dio.download(url, savePath, onReceiveProgress: onProgress);
    }
  }

  /// Update ONLY Node.js without full rootfs reinstall
  /// Surgical update that preserves existing setup
  Future<void> updateNodejsOnly(
      {required void Function(SetupState) onProgress}) async {
    try {
      _emitProgress(onProgress, SetupStep.checkingStatus, 0.0,
          'Checking Node.js version...', 2);

      if (!await checkNodeUpgradeRequired()) {
        _emitProgress(
            onProgress, SetupStep.complete, 1.0, 'Node.js is up to date.', 100);
        return;
      }

      _emitProgress(onProgress, SetupStep.installingNode, 0.0,
          'Updating Node.js only...', 5);

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

            _updateSetupNotification('Downloading Node.js: $mb / $totalMb MB',
                progress: notifProgress);
            onProgress(SetupState(
              step: SetupStep.installingNode,
              progress: progress,
              message: 'Downloading Node.js: $mb MB / $totalMb MB',
            ));
          }
        },
      );

      _emitProgress(onProgress, SetupStep.installingNode, 0.5,
          'Extracting Node.js...', 70);
      await NativeBridge.extractNodeTarball(nodeTarPath);

      // Fix ESM shebang after Node.js update
      await _fixOpenClawShebang(onProgress: onProgress);

      _emitProgress(
          onProgress, SetupStep.complete, 1.0, 'Node.js update complete!', 100);
    } catch (e) {
      _log('Node.js-only update failed: $e');
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Node.js update failed: $e',
      ));
    }
  }

  Future<void> runFullSetup(
      {required void Function(SetupState) onProgress}) async {
    final setupFlowPrefs = PreferencesService();
    await setupFlowPrefs.init();
    setupFlowPrefs.setupInProgress = true;
    try {
      // Pause any background gateway automation while setup rewrites config.
      // Reusing the singleton ensures provider-owned timers/subscriptions are stopped too.
      await _stopGatewayBeforeSetup();
      await GatewayService()
          .clearDeviceToken(clearProtocol: true)
          .catchError((_) => null);

      // Start foreground service to keep app alive during setup
      try {
        await NativeBridge.startSetupService();
      } catch (e) {
        _log('Non-fatal: Setup service failed to start', error: e);
      }

      // ---------------------------------------------------------
      // Step 0: Setup directories & Check status
      // ---------------------------------------------------------
      _emitProgress(onProgress, SetupStep.checkingStatus, 0.05,
          'Preparing environment...', 5);
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
        _emitProgress(onProgress, SetupStep.downloadingRootfs, 0.1,
            'Checking for bundled rootfs...', 10);
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

                _updateSetupNotification(
                    'Downloading rootfs: $mb / $totalMb MB',
                    progress: notifProgress);
                onProgress(SetupState(
                  step: SetupStep.downloadingRootfs,
                  progress: progress,
                  message: 'Downloading rootfs',
                  subMessage: '$mb / $totalMb MB',
                ));
              }
            },
          );

          _emitProgress(onProgress, SetupStep.extractingRootfs, 0.25,
              'Optimizing environment for local LLM...', 30);
          await NativeBridge.extractRootfs(tarPath);
          rootfsReady = true;
        }

        _emitProgress(onProgress, SetupStep.extractingRootfs, 0.35,
            'Rootfs environment ready', 40);
      } else {
        _emitProgress(onProgress, SetupStep.extractingRootfs, 0.35,
            'Rootfs already present', 40);
      }

      if (!bypassInstalled) {
        await NativeBridge.installBionicBypass();
      }

      // ---------------------------------------------------------
      // Step 3: Install Node.js & Fix Permissions
      // ---------------------------------------------------------
      final bool nodeUpgradeRequired =
          !nodeInstalled || await checkNodeUpgradeRequired();

      if (nodeUpgradeRequired) {
        _emitProgress(
            onProgress,
            SetupStep.installingNode,
            0.40,
            nodeInstalled
                ? 'Updating Node.js core...'
                : 'Installing Node.js core...',
            45);

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

        _emitProgress(onProgress, SetupStep.installingNode, 0.42,
            'Updating package lists...', 46,
            subMessage: 'Syncing with Ubuntu mirrors');

        await NativeBridge.runInProot(
            'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
            'export DEBIAN_FRONTEND=noninteractive && '
            'apt-get update -y');

        _emitProgress(onProgress, SetupStep.installingNode, 0.45,
            'Installing system tools...', 48,
            subMessage: 'ca-certificates • git • curl • zstd • tmux • jq');

        await NativeBridge.runInProot(
            'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
            'export DEBIAN_FRONTEND=noninteractive && '
            'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
            'echo "Etc/UTC" > /etc/timezone && '
            'apt-get install -y --no-install-recommends ca-certificates git curl zstd tmux jq && '
            'apt-get clean && rm -rf /var/lib/apt/lists/*');

        final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
        final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';

        _emitProgress(onProgress, SetupStep.installingNode, 0.50,
            'Downloading Node.js (fast link)...', 55);

        await _downloadParallel(
          nodeTarUrl,
          nodeTarPath,
          onProgress: (received, total) {
            if (total > 0) {
              final progress = 0.5 + (received / total) * 0.1;
              final mb = (received / 1024 / 1024).toStringAsFixed(1);
              final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
              final notifProgress = 55 + ((received / total) * 15).round();

              _updateSetupNotification('Downloading Node.js: $mb / $totalMb MB',
                  progress: notifProgress);
              onProgress(SetupState(
                step: SetupStep.installingNode,
                progress: progress,
                message: 'Downloading Node.js',
                subMessage: '$mb / $totalMb MB',
              ));
            }
          },
        );

        _emitProgress(onProgress, SetupStep.installingNode, 0.60,
            'Extracting Node.js...', 72);
        await NativeBridge.extractNodeTarball(nodeTarPath);
      } else {
        _emitProgress(onProgress, SetupStep.installingNode, 0.60,
            'Node.js already installed', 78);
      }

      await _hardenEnvironment();
      await _repairConfig();

      // ---------------------------------------------------------
      // Step 4: Install OpenClaw
      // ---------------------------------------------------------
      if (!openclawInstalled) {
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.65,
            'Installing OpenClaw core...', 80);

        bool success = false;
        if (_forceLiveOpenClawInstall) {
          _log(
              '[SETUP] Pre-bundled OpenClaw disabled; installing latest from npm.');
        } else {
          success = await _extractPrebundledOpenClaw(onProgress);
        }

        if (!success) {
          _log('ℹ️ Installing OpenClaw from npm...');
          await _installMinimalBuildTools();
          await _ensureOpenClawPackageExists();
          await _purgeBuildTools();
        }
      } else {
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.75,
            'OpenClaw already present', 95);
        await _ensureOpenClawPackageExists();
      }

      await NativeBridge.createBinWrappers('openclaw');
      await NativeBridge.ensureAgentSkillsAwareness();
      await _hardenOpenClawConfig();

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.80,
          'Running industrial onboard...', 85,
          subMessage: 'Hardware validation • SecretRef syncing');

      // Full onboard — AWAITED so it cannot race with config hardening below.
      // catchError makes it non-fatal; hardening overwrites any onboard defaults.
      await NativeBridge.runInProot(
        'openclaw onboard --non-interactive --mode local --flow quickstart --auth-choice skip --skip-health --accept-risk',
        timeout: 90,
      ).catchError((_) => '');

      // Re-harden after onboard: openclaw onboard writes its own defaults which may
      // include messages.tts.personas.*.model or skipBootstrap — keys that either
      // break strict schema validation or suppress default agent skill loading.
      await _hardenOpenClawConfig();

      // Bake API credentials collected in SetupFlowScreen BEFORE the gateway starts.
      // This eliminates the post-start reload that used to disrupt node pairing.
      final setupPrefs = PreferencesService();
      await setupPrefs.init();
      final pendingProvider = setupPrefs.pendingProvider;
      final pendingApiKey = setupPrefs.pendingApiKey;
      if (pendingProvider != null && pendingProvider.isNotEmpty) {
        final credGateway = GatewayService();
        final providerModel =
            ModelProviderCatalog.setupSafeModelForProvider(pendingProvider);
        final hasApiKey = pendingApiKey != null && pendingApiKey.isNotEmpty;

        if (hasApiKey) {
          _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.83,
              'Configuring API credentials...', 88,
              subMessage:
                  'Baking ${pendingProvider.replaceAll('_API_KEY', '')} key into gateway config');
          await credGateway.configureApiKey(
            pendingProvider,
            pendingApiKey,
            runBackgroundOnboard: false,
          );
          setupPrefs.pendingApiKey = null;
          setupPrefs.apiKeyConfigured = true;
          _log(
              '[SETUP] API credentials baked into config before gateway start.');
        } else {
          _log(
              '[SETUP] No API key supplied for $pendingProvider; applying model-only bootstrap defaults.');
        }

        try {
          await credGateway.persistModel(providerModel);
          setupPrefs.configuredModel = providerModel;
        } catch (e) {
          _log('[SETUP] Failed to persist bootstrap model', error: e);
        }

        setupPrefs.pendingProvider = null;
        setupPrefs.apiProvider =
            ModelProviderCatalog.apiProviderForSetupId(pendingProvider);
      }

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.85,
          'Applying industrial config hardening...', 90,
          subMessage: 'Zero-restart security sweep');

      // CRITICAL: ALL config changes FIRST — before ANY gateway start
      await _fullPreStartConfigHardening();

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.90,
          'Starting AI gateway...', 92,
          subMessage: 'Plugins loading • Voice engine • Canvas');

      final gateway = GatewayService();
      await gateway.attachOrStart(forceStart: true);

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.96,
          'Verifying connections...', 98,
          subMessage: 'WebSocket • Node pairing • Health check');

      try {
        await gateway.waitForStartup(timeout: const Duration(seconds: 180));

        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.97,
            'Stabilizing node handshake...', 98);
        // CRITICAL: Wait 5s to ensure Node has attempted connection and generated a requestId
        await Future.delayed(const Duration(seconds: 5));

        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.98,
            'Auto-approving local node...', 99);
        await _approveLocalNodeIfNeeded();

        _emitProgress(
            onProgress, SetupStep.complete, 1.0, 'Setup complete!', 100,
            subMessage: 'System Online & Ready');
      } catch (e) {
        _log('Gateway warmup or approval timed out', error: e);
        // Try approval one last time even if health check failed, but do not
        // mark bootstrap complete. A fresh install must not land users on Home
        // with a half-started gateway and missing skills.
        await _approveLocalNodeIfNeeded().catchError((_) => null);
        rethrow;
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
    } finally {
      setupFlowPrefs.setupInProgress = false;
    }
  }

  /// FIX: Repair broken openclaw.mjs shebang for ESM compatibility
  /// The exec node line is being parsed as JavaScript instead of shell
  Future<void> _fixOpenClawShebang(
      {required void Function(SetupState) onProgress}) async {
    try {
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.1,
          'Cleaning broken installation...', 82,
          subMessage: 'Purging global node_modules & apt cache');

      // 1. Force remove old installation and any stray files
      await NativeBridge.runInProot(
          'unset NODE_OPTIONS; env -u NODE_OPTIONS /usr/local/bin/npm uninstall -g openclaw || true');
      await NativeBridge.runInProot(
          'rm -rf /usr/local/lib/node_modules/openclaw');
      await NativeBridge.runInProot('rm -f /usr/local/bin/openclaw');
      await NativeBridge.runInProot(
          'unset NODE_OPTIONS; env -u NODE_OPTIONS /usr/local/bin/npm cache clean --force || true');
      await NativeBridge.runInProot('apt-get clean || true');

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.3,
          'Reinstalling OpenClaw (latest)...', 85,
          subMessage: 'Running npm install --omit=dev');

      // 2. Fresh install (latest) + peer dep fix for @buape/carbon
      await NativeBridge.runInProot(
        '$_latestOpenClawInstallCommand && '
        'cd /usr/local/lib/node_modules/openclaw && '
        'env -u NODE_OPTIONS /usr/local/bin/npm install --no-audit --no-fund --omit=dev 2>/dev/null || true',
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

      _emitProgress(onProgress, SetupStep.complete, 1.0,
          'Repair complete! Restarting gateway...', 100);
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
    final openclawDir =
        Directory('$rootfsDir/usr/local/lib/node_modules/openclaw');

    final exists = await openclawDir.exists();
    if (exists && !_forceLiveOpenClawInstall) {
      _log('✅ OpenClaw already present (pre-bundled or previously installed)');
      return;
    }

    _log(exists
        ? '⬆️ Updating OpenClaw to latest official package...'
        : '🚨 Installing OpenClaw (this may take 30-60s)...');

    try {
      // 1. Install with minimal flags
      await NativeBridge.runInProot(
        _latestOpenClawInstallCommand,
        timeout: 1800,
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
  Future<bool> _extractPrebundledOpenClaw(
      Function(SetupState) onProgress) async {
    if (_forceLiveOpenClawInstall) {
      _log(
          '📦 Pre-bundled OpenClaw assets are disabled for latest gateway compatibility.');
      return false;
    }

    _log('📦 Checking for pre-bundled OpenClaw assets...');
    try {
      final rootfsDir = await getRootfsDirectory();

      // Check if the asset exists in the bundle
      _log('📖 Reading 100MB pre-bundled modules (this may take a moment)...');
      final ByteData data =
          await rootBundle.load('assets/openclaw-node-modules.tar.gz');

      _log('🚚 Pre-bundled OpenClaw found! Extracting...');
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.3,
          'Using pre-bundled OpenClaw (fast setup)...', 85,
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
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.8,
          'Pre-bundled OpenClaw ready', 90,
          subMessage: 'Verifying package integrity');
      return true;
    } catch (e) {
      _log(
          'ℹ️ No pre-bundled OpenClaw found in assets, falling back to npm install. ($e)');
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

  void _emitProgress(Function(SetupState) onProgress, SetupStep step,
      double progress, String message, int notifProgress,
      {String? subMessage}) {
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

      // Keep Android out of the unrestricted/full tool universe. This uses
      // official groups/stable primitives, not guessed plugin slugs.
      GatewayToolCatalog.applyDefaultMobilePolicy(config);

      // Ensure gateway is in correct mode
      config['gateway'] ??= {};
      if (config['gateway'] is Map) {
        (config['gateway'] as Map)['mode'] = 'local';
      }

      await configFile
          .writeAsString(const JsonEncoder.withIndent('  ').convert(config));
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
      const pathExport =
          'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH';
      const nodeOptions =
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js"';

      await NativeBridge.runInProot(
          'grep -q "export PATH=/usr/local/sbin" /root/.bashrc || echo "$pathExport" >> /root/.bashrc');
      await NativeBridge.runInProot(
          'grep -q "export NODE_OPTIONS" /root/.bashrc || echo "$nodeOptions" >> /root/.bashrc');
      _log('✅ Environment hardened');
    } catch (e) {
      _log('Non-fatal: Environment hardening failed', error: e);
    }
  }

  /// NEW: Single, idempotent pre-start hardening (no reload after gateway starts)
  Future<void> _fullPreStartConfigHardening() async {
    try {
      final prefs = PreferencesService();
      await prefs.init();
      final existingConfig = await _readExistingOpenClawConfig();
      final preferredPrimaryModel =
          _resolveBootstrapPrimaryModel(prefs, existingConfig);
      final providerPatch = _buildProviderDefaultsPatch(existingConfig);
      final filesDir = await NativeBridge.getFilesDir();
      final configFile =
          File('$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json');

      // 1. Core stability flags + provider defaults via CLI
      await NativeBridge.runInProot(
        'openclaw config set gateway.bind loopback && '
        'openclaw config set gateway.port 18789 && '
        'openclaw config set gateway.mode local && '
        'openclaw config set discovery.mdns.mode off',
        timeout: 30,
      );

      // 2. Complex structures via patch (Atomic write).
      // Fresh installs have no gateway.auth yet; without a persisted token,
      // OpenClaw generates a runtime-only token and every restart changes the
      // trust root. Generate the stable token before the gateway ever boots.
      final workingConfig = Map<String, dynamic>.from(existingConfig);
      workingConfig['gateway'] ??= <String, dynamic>{};
      (workingConfig['gateway'] as Map)['mode'] = 'local';
      _ensurePersistentGatewayToken(workingConfig);
      _applyExplicitAuthMode(workingConfig);
      _syncLocalGatewayRemoteCredentials(workingConfig);
      _sanitizeOpenClawSchema(workingConfig);
      await _writeJsonAtomically(configFile, workingConfig);
      final authPatch = _buildSharedSecretAuthPatch(workingConfig);
      final remotePatch = _buildLocalGatewayRemotePatch(workingConfig);
      final rootAuthPatch = _buildRootAuthPatch(workingConfig);
      final nodeAllowCommandsJson =
          jsonEncode(GatewayToolCatalog.mobileNodeAllowCommands);
      final patchJson = '''
{
  "gateway": {
    "bind": "loopback",
    "port": 18789,
    "mode": "local",
    ${authPatch != null ? '"auth": ${jsonEncode(authPatch)},' : ''}
    ${remotePatch != null ? '"remote": ${jsonEncode(remotePatch)},' : ''}
    "controlUi": {
      "allowedOrigins": ${jsonEncode(GatewayService.localControlUiAllowedOrigins)}
    },
    "nodes": {
      "pairing": { "autoApproveCidrs": ["127.0.0.1/32"] },
      "denyCommands": [],
      "allowCommands": $nodeAllowCommandsJson
    },
    "http": { "endpoints": { "chatCompletions": { "enabled": true } } }
  },
  "discovery": {
    "mdns": { "mode": "off" },
    "wideArea": { "enabled": false }
  },
  "models": {
    "pricing": { "enabled": false },
    "providers": ${jsonEncode(providerPatch)}
  },
  "auth": ${jsonEncode(rootAuthPatch)},
  "agents": {
    "defaults": {
      "model": {
        "primary": ${jsonEncode(preferredPrimaryModel)}
      }
    }
  },
  "tools": ${jsonEncode(GatewayToolCatalog.defaultMobileToolsConfig())}
}
''';
      await NativeBridge.runInProot(
        'cat > /tmp/prestart_harden.json << \'EOF\'\n$patchJson\nEOF && '
        'openclaw config patch --file /tmp/prestart_harden.json && '
        'rm -f /tmp/prestart_harden.json',
        timeout: 30,
      );

      // 3. Ensure node starts on first-pair path.
      // Device approval now follows the official requestId-driven CLI flow
      // (openclaw devices approve <requestId>) in NodeService.
      prefs.nodeDeviceToken = null;
      _log('[HARDEN] Pre-start config injection complete.');
    } catch (e) {
      _log('[HARDEN] Warning: Pre-start hardening failed (non-fatal)',
          error: e);
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

      // Gateway-first hardening for setup-time configuration.
      config['gateway'] ??= {};
      config['gateway']['mode'] = 'local';
      config['gateway']['bind'] = 'loopback';
      config['gateway']['port'] = AppConstants.gatewayPort;
      config['gateway']['controlUi'] ??= {};
      config['gateway']['controlUi']['allowedOrigins'] =
          GatewayService.localControlUiAllowedOrigins;
      (config['gateway']['controlUi'] as Map).remove(
        'dangerouslyAllowHostHeaderOriginFallback',
      );
      config['gateway']['auth'] ??= {};
      (config['gateway']['auth'] as Map).remove('unauthenticatedLocalhost');
      _ensurePersistentGatewayToken(config);
      _applyExplicitAuthMode(config);
      _syncLocalGatewayRemoteCredentials(config);
      _sanitizeOpenClawSchema(config);

      // Fix autoApprove path to match official OpenClaw 2.0 strict schema
      config['gateway']['nodes'] ??= {};
      config['gateway']['nodes']['pairing'] ??= {};
      config['gateway']['nodes']['pairing']
          ['autoApproveCidrs'] = ['127.0.0.1/32'];

      // 2. Default Agent configuration
      config['agents'] ??= {};
      config['agents']['defaults'] ??= {};
      if (config['agents']['defaults'] is Map) {
        (config['agents']['defaults'] as Map).remove('skipBootstrap');
      }
      config['agents']['defaults']['model'] ??= {};
      final currentPrimary =
          config['agents']['defaults']['model']['primary'] as String?;
      config['agents']['defaults']['model']['primary'] =
          currentPrimary == null || currentPrimary.isEmpty
              ? ModelProviderCatalog.setupSafeGatewayModel
              : ModelProviderCatalog.canonicalizeModelId(currentPrimary);

      // 3. Hardened provider defaults. Preserve user keys while ensuring every
      // provider exposed by the UI has model metadata and known base URLs.
      config['models'] ??= {};
      config['models']['pricing'] ??= <String, dynamic>{};
      final pricing = config['models']['pricing'];
      if (pricing is Map) {
        pricing['enabled'] = false;
      } else {
        config['models']['pricing'] = <String, dynamic>{'enabled': false};
      }
      config['models']['providers'] ??= {};
      for (final provider in ModelProviderCatalog.providers) {
        final existing = config['models']['providers'][provider.id];
        config['models']['providers'][provider.id] =
            ModelProviderCatalog.mergeProviderConfig(
          provider.id,
          existing is Map ? existing : null,
        );
      }

      // 4. GLOBAL ORIGIN & DISCOVERY ENFORCEMENT
      config['gateway']['controlUi'] ??= {};
      config['gateway']['controlUi']['allowedOrigins'] =
          GatewayService.localControlUiAllowedOrigins;
      (config['gateway']['controlUi'] as Map).remove(
        'dangerouslyAllowHostHeaderOriginFallback',
      );
      config['discovery'] = {
        'mdns': {'mode': 'off'},
        'wideArea': {'enabled': false},
      };

      // Bounded mobile policy: enough for nodes/UI/web/memory/runtime without
      // loading every plugin/provider tool on phone startup.
      GatewayToolCatalog.applyDefaultMobilePolicy(config);
      GatewayService.ensureGatewayTalkTtsConfig(config);

      // Remove invalid TTS persona "model" keys — gateway schema rejects them.
      // Personas written by older versions of this code used "model" which is
      // not a recognized field; the gateway refuses to start if they're present.
      final existingPersonas =
          (config['messages'] as Map?)?['tts']?['personas'];
      if (existingPersonas is Map) {
        for (final p in existingPersonas.values) {
          if (p is Map) (p as Map<String, dynamic>).remove('model');
        }
      }

      await _writeJsonAtomically(configFile, config);
      _log(
          '[CONFIG] Hardened production-grade configuration (providers + origins).');
    } catch (e) {
      _log('[CONFIG] Hardening failed during setup', error: e);
    }
  }

  Future<void> repairOpenClaw(
      {required void Function(SetupState) onProgress}) async {
    await _fixOpenClawShebang(onProgress: onProgress);
  }

  Future<bool> checkNodeUpgradeRequired() async {
    try {
      final currentVersion = await NativeBridge.runInProot(
        'unset NODE_OPTIONS; '
        '/usr/local/bin/node --version 2>/dev/null || node --version 2>/dev/null || echo 0.0.0',
        timeout: 10,
      );
      return !_isNodeVersionAtLeast(
        currentVersion,
        AppConstants.nodeVersion,
      );
    } catch (_) {
      return true;
    }
  }

  bool _isNodeVersionAtLeast(String current, String required) {
    final currentParts = _parseSemver(current);
    final requiredParts = _parseSemver(required);

    for (var i = 0; i < requiredParts.length; i++) {
      if (currentParts[i] > requiredParts[i]) return true;
      if (currentParts[i] < requiredParts[i]) return false;
    }
    return true;
  }

  List<int> _parseSemver(String value) {
    final match = RegExp(r'v?(\d+)\.(\d+)\.(\d+)').firstMatch(value);
    if (match == null) return const [0, 0, 0];
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
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
    _log(
        '[SETUP] Node pairing is handled by live requestId approval on first connect');
  }

  Future<Map<String, dynamic>> _readExistingOpenClawConfig() async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final configPath = '$filesDir/rootfs/ubuntu/root/.openclaw/openclaw.json';
      final file = File(configPath);
      if (!await file.exists()) return <String, dynamic>{};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic>? _buildSharedSecretAuthPatch(
      Map<String, dynamic> config) {
    final auth = config['gateway']?['auth'];
    if (auth is! Map) return null;

    final patch = <String, dynamic>{};
    final token = auth['token'];
    final password = auth['password'];
    final mode = auth['mode'];

    if (token is String && token.isNotEmpty) patch['token'] = token;
    if (password is String && password.isNotEmpty) patch['password'] = password;

    if (mode is String && mode.isNotEmpty) {
      patch['mode'] = mode;
    } else if (patch.containsKey('token')) {
      patch['mode'] = 'token';
    } else if (patch.containsKey('password')) {
      patch['mode'] = 'password';
    }

    return patch.isEmpty ? null : patch;
  }

  void _ensurePersistentGatewayToken(Map<String, dynamic> config) {
    config['gateway'] ??= <String, dynamic>{};
    final gateway = config['gateway'];
    if (gateway is! Map) return;

    final mode = gateway['mode'];
    if (mode is String && mode.isNotEmpty && mode != 'local') return;

    gateway['auth'] ??= <String, dynamic>{};
    final auth = gateway['auth'];
    if (auth is! Map) return;

    final token = auth['token'];
    if (token is String && token.isNotEmpty) return;
    final password = auth['password'];
    if (password is String && password.isNotEmpty) return;

    auth['token'] = 'plawie-${const Uuid().v4().replaceAll('-', '')}';
    auth['mode'] = 'token';
  }

  String _resolveBootstrapPrimaryModel(
      PreferencesService prefs, Map<String, dynamic> config) {
    final configured = prefs.configuredModel;
    if (configured != null && configured.isNotEmpty) {
      return ModelProviderCatalog.canonicalizeModelId(configured);
    }

    final pendingProvider = prefs.pendingProvider;
    if (pendingProvider != null && pendingProvider.isNotEmpty) {
      return ModelProviderCatalog.setupSafeModelForProvider(pendingProvider);
    }

    final configPrimary =
        config['agents']?['defaults']?['model']?['primary'] as String?;
    if (configPrimary != null && configPrimary.isNotEmpty) {
      return ModelProviderCatalog.canonicalizeModelId(configPrimary);
    }

    return ModelProviderCatalog.setupSafeGatewayModel;
  }

  Map<String, dynamic> _buildProviderDefaultsPatch(
      Map<String, dynamic> existingConfig) {
    final existingProviders = existingConfig['models']?['providers'] is Map
        ? existingConfig['models']['providers'] as Map
        : <dynamic, dynamic>{};
    final providers = <String, dynamic>{};
    for (final provider in ModelProviderCatalog.providers) {
      final existing = existingProviders[provider.id];
      providers[provider.id] = ModelProviderCatalog.mergeProviderConfig(
        provider.id,
        existing is Map ? existing : null,
      );
    }
    return providers;
  }

  Map<String, dynamic> _buildRootAuthPatch(Map<String, dynamic> config) {
    final auth = config['auth'] is Map
        ? Map<String, dynamic>.from(config['auth'] as Map)
        : <String, dynamic>{};

    if (auth['profiles'] is! Map) auth['profiles'] = <String, dynamic>{};
    if (auth['order'] is! Map) auth['order'] = <String, dynamic>{};
    return {
      'profiles': Map<String, dynamic>.from(auth['profiles'] as Map),
      'order': Map<String, dynamic>.from(auth['order'] as Map),
    };
  }

  Map<String, dynamic>? _buildLocalGatewayRemotePatch(
      Map<String, dynamic> config) {
    final gateway = config['gateway'];
    if (gateway is! Map) return null;

    final mode = gateway['mode'];
    if (mode is String && mode.isNotEmpty && mode != 'local') return null;

    final auth = gateway['auth'];
    if (auth is! Map) return null;

    final patch = <String, dynamic>{};
    final token = auth['token'];
    final password = auth['password'];

    if (token is String && token.isNotEmpty) patch['token'] = token;
    if (password is String && password.isNotEmpty) patch['password'] = password;

    return patch.isEmpty ? null : patch;
  }

  void _applyExplicitAuthMode(Map<String, dynamic> config) {
    final auth = config['gateway']?['auth'];
    if (auth is! Map) return;

    final mode = auth['mode'];
    if (mode is String && mode.isNotEmpty) return;

    final token = auth['token'];
    final password = auth['password'];
    if (token is String && token.isNotEmpty) {
      auth['mode'] = 'token';
    } else if (password is String && password.isNotEmpty) {
      auth['mode'] = 'password';
    }
  }

  void _syncLocalGatewayRemoteCredentials(Map<String, dynamic> config) {
    config['gateway'] ??= {};
    final gateway = config['gateway'];
    if (gateway is! Map) return;

    final mode = gateway['mode'];
    if (mode is String && mode.isNotEmpty && mode != 'local') return;

    gateway['auth'] ??= {};
    final auth = gateway['auth'];
    if (auth is! Map) return;

    gateway['remote'] ??= {};
    final remote = gateway['remote'];
    if (remote is! Map) return;

    final token = auth['token'];
    if (token is String && token.isNotEmpty) {
      remote['token'] = token;
    } else {
      remote.remove('token');
    }

    final password = auth['password'];
    if (password is String && password.isNotEmpty) {
      remote['password'] = password;
    } else {
      remote.remove('password');
    }
  }

  void _sanitizeOpenClawSchema(Map<String, dynamic> config) {
    final gateway = config['gateway'];
    if (gateway is Map) {
      // OpenClaw 2026.5.x removed these legacy mobile-tuning keys from the
      // strict gateway schema. Leaving them in prevents gateway startup.
      gateway.remove('startup');
      gateway.remove('sidecars');
    }

    final models = config['models'];
    if (models is Map) {
      // Model prewarm is no longer configured under models.startup in the
      // current strict schema.
      models.remove('startup');
      models['pricing'] ??= <String, dynamic>{};
      final pricing = models['pricing'];
      if (pricing is Map) {
        pricing['enabled'] = false;
      } else {
        models['pricing'] = <String, dynamic>{'enabled': false};
      }
      final providers = models['providers'];
      if (providers is Map) providers.remove('ollama');
    }
    final auth = config['auth'];
    if (auth is Map) {
      final profiles = auth['profiles'];
      if (profiles is Map) profiles.remove('ollama:default');
      final order = auth['order'];
      if (order is Map) order.remove('ollama');
    }
    config.remove('ollama');

    final agentsDefaults = config['agents']?['defaults'];
    if (agentsDefaults is Map) {
      agentsDefaults.remove('skipBootstrap');
      agentsDefaults.remove('provider');
      agentsDefaults.remove('tools');
      agentsDefaults.remove('timeoutMs');
      agentsDefaults.remove('systemPrompt');
      final timeoutSeconds = agentsDefaults['timeoutSeconds'];
      if (timeoutSeconds is! num || timeoutSeconds < 240) {
        agentsDefaults['timeoutSeconds'] = 240;
      }
      final model = agentsDefaults['model'];
      if (model is Map) {
        final primary = model['primary'];
        if (primary is String && primary.isNotEmpty) {
          model['primary'] = ModelProviderCatalog.canonicalizeModelId(primary);
        }
      }
    }

    final skills = config['skills'];
    if (skills is Map) {
      skills.remove('discovery');
      skills.remove('mode');
      skills.remove('sync');
      if (skills.isEmpty) config.remove('skills');
    }

    // Default to the bounded Android tool policy. Device-native capabilities
    // remain controlled under gateway.nodes.
    GatewayToolCatalog.applyDefaultMobilePolicy(config);
    GatewayService.ensureGatewayTalkTtsConfig(config);

    final ttsPersonas = (config['messages'] as Map?)?['tts']?['personas'];
    if (ttsPersonas is Map) {
      for (final persona in ttsPersonas.values) {
        if (persona is Map) persona.remove('model');
      }
    }
  }

  Future<void> _writeJsonAtomically(
    File file,
    Map<String, dynamic> config,
  ) async {
    await file.parent.create(recursive: true);
    final tmp =
        File('${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    await tmp.writeAsString(jsonEncode(config), flush: true);
    try {
      await tmp.rename(file.path);
    } catch (_) {
      await file.writeAsString(jsonEncode(config), flush: true);
      if (await tmp.exists()) {
        await tmp.delete().catchError((_) => tmp);
      }
    }
  }
}
