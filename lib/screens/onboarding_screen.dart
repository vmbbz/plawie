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

  final List<Map<String, dynamic>> _providers = [
    {
      'id': 'google',
      'name': 'Google Gemini',
      'icon': 'smart_toy',
      'models': [
        {'id': 'gemini-3.1-pro-preview', 'name': 'Gemini 3.1 Pro Preview'},
        {'id': 'gemini-1.5-pro', 'name': 'Gemini 1.5 Pro'},
        {'id': 'gemini-1.5-flash', 'name': 'Gemini 1.5 Flash'},
      ],
      'defaultModel': 'gemini-3.1-pro-preview',
    },
    {
      'id': 'anthropic',
      'name': 'Anthropic Claude',
      'icon': 'api',
      'models': [
        {'id': 'claude-opus-4.6', 'name': 'Claude Opus 4.6'},
        {'id': 'claude-sonnet-4.6', 'name': 'Claude Sonnet 4.6'},
        {'id': 'claude-3-5-sonnet-latest', 'name': 'Claude 3.5 Sonnet'},
      ],
      'defaultModel': 'claude-opus-4.6',
    },
    {
      'id': 'openai',
      'name': 'OpenAI',
      'icon': 'psychology',
      'models': [
        {'id': 'gpt-4o', 'name': 'GPT-4o'},
        {'id': 'gpt-o1', 'name': 'GPT o1'},
      ],
      'defaultModel': 'gpt-4o',
    },
    {
      'id': 'groq',
      'name': 'Groq',
      'icon': 'speed',
      'models': [
        {'id': 'llama-3.1-405b', 'name': 'Llama 3.1 405B'},
        {'id': 'llama-3.1-70b-versatile', 'name': 'Llama 3.1 70B'},
      ],
      'defaultModel': 'llama-3.1-405b',
    },
  ];

  final Map<String, TextEditingController> _apiKeyControllers = {};
  final Map<String, String> _selectedModels = {};

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
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && openclaw onboard --help', // Dual-shim verified.
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
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && $command',
        timeout: 30000
      );
      
      _writeLog(result);
      
      final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);
      final lowercaseCommand = command.toLowerCase();

      if (lowercaseCommand.contains('api-key')) {
        _writeLog('\n🔑 Syncing API key to agent profiles...');
        
        // Extract key and provider
        String? key;
        String? provider;
        
        if (lowercaseCommand.contains('--claude-api-key')) {
          provider = 'anthropic';
          final match = RegExp(r'--claude-api-key\s+["' "'" r']?([^"' "'" r'\s]+)["' "'" r']?').firstMatch(command);
          key = match?.group(1);
        } else if (lowercaseCommand.contains('--gemini-api-key')) {
          provider = 'google';
          final match = RegExp(r'--gemini-api-key\s+["' "'" r']?([^"' "'" r'\s]+)["' "'" r']?').firstMatch(command);
          key = match?.group(1);
        } else if (lowercaseCommand.contains('--openai-api-key')) {
          provider = 'openai';
          final match = RegExp(r'--openai-api-key\s+["' "'" r']?([^"' "'" r'\s]+)["' "'" r']?').firstMatch(command);
          key = match?.group(1);
        } else if (lowercaseCommand.contains('--groq-api-key')) {
          provider = 'groq';
          final match = RegExp(r'--groq-api-key\s+["' "'" r']?([^"' "'" r'\s]+)["' "'" r']?').firstMatch(command);
          key = match?.group(1);
        }

        if (provider != null && key != null && key.isNotEmpty) {
          await _processProviderSetup(provider, key);
        }
      }
      
      if (lowercaseCommand.contains('api-key') || 
          lowercaseCommand.contains('binding')) {
        _writeLog('\n✓ Configuration command executed');
        
        if (lowercaseCommand.contains('binding')) {
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
      
      // BEFORE starting gateway - exact user-requested validation
      final validateResult = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && openclaw config --validate || openclaw doctor --fix',
        timeout: 10000
      );
      
      if (validateResult.contains('Invalid')) {
        _writeLog('\n⚠️ Configuration auto-fixed. Start may fail.');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Config auto-fixed – please restart if issues persist')),
           );
        }
      }

      final configCheck = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && openclaw config --show',
        timeout: 5000
      );
      
      _writeLog('\nCurrent config: $configCheck');
      
      if (configCheck.contains('claude-api-key') || configCheck.contains('openai-api-key') || 
          configCheck.contains('gemini-api-key') || configCheck.contains('groq-api-key')) {
        
        _writeLog('\n✅ API key found, starting OpenClaw CLI Gateway...');
        
        await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && pkill -f "openclaw gateway" || true',
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
    for (var c in _apiKeyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _processProviderSetup(String provider, String key, {String? modelId, String? modelName}) async {
    final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);
    
    _writeLog('\n🔑 Syncing $provider API key to agent profiles...');
    await gatewayProvider.configureApiKey(provider, key);

    // Dynamic model fallback
    if (modelId == null || modelName == null) {
      switch (provider.toLowerCase()) {
        case 'google':
          modelId = 'gemini-3.1-pro-preview';
          modelName = 'Gemini 3.1 Pro Preview';
          break;
        case 'anthropic':
          modelId = 'claude-opus-4.6';
          modelName = 'Claude Opus 4.6';
          break;
        case 'openai':
          modelId = 'gpt-4o';
          modelName = 'GPT-4o';
          break;
        case 'groq':
          modelId = 'llama-3.1-405b';
          modelName = 'Llama 3.1 405B';
          break;
        case 'openrouter':
          modelId = 'anthropic/claude-sonnet-4.5';
          modelName = 'Claude Sonnet 4.5 via OpenRouter';
          break;
        default:
          modelId = 'default';
          modelName = 'Default Model';
      }
    }

    _writeLog('\n🔄 Syncing auth-profiles.json for agent "main"...');
    String baseUrl = provider == 'google' ? 'https://generativelanguage.googleapis.com/v1beta' :
                     provider == 'anthropic' ? 'https://api.anthropic.com' :
                     provider == 'openai' ? 'https://api.openai.com/v1' : 
                     provider == 'openrouter' ? 'https://openrouter.ai/api/v1' : 'https://api.groq.com/openai/v1';

    await NativeBridge.runInProot('''
      export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && node -e '
        const fs = require("fs");
        const path = "/root/.openclaw/agents/main/agent/auth-profiles.json";
        let config = {};
        try { config = JSON.parse(fs.readFileSync(path, "utf8")); } catch (e) {}
        config["$provider"] = { apiKey: "$key", baseUrl: "$baseUrl" };
        fs.writeFileSync(path, JSON.stringify(config, null, 2));
        console.log("Synced $provider to auth-profiles.json");
      '
    ''');

    _writeLog('\n📦 Adding specific model and setting as primary...');
    // The exact sequence requested by the user
    await NativeBridge.runInProot('''
      export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && openclaw models add --provider $provider --id $modelId --name "$modelName"
      export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && openclaw doctor --fix
      export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --require /root/.openclaw/network-shim.js" && openclaw agents update --primary-model $provider/$modelId
    ''', timeout: 15000);
    
    _writeLog('✅ API key and model ($modelName) synced.');
  }

  Future<void> _executeProviderSetupUI(String provider, String key, String modelId, String modelName) async {
     try {
       await _processProviderSetup(provider, key, modelId: modelId, modelName: modelName);
       _writeLog('\n🚀 Starting OpenClaw services...');
       await _startOpenClawServices();
     } catch (e) {
       _writeLog('\n✗ Setup failed: $e');
     }
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
          
          ..._providers.map((p) => _buildProviderCard(p)),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Advanced CLI Command:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commandController,
                  decoration: InputDecoration(
                    hintText: 'e.g., openclaw onboard --binding 127.0.0.1',
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

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    final String id = provider['id'];
    _apiKeyControllers.putIfAbsent(id, () => TextEditingController());
    _selectedModels.putIfAbsent(id, () => provider['defaultModel']);

    final models = provider['models'] as List<Map<String, String>>;
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getIconForCommand(provider['icon']), color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(provider['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyControllers[id],
            decoration: InputDecoration(
              hintText: 'Enter API Key (sk-...)',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedModels[id],
            decoration: InputDecoration(
              labelText: 'Starting Model',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: models.map((m) => DropdownMenuItem(
              value: m['id'],
              child: Text(m['name']!),
            )).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedModels[id] = val);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final key = _apiKeyControllers[id]?.text.trim();
                if (key == null || key.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an API key')));
                   return;
                }
                final modelId = _selectedModels[id];
                final modelName = models.firstWhere((m) => m['id'] == modelId)['name'];
                
                // Switch to terminal tab and configure
                _tabController.animateTo(0);
                _executeProviderSetupUI(id, key, modelId!, modelName!);
              },
              child: const Text('Configure & Connect'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCommand(String iconType) {
    switch (iconType) {
      case 'api': return Icons.api;
      case 'smart_toy': return Icons.smart_toy;
      case 'psychology': return Icons.psychology;
      case 'speed': return Icons.speed;
      case 'settings_ethernet': return Icons.settings_ethernet;
      default: return Icons.code;
    }
  }
}
