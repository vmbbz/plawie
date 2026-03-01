import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/node_provider.dart';
import '../providers/setup_provider.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import 'node_screen.dart';
import 'setup_wizard_screen.dart';

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
  String _llmProvider = 'ollama';
  String _selectedModel = 'gemma3:2b';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _prefs.init();
    _autoStart = _prefs.autoStartGateway;
    _nodeEnabled = _prefs.nodeEnabled;
    _llmProvider = _prefs.llmProvider;
    _selectedModel = _prefs.selectedModel;

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
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                _sectionHeader(theme, 'AI PROVIDER'),
                ListTile(
                  title: const Text('Provider'),
                  subtitle: Text(_llmProvider == 'ollama' ? 'Local LLM (Ollama)' : 'Cloud (API)'),
                  leading: const Icon(Icons.psychology),
                  onTap: () => _changeLlmProvider(context),
                ),
                if (_llmProvider == 'ollama')
                  ListTile(
                    title: const Text('Local Model'),
                    subtitle: Text(_selectedModel),
                    leading: const Icon(Icons.model_training),
                    onTap: () => _changeLocalModel(context),
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
                  title: const Text('Clawa Pocket'),
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
                const Divider(),
                _sectionHeader(theme, 'ABOUT'),
                const ListTile(
                  title: const Text('Clawa Pocket'),
                  subtitle: Text(
                    'AI in Your Pocket\nVersion ${AppConstants.version}',
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
                    Uri.parse('https://github.com/clawa-pocket/docs'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('Community'),
                  subtitle: const Text('Join our Discord community'),
                  leading: const Icon(Icons.people),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('https://discord.gg/clawa-pocket'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('Email'),
                  subtitle: const Text('contact@clawa-pocket.com'),
                  leading: const Icon(Icons.email_outlined),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse('mailto:contact@clawa-pocket.com'),
                  ),
                ),
              ],
            ),
    );
  }

  void _changeLlmProvider(BuildContext context) {
    final currentProvider = _llmProvider;
    final prefs = _prefs;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose AI Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Local LLM (Ollama)'),
              subtitle: const Text('Runs entirely on your device (Offline)'),
              value: 'ollama',
              groupValue: currentProvider,
              onChanged: (val) {
                setState(() => _llmProvider = val!);
                prefs.llmProvider = val!;
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('Cloud (API)'),
              subtitle: const Text('Requires internet and API keys'),
              value: 'cloud',
              groupValue: currentProvider,
              onChanged: (val) {
                setState(() => _llmProvider = val!);
                prefs.llmProvider = val!;
                Navigator.pop(ctx);
              },
            ),
            _sectionHeader(Theme.of(context), 'Android 12+ Phantom Process Killer'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ ANDROID 12+ PHANTOM PROCESS KILLER',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Android 12+ may kill Ollama as a "rogue process" due to high RAM usage.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'POWER USERS: Run this ADB command to disable:',
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: const SelectableText(
                        'adb shell device_config put activity_manager max_phantom_processes 2147483647',
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Then restart your device and the app.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeLocalModel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Local Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _modelOption(ctx, 'gemma3:2b', 'Gemma 3B'),
            _modelOption(ctx, 'phi3:mini', 'Phi-3 Mini 3.8B'),
            _modelOption(ctx, 'qwen2.5:3b', 'Qwen2.5 3B'),
          ],
        ),
      ),
    );
  }

  Widget _modelOption(BuildContext ctx, String id, String name) {
    final currentModel = _selectedModel;
    final prefs = _prefs;
    return RadioListTile<String>(
      title: Text(name),
      value: id,
      groupValue: currentModel,
      onChanged: (val) {
        setState(() => _selectedModel = val!);
        prefs.selectedModel = val!;
        Navigator.pop(ctx);
        _promptModelDownload(val!);
      },
    );
  }

  void _promptModelDownload(String modelId) {
    final buildContext = context;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download Model?'),
        content: Text('Would you like to download $modelId now? This may take several minutes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              buildContext.read<SetupProvider>().pullModel(modelId);
              // We could navigate to a progress screen or show a persistent banner
              ScaffoldMessenger.of(buildContext).showSnackBar(
                SnackBar(content: Text('Downloading $modelId in background...')),
              );
            },
            child: const Text('Download'),
          ),
        ],
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
