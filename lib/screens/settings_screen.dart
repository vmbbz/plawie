import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../services/native_bridge.dart';
import '../services/diagnostic_service.dart';
import '../services/gateway_service.dart';
import '../services/model_provider_catalog.dart';
import '../services/dynamic_model_catalog.dart';
import '../services/provider_model_discovery_service.dart';
import '../services/preferences_service.dart';
import '../services/tts_service.dart';
import '../services/local_llm_service.dart';
import '../services/storage_service.dart';
import '../services/ui_chrome_service.dart';
import '../widgets/glass_card.dart';
import 'node_screen.dart';
import 'setup_wizard_screen.dart';
import 'vrm_store_screen.dart';
import 'management/local_llm_screen.dart';
import '../services/voice_persona_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();
  bool _autoStart = false;
  bool _nodeEnabled = false;
  bool _immersiveUi = false;
  bool _batteryOptimized = true;
  String _arch = '';
  String _prootPath = '';
  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _goInstalled = false;
  bool _brewInstalled = false;
  String _selectedAvatar = 'gemini.vrm';
  bool _hasFullStorageAccess = false;
  final _storageService = StorageService();

  // Voice & Speech
  String _ttsEngine = 'gateway';
  double _ttsSpeed = 1.2;
  bool _continuousMode = false;

  int _silenceTimeout = 5;

  final _voicePersonaService = VoicePersonaService();

  // Wake Word
  String _wakeWordMode = 'off'; // off | foreground | always
  bool _hotwordRunning = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<T> _safeCall<T>(
    Future<T> future,
    T fallback, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      return await future.timeout(timeout);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _loadSettings() async {
    bool autoStart = _autoStart;
    bool nodeEnabled = _nodeEnabled;
    bool immersiveUi = _immersiveUi;
    bool batteryOptimized = _batteryOptimized;
    String arch = _arch;
    String prootPath = _prootPath;
    Map<String, dynamic> status = _status;
    bool goInstalled = _goInstalled;
    bool brewInstalled = _brewInstalled;
    String selectedAvatar = _selectedAvatar;
    bool hasFullStorageAccess = _hasFullStorageAccess;
    String ttsEngine = _ttsEngine;
    double ttsSpeed = _ttsSpeed;
    bool continuousMode = _continuousMode;
    int silenceTimeout = _silenceTimeout;
    String wakeWordMode = _wakeWordMode;
    bool hotwordRunning = _hotwordRunning;

    try {
      await _safeCall(_prefs.init(), null);
      autoStart = _prefs.autoStartGateway;
      nodeEnabled = _prefs.nodeEnabled;
      immersiveUi = _prefs.immersiveUiEnabled;
      selectedAvatar = _prefs.selectedAvatar;
      ttsSpeed = _prefs.ttsSpeed;
      continuousMode = _prefs.continuousMode;
      silenceTimeout = _prefs.silenceTimeoutSeconds;
      final storedEngine = _prefs.ttsEngine;
      ttsEngine = 'gateway';
      if (storedEngine != 'gateway') {
        _prefs.ttsEngine = 'gateway';
      }
      wakeWordMode = _prefs.wakeWordMode;

      hotwordRunning = await _safeCall(NativeBridge.isHotwordRunning(), false);
      hasFullStorageAccess =
          await _safeCall(_storageService.updateStatus(), false);

      arch = await _safeCall(NativeBridge.getArch(), '');
      prootPath = await _safeCall(NativeBridge.getProotPath(), '');
      status = await _safeCall(
          NativeBridge.getBootstrapStatus(), <String, dynamic>{});
      batteryOptimized =
          await _safeCall(NativeBridge.isBatteryOptimized(), true);

      // Check optional package statuses
      final filesDir = await _safeCall(NativeBridge.getFilesDir(), '');
      final rootfs = '$filesDir/rootfs/ubuntu';
      goInstalled = File('$rootfs/usr/bin/go').existsSync();
      brewInstalled =
          File('$rootfs/home/linuxbrew/.linuxbrew/bin/brew').existsSync();
    } catch (_) {
      // Keep defaults and render what we have.
    } finally {
      if (mounted) {
        setState(() {
          _autoStart = autoStart;
          _nodeEnabled = nodeEnabled;
          _immersiveUi = immersiveUi;
          _batteryOptimized = batteryOptimized;
          _arch = arch;
          _prootPath = prootPath;
          _status = status;
          _goInstalled = goInstalled;
          _brewInstalled = brewInstalled;
          _selectedAvatar = selectedAvatar;
          _hasFullStorageAccess = hasFullStorageAccess;
          _ttsEngine = ttsEngine;
          _ttsSpeed = ttsSpeed;
          _continuousMode = continuousMode;
          _silenceTimeout = silenceTimeout;
          _wakeWordMode = wakeWordMode;
          _hotwordRunning = hotwordRunning;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          NebulaBg(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            CustomScrollView(
              slivers: [
                _buildAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPitchHeader(context),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  sliver: SliverList.list(
                    children: [
                      _sectionHeader(theme, 'GENERAL'),
                      SwitchListTile(
                        title: const Text('Auto-start gateway'),
                        subtitle:
                            const Text('Start the gateway when the app opens'),
                        value: _autoStart,
                        onChanged: (value) {
                          setState(() => _autoStart = value);
                          _prefs.autoStartGateway = value;
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Immersive app mode'),
                        subtitle: const Text(
                            'Hide Android status and navigation bars while using Plawie'),
                        secondary: const Icon(Icons.fullscreen_rounded),
                        value: _immersiveUi,
                        onChanged: (value) async {
                          setState(() => _immersiveUi = value);
                          await UiChromeService.setImmersive(value);
                        },
                      ),
                      ListTile(
                        title: const Text('Battery Optimization'),
                        subtitle: Text(_batteryOptimized
                            ? 'Optimized (may kill background sessions)'
                            : 'Unrestricted (recommended)'),
                        leading: const Icon(Icons.battery_alert),
                        trailing: _batteryOptimized
                            ? const Icon(Icons.warning,
                                color: AppColors.statusAmber)
                            : const Icon(Icons.check_circle,
                                color: AppColors.statusGreen),
                        onTap: () async {
                          await NativeBridge.requestBatteryOptimization();
                          // Refresh status after returning from settings
                          final optimized =
                              await NativeBridge.isBatteryOptimized();
                          setState(() => _batteryOptimized = optimized);
                        },
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'STORAGE & FILES'),
                      ListTile(
                        title: const Text('All Files Access (Pro)'),
                        subtitle: Text(_hasFullStorageAccess
                            ? 'Granted - available to the PRoot rollback shell'
                            : 'Disabled - only affects PRoot rollback shell access'),
                        leading: Icon(
                          Icons.folder_shared,
                          color: _hasFullStorageAccess
                              ? AppColors.statusGreen
                              : Colors.white38,
                        ),
                        trailing: _hasFullStorageAccess
                            ? const Icon(Icons.check_circle,
                                color: AppColors.statusGreen)
                            : const Icon(Icons.chevron_right),
                        onTap: () async {
                          if (!_hasFullStorageAccess) {
                            _showStoragePermissionDialog(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Phone storage mount is for the PRoot rollback shell. Native Gateway uses app-private storage.')),
                            );
                          }
                        },
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'NODE'),
                      SwitchListTile(
                        title: const Text('Enable Node'),
                        subtitle: const Text(
                            'Provide device capabilities to the gateway'),
                        value: _nodeEnabled,
                        onChanged: (value) {
                          setState(() => _nodeEnabled = value);
                          _prefs.nodeEnabled = value;
                          final nodeProvider = context.read<NodeProvider>();
                          if (value) {
                            nodeProvider.enable();
                          } else {
                            nodeProvider.disable();
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('Node Configuration'),
                        subtitle:
                            const Text('Connection, pairing, and capabilities'),
                        leading: const Icon(Icons.devices),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NodeScreen()),
                        ),
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'API KEYS & MODEL'),
                      ListTile(
                        title: const Text('Current Provider'),
                        subtitle: Text(_getProviderLabel(
                            _prefs.configuredModel ??
                                'google/gemini-3.1-pro-preview')),
                        leading: const Icon(Icons.key),
                        trailing: const Icon(Icons.edit, size: 18),
                        onTap: () => _showUpdateApiKeyDialog(context),
                      ),
                      ListTile(
                        title: const Text('Active Model'),
                        subtitle: Text(_getModelLabel(_prefs.configuredModel ??
                            'google/gemini-3.1-pro-preview')),
                        leading: const Icon(Icons.psychology),
                        trailing: const Icon(Icons.swap_horiz, size: 18),
                        onTap: () => _showChangeModelDialog(context),
                      ),
                      // Local LLM shortcut — shows live server status
                      StreamBuilder<LocalLlmState>(
                        stream: LocalLlmService().stateStream,
                        initialData: LocalLlmService().state,
                        builder: (context, snap) {
                          final llmState = snap.data ?? const LocalLlmState();
                          final isReady =
                              llmState.status == LocalLlmStatus.ready;
                          final statusLabel = switch (llmState.status) {
                            LocalLlmStatus.ready =>
                              'Running · ${llmState.activeModelId?.split('-').take(3).join('-') ?? ''}',
                            LocalLlmStatus.starting => 'Starting...',
                            LocalLlmStatus.downloading => 'Downloading model',
                            LocalLlmStatus.installing =>
                              'Compiling llama-server',
                            LocalLlmStatus.error => 'Error — tap to fix',
                            LocalLlmStatus.idle => 'Offline — tap to set up',
                          };
                          return ListTile(
                            title: const Text('Local LLM'),
                            subtitle: Text(statusLabel),
                            leading: Icon(
                              Icons.memory_rounded,
                              color: isReady
                                  ? AppColors.statusGreen
                                  : Colors.white38,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isReady)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.statusGreen
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.statusGreen
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _prefs.configuredModel
                                                  ?.startsWith('local-llm/') ==
                                              true
                                          ? 'ACTIVE'
                                          : 'READY',
                                      style: const TextStyle(
                                          color: AppColors.statusGreen,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right,
                                    color: Colors.white24),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LocalLlmScreen()),
                            ),
                          );
                        },
                      ),
                      _sectionHeader(theme, 'AVATAR'),
                      ListTile(
                        title: const Text('Selected Avatar'),
                        subtitle: Text(_prefs.selectedAvatar
                            .split('.')
                            .first
                            .toUpperCase()),
                        onTap: () => _changeAvatar(context),
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'GATEWAY VOICE'),
                      ListTile(
                        title: const Text('Voice engine'),
                        subtitle: const Text(
                            'Gateway Talk streams speech from configured providers'),
                        leading: const Icon(
                          Icons.settings_voice,
                          color: AppColors.statusGreen,
                        ),
                        trailing: const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Gateway'),
                        ),
                        onTap: () async {
                          await _voicePersonaService.setTtsEngine('gateway');
                          setState(() => _ttsEngine = 'gateway');
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Gateway Talk is the active voice engine.'),
                            ),
                          );
                        },
                      ),
                      const ListTile(
                        title: Text('Offline voice packs'),
                        subtitle: Text(
                            'Optional local voice runtime is not installed in this Android build'),
                        leading: Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white38,
                        ),
                        enabled: false,
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'VOICE & SPEECH'),
                      ListTile(
                        title: const Text('Voice Persona'),
                        subtitle:
                            Text(TtsService().currentPersona.toUpperCase()),
                        leading: const Icon(Icons.psychology_alt),
                        trailing: const Icon(Icons.swap_horiz, size: 18),
                        onTap: () => _showPersonaPicker(context),
                      ),
                      // Speed slider
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Speech Speed',
                                    style: TextStyle(fontSize: 14)),
                                Text('${_ttsSpeed.toStringAsFixed(1)}×',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white54)),
                              ],
                            ),
                            Slider(
                              value: _ttsSpeed,
                              min: 0.5,
                              max: 2.0,
                              divisions: 15,
                              onChanged: (v) {
                                setState(() => _ttsSpeed = v);
                                _prefs.ttsSpeed = v;
                              },
                            ),
                          ],
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Continuous Mode'),
                        subtitle:
                            const Text('Auto-restart mic after each response'),
                        value: _continuousMode,
                        onChanged: (v) {
                          setState(() => _continuousMode = v);
                          _prefs.continuousMode = v;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Silence Timeout',
                                    style: TextStyle(fontSize: 14)),
                                Text('${_silenceTimeout}s',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white54)),
                              ],
                            ),
                            Slider(
                              value: _silenceTimeout.toDouble(),
                              min: 1,
                              max: 15,
                              divisions: 14,
                              onChanged: (v) {
                                setState(() => _silenceTimeout = v.round());
                                _prefs.silenceTimeoutSeconds = v.round();
                              },
                            ),
                            Text(
                                'How long to wait after you stop speaking before submitting',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white38)),
                          ],
                        ),
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'WAKE WORD'),
                      // Status tile — shows running/idle
                      ListTile(
                        leading: Icon(
                          Icons.hearing,
                          color: _hotwordRunning
                              ? AppColors.statusGreen
                              : Colors.white38,
                        ),
                        title: const Text('Wake Word "Plawie"'),
                        subtitle: Text(_hotwordRunning
                            ? 'Listening · mode: $_wakeWordMode'
                            : 'Off — say "Plawie" to activate hands-free'),
                        trailing: _hotwordRunning
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.statusGreen
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.statusGreen
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Text('ACTIVE',
                                    style: TextStyle(
                                        color: AppColors.statusGreen,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5)),
                              )
                            : null,
                      ),
                      // Mode picker
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Mode', style: TextStyle(fontSize: 14)),
                            DropdownButton<String>(
                              value: _wakeWordMode,
                              dropdownColor: Colors.grey[900],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                    value: 'off', child: Text('Off')),
                                DropdownMenuItem(
                                    value: 'foreground',
                                    child: Text('Foreground only')),
                                DropdownMenuItem(
                                    value: 'always', child: Text('Always on')),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() => _wakeWordMode = v);
                                _prefs.wakeWordMode = v;
                                await NativeBridge.setHotwordMode(v);
                                if (v == 'off') {
                                  await NativeBridge.stopHotword();
                                } else {
                                  await NativeBridge.startHotword();
                                }
                                final running =
                                    await NativeBridge.isHotwordRunning();
                                if (mounted) {
                                  setState(() => _hotwordRunning = running);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'SYSTEM INFO'),
                      ListTile(
                        title: const Text('Architecture'),
                        subtitle: Text(_arch),
                        leading: const Icon(Icons.memory),
                      ),
                      ListTile(
                        title: const Text('PRoot rollback path'),
                        subtitle: Text(_prootPath.isEmpty
                            ? 'Emergency rollback runtime only'
                            : _prootPath),
                        leading: const Icon(Icons.folder),
                      ),
                      ListTile(
                        title: const Text('PRoot rollback rootfs'),
                        subtitle: Text(_status['rootfsExists'] == true
                            ? 'Installed - rollback only'
                            : 'Not installed'),
                        leading: const Icon(Icons.storage),
                      ),
                      ListTile(
                        title: const Text('PRoot Node.js'),
                        subtitle: Text(_status['nodeInstalled'] == true
                            ? 'Installed - rollback only'
                            : 'Not installed'),
                        leading: const Icon(Icons.code),
                      ),
                      ListTile(
                        title: const Text('PRoot OpenClaw Gateway'),
                        subtitle: Text(_status['openclawInstalled'] == true
                            ? 'Installed - rollback only'
                            : 'Not installed'),
                        leading: const Icon(Icons.cloud),
                      ),
                      ListTile(
                        title: const Text('Go (PRoot optional)'),
                        subtitle: Text(_goInstalled
                            ? 'Installed - not used by native Gateway'
                            : 'Not installed - not required by native Gateway'),
                        leading: const Icon(Icons.integration_instructions),
                      ),
                      ListTile(
                        title: const Text('Homebrew (PRoot optional)'),
                        subtitle: Text(_brewInstalled
                            ? 'Installed - not used by native Gateway'
                            : 'Not installed - not required by native Gateway'),
                        leading: const Icon(Icons.science),
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'MAINTENANCE'),
                      ListTile(
                        title: const Text('Test Gateway Connection'),
                        subtitle:
                            const Text('Check if the gateway is reachable'),
                        leading: const Icon(Icons.wifi_tethering),
                        onTap: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Testing connection...')),
                          );
                          final gw = context.read<GatewayProvider>();
                          final healthy = await gw.checkHealth();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              icon: Icon(
                                healthy ? Icons.check_circle : Icons.error,
                                color: healthy
                                    ? AppColors.statusGreen
                                    : AppColors.statusRed,
                                size: 48,
                              ),
                              title: Text(healthy
                                  ? 'Gateway Connected'
                                  : 'Connection Failed'),
                              content: Text(healthy
                                  ? 'Gateway is healthy and responding at ${AppConstants.gatewayUrl}'
                                  : 'Cannot reach the gateway at ${AppConstants.gatewayUrl}.\nMake sure it is running.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                                ListTile(
                                  title:
                                      const Text('Open official documentation'),
                                  subtitle: const Text(
                                      'View setup guide and usage docs',
                                      style: TextStyle(fontSize: 12)),
                                  trailing: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 18,
                                      color: Colors.white38),
                                  onTap: () => launchUrl(
                                    Uri.parse('https://openclaw.ai/docs'),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('Re-run setup'),
                        subtitle:
                            const Text('Reinstall or repair the environment'),
                        leading: const Icon(Icons.build),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const SetupWizardScreen(),
                          ),
                        ),
                      ),
                      Consumer<GatewayProvider>(
                        builder: (context, provider, _) {
                          final repairing = provider.state.isRepairing;
                          return ListTile(
                            title: const Text('Repair Gateway Installation'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  repairing
                                      ? provider.state.repairMessage
                                      : 'Fix SyntaxError or corrupted library files',
                                  style: TextStyle(
                                    color: repairing
                                        ? AppColors.statusAmber
                                        : Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                if (repairing) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: provider.state.repairProgress,
                                      backgroundColor: Colors.white10,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              AppColors.statusAmber),
                                      minHeight: 2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            leading: Icon(
                              Icons.build_circle,
                              color: repairing
                                  ? AppColors.statusAmber
                                  : Colors.white38,
                            ),
                            onTap: repairing
                                ? null
                                : () => _showRepairDialog(context),
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('Run Gateway Diagnostics'),
                        subtitle: const Text(
                            'Check tmux, openclaw, session and logs'),
                        leading: const Icon(Icons.bug_report),
                        onTap: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const Center(
                                child: CircularProgressIndicator()),
                          );
                          final results =
                              await DiagnosticService.runGatewayDiagnostics();
                          if (!context.mounted) return;
                          Navigator.pop(context); // close progress
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Diagnostics'),
                              content: SingleChildScrollView(
                                child: SelectableText(results.entries
                                    .map((e) => '${e.key}:\n${e.value}')
                                    .join('\n\n')),
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close')),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'ABOUT'),
                      const ListTile(
                        title: Text('Plawie'),
                        subtitle: Text(
                          'OpenClaw in your Pocket\nVersion ${AppConstants.version}',
                        ),
                        leading: Icon(Icons.info_outline),
                        isThreeLine: true,
                      ),
                      const ListTile(
                        title: Text('License'),
                        subtitle: Text(AppConstants.license),
                        leading: Icon(Icons.description),
                      ),
                      const Divider(),
                      _sectionHeader(theme, 'SUPPORT'),
                      ListTile(
                        title: const Text('Documentation'),
                        subtitle: const Text('View setup guide and usage docs'),
                        leading: const Icon(Icons.book),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => launchUrl(
                          Uri.parse('https://github.com/vmbbz/plawie'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      ListTile(
                        title: const Text('Community'),
                        subtitle: const Text('Join our Discord community'),
                        leading: const Icon(Icons.people),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () => launchUrl(
                          Uri.parse('https://discord.gg/openclaw'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showPersonaPicker(BuildContext context) async {
    final tts = TtsService();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Voice Persona'),
        children: tts.availablePersonas.map((p) {
          final isSelected = tts.currentPersona == p;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 20,
                  color: isSelected
                      ? Theme.of(ctx).colorScheme.primary
                      : Colors.white38,
                ),
                const SizedBox(width: 12),
                Text(p[0].toUpperCase() + p.substring(1)),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (picked != null && picked != tts.currentPersona) {
      setState(() {}); // Refresh local UI state
      await tts.setVoicePersona(picked);
      if (mounted) setState(() {}); // Final refresh
    }
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/app_icon_official.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Text(
            'SETTINGS',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 3.0,
              color: Colors.white,
            ),
          ),
        ],
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: FlexibleSpaceBar(
            background: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
      ),
    );
  }

  Widget _buildPitchHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Command\nCenter',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Configure your OpenClaw environment, manage API keys, node permissions, and local LLMs.',
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // Local LLM is accessible via Settings > Local LLM tile (StreamBuilder above).

  void _showRepairDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Background repair started. Check the Dashboard for status.'),
        backgroundColor: AppColors.statusAmber,
        duration: Duration(seconds: 5),
      ),
    );

    context.read<GatewayProvider>().repairAndRestart();
  }

  void _changeAvatar(BuildContext context) {
    final avatars = ['gemini.vrm'];
    final labels = ['Gemini (Default)'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Avatar'),
        content: RadioGroup<String>(
          groupValue: _selectedAvatar,
          onChanged: (val) {
            if (val == null) return;
            setState(() => _selectedAvatar = val);
            _prefs.selectedAvatar = val;
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                avatars.length,
                (i) => RadioListTile<String>(
                      title: Text(labels[i]),
                      value: avatars[i],
                    )),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.store_rounded, size: 16),
            label: const Text('Get More Avatars'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VrmStoreScreen()),
              ).then((_) {
                // Refresh equipped avatar after returning from the store
                setState(() => _selectedAvatar = _prefs.selectedAvatar);
              });
            },
          ),
        ],
      ),
    );
  }

  String _getModelLabel(String modelId) {
    // Local LLM: look up friendly name from catalog
    if (modelId.startsWith('local-llm/')) {
      final ggufId = modelId.replaceFirst('local-llm/', '');
      final match = LocalLlmService().catalog.where((m) => m.id == ggufId);
      if (match.isNotEmpty) return match.first.name;
      return 'Local · $ggufId';
    }
    return ModelProviderCatalog.labelForModel(modelId);
  }

  String _getProviderLabel(String modelId) {
    if (modelId.startsWith('local-llm/')) return 'On-Device (Free)';
    if (modelId.startsWith('plawie_ndk/')) return 'Plawie NDK Bridge';
    final model = ModelProviderCatalog.modelById(modelId);
    final provider = model == null
        ? null
        : ModelProviderCatalog.providerById(model.providerId);
    if (provider != null) return provider.label;
    return modelId.split('/').first.toUpperCase();
  }

  String _providerName(String provider) {
    final option = ModelProviderCatalog.providerById(provider);
    if (option == null) return provider;
    return option.id == 'xai' ? 'xAI / Grok' : option.label;
  }

  void _showUpdateApiKeyDialog(BuildContext context) {
    final keyController = TextEditingController();
    final providers = ModelProviderCatalog.providers
        .where((provider) => provider.requiresApiKey)
        .map((provider) => provider.id)
        .toList(growable: false);
    String selectedProvider = ModelProviderCatalog.apiProviderForSetupId(
        _prefs.apiProvider ?? 'openrouter');
    if (!providers.contains(selectedProvider)) selectedProvider = 'openrouter';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Update API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedProvider,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: providers
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(_providerName(p)),
                        ))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedProvider = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'New API Key',
                  hintText: 'Paste your API key here',
                ),
                obscureText: true,
              ),
              if (selectedProvider == 'openrouter') ...[
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => launchUrl(
                    Uri.parse('https://openrouter.ai/settings/keys'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new_rounded, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Get an OpenRouter API key. One key can route free models and paid upgrades.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final key = keyController.text.trim();
                if (key.isEmpty) return;
                Navigator.pop(ctx);

                // Show progress
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Updating API key...')),
                );

                try {
                  final gw = context.read<GatewayProvider>();
                  await gw.configureApiKey(
                    selectedProvider,
                    key,
                    runBackgroundOnboard: false,
                  );
                  if (!context.mounted) return;
                  _prefs.apiProvider = selectedProvider;
                  _prefs.apiKeyConfigured = true;
                  setState(() {});

                  String modelRefreshMessage =
                      'Provider key saved. Showing the bundled model list.';
                  try {
                    final refreshed =
                        await ProviderModelDiscoveryService().refreshProvider(
                      selectedProvider,
                      apiKey: key,
                    );
                    final count = refreshed.providers
                        .firstWhere(
                            (provider) => provider.id == selectedProvider)
                        .models
                        .length;
                    modelRefreshMessage =
                        'Provider key saved. Refreshed $count models.';
                  } on ProviderDiscoveryException catch (error) {
                    modelRefreshMessage =
                        'Provider key saved, but model refresh failed: ${error.message}';
                  } catch (error) {
                    modelRefreshMessage =
                        'Provider key saved, but model refresh failed: $error';
                  }

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '$modelRefreshMessage Gateway may restart briefly before reconnecting.')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update key: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeModelDialog(BuildContext context) async {
    final cached = await DynamicModelCatalogRepository().load();
    final snapshot = cached != null &&
            cached.providers.any(
              (provider) => provider.models.isNotEmpty,
            )
        ? cached
        : DynamicCatalogSnapshot.bundledFallback();
    if (!context.mounted) return;

    final dynamicModels = <DynamicModelRecord>[
      for (final provider in snapshot.providers) ...provider.models,
    ];
    final llmService = LocalLlmService();
    final llmReady = llmService.state.status == LocalLlmStatus.ready;
    final localModelId = llmReady && llmService.state.activeModelId != null
        ? 'local-llm/${llmService.state.activeModelId}'
        : null;
    final localLabel = llmReady
        ? '🧠 ${_getModelLabel(localModelId!)} (Free · On-Device)'
        : null;

    String current = ModelProviderCatalog.canonicalizeModelId(
        _prefs.configuredModel ??
            ModelProviderCatalog.defaultCloudFallbackModel);

    Future<void> switchModel(
      String val,
      String label,
      DynamicModelRecord? dynamicModel,
    ) async {
      final modelId = ModelProviderCatalog.canonicalizeModelId(val);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switching model...')),
      );
      try {
        final gw = context.read<GatewayProvider>();
        final catalogModel = ModelProviderCatalog.modelById(modelId);
        final providerId = dynamicModel?.providerId ?? catalogModel?.providerId;
        if (providerId != null &&
            !await GatewayService().hasProviderCredential(providerId)) {
          if (!context.mounted) return;
          final provider = ModelProviderCatalog.providerById(providerId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Add a ${provider?.label ?? providerId} API key before using $label.',
              ),
            ),
          );
          return;
        }
        if (dynamicModel != null &&
            dynamicModel.sourceModelId != null &&
            !ModelProviderCatalog.cloudModelIds.contains(modelId)) {
          await gw.persistDynamicModel(dynamicModel);
        } else {
          await gw.persistModel(modelId);
        }
        if (!context.mounted) return;
        _prefs.configuredModel = modelId;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Model set to $label. OpenClaw will hot-reload.')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }

    final cloudIds = dynamicModels.map((model) => model.id).toSet();
    if (!cloudIds.contains(current) && localModelId != current) {
      current = dynamicModels.isNotEmpty
          ? dynamicModels.first.id
          : ModelProviderCatalog.defaultCloudFallbackModel;
    }

    final selection = await showDialog<String>(
      context: context,
      builder: (ctx) {
        var query = '';
        final expanded = <String>{
          for (final provider in snapshot.providers) provider.id,
        };
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final normalizedQuery = query.trim().toLowerCase();
            final providerGroups = snapshot.providers
                .map((provider) {
                  final models = normalizedQuery.isEmpty
                      ? provider.models
                      : provider.models
                          .where((model) =>
                              model.label
                                  .toLowerCase()
                                  .contains(normalizedQuery) ||
                              model.id.toLowerCase().contains(normalizedQuery))
                          .toList(growable: false);
                  return (provider: provider, models: models);
                })
                .where((group) => group.models.isNotEmpty)
                .toList(growable: false);

            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Select Model')),
                  IconButton(
                    tooltip: 'Manage provider keys and refresh models',
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showUpdateApiKeyDialog(context);
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.sizeOf(context).height * 0.66,
                child: RadioGroup<String>(
                  groupValue: current,
                  onChanged: (val) => Navigator.pop(ctx, val),
                  child: Column(
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search models or providers',
                        ),
                        onChanged: (value) =>
                            setDialogState(() => query = value),
                      ),
                      if (snapshot.state == DynamicCatalogSnapshotState.stale ||
                          snapshot.state == DynamicCatalogSnapshotState.error)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              snapshot.state ==
                                      DynamicCatalogSnapshotState.stale
                                  ? 'Cached model list · refresh from Provider keys'
                                  : 'Provider refresh had an error · showing cached models',
                              style: const TextStyle(
                                  color: Colors.amber, fontSize: 11),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            if (llmReady && localModelId != null) ...[
                              const Text('ON-DEVICE',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                      color: AppColors.statusGreen)),
                              RadioListTile<String>(
                                title: Text(localLabel!),
                                subtitle: const Text(
                                    'No API key · No internet · Private',
                                    style: TextStyle(fontSize: 11)),
                                value: localModelId,
                              ),
                              const Divider(),
                            ],
                            if (providerGroups.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text('CLOUD PROVIDERS',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                        color: Colors.white38)),
                              ),
                            ...providerGroups.map((group) {
                              final provider = group.provider;
                              final isExpanded = normalizedQuery.isNotEmpty ||
                                  expanded.contains(provider.id);
                              return ExpansionTile(
                                key: PageStorageKey<String>(provider.id),
                                initiallyExpanded: isExpanded,
                                onExpansionChanged: (value) {
                                  if (value) {
                                    expanded.add(provider.id);
                                  } else {
                                    expanded.remove(provider.id);
                                  }
                                  setDialogState(() {});
                                },
                                tilePadding: EdgeInsets.zero,
                                title: Text(provider.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  '${group.models.length} models · ${provider.connectionState.name}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                children: isExpanded
                                    ? group.models
                                        .map((model) => RadioListTile<String>(
                                              dense: true,
                                              title: Text(model.label,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              subtitle: Text(
                                                '${model.agentReady ? 'Agent-ready' : 'Tool support unknown'} · ${model.id}',
                                                style: const TextStyle(
                                                    fontSize: 10),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              value: model.id,
                                            ))
                                        .toList(growable: false)
                                    : const <Widget>[],
                              );
                            }),
                            if (providerGroups.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child:
                                    Text('No cached models match that search.'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (selection == null || !context.mounted) return;
    final dynamicModel = dynamicModels.firstWhere(
      (model) => model.id == selection,
      orElse: () => const DynamicModelRecord(
        id: '',
        providerId: '',
        label: '',
        route: ModelRouteKind.cloud,
      ),
    );
    await switchModel(
      selection,
      dynamicModel.id.isEmpty ? _getModelLabel(selection) : dynamicModel.label,
      dynamicModel.id.isEmpty ? null : dynamicModel,
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showStoragePermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('All Files Access',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_shared,
                size: 48, color: AppColors.statusAmber),
            const SizedBox(height: 16),
            Text(
              _storageService.permissionReason,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _storageService.requestAccess();
              if (success) {
                setState(() => _hasFullStorageAccess = true);
              }
              // Even if success is false, they might have granted it and returned.
              // Let's re-check status.
              final status = await _storageService.updateStatus();
              setState(() => _hasFullStorageAccess = status);
            },
            child: const Text('ENABLE'),
          ),
        ],
      ),
    );
  }
}
