import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import '../widgets/avatar_logo.dart';
import 'setup_wizard_screen.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';
import 'setup_flow_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _status = 'Initializing...';
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Epic animation controllers for 2026 feel
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create sophisticated animations
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOutCubic,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticOut,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start epic animation sequence
    _startEpicAnimation();
    _checkAndRoute();
  }

  void _startEpicAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRoute() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      setState(() => _status = 'Checking setup status...');

      final prefs = PreferencesService();
      await prefs.init();

      bool bootstrapOk = false;
      try {
        bootstrapOk = await NativeBridge.isBootstrapComplete();
      } catch (_) {}

      if (!mounted) return;

      final dashboardUrl = prefs.dashboardUrl;
      final isFullyConfigured = bootstrapOk && (
        (dashboardUrl != null && dashboardUrl.isNotEmpty) || prefs.apiKeyConfigured
      );

      if (isFullyConfigured) {
        prefs.setupComplete = true;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const DashboardScreen(),
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
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } else {
        // If bootstrap is complete, go to onboarding; otherwise go to setup
        Widget targetScreen;
        if (bootstrapOk) {
          targetScreen = const OnboardingScreen(isFirstRun: true);
        } else {
          targetScreen = const SetupWizardScreen();
        }
            
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
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
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [
                  const Color(0xFF000000),
                  const Color(0xFF0A0A0A),
                  const Color(0xFF141414),
                ]
              : [
                  const Color(0xFFFFFFFF),
                  const Color(0xFAFAFA),
                  const Color(0xFFF5F5F5),
                ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Epic logo container with metallic effect
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                        ? [
                            const Color(0xFF2A2A2A),
                            const Color(0xFF1A1A1A),
                            const Color(0xFF0A0A0A),
                          ]
                        : [
                            const Color(0xFFF0F0F0),
                            const Color(0xFFE0E0E0),
                            const Color(0xFFD0D0D0),
                          ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark 
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: isDark 
                          ? const Color(0xFF333333).withOpacity(0.2)
                          : const Color(0xFFCCCCCC).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(32),
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: AvatarLogo(
                      size: 100,
                      animated: true,
                      showGlow: true,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Epic title with gradient text
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark
                      ? [const Color(0xFFFFFFFF), const Color(0xFFCCCCCC)]
                      : [const Color(0xFF000000), const Color(0xFF666666)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'Clawa Pocket',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Subtitle with premium styling
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isDark 
                        ? const Color(0xFF1A1A1A).withOpacity(0.8)
                        : const Color(0xFFF0F0F0).withOpacity(0.8),
                      border: Border.all(
                        color: isDark 
                          ? const Color(0xFF333333)
                          : const Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      AppConstants.appMotto,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: isDark 
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Modern loading indicator
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? const Color(0xFF00C853) : const Color(0xFF00C853),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Status text with fade-in
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isDark 
                        ? const Color(0xFF1A1A1A).withOpacity(0.6)
                        : const Color(0xFFF5F5F5).withOpacity(0.8),
                      border: Border.all(
                        color: isDark 
                          ? const Color(0xFF333333).withOpacity(0.3)
                          : const Color(0xFFE0E0E0).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _status,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark 
                          ? const Color(0xFF999999)
                          : const Color(0xFF666666),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
