import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../app.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Ambient Background Glow
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.statusGreen.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.statusGreen.withValues(alpha: 0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPitchHeader(context),
                      const SizedBox(height: 40),
                      
                      _buildSectionHeader('Your Pocket AI Power'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Always-On Intelligence',
                        description: 'Your bot never sleeps. It runs in the background 24/7, ready to help even if the app is closed.',
                        icon: Icons.auto_awesome_rounded,
                        gradient: [Colors.blueAccent, Colors.cyanAccent],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Talk Like a Human',
                        description: 'Use the floating mic to speak naturally. Your companion understands and acts on your voice commands.',
                        icon: Icons.record_voice_over_rounded,
                        gradient: [Colors.orangeAccent, Colors.redAccent],
                      ),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader('Professional Upgrades'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Web3 & Financials',
                        description: 'Manage money, swap tokens, and issue virtual cards. No bank account or complex tech skills needed.',
                        icon: Icons.account_balance_wallet_rounded,
                        gradient: [Colors.purpleAccent, Colors.deepPurpleAccent],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Auto-Work & Calls',
                        description: 'Your bot can handle phone calls, sms, and on-chain jobs while you focus on what matters.',
                        icon: Icons.work_history_rounded,
                        gradient: [Colors.tealAccent, Colors.lightGreenAccent],
                      ),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader('Total Control'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Notifications & Safety',
                        description: 'Control your bot directly from your phone notifications. Stop or restart with a single tap.',
                        icon: Icons.notifications_active_rounded,
                        gradient: [Colors.pinkAccent, Colors.redAccent],
                      ),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader('Under the Hood'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Private Linux Server',
                        description: 'Your phone runs a real Linux environment with its own AI server. No cloud, no middleman — your data never leaves this device.',
                        icon: Icons.dns_rounded,
                        gradient: [const Color(0xFF6C63FF), const Color(0xFF3F3D99)],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Self-Healing Background',
                        description: 'A watchdog monitors your AI server every 30 seconds. If anything goes wrong, it auto-restarts — even if you swipe the app closed.',
                        icon: Icons.security_rounded,
                        gradient: [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Multi-Model Intelligence',
                        description: 'Switch between Gemini, Claude, GPT and more. Your server orchestrates any AI model, running conversations locally through industry-standard protocols.',
                        icon: Icons.hub_rounded,
                        gradient: [const Color(0xFFE76F51), const Color(0xFFF4A261)],
                      ),
                      
                      const SizedBox(height: 40),
                      _buildSupportLinks(context),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0D1B2A).withValues(alpha: 0.8),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: FlexibleSpaceBar(
            centerTitle: true,
            title: Text(
              'HELP CENTER',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 4,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            background: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Hero(
                  tag: 'app_logo',
                  child: SvgPicture.asset(
                    'assets/app_icon_official.svg',
                    width: 70,
                    height: 70,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPitchHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Master Your Reality.',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Plawie is the first 100% private, autonomous AI companion that lives entirely on your phone. No servers, no spying—just pure intelligence at your fingertips.',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: AppColors.statusGreen.withValues(alpha: 0.8),
      ),
    );
  }

  Widget _buildHelpCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {}, 
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                   Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: gradient[0].withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportLinks(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSupportButton(context, 'Explore Code', 'https://github.com/vmbbz/plawie'),
            const SizedBox(width: 32),
            _buildSupportButton(context, 'Join Discord', 'https://discord.gg/openclaw'),
          ],
        ),
      ],
    );
  }

  Widget _buildSupportButton(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 1,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
