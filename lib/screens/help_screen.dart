import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import '../app.dart';
import '../widgets/glass_card.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const NebulaBg(),
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
                      const SizedBox(height: 28),

                      _buildFlagshipCard(context),
                      const SizedBox(height: 40),

                      _buildSectionHeader('The Core Foundation'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Ubuntu PRoot Sandbox',
                        description: 'We bundle a complete Linux userland inside the APK. The OpenClaw Node.js execution environment runs securely within PRoot on your processor — no root access required.',
                        icon: Icons.terminal_rounded,
                        color: AppColors.statusAmber,
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Industrial Background Stability',
                        description: 'The PlawieForegroundService runs as a sticky Android service with partial CPU WakeLocks. A watchdog monitors the OpenClaw gateway every 30 seconds and self-heals across background pruning.',
                        icon: Icons.security_rounded,
                        color: AppColors.statusGreen,
                      ),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader('Native Integrations'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Web3 & Solana Identity',
                        description: 'Real Ed25519 keypairs are generated and protected in secure on-device storage. Transactions are constructed and signed locally without cloud intermediaries.',
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF9945FF),
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Procedural XR Engine',
                        description: 'Our WebGL-based VRM avatars are driven by a mathematical engine. Independent neck and eye-tracking using sum-of-sines algorithms create hyper-realistic saccades driven by real-time TTS events.',
                        icon: Icons.architecture_rounded,
                        color: Colors.cyanAccent,
                      ),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader('Advanced Extensibility'),
                      const SizedBox(height: 16),
                      _buildMoonPayCard(context),

                      const SizedBox(height: 12),
                      _buildPremiumSkillsTable(context),
                      
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
      expandedHeight: 100,
      floating: false,
      pinned: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/app_icon_official.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Text(
            'ARCHITECTURE',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 3.0,
            ),
          ),
        ],
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: FlexibleSpaceBar(
            background: Container(color: Colors.black.withValues(alpha: 0.2)),
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
          'Your Pocket\nOpenClaw Companion',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A top 1% engineering achievement embedding a strict Ubuntu + Node.js OpenClaw execution environment running entirely within a sandboxed layer directly on your phone.',
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFlagshipCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      accentColor: AppColors.statusGreen, // Added accent color
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_system_daydream_rounded, color: AppColors.statusGreen, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.statusGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        'CORE ARCHITECTURE',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: AppColors.statusGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Local Execution Engine',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'This architecture operates entirely independent of cloud boundaries. The on-device PRoot gateway uses WebSockets and native MethodChannels (bionic-bypass.js) to manage complex tool-calling natively across local Android services.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFlagshipPill(Icons.memory_rounded, 'Snapdragon Optimized', AppColors.statusGreen),
              _buildFlagshipPill(Icons.bolt_rounded, 'Fully Local', AppColors.statusAmber),
              _buildFlagshipPill(Icons.terminal_rounded, 'Native PRoot', Colors.blueAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlagshipPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context, {required String title, required String description, required IconData icon, Color color = Colors.white}) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      accentColor: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoonPayCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.currency_exchange_rounded, color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('MCP SERVER SKILL',
                          style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 6),
                    Text('MoonPay Banking',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '@moonpay/cli seamlessly provisions verified bank accounts inside the OpenClaw gateway context. Support includes cross-chain bridges, token swaps, and dollar-cost algorithmic routing.',
            style: GoogleFonts.outfit(
                color: Colors.white70, fontSize: 12, height: 1.55),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Swap', 'Bridge', 'Fiat Onramps', 'DCA Algorithms', 'Market APIs',
            ].map((label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSkillsTable(BuildContext context) {
    final skills = [
      (Icons.account_balance_wallet_rounded, 'AgentCard', 'Virtual Visa + Base execution'),
      (Icons.work_rounded, 'MoltLaunch', 'On-chain AI jobs via ERC-8004 identity'),
      (Icons.memory_rounded, 'Local LLM', 'Llama Qwen support without cloud egress'),
      (Icons.phone_in_talk_rounded, 'Twilio AI', 'Inbound & outbound voice via ConversationRelay'),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CORE MCP INTEGRATIONS',
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white54)),
          const SizedBox(height: 16),
          ...skills.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(s.$1, size: 16, color: Colors.white70),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$2,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(s.$3,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
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
            _buildSupportButton(
              context, 'Explore Git Source', 'https://github.com/vmbbz/plawie', Icons.code_rounded),
            const SizedBox(width: 32),
            _buildSupportButton(
              context, 'Join Discord', 'https://discord.gg/openclaw', Icons.forum_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildSupportButton(BuildContext context, String label, String url, IconData icon) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
