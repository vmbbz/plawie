import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';
import 'preferences_service.dart';

class BootstrapService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10), // Rootfs can be large
  ));

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: 'BootstrapService', error: error, stackTrace: stackTrace);
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

  /// Helper for robust file downloading with retries
  Future<void> _downloadWithRetry(
    String url,
    String savePath, {
    required void Function(int received, int total) onProgress,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        await _dio.download(url, savePath, onReceiveProgress: onProgress);
        return; // Success
      } on DioException catch (e) {
        attempt++;
        _log('Download attempt $attempt failed for $url', error: e);
        if (attempt >= maxRetries) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
      }
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
      // Step 0: Setup directories
      // ---------------------------------------------------------
      _emitProgress(onProgress, SetupStep.checkingStatus, 0.0, 'Setting up directories...', 2);
      await NativeBridge.setupDirs();
      await NativeBridge.writeResolv();

      // ---------------------------------------------------------
      // Step 1: Download rootfs
      // ---------------------------------------------------------
      final arch = await NativeBridge.getArch();
      final rootfsUrl = AppConstants.getRootfsUrl(arch);
      final filesDir = await NativeBridge.getFilesDir();
      final tarPath = '$filesDir/tmp/ubuntu-rootfs.tar.gz';

      _emitProgress(onProgress, SetupStep.downloadingRootfs, 0.0, 'Downloading Ubuntu rootfs...', 5);

      await _downloadWithRetry(
        rootfsUrl,
        tarPath,
        onProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            final mb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            final notifProgress = 5 + (progress * 25).round();
            
            _updateSetupNotification('Downloading rootfs: $mb / $totalMb MB', progress: notifProgress);
            onProgress(SetupState(
              step: SetupStep.downloadingRootfs,
              progress: progress,
              message: 'Downloading: $mb MB / $totalMb MB',
            ));
          }
        },
      );

      // ---------------------------------------------------------
      // Step 2: Extract rootfs
      // ---------------------------------------------------------
      _emitProgress(onProgress, SetupStep.extractingRootfs, 0.0, 'Extracting rootfs (this takes a while)...', 30);
      await NativeBridge.extractRootfs(tarPath);
      
      _emitProgress(onProgress, SetupStep.extractingRootfs, 1.0, 'Rootfs extracted', 40);
      await NativeBridge.installBionicBypass();

      // ---------------------------------------------------------
      // Step 3: Install Node.js & Fix Permissions
      // ---------------------------------------------------------
      _emitProgress(onProgress, SetupStep.installingNode, 0.0, 'Fixing rootfs permissions...', 45);

      try {
        await NativeBridge.runInProot(
          'chmod -R 755 /usr/bin /usr/sbin /bin /sbin /usr/local/bin /usr/local/sbin 2>/dev/null; '
          'chmod -R +x /usr/lib/apt/ /usr/lib/dpkg/ /usr/libexec/ /var/lib/dpkg/info/ /usr/share/debconf/ 2>/dev/null; '
          'chmod 755 /lib/*/ld-linux-*.so* /usr/lib/*/ld-linux-*.so* 2>/dev/null; '
          'mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/triggers; '
          'echo permissions_fixed',
        );
      } catch (e) {
        rethrow;
      }

      _emitProgress(onProgress, SetupStep.installingNode, 0.1, 'Updating package lists...', 48);
      
      // Use robust apt-get commands to avoid interactive prompts breaking the process
      await NativeBridge.runInProot(
        'export DEBIAN_FRONTEND=noninteractive && '
        'apt-get update -y && '
        'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
        'echo "Etc/UTC" > /etc/timezone && '
        'apt-get install -y --no-install-recommends ca-certificates git python3 make g++ curl zstd'
      );

      final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
      final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';

      _emitProgress(onProgress, SetupStep.installingNode, 0.3, 'Downloading Node.js...', 55);

      await _downloadWithRetry(
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
      await NativeBridge.runInProot('node --version && $nodeRun $npmCli --version');

      // ---------------------------------------------------------
      // Step 4: Install OpenClaw
      // ---------------------------------------------------------
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.0, 'Installing OpenClaw (this may take a few minutes)...', 80);
      await NativeBridge.runInProot('npm install -g openclaw', timeout: 1800);

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.7, 'Creating bin wrappers...', 85);
      await NativeBridge.createBinWrappers('openclaw');

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.9, 'Verifying OpenClaw...', 90);
      await NativeBridge.runInProot('openclaw --version || echo openclaw_installed');

      // ---------------------------------------------------------
      // Step 5: Install Ollama
      // ---------------------------------------------------------
      final prefs = PreferencesService();
      await prefs.init();
      
      if (prefs.llmProvider == 'ollama') {
        _emitProgress(onProgress, SetupStep.installingOllama, 0.0, 'Installing Ollama server...', 92);
        
        try {
          final envCheck = await NativeBridge.runInProot('command -v pkg >/dev/null 2>&1 && echo "TERMUX" || echo "UBUNTU"', timeout: 30);
          
          if (envCheck.contains('TERMUX')) {
            await _installOllamaTermuxNative(onProgress);
          } else {
            await _installOllamaUbuntu(onProgress);
          }
          final checkResult = await NativeBridge.runInProot('command -v ollama >/dev/null 2>&1 && echo "OK" || echo "NOT_FOUND"', timeout: 30);
          if (!checkResult.contains('OK')) throw Exception('Ollama binary not found in PATH');

          // Step 6: Pull Model
          final model = prefs.selectedModel;
          _emitProgress(onProgress, SetupStep.pullingModel, 0.0, 'Preparing Ollama model $model...', 96);
          
          await _startOllamaServer();
          await _pullModelWithServerCheck(model, onProgress);
          
        } catch (e) {
          _log('Ollama installation failed, continuing without it', error: e);
          onProgress(SetupState(
            step: SetupStep.error, // Show error but don't halt the whole process immediately if you want to allow bypass later
            error: 'Ollama failed: $e\n\nYou can still use cloud providers (Gemini, Claude) inside the app.',
          ));
          return; // Stop setup
        }
      }

      // ---------------------------------------------------------
      // Step 7: Finalize
      // ---------------------------------------------------------
      _emitProgress(onProgress, SetupStep.configuringBypass, 1.0, 'Setup complete! Ready to start the gateway.', 100);
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

  void _emitProgress(Function(SetupState) onProgress, SetupStep step, double progress, String message, int notifProgress) {
    _updateSetupNotification(message, progress: notifProgress);
    onProgress(SetupState(step: step, progress: progress, message: message));
  }

  // NATIVE TERMUX INSTALL
  static Future<void> _installOllamaTermuxNative(Function(SetupState) onProgress) async {
    onProgress(const SetupState(step: SetupStep.installingOllama, progress: 0.2, message: 'Installing Ollama (Termux)...'));
    await NativeBridge.runInProot('''
      pkg install tur-repo -y || true
      pkg update -y
      pkg install ollama tmux -y
      ollama --version
    ''', timeout: 300);
  }

  // UBUNTU PROOT INSTALL
  static Future<void> _installOllamaUbuntu(Function(SetupState) onProgress) async {
    onProgress(const SetupState(step: SetupStep.installingOllama, progress: 0.2, message: 'Preparing Ubuntu environment...'));
    await NativeBridge.runInProot('export DEBIAN_FRONTEND=noninteractive && apt-get update -y && apt-get install -y curl tar zstd tmux', timeout: 180);
    
    onProgress(const SetupState(step: SetupStep.installingOllama, progress: 0.4, message: 'Downloading Ollama binary...'));
    await NativeBridge.runInProot('''
      set -e
      ARCH=\$(uname -m)
      
      # FIX: Every single bracket now has a space on BOTH sides.
      if[ "\$ARCH" = "x86_64" ]; then 
          ARCH="amd64"
      elif[ "\$ARCH" = "aarch64" ] || [ "\$ARCH" = "arm64" ]; then 
          ARCH="arm64"
      else 
          echo "Unsupported architecture: \$ARCH"
          exit 1
      fi
      
      curl -fsSL "https://ollama.com/download/ollama-linux-\${ARCH}.tar.zst" -o /tmp/ollama.tar.zst
      cd /usr && tar -I zstd -xf /tmp/ollama.tar.zst
      chmod +x /usr/bin/ollama
      rm -f /tmp/ollama.tar.zst
    ''', timeout: 300);
  }

  // OLLAMA SERVER MANAGEMENT - PRODUCTION-GRADE LIFECYCLE
  Future<void> _startOllamaServer() async {
    _log('Starting Ollama server...');
    
    // 1. Check if it's already running to prevent double-spawning
    if (await isOllamaServerRunning()) {
      _log('Ollama is already running.');
      return;
    }

    // 2. Spawn the server in the foreground of a dedicated PRoot session.
    // CRITICAL: We DO NOT put 'await' here. We launch it into the background.
    // Flutter moves on instantly, but the underlying PRoot process stays alive
    // perfectly tracking the Ollama server until the app is closed.
    NativeBridge.runInProot('''
      mkdir -p /root/.openclaw/logs
      mkdir -p /root/.ollama/models
      export OLLAMA_HOST="127.0.0.1:11434"
      export OLLAMA_MODELS="/root/.ollama/models"
      
      # Run in foreground. Logs are piped to file.
      ollama serve > /root/.openclaw/logs/ollama.log 2>&1
    ''', timeout: 86400).then((_) { // 86400 seconds = 24 hour timeout
      _log('Ollama server process exited cleanly.');
    }).catchError((e) {
      _log('Ollama server process terminated/killed: $e');
    });
  }

  Future<void> stopOllamaServer() async {
    // Because the server is bound to a long-lived PRoot session, 
    // the safest way to cleanly shut it down is a cross-session pkill.
    await NativeBridge.runInProot('pkill -15 -f "ollama serve" || true', timeout: 10);
  }

  Future<void> _pullModelWithServerCheck(String model, Function(SetupState) onProgress) async {
    _log('Waiting for Ollama API to boot...');
    final readinessResult = await NativeBridge.runInProot('''
      for i in {1..40}; do
        if curl -s --connect-timeout 1 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
          echo "READY"
          exit 0
        fi
        sleep 1
      done
      echo "FAILED"
    ''', timeout: 60);

    if (!readinessResult.contains('READY')) {
      throw Exception('Ollama server failed to bind to port 11434.');
    }
    
    _emitProgress(onProgress, SetupStep.pullingModel, 0.5, 'Pulling $model (may take a while)...', 98);
    
    // FIX: Increased from 1800 (30 mins) to 7200 (2 hours) to protect users with slow networks.
    await NativeBridge.runInProot('ollama pull $model', timeout: 7200); 
  }

  Future<void> pullModel(String modelId, {required void Function(SetupState) onProgress}) async {
    try {
      _emitProgress(onProgress, SetupStep.pullingModel, 0.0, 'Pulling $modelId...', 0);
      await _startOllamaServer();
      await _pullModelWithServerCheck(modelId, onProgress);
      _emitProgress(onProgress, SetupStep.complete, 1.0, 'Model $modelId ready', 100);
    } catch (e) {
      onProgress(SetupState(step: SetupStep.error, error: 'Failed to pull model: $e'));
    }
  }

  Future<bool> isOllamaServerRunning() async {
    try {
      // The most bulletproof way to check if a web server is running 
      // is to simply ping its API, rather than looking at process lists.
      final result = await NativeBridge.runInProot('''
        if curl -s --connect-timeout 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
          echo "RUNNING"
        else
          echo "STOPPED"
        fi
      ''', timeout: 10);
      return result.contains('RUNNING');
    } catch (_) {
      return false;
    }
  }
}
