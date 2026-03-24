import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
                  const Color(0xFF0F0F0F),
                  const Color(0xFF1A1A1A),
                  const Color(0xFF252525),
                ]
              : [
                  const Color(0xFFF8F9FA),
                  const Color(0xFFF1F3F4),
                  const Color(0xFFE9ECEF),
                ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background elements
            Positioned.fill(
              child: _buildAnimatedBackground(isDark),
            ),
            
            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Liquid glass logo container
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: isDark 
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                        border: Border.all(
                          color: isDark 
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark 
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: isDark 
                              ? Colors.white.withOpacity(0.1)
                              : Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: -5,
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
                        child: SvgPicture.asset(
                          'assets/app_icon_official.svg',
                          width: 100,
                          height: 100,
                          colorFilter: ColorFilter.mode(
                            isDark ? Colors.white : Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Liquid glass title
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isDark 
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                        border: Border.all(
                          color: isDark 
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark 
                              ? Colors.black.withOpacity(0.2)
                              : Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: isDark
                            ? [const Color(0xFFFFFFFF), const Color(0xFFE0E0E0)]
                            : [const Color(0xFF000000), const Color(0xFF333333)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          'Plawie',
                          style: GoogleFonts.inter(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Liquid glass subtitle
                    SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isDark 
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.03),
                          border: Border.all(
                            color: isDark 
                              ? Colors.white.withOpacity(0.12)
                              : Colors.black.withOpacity(0.08),
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
                              ? const Color(0xFFE0E0E0)
                              : const Color(0xFF666666),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Modern glass loading indicator
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isDark 
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05),
                        border: Border.all(
                          color: isDark 
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark 
                              ? Colors.black.withOpacity(0.2)
                              : Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? const Color(0xFF00C853) : const Color(0xFF00C853),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Glass status text
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isDark 
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.03),
                          border: Border.all(
                            color: isDark 
                              ? Colors.white.withOpacity(0.12)
                              : Colors.black.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _status,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark 
                              ? const Color(0xFFE0E0E0)
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
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(bool isDark) {
    return Stack(
      children: [
        // Floating glass orbs
        Positioned(
          top: MediaQuery.of(context).size.height * 0.1,
          left: MediaQuery.of(context).size.width * 0.1,
          child: _buildFloatingOrb(isDark, 80, 0.3),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.7,
          right: MediaQuery.of(context).size.width * 0.15,
          child: _buildFloatingOrb(isDark, 60, 0.2),
        ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.2,
          left: MediaQuery.of(context).size.width * 0.2,
          child: _buildFloatingOrb(isDark, 100, 0.15),
        ),
      ],
    );
  }

  Widget _buildFloatingOrb(bool isDark, double size, double opacity) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isDark
                ? [
                    Colors.white.withOpacity(opacity * 0.3),
                    Colors.white.withOpacity(opacity * 0.1),
                    Colors.transparent,
                  ]
                : [
                    Colors.black.withOpacity(opacity * 0.2),
                    Colors.black.withOpacity(opacity * 0.05),
                    Colors.transparent,
                  ],
            ),
            boxShadow: [
              BoxShadow(
                color: isDark 
                  ? Colors.white.withOpacity(opacity * 0.2)
                  : Colors.black.withOpacity(opacity * 0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
        );
      },
    );
  }
}
