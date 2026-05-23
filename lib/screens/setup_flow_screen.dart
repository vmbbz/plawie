import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart';
import '../constants.dart';
import '../services/native_bridge.dart';
import '../services/model_provider_catalog.dart';
import '../services/preferences_service.dart';
import 'setup_wizard_screen.dart';

/// Pre-install info collector — shown BEFORE SetupWizardScreen.
/// Collects provider, API key, agent name, and settings, then saves them to
/// prefs so BootstrapService can bake credentials into the gateway config
/// before the first start (no post-start reload needed).
///
/// Steps: Choose Provider → Enter API Key → Name Agent → Settings → Start
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

  // Step 0: Provider
  String? _selectedProvider;

  // Step 1: API Key
  final _apiKeyController = TextEditingController();
  bool _apiKeyObscured = true;

  // Step 2: Agent Name
  final _agentNameController = TextEditingController(text: 'Plawie');

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  static const _providers = [
    _ProviderInfo(
      id: 'anthropic',
      name: 'Claude',
      subtitle: 'by Anthropic',
      icon: Icons.auto_awesome,
      color: Color(0xFFD97706),
      hint: 'sk-ant-api03-...',
      prefix: 'sk-ant-',
      defaultModel: 'anthropic/claude-opus-4-6',
      requiresApiKey: true,
    ),
    _ProviderInfo(
      id: 'google',
      name: 'Gemini',
      subtitle: 'by Google',
      icon: Icons.diamond_outlined,
      color: Color(0xFF4285F4),
      hint: 'AIzaSy...',
      prefix: 'AIza',
      defaultModel: 'google/gemini-3.1-pro-preview',
      requiresApiKey: true,
    ),
    _ProviderInfo(
      id: 'openai',
      name: 'OpenAI',
      subtitle: 'GPT models',
      icon: Icons.psychology,
      color: Color(0xFF10A37F),
      hint: 'sk-proj-...',
      prefix: 'sk-',
      defaultModel: 'openai/gpt-5.4',
      requiresApiKey: true,
    ),
    _ProviderInfo(
      id: 'xai',
      name: 'Grok',
      subtitle: 'by xAI',
      icon: Icons.rocket_launch_rounded,
      color: Color(0xFFE0E0E0),
      hint: 'xai-...',
      prefix: 'xai-',
      defaultModel: 'xai/grok-4',
      requiresApiKey: true,
    ),
    _ProviderInfo(
      id: 'groq',
      name: 'Groq',
      subtitle: 'Lightning fast',
      icon: Icons.bolt,
      color: Color(0xFFF55036),
      hint: 'gsk_...',
      prefix: 'gsk_',
      defaultModel: 'groq/llama-3.3-70b-versatile',
      requiresApiKey: true,
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
        if (_activeProvider?.requiresApiKey == false) return true;
        return _apiKeyController.text.trim().length >= 8;
      case 2:
        return _agentNameController.text.trim().isNotEmpty;
      case 3:
        return true;
      default:
        return false;
    }
  }

  /// Saves credentials to prefs and navigates to SetupWizardScreen.
  /// BootstrapService reads these prefs and bakes them into the gateway config
  /// BEFORE the first start, so no post-start reload is ever needed.
  Future<void> _startInstallation() async {
    setState(() => _isProcessing = true);
    try {
      final prefs = PreferencesService();
      await prefs.init();

      if (_selectedProvider != null) {
        final activeProvider = _activeProvider!;
        final apiProvider =
            ModelProviderCatalog.apiProviderForSetupId(activeProvider.id);
        final setupModel =
            ModelProviderCatalog.setupSafeModelForProvider(activeProvider.id);
        prefs.pendingProvider = activeProvider.id;
        prefs.apiProvider = apiProvider;
        prefs.configuredModel = setupModel;
      }
      final key = _apiKeyController.text.trim();
      if (key.isNotEmpty && _activeProvider?.requiresApiKey != false) {
        prefs.pendingApiKey = key;
      }
      prefs.agentName = _agentNameController.text.trim();
      prefs.isFirstRun = false;

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SetupWizardScreen(),
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
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Failed to save settings: $e';
      });
    }
  }

  /// Skip provider setup — start installation without pre-configured credentials.
  /// User can configure their API key later from Settings.
  void _skipToInstallation() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SetupWizardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
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
            _buildHeader(theme, isDark),
            _buildStepIndicator(theme, isDark),
            const SizedBox(height: 8),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildStepContent(theme, isDark),
              ),
            ),
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/app_icon_official.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.statusGreen,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plawie',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _stepTitles[_currentStep],
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_currentStep < 3)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(50),
                  width: 1,
                ),
              ),
              child: TextButton(
                onPressed: _isProcessing ? null : _skipToInstallation,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                    fontSize: 13,
                  ),
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
  ];

  Widget _buildStepIndicator(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index == _currentStep;
          final isPast = index < _currentStep;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isPast
                    ? AppColors.statusGreen
                    : isActive
                        ? AppColors.statusGreen.withAlpha(180)
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
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 0: Choose Provider ──────────────────────────────────────

  Widget _buildProviderStep(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text(
          'Which AI would you like to use?',
          style: GoogleFonts.outfit(
            fontSize: 18,
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose the cloud provider for OpenClaw Gateway mode. Offline NDK models are set up later from Local LLM and never require an API key.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.1),
                  width: 1,
                ),
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
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? provider.color
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05)),
                border: Border.all(
                  color: isSelected
                      ? provider.color
                      : theme.colorScheme.onSurfaceVariant.withAlpha(80),
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: provider.color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
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

  // ─── Step 1: API Key ──────────────────────────────────────────────

  Widget _buildApiKeyStep(ThemeData theme, bool isDark) {
    final provider = _activeProvider;
    if (provider == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: provider.color.withAlpha(isDark ? 40 : 25),
                ),
                child: Icon(provider.icon, color: provider.color, size: 16),
              ),
              const SizedBox(width: 8),
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
        const SizedBox(height: 24),
        if (!provider.requiresApiKey) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: provider.color.withAlpha(isDark ? 20 : 15),
              border: Border.all(
                color: provider.color.withAlpha(50),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(provider.icon, color: provider.color, size: 48),
                const SizedBox(height: 16),
                Text(
                  'No API key needed',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Plawie will boot the Gateway first. Private offline models can be downloaded later from Local LLM and do not require a provider key.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            'Enter your ${provider.name} API key',
            style:
                GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Stored locally on your device and baked directly into the gateway config — never sent anywhere.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _apiKeyController,
              obscureText: _apiKeyObscured,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: provider.hint,
                hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                ),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.statusGreen.withAlpha(40),
                  ),
                  child:
                      Icon(Icons.key, color: AppColors.statusGreen, size: 20),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _apiKeyObscured ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      setState(() => _apiKeyObscured = !_apiKeyObscured),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.03),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
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
      ],
    );
  }

  // ─── Step 2: Agent Name ───────────────────────────────────────────

  Widget _buildAgentNameStep(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text(
          'What should your AI agent be called?',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
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
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. Plawie, Jarvis, Nova...',
            prefixIcon: const Icon(Icons.smart_toy_outlined,
                size: 22, color: AppColors.statusGreen),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.colorScheme.outline.withAlpha(80)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.statusGreen, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Plawie', 'Atlas', 'Nova', 'Sage', 'Echo']
              .map(
                (name) => ActionChip(
                  label: Text(
                    name,
                    style: TextStyle(
                      color: _agentNameController.text == name
                          ? AppColors.statusGreen
                          : theme.colorScheme.onSurface,
                      fontWeight: _agentNameController.text == name
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () {
                    _agentNameController.text = name;
                    setState(() {});
                  },
                  backgroundColor: _agentNameController.text == name
                      ? AppColors.statusGreen.withValues(alpha: 0.08)
                      : Colors.transparent,
                  side: BorderSide(
                    color: _agentNameController.text == name
                        ? AppColors.statusGreen.withAlpha(150)
                        : theme.colorScheme.outline.withAlpha(40),
                    width: _agentNameController.text == name ? 1.2 : 1,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  // ─── Step 3: Settings ─────────────────────────────────────────────

  Widget _buildSettingsStep(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Text(
          'Final touches',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600),
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
        const SizedBox(height: 12),
        _buildSettingTile(
          theme: theme,
          isDark: isDark,
          icon: Icons.security_outlined,
          title: 'Advanced Onboarding',
          subtitle: 'Use SecretRef for secure key handling',
          value: true,
          onChanged: (_) {},
        ),
        const SizedBox(height: 24),
        // Pre-install summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.statusGreen.withAlpha(isDark ? 15 : 10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.statusGreen.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_launch,
                      color: AppColors.statusGreen, size: 16),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.statusGreen.withAlpha(60)),
                    ),
                    child: Text(
                      'READY TO INSTALL',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: AppColors.statusGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSummaryRow(
                  theme, _activeProvider?.name ?? 'No provider selected'),
              _buildSummaryRow(
                  theme, 'Agent: ${_agentNameController.text.trim()}'),
              _buildSummaryRow(
                  theme, 'Gateway: 127.0.0.1:18789 (auto-configured)'),
              const SizedBox(height: 8),
              Text(
                'Credentials will be baked into the gateway config before it starts — no reload, no disruption.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.statusGreen.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
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
        color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.statusGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.statusGreen,
              activeTrackColor: AppColors.statusGreen.withValues(alpha: 0.3),
            ),
        ],
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
            color:
                isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _isProcessing ? null : _prevStep,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            const SizedBox(width: 80),
          const Spacer(),
          if (_currentStep < 3)
            FilledButton(
              onPressed: _canProceed ? _nextStep : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Continue',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: Colors.white),
                ],
              ),
            )
          else
            FilledButton.icon(
              onPressed: _isProcessing ? null : _startInstallation,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download_rounded,
                      size: 18, color: Colors.white),
              label: Text(
                _isProcessing ? 'Starting...' : 'Start Installation',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
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
  final bool requiresApiKey;

  const _ProviderInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.hint,
    required this.prefix,
    required this.defaultModel,
    required this.requiresApiKey,
  });
}
