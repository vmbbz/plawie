import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';
import 'package:flutter/services.dart' show rootBundle;
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

      await NativeBridge.runInProot('''
        mkdir -p /root/.openclaw
      ''');

      try {
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
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
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'export DEBIAN_FRONTEND=noninteractive && '
        'apt-get update -y && '
        'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
        'echo "Etc/UTC" > /etc/timezone && '
        'apt-get install -y --no-install-recommends ca-certificates git python3 make g++ curl zstd tmux'
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
      await NativeBridge.runInProot('export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && node --version && $nodeRun $npmCli --version');

      // ---------------------------------------------------------
      // Step 4: Install OpenClaw
      // ---------------------------------------------------------
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.0, 'Verifying OpenClaw installation...', 80);
      
      final checkOpenClaw = await NativeBridge.runInProot('command -v openclaw || echo "missing"');
      if (checkOpenClaw.contains('missing')) {
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.1, 'Installing OpenClaw (this may take 10-15 minutes, please wait)...', 82);
        // --ignore-scripts: skip node-llama-cpp postinstall (cmake build) — fails on phones
        await NativeBridge.runInProot('export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && npm install -g openclaw --ignore-scripts', timeout: 1800);
      } else {
        _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.5, 'OpenClaw already installed, skipping...', 84);
      }

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.7, 'Creating bin wrappers...', 85);
      await NativeBridge.createBinWrappers('openclaw');
      
      // FIX: Repair broken openclaw.mjs shebang for ESM compatibility
      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.75, 'Fixing OpenClaw ESM shebang...', 87);
      await _fixOpenClawShebang();

      _emitProgress(onProgress, SetupStep.installingOpenClaw, 0.9, 'Verifying OpenClaw...', 90);
      await NativeBridge.runInProot('export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw --version || echo openclaw_installed');

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
      
      if (!await openclawMjs.exists()) {
        _log('openclaw.mjs not found, skipping shebang fix');
        return;
      }
      
      String content = await openclawMjs.readAsString();
      
      // Fix the broken shebang by replacing the invalid exec line with proper ESM handling
      if (content.contains('exec node "')) {
        // Replace the broken shebang with a proper Node.js ESM invocation
        content = content.replaceAll(
          RegExp(r'^exec node ".*?" "\$@"'),
          '#!/bin/sh\n":" //# comment; exec /usr/bin/env node --input-type=module "$0" "$@"',
        );
        
        await openclawMjs.writeAsString(content);
        _log('Fixed openclaw.mjs shebang for ESM compatibility');
      }
    } catch (e) {
      _log('Failed to fix openclaw.mjs shebang: $e');
    }
  }

  void _emitProgress(Function(SetupState) onProgress, SetupStep step, double progress, String message, int notifProgress) {
    _updateSetupNotification(message, progress: notifProgress);
    onProgress(SetupState(step: step, progress: progress, message: message));
  }
}
