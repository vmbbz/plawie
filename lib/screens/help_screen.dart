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
                      const SizedBox(height: 28),

                      // ═══ #1 FLAGSHIP HERO CARD — OpenClaw on your phone ═══
                      _buildFlagshipCard(context),
                      const SizedBox(height: 40),

                      _buildSectionHeader('Your Pocket AI Power'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Always-On Intelligence',
                        description: 'Your OpenClaw gateway runs 24/7 in the background, even when the app is closed. Your AI is always standing by.',
                        icon: Icons.auto_awesome_rounded,
                        gradient: [Colors.blueAccent, Colors.cyanAccent],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Talk Like a Human',
                        description: 'Use the floating mic to speak naturally. Your companion understands context and acts on your voice commands in real time.',
                        icon: Icons.record_voice_over_rounded,
                        gradient: [Colors.orangeAccent, Colors.redAccent],
                      ),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader('Professional Upgrades'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Web3 & Financials',
                        description: 'Manage money, swap tokens, and issue virtual cards. No bank account or complex tech skills needed — your agent handles it.',
                        icon: Icons.account_balance_wallet_rounded,
                        gradient: [Colors.purpleAccent, Colors.deepPurpleAccent],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Auto-Work & Calls',
                        description: 'Your bot handles phone calls, SMS, and on-chain jobs while you stay focused on what matters most.',
                        icon: Icons.work_history_rounded,
                        gradient: [Colors.tealAccent, Colors.lightGreenAccent],
                      ),
                      const SizedBox(height: 12),
                      _buildMoonPayCard(context),

                      const SizedBox(height: 24),
                      _buildPremiumSkillsTable(context),

                      const SizedBox(height: 32),
                      _buildSectionHeader('Total Control'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Command from Notifications',
                        description: 'Stop or restart your gateway directly from the notification shade. Full control without opening the app.',
                        icon: Icons.notifications_active_rounded,
                        gradient: [Colors.pinkAccent, Colors.redAccent],
                      ),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader('Under the Hood'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Self-Healing Background Service',
                        description: 'A watchdog checks your AI server every 30 seconds. If anything goes wrong, it auto-restarts — even after you swipe the app away.',
                        icon: Icons.security_rounded,
                        gradient: [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Multi-Model Intelligence',
                        description: 'Switch between Gemini, Claude, GPT-4o and more. Your gateway orchestrates any AI model through industry-standard protocols.',
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
          'Your Phone.\nYour AI. Your Rules.',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Plawie is the first app to run a complete OpenClaw AI gateway directly on your Android — no cloud, no server fees, total privacy.',
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// The #1 flagship selling point card — full OpenClaw gateway running on-device.
  /// Based on ARCHITECTURE_REPORT.md: "No known production app ships a bundled
  /// Linux rootfs + PRoot + Node.js + AI gateway inside a single Flutter APK."
  Widget _buildFlagshipCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3D2B), Color(0xFF0D2A40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.statusGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.statusGreen.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.statusGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.statusGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppColors.statusGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.statusGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'WORLD FIRST',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppColors.statusGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OpenClaw AI — On Your Phone',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
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
              'Plawie embeds a full OpenClaw AI gateway — the same server-grade intelligence used by enterprises — directly inside this APK. It runs inside a real Linux environment on your phone via PRoot. No root access. No subscription. No internet required.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFlagshipPill('🔒 100% Private'),
                _buildFlagshipPill('⚡ No Cloud'),
                _buildFlagshipPill('🐧 Real Linux'),
                _buildFlagshipPill('📦 One APK'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagshipPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
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

  Widget _buildMoonPayCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1060), Color(0xFF0A1F3C)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF7B2FBE).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2FBE).withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2FBE).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.currency_exchange_rounded,
                    color: Color(0xFF9B6FDE), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2FBE).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('NEW — MCP SKILL',
                          style: TextStyle(color: Color(0xFF9B6FDE), fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    Text('Agent Banking via MoonPay',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Give your AI a verified bank account. MoonPay Agents connects your OpenClaw agent to 30+ financial skills — swap tokens, bridge cross-chain, buy/sell crypto via fiat, and run DCA strategies — all from natural language in chat.',
            style: GoogleFonts.outfit(
                color: Colors.white70, fontSize: 13, height: 1.55),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              '💱 Swap', '🌉 Bridge', '💵 Buy/Sell', '📊 DCA', '📈 Live Prices',
            ].map((label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2FBE).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF7B2FBE).withValues(alpha: 0.3)),
              ),
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF9B6FDE), fontSize: 11, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumSkillsTable(BuildContext context) {
    final skills = [
      ('💳', 'Wallet', 'AgentCard.ai', 'Virtual Visa cards + autonomous spending on Base'),
      ('🔨', 'Work', 'MoltLaunch', 'On-chain AI jobs • ETH escrow • ERC-8004 identity'),
      ('🛡️', 'Credit', 'Valeo Sentinel', 'x402 budget caps: per-call / hourly / daily'),
      ('📞', 'Calls', 'Twilio AI', 'AI voice calls + real-time transcription (Deepgram)'),
      ('💸', 'Finance', 'MoonPay', 'Swap / bridge / buy / sell / DCA / live prices'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PREMIUM SKILLS',
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.statusGreen.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          Text('Tap ⓘ on any skill card in Agent Skills to see what your agent can do.',
              style: GoogleFonts.outfit(
                  fontSize: 11, color: Colors.white38)),
          const SizedBox(height: 14),
          ...skills.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.$1, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(s.$2,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text('/ ${s.$3}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(s.$4,
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
              context, 'Explore Code', 'https://github.com/vmbbz/plawie'),
            const SizedBox(width: 32),
            _buildSupportButton(
              context, 'Join Discord', 'https://discord.gg/openclaw'),
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
