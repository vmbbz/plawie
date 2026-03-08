import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gateway_provider.dart';
import '../models/gateway_state.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import 'dashboard_screen.dart';

/// Modern Material 3 setup wizard — replaces the old terminal onboarding.
/// 5 steps: Choose Provider → Enter API Key → Name Agent → Settings → Launch
class SetupFlowScreen extends StatefulWidget {
  const SetupFlowScreen({super.key});

  @override
  State<SetupFlowScreen> createState() => _SetupFlowScreenState();
}

class _SetupFlowScreenState extends State<SetupFlowScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isProcessing = false;
  String? _error;

  // Step 1: Provider
  String? _selectedProvider;

  // Step 2: API Key
  final _apiKeyController = TextEditingController();
  bool _apiKeyObscured = true;

  // Step 3: Agent Name
  final _agentNameController = TextEditingController(text: 'Clawa');

  // Step 5: Launch status
  String _launchStatus = '';
  double _launchProgress = 0.0;
  bool _launchComplete = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  static const _providers = [
    _ProviderInfo(
      id: 'ANTHROPIC_API_KEY',
      name: 'Claude',
      subtitle: 'by Anthropic',
      icon: Icons.auto_awesome,
      color: Color(0xFFD97706),
      hint: 'sk-ant-api03-...',
      prefix: 'sk-ant-',
      defaultModel: 'anthropic/claude-opus-4-6',
    ),
    _ProviderInfo(
      id: 'GEMINI_API_KEY',
      name: 'Gemini',
      subtitle: 'by Google',
      icon: Icons.diamond_outlined,
      color: Color(0xFF4285F4),
      hint: 'AIzaSy...',
      prefix: 'AIza',
      defaultModel: 'google/gemini-3.1-pro-preview',
    ),
    _ProviderInfo(
      id: 'OPENAI_API_KEY',
      name: 'OpenAI',
      subtitle: 'GPT-4 / GPT-4o',
      icon: Icons.psychology,
      color: Color(0xFF10A37F),
      hint: 'sk-proj-...',
      prefix: 'sk-',
      defaultModel: 'openai/gpt-4o',
    ),
    _ProviderInfo(
      id: 'GROQ_API_KEY',
      name: 'Groq',
      subtitle: 'Lightning fast',
      icon: Icons.bolt,
      color: Color(0xFFF55036),
      hint: 'gsk_...',
      prefix: 'gsk_',
      defaultModel: 'groq/llama-3.1-405b',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _apiKeyController.dispose();
    _agentNameController.dispose();
    super.dispose();
  }

  _ProviderInfo? get _activeProvider {
    if (_selectedProvider == null) return null;
    return _providers.firstWhere((p) => p.id == _selectedProvider);
  }

  void _goToStep(int step) {
    _fadeController.reverse().then((_) {
      setState(() {
        _currentStep = step;
        _error = null;
      });
      _fadeController.forward();
    });
  }

  void _nextStep() => _goToStep(_currentStep + 1);
  void _prevStep() => _goToStep(_currentStep - 1);

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _selectedProvider != null;
      case 1:
        return _apiKeyController.text.trim().length >= 8;
      case 2:
        return _agentNameController.text.trim().isNotEmpty;
      case 3:
        return true; // Settings always valid
      case 4:
        return _launchComplete;
      default:
        return false;
    }
  }

  Future<void> _launchGateway() async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _launchStatus = 'Saving API key...';
      _launchProgress = 0.3;
    });

    try {
      final gatewayProvider = Provider.of<GatewayProvider>(context, listen: false);

      // World-Class Stability: Ensure config is healthy before writing keys
      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && openclaw doctor --fix',
        timeout: 10000
      );

      await gatewayProvider.configureAndStart(
        provider: _selectedProvider!,
        apiKey: _apiKeyController.text.trim(),
        agentName: _agentNameController.text.trim(),
      );


      setState(() {
        _launchStatus = 'Starting gateway...';
        _launchProgress = 0.7;
      });

      // Short safe wait (matches the working commit)
      await Future.delayed(const Duration(seconds: 3));

      setState(() {
        _launchProgress = 1.0;
        _launchStatus = 'Gateway is running!';
        _launchComplete = true;
        _isProcessing = false;
      });

      final prefs = PreferencesService();
      await prefs.init();
      prefs.apiKeyConfigured = true;
      prefs.setupComplete = true;
      prefs.isFirstRun = false;
      prefs.autoStartGateway = true;

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Setup failed: \$e';
        _launchStatus = 'Failed';
      });
    }
  }


  void _goToDashboard() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(theme, isDark),

            // Step indicator
            _buildStepIndicator(theme, isDark),

            const SizedBox(height: 8),

            // Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildStepContent(theme, isDark),
              ),
            ),

            // Error banner
            if (_error != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: theme.colorScheme.error.withAlpha(25),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom navigation
            _buildBottomNav(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          // Logo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00C853),
                  const Color(0xFF00C853).withAlpha(180),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C853).withAlpha(60),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clawa Setup',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _stepTitles[_currentStep],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Skip button (only before launch)
          if (_currentStep < 4)
            TextButton(
              onPressed: _goToDashboard,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _stepTitles = [
    'Choose your AI model',
    'Enter your API key',
    'Name your agent',
    'Quick settings',
    'Launching gateway',
  ];

  Widget _buildStepIndicator(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(5, (index) {
          final isActive = index == _currentStep;
          final isPast = index < _currentStep;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isPast
                    ? const Color(0xFF00C853)
                    : isActive
                        ? const Color(0xFF00C853).withAlpha(180)
                        : (isDark
                            ? Colors.white.withAlpha(20)
                            : Colors.black.withAlpha(20)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(ThemeData theme, bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildProviderStep(theme, isDark);
      case 1:
        return _buildApiKeyStep(theme, isDark);
      case 2:
        return _buildAgentNameStep(theme, isDark);
      case 3:
        return _buildSettingsStep(theme, isDark);
      case 4:
        return _buildLaunchStep(theme, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Choose Provider ──────────────────────────────────────

  Widget _buildProviderStep(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text(
          'Which AI would you like to use?',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        ..._providers.map((p) => _buildProviderCard(p, theme, isDark)),
      ],
    );
  }

  Widget _buildProviderCard(
      _ProviderInfo provider, ThemeData theme, bool isDark) {
    final isSelected = _selectedProvider == provider.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedProvider = provider.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? provider.color.withAlpha(isDark ? 25 : 15)
              : (isDark
                  ? Colors.white.withAlpha(8)
                  : Colors.black.withAlpha(8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? provider.color.withAlpha(150)
                : (isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(15)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Provider icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: provider.color.withAlpha(isDark ? 40 : 25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(provider.icon, color: provider.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    provider.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? provider.color : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? provider.color
                      : theme.colorScheme.onSurfaceVariant.withAlpha(80),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 2: API Key Input ────────────────────────────────────────

  Widget _buildApiKeyStep(ThemeData theme, bool isDark) {
    final provider = _activeProvider;
    if (provider == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        // Provider badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: provider.color.withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(provider.icon, color: provider.color, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    provider.name,
                    style: TextStyle(
                      color: provider.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Enter your ${provider.name} API key',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your key is stored locally on your device and never shared.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _apiKeyController,
          obscureText: _apiKeyObscured,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          decoration: InputDecoration(
            hintText: provider.hint,
            hintStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
            ),
            prefixIcon: Icon(Icons.key, color: provider.color, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _apiKeyObscured ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _apiKeyObscured = !_apiKeyObscured),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Key format hint
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(8)
                : Colors.black.withAlpha(5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(10)
                  : Colors.black.withAlpha(8),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Keys typically start with "${provider.prefix}"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 3: Agent Name ───────────────────────────────────────────

  Widget _buildAgentNameStep(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text(
          'What should your AI agent be called?',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This name will appear in conversations and notifications.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _agentNameController,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. Clawa, Jarvis, Friday...',
            prefixIcon: const Icon(Icons.smart_toy_outlined, size: 22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Suggestion chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Clawa', 'Atlas', 'Nova', 'Sage', 'Echo']
              .map(
                (name) => ActionChip(
                  label: Text(name),
                  onPressed: () {
                    _agentNameController.text = name;
                    setState(() {});
                  },
                  backgroundColor: _agentNameController.text == name
                      ? const Color(0xFF00C853).withAlpha(30)
                      : null,
                  side: BorderSide(
                    color: _agentNameController.text == name
                        ? const Color(0xFF00C853).withAlpha(120)
                        : theme.colorScheme.outline.withAlpha(60),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ─── Step 4: Settings ─────────────────────────────────────────────

  Widget _buildSettingsStep(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text(
          'Final touches',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'These can be changed later in Settings.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _buildSettingTile(
          theme: theme,
          isDark: isDark,
          icon: Icons.play_circle_outline,
          title: 'Auto-start gateway',
          subtitle: 'Start the AI gateway when app opens',
          value: true,
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        _buildSettingTile(
          theme: theme,
          isDark: isDark,
          icon: Icons.battery_saver,
          title: 'Battery optimization',
          subtitle: 'Disable to keep gateway alive in background',
          value: false,
          onChanged: (_) async {
            try {
              await NativeBridge.requestBatteryOptimization();
            } catch (_) {}
          },
          isAction: true,
        ),
        const SizedBox(height: 24),
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withAlpha(isDark ? 15 : 10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF00C853).withAlpha(40),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF00C853), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Ready to launch',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF00C853),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                theme, '${_activeProvider?.name}'),
              _buildSummaryRow(
                theme, 'Agent: ${_agentNameController.text.trim()}'),
              _buildSummaryRow(
                theme, 'Gateway: 127.0.0.1:18789 (auto-configured)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: 26),
          Icon(Icons.chevron_right,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isAction = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(12)
              : Colors.black.withAlpha(8),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (isAction)
            FilledButton.tonal(
              onPressed: () => onChanged(true),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Configure'),
            )
          else
            Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ─── Step 5: Launch ───────────────────────────────────────────────

  Widget _buildLaunchStep(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _launchComplete
                  ? Container(
                      key: const ValueKey('done'),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00C853),
                            const Color(0xFF00C853).withAlpha(180),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C853).withAlpha(80),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 40),
                    )
                  : Container(
                      key: const ValueKey('loading'),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withAlpha(8)
                            : Colors.black.withAlpha(5),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
            ),
            const SizedBox(height: 32),
            Text(
              _launchComplete ? 'You\'re all set!' : 'Setting up...',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _launchStatus,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Progress bar
            if (!_launchComplete)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _launchProgress,
                  minHeight: 4,
                  backgroundColor: isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.black.withAlpha(10),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00C853)),
                ),
              ),
            if (_launchComplete) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _goToDashboard,
                icon: const Icon(Icons.dashboard_outlined, size: 20),
                label: const Text('Open Dashboard'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Bottom Navigation ────────────────────────────────────────────

  Widget _buildBottomNav(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(10)
                : Colors.black.withAlpha(8),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          if (_currentStep > 0 && _currentStep < 4)
            TextButton.icon(
              onPressed: _prevStep,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            const SizedBox(width: 80),

          const Spacer(),

          // Next / Launch button
          if (_currentStep < 3)
            FilledButton(
              onPressed: _canProceed ? _nextStep : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Continue',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            )
          else if (_currentStep == 3)
            FilledButton.icon(
              onPressed: () {
                _nextStep();
                // Auto-launch after animation
                Future.delayed(
                    const Duration(milliseconds: 500), _launchGateway);
              },
              icon: const Icon(Icons.rocket_launch, size: 18),
              label: const Text('Launch Gateway',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            )
          else if (_currentStep == 4 && _launchComplete)
            const SizedBox.shrink() // Dashboard button is in the launch step
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// ─── Provider Info Model ──────────────────────────────────────────────

class _ProviderInfo {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String hint;
  final String prefix;
  final String defaultModel;

  const _ProviderInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.hint,
    required this.prefix,
    required this.defaultModel,
  });
}
