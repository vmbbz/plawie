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
                        title: 'On-Device Local LLM',
                        description: 'Two local inference modes:\n\n'
                            '• NDK Direct (fllama) — GGUF models run entirely inside the app via llama.cpp NDK. Zero network, maximum privacy. Download models in Local LLM settings, then select a local-llm/ model in the chat picker. No tools or skills — pure private inference.\n\n'
                            '• Local LLM Hub (Ollama) — the same models routed through the OpenClaw gateway agent loop. Full tool-use, skills, and multi-step reasoning. Start Ollama in Local LLM settings and pick an ollama/ model in the chat model picker.',
                        icon: Icons.memory_rounded,
                        color: AppColors.statusGreen,
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Base Chain Wallet',
                        description: 'A full EVM wallet on Coinbase\'s Base L2 is built into the app. secp256k1 keypairs are generated and stored securely on-device. Check ETH and USDC balances, send to any 0x address or .base.eth Basename, and view your transaction history — all without a cloud intermediary.\n\nInstall Coinbase AgentKit from the Skills Manager to give the AI 50+ autonomous actions: gasless token swaps, NFT deployment, DCA, bridge, Farcaster posts, and more.',
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF0052FF),
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Procedural XR Engine',
                        description: 'Our WebGL-based VRM avatars are driven by a mathematical engine. Independent neck and eye-tracking using sum-of-sines algorithms create hyper-realistic saccades driven by real-time TTS events.',
                        icon: Icons.architecture_rounded,
                        color: Colors.cyanAccent,
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Gestures & Avatar Animations',
                        description: 'The AI agent can trigger full-body animations on the 3D avatar via the Avatar Control skill. Ask it to wave, dance, or strike a pose — it picks the right animation automatically.\n\nAvailable gestures: greeting · dance · cute · elegant · fight · peacesign · pose · powerful · ready · shoot · spin · squat · talk · idle\n\nYou can also embed animations inline in any message using the syntax (gesture:name). The avatar uses the "pose" gesture while thinking and "ready" when a task completes.',
                        icon: Icons.emoji_people_rounded,
                        color: Colors.purpleAccent,
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Natural Voice (Piper TTS)',
                        description: 'The app ships with native Android TTS by default (fast, robotic). To unlock a natural-sounding AI voice, download the Piper TTS model from the chat page banner — tap "Enable Voice" and wait for the one-time download (~45 MB).\n\nOnce downloaded, the natural voice activates immediately and the setting persists — you will never be prompted to download again. Switch back to native TTS anytime in Settings.',
                        icon: Icons.record_voice_over_rounded,
                        color: Colors.tealAccent,
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Canvas (AI Web Browser)',
                        description: 'The AI agent can open a live web browser overlay directly in the chat page using canvas commands: navigate to a URL, run JavaScript on the page, and take a screenshot that appears inline in the conversation.\n\nCanvas is active whenever you are on the Chat page. Ask the AI to "open example.com in canvas" or "take a screenshot of the current canvas" — the WebView panel appears at the bottom of chat and can be closed at any time.',
                        icon: Icons.web_rounded,
                        color: Colors.orangeAccent,
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader('Advanced Extensibility'),
                      const SizedBox(height: 16),
                      _buildSkillsManagerCard(context),
                      const SizedBox(height: 12),
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

  Widget _buildSkillsManagerCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      accentColor: Colors.purpleAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.extension_rounded, color: Colors.purpleAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                      ),
                      child: Text('SKILLS MANAGER',
                          style: GoogleFonts.outfit(
                              color: Colors.purpleAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5)),
                    ),
                    const SizedBox(height: 6),
                    Text('3-Tab Skills Interface',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...[
            (Icons.check_circle_rounded, Colors.greenAccent, 'My Skills',
                'Your installed skills, Local LLM status, Base Chain wallet, and workspace config — all in one place.'),
            (Icons.explore_rounded, Colors.cyanAccent, 'Discover',
                'Live search against the ClawHub community registry. Browse, preview, and install skills with one tap.'),
            (Icons.build_rounded, Colors.amberAccent, 'Tools',
                'Reads your running gateway\'s tools.allow config live — no hardcoded list, always accurate.'),
          ].map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(t.$1, size: 16, color: t.$2),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.$3, style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(t.$4, style: GoogleFonts.outfit(
                          color: Colors.white54, fontSize: 11, height: 1.45)),
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
    // (icon, name, subtitle, description, requiresInstall)
    // requiresInstall=true → shows "INSTALL" badge; false → shows active/built-in
    final skills = [
      (Icons.account_balance_wallet_rounded, 'Wallet', 'AgentCard.ai',
          'Issue virtual Visa cards and make autonomous on-chain payments via Base. Install via Skills Manager → Partner Skills.', true),
      (Icons.work_rounded, 'Work', 'MoltLaunch',
          'EVM/Base-compatible AI job marketplace with Molt.ID identity and ETH escrow. Install via Skills Manager → Partner Skills.', true),
      (Icons.credit_score_rounded, 'Credit', 'Valeo Sentinel',
          'x402 spending policy: per-call, hourly & daily budget caps with on-chain audit log. Install via Skills Manager → Partner Skills.', true),
      (Icons.phone_android_rounded, 'Calls', 'Twilio AI',
          'Inbound & outbound voice via ConversationRelay with real-time AI transcription. Requires Twilio Account SID + Auth Token. Install via Skills Manager → Partner Skills.', true),
      (Icons.rocket_launch_rounded, 'AI Wallet', 'Coinbase AgentKit',
          '50+ AI-callable actions on Base: gasless token swaps, NFT deploy, DCA, bridge, Farcaster, and Basenames. Requires CDP API Key from portal.cdp.coinbase.com. Install via Skills Manager → Partner Skills.', true),
      (Icons.currency_exchange_rounded, 'Finance', 'MoonPay',
          'Verified agent bank account — swap, bridge, DCA, fiat onramps and live market prices.', false),
      (Icons.memory_rounded, 'Local LLM', 'fllama / Ollama',
          'NDK fllama for private offline chat. Local LLM Hub (Ollama) for full tool-use and skills. No API key — total on-device control.', false),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PREMIUM SKILLS',
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white54)),
          const SizedBox(height: 16),
          ...skills.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(s.$1, size: 16, color: s.$5 ? Colors.white38 : Colors.white70),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(s.$2,
                              style: TextStyle(
                                  color: s.$5 ? Colors.white54 : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Text(s.$3,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                          if (s.$5) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0052FF).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF0052FF).withValues(alpha: 0.4)),
                              ),
                              child: const Text('INSTALL',
                                  style: TextStyle(
                                      color: Color(0xFF6699FF),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(s.$4,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11, height: 1.4)),
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
