import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap pins compatible Node and OpenClaw releases', () async {
    final constants = await File('lib/constants.dart').readAsString();
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final nativeBootstrap = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/BootstrapManager.kt',
    ).readAsString();

    expect(constants, contains("nodeVersion = '22.22.3'"));
    expect(bootstrap, contains("_requiredOpenClawVersion = '2026.7.1'"));
    expect(bootstrap, contains('openclaw@2026.7.1'));
    expect(nativeBootstrap, contains('requiredOpenClawVersion = "2026.7.1"'));
    expect(nativeBootstrap, contains('minimumNodeVersion = listOf(22, 22, 3)'));
  });

  test('npm repair removes stale global launchers before installing', () async {
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final nativeBootstrap = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/BootstrapManager.kt',
    ).readAsString();

    for (final source in [bootstrap, nativeBootstrap]) {
      expect(source, contains('/usr/local/bin/openclaw'));
      expect(source, contains('rm -rf /usr/local/lib/node_modules/openclaw'));
    }
  });

  test('OpenClaw installation verifies the package in PRoot and native rootfs',
      () async {
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final nativeBootstrap = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/BootstrapManager.kt',
    ).readAsString();

    for (final source in [bootstrap, nativeBootstrap]) {
      expect(source, contains('npm_config_prefix=/usr/local'));
      expect(source, contains('OPENCLAW_INSTALL_VERIFY_ERROR'));
      expect(source, contains('__OPENCLAW_INSTALL_VERIFIED__='));
    }
    expect(bootstrap, contains('_openClawVersionProbeCommand'));
    expect(bootstrap, contains('_awaitNativeOpenClawStatus'));
  });

  test('fresh setup gates completion on dependency-pack verification',
      () async {
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final provisioning = await File(
      'lib/services/skill_provisioning_service.dart',
    ).readAsString();

    expect(bootstrap, contains('final packsReady ='));
    expect(bootstrap, contains('if (!packsReady)'));
    expect(provisioning, contains('onProgress(pack.id, 1.0);'));
  });

  test('remote dependency packs require pinned Ed25519 verification', () async {
    final provisioning = await File(
      'lib/services/skill_provisioning_service.dart',
    ).readAsString();
    final signingKeys =
        await File('lib/services/signing_keys.dart').readAsString();
    final signingDocs = await File('docs/SIGNING_KEYS.md').readAsString();

    expect(provisioning, contains('_verifyDependencyPackSignature'));
    expect(provisioning, contains('Ed25519().verify'));
    expect(provisioning, contains('kDependencyPackSigningKeyId'));
    expect(signingKeys, contains("kDependencyPackPublicKey = r'''"));
    expect(signingDocs, isNot(contains('BEGIN PRIVATE KEY')));
  });

  test('fresh setup installs only the official upstream native gateway',
      () async {
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final installer = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/OfficialOpenClawProvisioner.kt',
    ).readAsString();
    final nativeRuntime = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/NativeNodeEmbeddedService.kt',
    ).readAsString();
    final gateway =
        await File('lib/services/gateway_service.dart').readAsString();
    final setupGuards = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/SetupGuards.kt',
    ).readAsString();
    final mainActivity = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    ).readAsString();
    final isolatedInstaller = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/OfficialOpenClawInstallService.kt',
    ).readAsString();
    final manifest =
        await File('android/app/src/main/AndroidManifest.xml').readAsString();

    final freshSetupStart = bootstrap.indexOf('Future<void> runFullSetup(');
    final rollbackSetupStart =
        bootstrap.indexOf('Future<void> provisionProotRollback(');
    expect(freshSetupStart, greaterThanOrEqualTo(0));
    expect(rollbackSetupStart, greaterThan(freshSetupStart));
    final freshSetup = bootstrap.substring(freshSetupStart, rollbackSetupStart);

    expect(freshSetup, contains('NativeBridge.provisionOfficialOpenClaw()'));
    expect(
      freshSetup,
      contains('_stopGatewayBeforeSetup(includeProotRollback: false)'),
    );
    final rollbackSetup = bootstrap.substring(rollbackSetupStart);
    expect(
      rollbackSetup,
      contains('_stopGatewayBeforeSetup(includeProotRollback: true)'),
    );
    expect(
      bootstrap,
      contains('if (includeProotRollback) {'),
    );
    expect(freshSetup, isNot(contains('NativeBridge.setupDirs()')));
    expect(freshSetup, isNot(contains('NativeBridge.writeResolv()')));
    expect(freshSetup, isNot(contains('NativeBridge.runInProot(')));
    expect(freshSetup, isNot(contains('NativeBridge.extractRootfs(')));
    expect(freshSetup, isNot(contains('NativeBridge.installBionicBypass()')));

    expect(
        installer,
        contains(
            'https://api.github.com/repos/openclaw/openclaw/releases/latest'));
    expect(installer, contains('openclawNpmTarball'));
    expect(installer, contains('openclawNpmIntegrity'));
    expect(installer, contains('npmRegistrySignaturesVerified'));
    expect(installer, contains('npmProvenanceAttestationMatched'));
    expect(installer, contains('verifySha512Integrity'));
    expect(installer, contains('NPM_CLI_INTEGRITY'));
    expect(installer, contains('--ignore-scripts'));
    expect(installer, contains('npmExitCodeFromLogs'));
    expect(installer, contains('canonicalPackageDir(workDir)'));
    expect(
      installer,
      contains(
        'File(File(workDir, FULL_GATEWAY_DIR), PACKAGE_RELATIVE_PATH)',
      ),
    );
    expect(mainActivity, contains('OfficialOpenClawInstallService.start'));
    expect(mainActivity, contains('awaitIsolatedProvisionResult'));
    expect(isolatedInstaller, contains('Process.killProcess(Process.myPid())'));
    expect(manifest, contains('android:process=":native_node_install"'));
    expect(nativeRuntime, isNot(contains('syncOpenClawFromProotInstall')));
    expect(gateway, isNot(contains("reason: 'failed-native-default-start'")));
    expect(setupGuards, contains('setup/.bootstrap_complete'));
    expect(File('assets/openclaw-node-modules.tar.gz').existsSync(), isFalse);
  });

  test('native installer recovers a completed npm transaction once', () async {
    final provisioner = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/OfficialOpenClawProvisioner.kt',
    ).readAsString();
    final installer = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/OfficialOpenClawInstallService.kt',
    ).readAsString();
    final setupService = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/SetupService.kt',
    ).readAsString();

    expect(provisioner,
        contains('writeStagedRelease(staging, release, requestId)'));
    expect(provisioner, contains('recoverCompletedStagedInstall(requestId)'));
    expect(provisioner,
        contains('npmExitCodeFromLogs(cacheDir, staged.stagedAtEpochMs)'));
    expect(provisioner,
        contains('activateVerifiedInstall(candidate, staged.release)'));
    expect(installer, contains('}.provisionLatest(requestId)'));
    expect(installer, contains('SetupService.NOTIFICATION_ID'));
    expect(installer, contains('stopForeground(false)'));
    expect(setupService,
        contains('fun ensureNotificationChannel(context: Context)'));
  });

  test('native first setup reports official progress and verified native packs',
      () async {
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final provisioner = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/OfficialOpenClawProvisioner.kt',
    ).readAsString();
    final installer = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/OfficialOpenClawInstallService.kt',
    ).readAsString();
    final mainActivity = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    ).readAsString();
    final nativeRuntime = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/NativeNodeEmbeddedService.kt',
    ).readAsString();
    final gateway =
        await File('lib/services/gateway_service.dart').readAsString();
    final providers =
        await File('lib/services/model_provider_catalog.dart').readAsString();
    final packs = await File('lib/services/skill_provisioning_service.dart')
        .readAsString();

    final freshSetupStart = bootstrap.indexOf('Future<void> runFullSetup(');
    final rollbackSetupStart =
        bootstrap.indexOf('Future<void> provisionProotRollback(');
    final freshSetup = bootstrap.substring(freshSetupStart, rollbackSetupStart);

    expect(
      freshSetup,
      contains('_provisionOfficialOpenClawWithProgress(onProgress)'),
    );
    expect(
      freshSetup,
      contains('SkillProvisioningService.nativeSetupWizardPackIds'),
    );
    expect(
      freshSetup,
      contains('SkillProvisioningService.refreshRemotePackCatalog()'),
    );
    expect(
      freshSetup,
      contains('Metadata first • SHA-256 + Ed25519 verification'),
    );
    expect(
      freshSetup,
      contains('Downloading native dependency packs'),
    );
    expect(
      packs,
      contains('nativeSetupWizardPackIds = setupWizardPackIds'),
    );
    for (final packId in const [
      'android-whisper-runtime',
      'android-tts-runtime',
      'android-cli-core-pack',
      'android-vision-media-pack',
      'android-audio-runtime-pack',
      'android-terminal-pack',
    ]) {
      expect(packs, contains("'$packId'"));
    }
    final setupPackListStart =
        packs.indexOf('static const List<String> setupWizardPackIds = [');
    final setupPackListEnd = packs.indexOf('];', setupPackListStart);
    final setupPackList = packs.substring(setupPackListStart, setupPackListEnd);
    expect(setupPackList, isNot(contains('android-agent-cli-pack')));
    expect(packs, contains('progress * 0.82'));
    expect(packs, contains("const <String>['-V']"));
    expect(packs, contains('_dependencyPackManifestCacheTtl'));
    expect(packs, contains('_writeJsonAtomically('));
    expect(mainActivity, contains('environment()["LD_LIBRARY_PATH"]'));
    expect(mainActivity, contains('managedLib.absolutePath'));
    expect(mainActivity, contains('managedNativeElfCommand'));
    expect(mainActivity, contains('File("/system/bin/linker64")'));
    expect(nativeRuntime, contains('process.env.LD_LIBRARY_PATH = ['));
    expect(nativeRuntime, contains('OPENCLAW_NATIVE_MANAGED_LIB'));
    expect(nativeRuntime, contains('managedNativeInvocation'));
    expect(nativeRuntime,
        contains('const nativeLinker64 = "/system/bin/linker64"'));
    expect(packs, contains('_readOrDownloadDependencyPackBytes'));
    expect(packs, contains('using verified archive cache'));
    expect(packs, contains('dependencyArchiveCacheDir'));
    expect(packs, contains('_isSharedObjectPath'));
    expect(packs, contains(r'\.so(?:\.\d+)*$'));
    expect(provisioner, contains('onBytesCopied'));
    expect(provisioner, contains('markIsolatedProvisionProgress'));
    expect(installer, contains('markIsolatedProvisionProgress'));
    expect(mainActivity, contains('getOfficialOpenClawProvisionStatus'));
    expect(nativeRuntime, contains('makeBlockedNpmProcess'));
    expect(nativeRuntime, contains('traceBlockedNpm'));
    expect(
      nativeRuntime,
      contains('patchOpenClawAndroidStartupMigrations(packageDir)'),
    );
    expect(
      nativeRuntime,
      contains('if (process.platform === \\"android\\") return false;'),
    );
    expect(
      nativeRuntime,
      contains(
        'process.platform !== \\"android\\" && " +\n'
        '                "shouldMigrateStateFromPath(commandPath);',
      ),
    );
    expect(
      gateway,
      contains('Native setup must enter waitForStartup immediately'),
    );
    expect(gateway, contains('_applyNativeProviderConfigPolicy'));
    expect(gateway, contains('_applyNativeBundledPluginPolicy'));
    expect(gateway, contains('nativeGatewayExternalPackageForProvider'));
    expect(providers, contains('nativeGatewayBundledPluginIds'));

    final nativeAuditStart =
        gateway.indexOf('Future<void> _auditNativeSkillParity(');
    final nativeAuditEnd =
        gateway.indexOf('Iterable<String> _skillProvisioningActivityLines(');
    expect(nativeAuditStart, greaterThanOrEqualTo(0));
    expect(nativeAuditEnd, greaterThan(nativeAuditStart));
    final nativeAudit = gateway.substring(nativeAuditStart, nativeAuditEnd);
    expect(nativeAudit, contains('repairNativeFromProot: false'));
    expect(nativeAudit, contains('.planSnapshot(snapshot)'));
    expect(nativeAudit, isNot(contains('.provisionSnapshot(snapshot)')));
    expect(nativeAudit, isNot(contains('repairNativeFromProot: true')));
  });

  test('setup and gateway notifications have distinct non-redundant owners',
      () async {
    final setupService = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/SetupService.kt',
    ).readAsString();
    final nativeRuntime = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/NativeNodeEmbeddedService.kt',
    ).readAsString();
    final nodeService = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/NodeForegroundService.kt',
    ).readAsString();
    final gateway =
        await File('lib/services/gateway_service.dart').readAsString();
    final heartbeat = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/HeartbeatWorker.kt',
    ).readAsString();
    final bootReceiver = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/BootReceiver.kt',
    ).readAsString();
    final legacyWatchdog = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/PlawieForegroundService.kt',
    ).readAsString();
    final mainActivity = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    ).readAsString();
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final isolatedInstaller = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/OfficialOpenClawInstallService.kt',
    ).readAsString();

    expect(setupService,
        contains('OfficialOpenClawInstallService.clearLegacyNotification'));
    expect(setupService,
        contains('NativeNodeEmbeddedService.clearGatewayNotification'));
    expect(
      nativeRuntime,
      contains('internal const val GATEWAY_NOTIFICATION_ID = 7'),
    );
    expect(nativeRuntime, contains('stopForeground(true)'));
    expect(nativeRuntime, contains('discarded null restart intent'));
    expect(nativeRuntime, contains('return START_NOT_STICKY'));
    expect(nativeRuntime, isNot(contains('return START_STICKY')));
    expect(nodeService, contains('const val NOTIFICATION_ID = 9'));
    expect(
      nodeService,
      contains('NativeNodeEmbeddedService.GATEWAY_NOTIFICATION_ID'),
    );
    expect(
      nodeService,
      contains('NativeNodeEmbeddedService.GATEWAY_NOTIFICATION_CHANNEL_ID'),
    );
    expect(nodeService, contains('if (wakeLock?.isHeld == true)'));
    expect(nodeService, contains('stopForeground(false)'));
    expect(nodeService, contains('if (lastNotificationText == text)'));
    expect(nativeRuntime, contains('if (lastNotificationText == text)'));
    expect(
      nativeRuntime,
      contains(
        'intent.action == ACTION_START && NativeNodeBridge.running()',
      ),
    );
    expect(
      nativeRuntime,
      contains(
          'runtimeAlreadyRunning -> "Native OpenClaw diagnostics running"'),
    );
    expect(
      gateway,
      isNot(
        contains(
          'action.status == SkillProvisioningActionStatus.missingPack',
        ),
      ),
    );
    expect(nodeService,
        contains('Node foreground service deferred until setup completes'));
    expect(gateway, isNot(contains('FlutterForegroundTask.startService')));
    expect(heartbeat, contains('SetupGuards.isNativeGatewayOwner'));
    expect(heartbeat, contains('nativeGateway.startFullGatewayProduction()'));
    expect(bootReceiver, contains('ensureGatewayOwnerService(context)'));
    expect(
      legacyWatchdog,
      contains(
        'PlawieForegroundService start ignored; native Gateway service owns notifications',
      ),
    );
    expect(
      mainActivity,
      contains('nativeNodeSmokeProcess.isFullGatewayProductionRunning()'),
    );
    expect(
      bootstrap,
      contains('updateNotification: false'),
    );
    expect(
      isolatedInstaller,
      contains('MIN_NOTIFICATION_UPDATE_INTERVAL_MS = 1_500L'),
    );
    expect(
      setupService,
      contains('MIN_NOTIFICATION_UPDATE_INTERVAL_MS = 1_000L'),
    );
  });

  test('native startup avoids redundant process and filesystem work', () async {
    final nativeProcess = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/NativeNodeSmokeProcess.kt',
    ).readAsString();
    final mainActivity = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    ).readAsString();
    final nativeRuntime = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/NativeNodeEmbeddedService.kt',
    ).readAsString();
    final gateway =
        await File('lib/services/gateway_service.dart').readAsString();
    final node = await File('lib/services/node_service.dart').readAsString();
    final nodeProvider =
        await File('lib/providers/node_provider.dart').readAsString();
    final provisioning = await File(
      'lib/services/skill_provisioning_service.dart',
    ).readAsString();

    expect(
      nativeProcess,
      contains('stop skipped; no native runtime process or listener is active'),
    );
    expect(nativeRuntime, isNot(contains('countExistingFiles')));
    expect(nativeRuntime, isNot(contains('walkTopDown().count')));
    expect(
      mainActivity,
      contains(
        'Thread {\n'
        '                        val running = if '
        '(SetupGuards.isNativeGatewayOwner(this))',
      ),
    );
    expect(
      nativeRuntime,
      contains('"verificationMode", "activated-receipt-and-required-files"'),
    );

    final freshStart = gateway.indexOf(
      "await NativeBridge.acquirePartialWakeLock();",
    );
    final runtimeStart = gateway.indexOf(
      'final success = await _runtime.start(',
      freshStart,
    );
    expect(freshStart, greaterThanOrEqualTo(0));
    expect(runtimeStart, greaterThan(freshStart));
    expect(
      gateway.substring(freshStart, runtimeStart),
      isNot(contains('_auditNativeSkillParity')),
    );
    expect(gateway, isNot(contains('bypassCooldown: true')));
    expect(
      gateway,
      contains('node.connect(gatewayAlreadyReady: true)'),
    );
    expect(
      nodeProvider,
      contains('_nodeService.connect(gatewayAlreadyReady: true)'),
    );
    expect(node, contains('bool gatewayAlreadyReady = false'));
    expect(node, contains('if (localGateway && gatewayAlreadyReady)'));
    expect(node, contains('!await NativeBridge.isGatewayRunning()'));
    expect(
      node,
      contains(
        'Local Gateway did not become ready for node pairing within 180 seconds.',
      ),
    );

    expect(provisioning, contains('receipt.id == pack.id'));
    expect(provisioning, contains('receipt.version == pack.version'));
    expect(provisioning, contains('receipt.sha256 == pack.sha256'));
    expect(provisioning, contains('receipt.smokePassed'));
    expect(
      provisioning,
      contains('await _dependencyPackMarkersPresent(layout, pack)'),
    );
  });

  test('mobile defaults prevent unrequested autonomous model traffic',
      () async {
    final bootstrap =
        await File('lib/services/bootstrap_service.dart').readAsString();
    final gateway =
        await File('lib/services/gateway_service.dart').readAsString();
    final providers =
        await File('lib/services/model_provider_catalog.dart').readAsString();
    final nativeRuntime = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/NativeNodeEmbeddedService.kt',
    ).readAsString();

    expect(bootstrap, contains("'every': '0m'"));
    expect(gateway, contains('_applyMobileHeartbeatDefault'));
    expect(gateway, contains("'every': '0m'"));
    expect(
      gateway,
      contains('contents.trim() == legacyAutogeneratedContents.trim()'),
    );
    expect(gateway, isNot(contains('await heartbeat.writeAsString')));
    expect(providers, contains("'browser'"));
    expect(providers, contains("'file-transfer'"));
    expect(nativeRuntime, contains('MAX_RUNTIME_LOG_BYTES = 512L * 1024L'));
    expect(nativeRuntime, contains('RETAIN_RUNTIME_LOG_LINES = 400'));
  });
}
