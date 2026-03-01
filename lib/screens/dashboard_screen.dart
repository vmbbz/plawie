import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../widgets/gateway_controls.dart';
import '../widgets/status_card.dart';
import 'node_screen.dart';
import 'onboarding_screen.dart';
import 'terminal_screen.dart';
import 'web_dashboard_screen.dart';
import 'logs_screen.dart';
import 'packages_screen.dart';
import 'packages_screen.dart';
import 'settings_screen.dart';
import '../services/preferences_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clawa Pocket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GatewayControls(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'QUICK ACTIONS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            StatusCard(
              title: 'Terminal',
              subtitle: 'Open Ubuntu shell with Clawa Pocket',
              icon: Icons.terminal,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TerminalScreen()),
              ),
            ),
            Consumer<GatewayProvider>(
              builder: (context, provider, _) {
                return StatusCard(
                  title: 'Web Dashboard',
                  subtitle: provider.state.isRunning
                      ? 'Open Clawa Pocket dashboard in browser'
                      : 'Start gateway first',
                  icon: Icons.dashboard,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: provider.state.isRunning
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => WebDashboardScreen(
                                url: provider.state.dashboardUrl,
                              ),
                            ),
                          )
                      : null,
                );
              },
            ),
            StatusCard(
              title: 'Onboarding',
              subtitle: 'Configure API keys and binding',
              icon: Icons.vpn_key,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              ),
            ),
            StatusCard(
              title: 'Packages',
              subtitle: 'Install optional tools (Go, Homebrew)',
              icon: Icons.extension,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PackagesScreen()),
              ),
            ),
            StatusCard(
              title: 'Logs',
              subtitle: 'View gateway output and errors',
              icon: Icons.article_outlined,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogsScreen()),
              ),
            ),
            FutureBuilder<PreferencesService>(
              future: () async {
                final p = PreferencesService();
                await p.init();
                return p;
              }(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final prefs = snapshot.data!;
                final isLocal = prefs.llmProvider == 'ollama';
                return StatusCard(
                  title: 'AI Model',
                  subtitle: isLocal
                      ? 'Local: ${prefs.selectedModel}'
                      : 'Cloud API',
                  icon: isLocal ? Icons.psychology : Icons.cloud_queue,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                );
              },
            ),
            Consumer<NodeProvider>(
              builder: (context, nodeProvider, _) {
                final nodeState = nodeProvider.state;
                return StatusCard(
                  title: 'Node',
                  subtitle: nodeState.isPaired
                      ? 'Connected to gateway'
                      : nodeState.isDisabled
                          ? 'Device capabilities for AI'
                          : nodeState.statusText,
                  icon: Icons.devices,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NodeScreen()),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    'Clawa Pocket v${AppConstants.version}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppConstants.appMotto,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
