import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../services/native_bridge.dart';
import '../services/diagnostic_service.dart';
import '../services/preferences_service.dart';
import '../services/tts_service.dart';
import '../services/local_llm_service.dart';
import '../widgets/glass_card.dart';
import 'node_screen.dart';
import 'setup_wizard_screen.dart';
import 'management/local_llm_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();
  bool _autoStart = false;
  bool _nodeEnabled = false;
  bool _batteryOptimized = true;
  String _arch = '';
  String _prootPath = '';
  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _goInstalled = false;
  bool _brewInstalled = false;
  String _selectedAvatar = 'gemini.vrm';

  // Voice & Speech
  String _ttsEngine = 'kokoro';
  double _ttsSpeed = 1.2;
  bool _continuousMode = false;
  int _kokoroVoiceSid = 1;

  int _silenceTimeout = 5;

  // Wake Word
  String _wakeWordMode = 'off'; // off | foreground | always
  bool _hotwordRunning = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _prefs.init();
    _autoStart = _prefs.autoStartGateway;
    _nodeEnabled = _prefs.nodeEnabled;
    _selectedAvatar = _prefs.selectedAvatar;
    _ttsEngine = _prefs.ttsEngine;
    _ttsSpeed = _prefs.ttsSpeed;
    _continuousMode = _prefs.continuousMode;
    _kokoroVoiceSid = _prefs.kokoroVoiceSid;
    _silenceTimeout = _prefs.silenceTimeoutSeconds;
    _wakeWordMode = _prefs.wakeWordMode;
    _hotwordRunning = await NativeBridge.isHotwordRunning();

    try {
      final arch = await NativeBridge.getArch();
      final prootPath = await NativeBridge.getProotPath();
      final status = await NativeBridge.getBootstrapStatus();
      final batteryOptimized = await NativeBridge.isBatteryOptimized();

      // Check optional package statuses
      final filesDir = await NativeBridge.getFilesDir();
      final rootfs = '$filesDir/rootfs/ubuntu';
      final goInstalled = File('$rootfs/usr/bin/go').existsSync();
      final brewInstalled =
          File('$rootfs/home/linuxbrew/.linuxbrew/bin/brew').existsSync();

      setState(() {
        _batteryOptimized = batteryOptimized;
        _arch = arch;
        _prootPath = prootPath;
        _status = status;
        _goInstalled = goInstalled;
        _brewInstalled = brewInstalled;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icon/plawie_icon.png',
              width: 20,
              height: 20,
              color: Colors.white,
              errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
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
      ),
      body: Stack(
        children: [
          const NebulaBg(),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                _sectionHeader(theme, 'GENERAL'),
                SwitchListTile(
                  title: const Text('Auto-start gateway'),
                  subtitle: const Text('Start the gateway when the app opens'),
                  value: _autoStart,
                  onChanged: (value) {
                    setState(() => _autoStart = value);
                    _prefs.autoStartGateway = value;
                  },
                ),
                ListTile(
                  title: const Text('Battery Optimization'),
                  subtitle: Text(_batteryOptimized
                      ? 'Optimized (may kill background sessions)'
                      : 'Unrestricted (recommended)'),
                  leading: const Icon(Icons.battery_alert),
                  trailing: _batteryOptimized
                      ? const Icon(Icons.warning, color: AppColors.statusAmber)
                      : const Icon(Icons.check_circle, color: AppColors.statusGreen),
                  onTap: () async {
                    await NativeBridge.requestBatteryOptimization();
                    // Refresh status after returning from settings
                    final optimized = await NativeBridge.isBatteryOptimized();
                    setState(() => _batteryOptimized = optimized);
                  },
                ),
                const Divider(),
                _sectionHeader(theme, 'NODE'),
                SwitchListTile(
                  title: const Text('Enable Node'),
                  subtitle: const Text('Provide device capabilities to the gateway'),
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
                  subtitle: const Text('Connection, pairing, and capabilities'),
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
                  subtitle: Text(_getProviderLabel(_prefs.configuredModel ?? 'google/gemini-3.1-pro-preview')),
                  leading: const Icon(Icons.key),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _showUpdateApiKeyDialog(context),
                ),
                ListTile(
                  title: const Text('Active Model'),
                  subtitle: Text(_getModelLabel(_prefs.configuredModel ?? 'google/gemini-3.1-pro-preview')),
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
                    final isReady = llmState.status == LocalLlmStatus.ready;
                    final statusLabel = switch (llmState.status) {
                      LocalLlmStatus.ready => 'Running · ${llmState.activeModelId?.split('-').take(3).join('-') ?? ''}',
                      LocalLlmStatus.starting => 'Starting...',
                      LocalLlmStatus.downloading => 'Downloading model',
                      LocalLlmStatus.installing => 'Compiling llama-server',
                      LocalLlmStatus.error => 'Error — tap to fix',
                      LocalLlmStatus.idle => 'Offline — tap to set up',
                    };
                    return ListTile(
                      title: const Text('Local LLM'),
                      subtitle: Text(statusLabel),
                      leading: Icon(
                        Icons.memory_rounded,
                        color: isReady ? AppColors.statusGreen : Colors.white38,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isReady)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.statusGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.statusGreen.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _prefs.configuredModel?.startsWith('local-llm/') == true ? 'ACTIVE' : 'READY',
                                style: const TextStyle(color: AppColors.statusGreen, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: Colors.white24),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LocalLlmScreen()),
                      ),
                    );
                  },
                ),
                _sectionHeader(theme, 'AVATAR'),
                ListTile(
                  title: const Text('Selected Avatar'),
                  subtitle: Text(_prefs.selectedAvatar.split('.').first.toUpperCase()),
                  leading: const Icon(Icons.face),
                  onTap: () => _changeAvatar(context),
                ),
                const Divider(),
                _sectionHeader(theme, 'VOICE & SPEECH'),
                // TTS engine selector
                ListTile(
                  title: const Text('TTS Engine'),
                  subtitle: Text(_ttsEngineLabel(_ttsEngine)),
                  leading: const Icon(Icons.record_voice_over),
                  trailing: const Icon(Icons.swap_horiz, size: 18),
                  onTap: () => _showTtsEnginePicker(context),
                ),
                // Kokoro voice picker — only shown when Kokoro is the active engine
                if (_ttsEngine == 'kokoro')
                  ListTile(
                    title: const Text('Kokoro Voice'),
                    subtitle: Text(_kokoroVoiceLabel(_kokoroVoiceSid)),
                    leading: const Icon(Icons.mic_none),
                    trailing: const Icon(Icons.swap_horiz, size: 18),
                    onTap: () => _showKokoroVoicePicker(context),
                  ),
                // Speed slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Speech Speed', style: TextStyle(fontSize: 14)),
                          Text('${_ttsSpeed.toStringAsFixed(1)}×',
                              style: const TextStyle(fontSize: 14, color: Colors.white54)),
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
                  subtitle: const Text('Auto-restart mic after each response'),
                  value: _continuousMode,
                  onChanged: (v) {
                    setState(() => _continuousMode = v);
                    _prefs.continuousMode = v;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Silence Timeout', style: TextStyle(fontSize: 14)),
                          Text('${_silenceTimeout}s',
                              style: const TextStyle(fontSize: 14, color: Colors.white54)),
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
                      Text('How long to wait after you stop speaking before submitting',
                          style: TextStyle(fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ),
                const Divider(),
                _sectionHeader(theme, 'WAKE WORD'),
                // Status tile — shows running/idle
                ListTile(
                  leading: Icon(
                    Icons.hearing,
                    color: _hotwordRunning ? AppColors.statusGreen : Colors.white38,
                  ),
                  title: const Text('Wake Word "Plawie"'),
                  subtitle: Text(_hotwordRunning
                      ? 'Listening · mode: $_wakeWordMode'
                      : 'Off — say "Plawie" to activate hands-free'),
                  trailing: _hotwordRunning
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.3)),
                          ),
                          child: const Text('ACTIVE',
                              style: TextStyle(color: AppColors.statusGreen, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        )
                      : null,
                ),
                // Mode picker
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mode', style: TextStyle(fontSize: 14)),
                      DropdownButton<String>(
                        value: _wakeWordMode,
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'off',        child: Text('Off')),
                          DropdownMenuItem(value: 'foreground', child: Text('Foreground only')),
                          DropdownMenuItem(value: 'always',     child: Text('Always on')),
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
                          final running = await NativeBridge.isHotwordRunning();
                          if (mounted) setState(() => _hotwordRunning = running);
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
                  title: const Text('PRoot path'),
                  subtitle: Text(_prootPath),
                  leading: const Icon(Icons.folder),
                ),
                ListTile(
                  title: const Text('Rootfs'),
                  subtitle: Text(_status['rootfsExists'] == true
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.storage),
                ),
                ListTile(
                  title: const Text('Node.js'),
                  subtitle: Text(_status['nodeInstalled'] == true
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.code),
                ),
                ListTile(
                  title: const Text('OpenClaw Gateway'),
                  subtitle: Text(_status['openclawInstalled'] == true
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.cloud),
                ),
                ListTile(
                  title: const Text('Go (Golang)'),
                  subtitle: Text(_goInstalled
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.integration_instructions),
                ),
                ListTile(
                  title: const Text('Homebrew'),
                  subtitle: Text(_brewInstalled
                      ? 'Installed'
                      : 'Not installed'),
                  leading: const Icon(Icons.science),
                ),
                const Divider(),
                _sectionHeader(theme, 'MAINTENANCE'),
                ListTile(
                  title: const Text('Test Gateway Connection'),
                  subtitle: const Text('Check if the gateway is reachable'),
                  leading: const Icon(Icons.wifi_tethering),
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Testing connection...')),
                    );
                    final gw = context.read<GatewayProvider>();
                    final healthy = await gw.checkHealth();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        icon: Icon(
                          healthy ? Icons.check_circle : Icons.error,
                          color: healthy ? AppColors.statusGreen : AppColors.statusRed,
                          size: 48,
                        ),
                        title: Text(healthy ? 'Gateway Connected' : 'Connection Failed'),
                        content: Text(healthy
                          ? 'Gateway is healthy and responding at ${AppConstants.gatewayUrl}'
                          : 'Cannot reach the gateway at ${AppConstants.gatewayUrl}.\nMake sure it is running.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                          ListTile(
                            title: const Text('Open official documentation'),
                            subtitle: const Text('View setup guide and usage docs', style: TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white38),
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
                  subtitle: const Text('Reinstall or repair the environment'),
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
                            repairing ? provider.state.repairMessage : 'Fix SyntaxError or corrupted library files',
                            style: TextStyle(
                              color: repairing ? AppColors.statusAmber : Colors.white54,
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
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.statusAmber),
                                minHeight: 2,
                              ),
                            ),
                          ],
                        ],
                      ),
                      leading: Icon(
                        Icons.build_circle,
                        color: repairing ? AppColors.statusAmber : Colors.white38,
                      ),
                      onTap: repairing ? null : () => _showRepairDialog(context),
                    );
                  },
                ),
                ListTile(
                  title: const Text('Run Gateway Diagnostics'),
                  subtitle: const Text('Check tmux, openclaw, session and logs'),
                  leading: const Icon(Icons.bug_report),
                  onTap: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => const Center(child: CircularProgressIndicator()),
                    );
                    final results = await DiagnosticService.runGatewayDiagnostics();
                    Navigator.pop(context); // close progress
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Diagnostics'),
                        content: SingleChildScrollView(
                          child: SelectableText(results.entries.map((e) => '${e.key}:\n${e.value}').join('\n\n')),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
                  title: const Text('License'),
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
    );
  }

  // Local LLM is accessible via Settings > Local LLM tile (StreamBuilder above).

  void _showRepairDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Background repair started. Check the Dashboard for status.'),
        backgroundColor: AppColors.statusAmber,
        duration: Duration(seconds: 5),
      ),
    );

    context.read<GatewayProvider>().repairAndRestart();
  }

  void _changeAvatar(BuildContext context) {
    final avatars = ['gemini.vrm', 'boruto.vrm', 'default_avatar.vrm'];
    final labels = ['Gemini (Default)', 'Boruto', 'Plawie'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Avatar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(avatars.length, (i) => RadioListTile<String>(
            title: Text(labels[i]),
            value: avatars[i],
            groupValue: _selectedAvatar,
            onChanged: (val) {
              setState(() => _selectedAvatar = val!);
              _prefs.selectedAvatar = val!;
              Navigator.pop(ctx);
            },
          )),
        ),
      ),
    );
  }

  static const _ttsEngines = [
    ('kokoro',     'Kokoro (Offline)'),
    ('native',     'Device TTS'),
    ('elevenlabs', 'ElevenLabs'),
    ('openai',     'OpenAI TTS'),
  ];

  static const _kokoroVoices = [
    (0,  'af — American Female'),
    (1,  'af_bella — American Female (Best)'),
    (2,  'af_nicole — American Female'),
    (3,  'af_sarah — American Female'),
    (4,  'af_sky — American Female'),
    (5,  'am_adam — American Male'),
    (6,  'am_michael — American Male'),
    (7,  'bf_emma — British Female'),
    (8,  'bf_isabella — British Female'),
    (9,  'bm_george — British Male'),
    (10, 'bm_lewis — British Male'),
  ];

  String _ttsEngineLabel(String id) =>
      _ttsEngines.firstWhere((e) => e.$1 == id, orElse: () => (id, id)).$2;

  Future<void> _showTtsEnginePicker(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('TTS Engine'),
        children: _ttsEngines.map((e) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e.$1),
            child: Row(
              children: [
                Icon(
                  _ttsEngine == e.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: _ttsEngine == e.$1 ? Theme.of(ctx).colorScheme.primary : Colors.white38,
                ),
                const SizedBox(width: 12),
                Text(e.$2),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (picked != null && picked != _ttsEngine) {
      setState(() => _ttsEngine = picked);
      _prefs.ttsEngine = picked;
    }
  }

  String _kokoroVoiceLabel(int sid) =>
      _kokoroVoices.firstWhere((v) => v.$1 == sid, orElse: () => (sid, 'Voice $sid')).$2;

  Future<void> _showKokoroVoicePicker(BuildContext context) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Kokoro Voice'),
        children: _kokoroVoices.map((v) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, v.$1),
            child: Row(
              children: [
                Icon(
                  _kokoroVoiceSid == v.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: _kokoroVoiceSid == v.$1 ? Theme.of(ctx).colorScheme.primary : Colors.white38,
                ),
                const SizedBox(width: 12),
                Text(v.$2),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (picked != null && picked != _kokoroVoiceSid) {
      setState(() => _kokoroVoiceSid = picked);
      TtsService().updateKokoroVoice(picked);
    }
  }

  String _getModelLabel(String modelId) {
    // Local LLM: look up friendly name from catalog
    if (modelId.startsWith('local-llm/')) {
      final ggufId = modelId.replaceFirst('local-llm/', '');
      final match = LocalLlmService().catalog.where((m) => m.id == ggufId);
      if (match.isNotEmpty) return match.first.name;
      return 'Local · $ggufId';
    }
    const models = [
      'google/gemini-3.1-pro-preview',
      'anthropic/claude-opus-4.6',
      'openai/gpt-4o',
      'groq/llama-3.1-405b',
    ];
    const labels = [
      'Gemini 3.1 Pro Preview',
      'Claude Opus 4.6',
      'GPT-4o',
      'Llama 3.1 405B',
    ];
    final idx = models.indexOf(modelId);
    if (idx != -1) return labels[idx];
    return modelId.split('/').last;
  }

  String _getProviderLabel(String modelId) {
    if (modelId.startsWith('local-llm/')) return 'On-Device (Free)';
    if (modelId.startsWith('google/')) return 'Google';
    if (modelId.startsWith('anthropic/')) return 'Anthropic';
    if (modelId.startsWith('openai/')) return 'OpenAI';
    if (modelId.startsWith('groq/')) return 'Groq';
    return modelId.split('/').first.toUpperCase();
  }

  void _showUpdateApiKeyDialog(BuildContext context) {
    final keyController = TextEditingController();
    final providers = ['google', 'anthropic', 'openai', 'groq'];
    String selectedProvider = _prefs.apiProvider ?? 'google';
    if (!providers.contains(selectedProvider)) selectedProvider = 'google';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Update API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedProvider,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: providers.map((p) => DropdownMenuItem(
                  value: p,
                  child: Text(p[0].toUpperCase() + p.substring(1)),
                )).toList(),
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
                  await gw.configureApiKey(selectedProvider, key);
                  _prefs.apiProvider = selectedProvider;
                  _prefs.apiKeyConfigured = true;
                  setState(() {});
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API key updated! OpenClaw will hot-reload the config.')),
                  );
                } catch (e) {
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

  void _showChangeModelDialog(BuildContext context) {
    final cloudModels = [
      'google/gemini-3.1-pro-preview',
      'anthropic/claude-opus-4.6',
      'openai/gpt-4o',
      'groq/llama-3.1-405b',
      'ollama/qwen3-coder:480b-cloud',
      'ollama/gpt-oss:120b-cloud',
      'ollama/deepseek-v3.1:671b-cloud',
      'ollama/kimi-k2.5:cloud',
      'ollama/minimax-m2.7:cloud',
      'ollama/glm-5:cloud',
    ];
    final cloudLabels = [
      'Gemini 3.1 Pro Preview',
      'Claude Opus 4.6',
      'GPT-4o',
      'Llama 3.1 405B',
      '☁ QWEN3 CODER 480B',
      '☁ GPT-OSS 120B',
      '☁ DEEPSEEK V3.1 671B',
      '☁ KIMI K2.5',
      '☁ MINIMAX M2.7',
      '☁ GLM-5',
    ];

    final llmService = LocalLlmService();
    final llmReady = llmService.state.status == LocalLlmStatus.ready;
    final localModelId = llmReady && llmService.state.activeModelId != null
        ? 'local-llm/${llmService.state.activeModelId}'
        : null;
    final localLabel = llmReady
        ? '🧠 ${_getModelLabel(localModelId!)} (Free · On-Device)'
        : null;

    String current = _prefs.configuredModel ?? cloudModels[0];

    Future<void> switchModel(String val, String label) async {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switching model...')),
      );
      try {
        final gw = context.read<GatewayProvider>();
        await gw.persistModel(val);
        _prefs.configuredModel = val;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Model set to $label. OpenClaw will hot-reload.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Model'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Local LLM option — only shown when llama-server is running
              if (llmReady && localModelId != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                  child: Text('ON-DEVICE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.statusGreen.withValues(alpha: 0.8))),
                ),
                RadioListTile<String>(
                  title: Text(localLabel!),
                  subtitle: const Text('No API key · No internet · Private', style: TextStyle(fontSize: 11)),
                  value: localModelId,
                  groupValue: current,
                  activeColor: AppColors.statusGreen,
                  onChanged: (val) async {
                    Navigator.pop(ctx);
                    await switchModel(val!, _getModelLabel(val));
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                  child: Text('CLOUD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Colors.white38)),
                ),
              ],
              ...List.generate(cloudModels.length, (i) => RadioListTile<String>(
                title: Text(cloudLabels[i]),
                subtitle: Text(cloudModels[i], style: const TextStyle(fontSize: 11)),
                value: cloudModels[i],
                groupValue: current,
                onChanged: (val) async {
                  Navigator.pop(ctx);
                  await switchModel(val!, cloudLabels[i]);
                },
              )),
              if (!llmReady)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Start Local LLM from Agent Skills to unlock free on-device inference.',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ),
            ],
          ),
        ),
      ),
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
}
