import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import '../models/optional_package.dart';
import '../providers/setup_provider.dart';
import '../services/package_service.dart';
import '../services/preferences_service.dart';
import '../widgets/progress_step.dart';
import '../widgets/avatar_logo.dart';
import 'onboarding_screen.dart';
import 'package_install_screen.dart';
import 'dashboard_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen>
    with SingleTickerProviderStateMixin {
  bool _started = false;
  bool _didAutoNavigate = false;
  Map<String, bool> _pkgStatuses = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    // Preferences are now handled by services; no LLM config needed here
  }

  Future<void> _savePrefs() async {
    // Preferences are now handled by services; no LLM config needed here
  }

  Future<void> _refreshPkgStatuses() async {
    final statuses = await PackageService.checkAllStatuses();
    if (mounted) setState(() => _pkgStatuses = statuses);
  }

  Future<void> _installPackage(OptionalPackage package) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PackageInstallScreen(package: package),
      ),
    );
    if (result == true) _refreshPkgStatuses();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.darkBg,
                    AppColors.darkSurface,
                    AppColors.darkSurfaceAlt,
                  ]
                : [
                    AppColors.lightBg,
                    const Color(0xFFF8F9FA),
                    const Color(0xFFF1F3F4),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Consumer<SetupProvider>(
            builder: (context, provider, _) {
              final state = provider.state;

              // Load package statuses once setup completes
              if (state.isComplete && _pkgStatuses.isEmpty) {
                _refreshPkgStatuses();
              }

              if (state.isComplete && !_didAutoNavigate) {
                _didAutoNavigate = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 1500), () {
                    if (mounted) _goToApp(context);
                  });
                });
              }

              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        _buildPremiumHeader(isDark),
                        const SizedBox(height: 24),
                        _buildDescriptionSection(theme, isDark),
                        const SizedBox(height: 32),
                        Expanded(
                          child: _buildSteps(state, theme, isDark),
                        ),
                        if (state.hasError) ...[
                          _buildErrorSection(state, theme),
                          const SizedBox(height: 16),
                        ],
                        _buildActionButtons(provider, state, theme, isDark),
                        if (!_started) ...[
                          const SizedBox(height: 8),
                          _buildStorageInfo(theme),
                        ],
                        const SizedBox(height: 16),
                        _buildFooter(theme),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.darkSurface.withOpacity(0.8),
                  AppColors.darkSurfaceAlt.withOpacity(0.6),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  const Color(0xFFF8F9FA).withOpacity(0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
              ? AppColors.darkBorder.withOpacity(0.3)
              : AppColors.lightBorder.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          AvatarLogo(
            size: 80,
            animated: true,
            showGlow: true,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                        ? [AppColors.inverseText, AppColors.inverseText.withOpacity(0.8)]
                        : [AppColors.darkBg, AppColors.darkBg.withOpacity(0.8)],
                  ).createShader(bounds),
                  child: Text(
                    'Setup Clawa',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.inverseText : AppColors.darkBg,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConstants.appMotto,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark 
                        ? AppColors.inverseText.withOpacity(0.7)
                        : AppColors.darkBg.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark 
            ? AppColors.darkSurface.withOpacity(0.6)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? AppColors.darkBorder.withOpacity(0.2)
              : AppColors.lightBorder.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _started ? Icons.settings_suggest : Icons.info_outline,
            color: AppColors.statusGreen,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _started
                  ? 'Setting up the environment. This may take several minutes.'
                  : 'This will download Ubuntu, Node.js, and Clawa into a self-contained environment.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark 
                    ? AppColors.inverseText.withOpacity(0.9)
                    : AppColors.darkBg.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection(SetupState state, ThemeData theme) {
    final errorMessage = state.error ?? 'Unknown error occurred';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.errorContainer.withOpacity(0.8),
            theme.colorScheme.errorContainer.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Setup Error',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: errorMessage));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Error message copied to clipboard'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: Icon(
                  Icons.copy,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                tooltip: 'Copy error message',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.error.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                errorMessage,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    SetupProvider provider,
    SetupState state,
    ThemeData theme,
    bool isDark,
  ) {
    if (state.isComplete) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.statusGreen,
              AppColors.statusGreen.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.statusGreen.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _goToApp(context),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Continue to App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_started || state.hasError) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: provider.isRunning
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    isDark ? AppColors.darkBorder.withOpacity(0.8) : AppColors.lightBorder.withOpacity(0.8),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.statusGreen,
                    AppColors.statusGreen.withOpacity(0.8),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: provider.isRunning
              ? []
              : [
                  BoxShadow(
                    color: AppColors.statusGreen.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: provider.isRunning
                ? null
                : () async {
                    await _savePrefs();
                    setState(() => _started = true);
                    provider.runSetup();
                  },
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    provider.isRunning ? Icons.hourglass_empty : Icons.download,
                    color: provider.isRunning 
                        ? (isDark ? AppColors.inverseText.withOpacity(0.5) : AppColors.darkBg.withOpacity(0.5))
                        : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _started ? 'Retry Setup' : 'Begin Setup',
                    style: TextStyle(
                      color: provider.isRunning 
                          ? (isDark ? AppColors.inverseText.withOpacity(0.5) : AppColors.darkBg.withOpacity(0.5))
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStorageInfo(ThemeData theme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storage_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Requires ~500MB of storage and an internet connection',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Center(
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            AppColors.statusGreen.withOpacity(0.8),
            AppColors.statusGreen.withOpacity(0.4),
          ],
        ).createShader(bounds),
        child: Text(
          AppConstants.appMotto,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.statusGreen,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSteps(SetupState state, ThemeData theme, bool isDark) {
    final steps = [
      (1, 'Download Ubuntu rootfs', SetupStep.downloadingRootfs),
      (2, 'Extract rootfs', SetupStep.extractingRootfs),
      (3, 'Install Node.js', SetupStep.installingNode),
      (4, 'Install Clawa', SetupStep.installingOpenClaw),
      (5, 'Configure Bionic Bypass', SetupStep.configuringBypass),
    ];

    return ListView(
      children: [
        for (final (num, label, step) in steps)
          ProgressStep(
            stepNumber: num,
            label: state.step == step ? state.message : label,
            isActive: state.step == step,
            isComplete: state.stepNumber > step.index + 1 || state.isComplete,
            hasError: state.hasError && state.step == step,
            progress: state.step == step ? state.progress : null,
          ),
        if (state.isComplete) ...[
          ProgressStep(
            stepNumber: 6,
            label: 'Setup complete!',
            isComplete: true,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'OPTIONAL PACKAGES',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final pkg in OptionalPackage.all)
            _buildPackageTile(theme, pkg, isDark),
        ],
      ],
    );
  }

  Widget _buildPackageTile(ThemeData theme, OptionalPackage package, bool isDark) {
    final installed = _pkgStatuses[package.id] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.darkSurface.withOpacity(0.8),
                  AppColors.darkSurfaceAlt.withOpacity(0.6),
                ]
              : [
                  Colors.white.withOpacity(0.9),
                  const Color(0xFFF8F9FA).withOpacity(0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? AppColors.darkBorder.withOpacity(0.3)
              : AppColors.lightBorder.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: installed
                  ? [
                      AppColors.statusGreen.withOpacity(0.2),
                      AppColors.statusGreen.withOpacity(0.1),
                    ]
                  : [
                      isDark 
                          ? AppColors.darkSurfaceAlt.withOpacity(0.8)
                          : const Color(0xFFF1F3F4),
                      isDark 
                          ? AppColors.darkSurfaceAlt.withOpacity(0.6)
                          : const Color(0xFFE8EAED),
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: installed
                  ? AppColors.statusGreen.withOpacity(0.3)
                  : (isDark 
                      ? AppColors.darkBorder.withOpacity(0.2)
                      : AppColors.lightBorder.withOpacity(0.3)),
              width: 1,
            ),
          ),
          child: Icon(
            package.icon,
            color: installed 
                ? AppColors.statusGreen
                : (isDark 
                    ? AppColors.inverseText.withOpacity(0.7)
                    : AppColors.darkBg.withOpacity(0.7)),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                package.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.inverseText : AppColors.darkBg,
                  fontSize: 15,
                ),
              ),
            ),
            if (installed) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.statusGreen.withOpacity(0.2),
                      AppColors.statusGreen.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.statusGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Installed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.statusGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              package.description,
              style: TextStyle(
                color: isDark 
                    ? AppColors.inverseText.withOpacity(0.7)
                    : AppColors.darkBg.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              package.estimatedSize,
              style: TextStyle(
                color: isDark 
                    ? AppColors.inverseText.withOpacity(0.5)
                    : AppColors.darkBg.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: installed
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.statusGreen,
                  size: 20,
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.statusGreen.withOpacity(0.8),
                      AppColors.statusGreen.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.statusGreen.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _installPackage(package),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Install',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _goToApp(BuildContext context) async {
    final prefs = PreferencesService();
    await prefs.init();
    
    // If we have a dashboard URL, go to Dashboard
    // Otherwise go to Onboarding
    if (prefs.dashboardUrl != null && prefs.dashboardUrl!.isNotEmpty) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DashboardScreen()),
        );
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const OnboardingScreen(isFirstRun: true),
          ),
        );
      }
    }
  }
}
