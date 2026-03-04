import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../providers/gateway_provider.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isFirstRun;

  const OnboardingScreen({super.key, this.isFirstRun = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  String? _error;
  final TextEditingController _commandController = TextEditingController();
  
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

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
      'description': 'Set local binding (recommended)',
      'icon': 'settings_ethernet',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOnboardingHelp();
  }

  void _writeLog(String text) {
    if (!mounted) return;
    setState(() {
      _logs.addAll(text.split('\n').where((l) => l.trim().isNotEmpty));
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadOnboardingHelp() async {
    try {
      setState(() => _loading = true);
      
      final result = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw onboard --help',
        timeout: 15000
      );
      
      _writeLog(result);
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load onboarding: $e';
        });
      }
    }
  }

  Future<void> _executeCommand(String command) async {
    try {
      _writeLog('> $command');
      
      final result = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && $command',
        timeout: 30000
      );
      
      _writeLog(result);
      
      if (command.toLowerCase().contains('api-key') || 
          command.toLowerCase().contains('binding')) {
        _writeLog('\n✓ Configuration command executed');
        
        if (command.toLowerCase().contains('binding')) {
          final bindingMatch = RegExp(r'--binding\s+([^\s]+)').firstMatch(command);
          if (bindingMatch != null) {
            final bindingAddress = bindingMatch.group(1);
            _writeLog('\n🔄 Syncing WebSocket connection to $bindingAddress');
            
            final prefs = PreferencesService();
            await prefs.init();
            prefs.nodeGatewayHost = bindingAddress;
            
            _writeLog('\n✅ WebSocket will connect to $bindingAddress');
          }
        }
        
        _writeLog('\n🚀 Starting OpenClaw services...');
        await _startOpenClawServices();
      }
    } catch (e) {
      _writeLog('\n✗ Command failed: $e');
    }
  }

  Future<void> _startOpenClawServices() async {
    try {
      _writeLog('\nChecking OpenClaw configuration...');
      
      final configCheck = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw config --show',
        timeout: 5000
      );
      
      _writeLog('\nCurrent config: $configCheck');
      
      if (configCheck.contains('claude-api-key') || configCheck.contains('openai-api-key') || 
          configCheck.contains('gemini-api-key') || configCheck.contains('groq-api-key')) {
        
        _writeLog('\n✅ API key found, starting OpenClaw CLI Gateway...');
        
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && pkill -f "openclaw gateway" || true',
          timeout: 5000
        );
        
        final gatewayStarted = await NativeBridge.startGateway();
        
        if (gatewayStarted) {
          _writeLog('\n✅ OpenClaw CLI Gateway started successfully');
          _writeLog('\n🤖 OpenClaw Agent is now running 24/7');
          _writeLog('\n📱 Dashboard available at: http://localhost:18789');
          
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) _triggerGatewayStateRefresh();
          
          await _markOnboardingComplete();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ OpenClaw CLI Gateway is now running!'),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          _writeLog('\n❌ Failed to start OpenClaw CLI Gateway');
        }
      } else {
        _writeLog('\n❌ No API key configured. Please configure an API key first.');
      }
    } catch (e) {
      _writeLog('\n❌ Service startup failed: $e');
    }
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.setupComplete = true;
    prefs.isFirstRun = false;
  }

  void _triggerGatewayStateRefresh() {
    final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);
    gatewayProvider.checkHealth();
  }

  Future<void> _copyCommand(String command) async {
    await Clipboard.setData(ClipboardData(text: command));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Command copied!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _commandController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
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
                Tab(icon: Icon(Icons.terminal, size: 20), text: 'Terminal'),
                Tab(icon: Icon(Icons.flash_on, size: 20), text: 'Quick Setup'),
              ],
              labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              indicatorColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          
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
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                   controller: _scrollController,
                   padding: const EdgeInsets.all(12),
                   itemCount: _logs.length,
                   itemBuilder: (context, index) {
                     return Padding(
                       padding: const EdgeInsets.only(bottom: 2),
                       child: SelectableText(
                         _logs[index],
                         style: const TextStyle(
                           fontFamily: 'monospace',
                           color: Colors.lightGreenAccent,
                           fontSize: 12,
                           height: 1.3,
                         ),
                       ),
                     );
                   },
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
          Text(
            'Configure your AI model:',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          ..._commands.map((cmd) => _buildCommandCard(cmd)),
          
          const SizedBox(height: 24),
          
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
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
          icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary, size: 20),
          onPressed: () => _copyCommand(command['command']!),
          tooltip: 'Copy command',
        ),
      ),
    );
  }

  IconData _getIconForCommand(String iconType) {
    switch (iconType) {
      case 'api': return Icons.api;
      case 'speed': return Icons.speed;
      case 'settings_ethernet': return Icons.settings_ethernet;
      default: return Icons.code;
    }
  }
}
