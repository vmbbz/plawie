import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter/services.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import 'dashboard_screen.dart';

/// Modern Material Terminal - Clean, Material Design 3 with proper ANSI formatting
/// Provides intuitive command execution with copy-paste functionality
class OnboardingScreen extends StatefulWidget {
  final bool isFirstRun;

  const OnboardingScreen({super.key, this.isFirstRun = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  late final Terminal _terminal;
  late final TerminalController _controller;
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  final TextEditingController _commandController = TextEditingController();

  // Command examples with descriptions - multiple AI services
  final List<Map<String, String>> _commands = [
    {
      'command': 'openclaw onboard --claude-api-key "sk-ant-xxx"',
      'description': 'Configure Claude API key',
      'icon': 'api',
    },
    {
      'command': 'openclaw onboard --gemini-api-key "AIzaSy..."',
      'description': 'Configure Gemini API key',
      'icon': 'smart_toy',
    },
    {
      'command': 'openclaw onboard --openai-api-key "sk-proj..."',
      'description': 'Configure OpenAI API key',
      'icon': 'psychology',
    },
    {
      'command': 'openclaw onboard --groq-api-key "gsk_xxx"',
      'description': 'Configure Groq API key',
      'icon': 'speed',
    },
    {
      'command': 'openclaw onboard --binding 127.0.0.1',
      'description': 'Set local binding address',
      'icon': 'settings_ethernet',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize TabController
    _tabController = TabController(length: 2, vsync: this);
    
    // Terminal with proper ANSI support (matches original)
    _terminal = Terminal(maxLines: 500);
    _controller = TerminalController();
    _loadOnboardingHelp();
  }

  Future<void> _loadOnboardingHelp() async {
    try {
      setState(() => _loading = true);
      
      // Simple command - just get help text (like original)
      final result = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw onboard --help',
        timeout: 15000
      );
      
      // Write directly like original - no line ending manipulation
      _terminal.write(result);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load onboarding: $e';
      });
    }
  }

  Future<void> _executeCommand(String command) async {
    try {
      _terminal.write('\r\n> $command\r\n');
      
      final result = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && $command',
        timeout: 30000
      );
      
      _terminal.write(result);
      
      // Check if configuration was successful
      if (command.toLowerCase().contains('api-key') || 
          command.toLowerCase().contains('binding')) {
        _terminal.write('\r\n✓ Configuration command executed\r\n');
        
        // AUTOMATIC SERVICE STARTUP - Like SeekerClaw!
        _terminal.write('\r\n🚀 Starting OpenClaw services...\r\n');
        await _startOpenClawServices();
      }
    } catch (e) {
      _terminal.write('\r\n✗ Command failed: $e\r\n');
    }
  }

  Future<void> _startOpenClawServices() async {
    try {
      // Start OpenClaw Gateway automatically
      _terminal.write('\r\n📡 Starting OpenClaw Gateway...\r\n');
      final gatewayStarted = await NativeBridge.startGateway();
      
      if (gatewayStarted) {
        _terminal.write('\r\n✅ OpenClaw Gateway started successfully\r\n');
        _terminal.write('\r\n🤖 OpenClaw Agent is now running 24/7\r\n');
        _terminal.write('\r\n📱 Dashboard available at: http://localhost:18789\r\n');
        
        // Save completion status
        await _markOnboardingComplete();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ OpenClaw is now running!'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _terminal.write('\r\n❌ Failed to start OpenClaw Gateway\r\n');
      }
    } catch (e) {
      _terminal.write('\r\n❌ Service startup failed: $e\r\n');
    }
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.setupComplete = true;
    prefs.isFirstRun = false;
  }

  Future<void> _copyCommand(String command) async {
    await Clipboard.setData(ClipboardData(text: command));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Command copied!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _commandController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _goToDashboard() async {
    final navigator = Navigator.of(context);
    final prefs = PreferencesService();
    await prefs.init();
    prefs.setupComplete = true;
    prefs.isFirstRun = false;

    if (mounted) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenClaw Onboarding'),
        // Remove redundant back button for first run
        automaticallyImplyLeading: !widget.isFirstRun,
        actions: [
          if (widget.isFirstRun)
            TextButton(
              onPressed: _goToDashboard,
              child: const Text('Dashboard'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading onboarding options...'),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadOnboardingHelp,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.terminal, size: 20),
                  text: 'Terminal',
                ),
                Tab(
                  icon: Icon(Icons.flash_on, size: 20),
                  text: 'Quick Setup',
                ),
              ],
              labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTerminalTab(),
                _buildQuickSetupTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Terminal with Material Design 3 styling
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TerminalView(
                  _terminal,
                  controller: _controller,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSetupTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple instruction
          Text(
            'Configure your AI model:',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Single command cards with copy buttons
          ..._commands.map((cmd) => _buildCommandCard(cmd)),
          
          const SizedBox(height: 24),
          
          // Command input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commandController,
                  decoration: InputDecoration(
                    hintText: 'Or type your command here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14, 
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _executeCommand(_commandController.text),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Execute'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCard(Map<String, String> command) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          _getIconForCommand(command['icon']!),
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        title: Text(
          command['description']!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          command['command']!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.copy,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          onPressed: () => _copyCommand(command['command']!),
          tooltip: 'Copy command',
        ),
      ),
    );
  }

  IconData _getIconForCommand(String iconType) {
    switch (iconType) {
      case 'api':
        return Icons.api;
      case 'speed':
        return Icons.speed;
      case 'settings_ethernet':
        return Icons.settings_ethernet;
      default:
        return Icons.code;
    }
  }
}
