import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../providers/gateway_provider.dart';
import '../widgets/glass_card.dart';
import '../app.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isFirstRun;

  const OnboardingScreen({super.key, this.isFirstRun = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
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
        {'id': 'claude-opus-4-6', 'name': 'Claude Opus 4.6'},
        {'id': 'claude-sonnet-4-6', 'name': 'Claude Sonnet 4.6'},
        {'id': 'claude-3-5-sonnet-latest', 'name': 'Claude 3.5 Sonnet'},
      ],
      'defaultModel': 'claude-opus-4-6',
    },
    {
      'id': 'openai',
      'name': 'OpenAI',
      'icon': 'psychology',
      'models': [
        {'id': 'gpt-5.4', 'name': 'GPT-5.4'},
        {'id': 'gpt-4o', 'name': 'GPT-4o'},
      ],
      'defaultModel': 'gpt-5.4',
    },
    {
      'id': 'xai',
      'name': 'xAI Grok',
      'icon': 'rocket_launch',
      'models': [
        {'id': 'grok-4', 'name': 'Grok 4'},
        {'id': 'grok-4-1-fast', 'name': 'Grok 4.1 Fast'},
        {'id': 'grok-code-fast-1', 'name': 'Grok Code Fast 1'},
      ],
      'defaultModel': 'grok-4',
    },
    {
      'id': 'openrouter',
      'name': 'OpenRouter',
      'icon': 'hub',
      'models': [
        {'id': 'openai/gpt-oss-20b:free', 'name': 'GPT-OSS 20B Free'},
        {'id': 'openrouter/free', 'name': 'OpenRouter Free Router'},
        {'id': 'auto', 'name': 'OpenRouter Auto'},
        {'id': 'moonshotai/kimi-k2.6', 'name': 'Kimi K2.6'},
      ],
      'defaultModel': 'openai/gpt-oss-20b:free',
    },
    {
      'id': 'groq',
      'name': 'Groq',
      'icon': 'speed',
      'models': [
        {'id': 'llama-3.3-70b-versatile', 'name': 'Llama 3.3 70B'},
        {'id': 'llama-3.1-8b-instant', 'name': 'Llama 3.1 8B Instant'},
      ],
      'defaultModel': 'llama-3.3-70b-versatile',
    },
    {
      'id': 'zenmux',
      'name': 'Zenmux',
      'icon': 'public',
      'models': [
        {'id': 'z-ai/glm-5.2-free', 'name': 'GLM-5.2 Free'},
      ],
      'defaultModel': 'z-ai/glm-5.2-free',
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
          'export PATH=\$PATH:/usr/local/bin:/usr/bin && export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw onboard --help',
          timeout: 15);

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

  Future<void> _startOpenClawServices() async {
    try {
      _writeLog('\nChecking OpenClaw configuration...');

      final validateResult = await NativeBridge.runInProot(
          'export PATH=\$PATH:/usr/local/bin:/usr/bin && export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && (openclaw config --validate || openclaw doctor --fix)',
          timeout: 30);

      if (validateResult.contains('Invalid')) {
        _writeLog('\n⚠️ Configuration auto-fixed. Start may fail.');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Config auto-fixed – please restart if issues persist')),
        );
      }

      final configCheck = await NativeBridge.runInProot(
          'export PATH=\$PATH:/usr/local/bin:/usr/bin && export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw config --show',
          timeout: 5000);

      _writeLog('\nCurrent config: $configCheck');

      if (configCheck.contains('api-key')) {
        _writeLog('\n✅ API key found, starting OpenClaw CLI Gateway...');

        await NativeBridge.runInProot(
            'export PATH=\$PATH:/usr/local/bin:/usr/bin && export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && pkill -f "openclaw gateway" || true',
            timeout: 5000);

        final gatewayStarted = await NativeBridge.startGateway();

        if (gatewayStarted) {
          _writeLog('\n✅ OpenClaw CLI Gateway started successfully');
          _writeLog('\n🤖 OpenClaw Agent is now running 24/7');

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
        _writeLog(
            '\n❌ No API key configured. Please configure an API key first.');
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
    final gatewayProvider =
        Provider.of<GatewayProvider>(context, listen: false);
    gatewayProvider.checkHealth();
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

  Future<void> _processProviderSetup(String provider, String key,
      {String? modelId, String? modelName}) async {
    final gatewayProvider =
        Provider.of<GatewayProvider>(context, listen: false);

    _writeLog(
        '\n🔑 Configuring $provider API key and syncing to global .env...');
    await gatewayProvider.configureApiKey(provider, key);

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
        case 'zenmux':
          modelId = 'z-ai/glm-5.2-free';
          modelName = 'GLM-5.2 Free';
          break;
        default:
          modelId = 'default';
          modelName = 'Default Model';
      }
    }

    final openClawProvider = _toOpenClawProvider(provider);
    final primaryModel = '$openClawProvider/$modelId';

    _writeLog('\n📦 Saving model preference ($modelName)...');
    await gatewayProvider.persistModel(primaryModel);

    _writeLog('\n🔄 Triggering gateway hot-reload...');
    await NativeBridge.runInProot(
        'export PATH=\$PATH:/usr/local/bin:/usr/bin && export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw reload || true');

    _writeLog('✅ API key and model ($modelName) synced.');
  }

  String _toOpenClawProvider(String provider) {
    final p = provider.toLowerCase();
    if (p.contains('claude') || p.contains('anthropic')) return 'anthropic';
    if (p.contains('openrouter')) return 'openrouter';
    if (p.contains('openai')) return 'openai';
    if (p.contains('gemini') || p.contains('google')) return 'google';
    if (p.contains('groq')) return 'groq';
    if (p.contains('zenmux')) return 'zenmux';
    if (p.contains('ollama')) return 'google';
    return p;
  }

  Future<void> _executeProviderSetupUI(
      String provider, String key, String modelId, String modelName) async {
    try {
      await _processProviderSetup(provider, key,
          modelId: modelId, modelName: modelName);
      _writeLog('\n🚀 Starting OpenClaw services...');
      await _startOpenClawServices();
    } catch (e) {
      _writeLog('\n✗ Setup failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const NebulaBg(),
          Column(
            children: [
              // Blurred app bar
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: 56,
                        child: Row(
                          children: [
                            if (!widget.isFirstRun)
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_rounded,
                                    color: Colors.white70, size: 18),
                                onPressed: () => Navigator.of(context).pop(),
                              )
                            else
                              const SizedBox(width: 16),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                      'assets/app_icon_official.svg',
                                      width: 18,
                                      height: 18,
                                      colorFilter: const ColorFilter.mode(
                                          Colors.white, BlendMode.srcIn)),
                                  const SizedBox(width: 10),
                                  Text('OPENCLAW SETUP',
                                      style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          letterSpacing: 2.5,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Styled TabBar
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'TERMINAL'),
                    Tab(text: 'QUICK SETUP'),
                  ],
                  indicatorColor: AppColors.statusGreen,
                  indicatorWeight: 2,
                  labelColor: AppColors.statusGreen,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.5),
                  unselectedLabelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 1.5),
                ),
              ),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.statusGreen));
    }
    if (_error != null) {
      return Center(
          child: Text('Error: $_error',
              style: const TextStyle(color: Colors.white70)));
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTerminalTab(),
        _buildQuickSetupTab(),
      ],
    );
  }

  Widget _buildTerminalTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) => Text(
                  _logs[index],
                  style: GoogleFonts.jetBrainsMono(
                      color: AppColors.statusGreen, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSetupTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: _providers.map((p) => _buildProviderCard(p)).toList(),
    );
  }

  Widget _buildBadge(String id) {
    String text = 'VERIFIED';
    Color color = AppColors.statusGreen;
    switch (id) {
      case 'google':
        text = 'MOST SCALABLE';
        color = const Color(0xFF4285F4);
        break;
      case 'anthropic':
        text = 'BEST INTELLIGENCE';
        color = const Color(0xFFD97757);
        break;
      case 'openai':
        text = 'FASTEST RESPONSE';
        color = const Color(0xFF10A37F);
        break;
      case 'groq':
        text = 'ULTRA SPEED';
        color = const Color(0xFFF55036);
        break;
      case 'zenmux':
        text = 'FREE COMMUNITY';
        color = const Color(0xFF7C3AED);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    final id = provider['id'];
    _apiKeyControllers.putIfAbsent(id, () => TextEditingController());
    _selectedModels.putIfAbsent(id, () => provider['defaultModel']);
    final models = provider['models'] as List<Map<String, String>>;

    return GlassCard(
      blurStrength: 20,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.api, color: AppColors.statusGreen),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(provider['name'],
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Colors.white)),
                      _buildBadge(id),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyControllers[id],
              decoration: const InputDecoration(
                  hintText: 'Enter API Key', isDense: true),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final key = _apiKeyControllers[id]?.text.trim();
                  if (key == null || key.isEmpty) return;
                  final modelId = _selectedModels[id]!;
                  final modelName =
                      models.firstWhere((m) => m['id'] == modelId)['name']!;
                  _tabController.animateTo(0);
                  _executeProviderSetupUI(id, key, modelId, modelName);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusGreen,
                    foregroundColor: Colors.black),
                child: const Text('CONFIGURE & CONNECT',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
