import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../constants.dart';
import '../providers/node_provider.dart';
import '../services/native_bridge.dart';
import '../services/diagnostic_service.dart';
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
  String _selectedAvatar = 'gemini.vrm';

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
                // AI provider selection removed; gateway configuration is used instead
                const SizedBox.shrink(),
                _sectionHeader(theme, 'AVATAR'),
                ListTile(
                  title: const Text('Selected Avatar'),
                  subtitle: Text(_selectedAvatar == 'gemini.vrm' ? 'Gemini (Default)' : 'Boruto'),
                  leading: const Icon(Icons.face),
                  onTap: () => _changeAvatar(context),
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

  // Local LLM support removed; gateway-based providers are used.

  void _changeAvatar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Avatar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Gemini (Default)'),
              value: 'gemini.vrm',
              groupValue: _selectedAvatar,
              onChanged: (val) {
                setState(() => _selectedAvatar = val!);
                _prefs.selectedAvatar = val!;
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('Boruto'),
              value: 'boruto.vrm',
              groupValue: _selectedAvatar,
              onChanged: (val) {
                setState(() => _selectedAvatar = val!);
                _prefs.selectedAvatar = val!;
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Model download UI removed.

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
