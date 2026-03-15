import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

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
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.1),
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              ),
            ),
          ),
          
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Quick Start Guide'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Getting Started',
                        description: 'Learn how to activate your agent and send your first command.',
                        icon: Icons.rocket_launch_outlined,
                        gradient: [Colors.orangeAccent, Colors.redAccent],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Voice Interaction',
                        description: 'How to use the floating mic for hands-free AI assistance.',
                        icon: Icons.mic_none_outlined,
                        gradient: [Colors.blueAccent, Colors.cyanAccent],
                      ),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader('Foundational Engine'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'PRoot & Gateway',
                        description: 'Deep dive into the local Ubuntu OpenClaw execution environment.',
                        icon: Icons.terminal_outlined,
                        gradient: [Colors.greenAccent, Colors.tealAccent],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Solana Web3 Logic',
                        description: 'Understanding native transactions and key security.',
                        icon: Icons.account_balance_wallet_outlined,
                        gradient: [Colors.purpleAccent, Colors.deepPurpleAccent],
                      ),

                      const SizedBox(height: 32),
                      _buildSectionHeader('Advanced Skill Hub'),
                      const SizedBox(height: 16),
                      _buildHelpCard(
                        context,
                        title: 'Twilio & Telephony',
                        description: 'Configuring your agent for voice bridging and SMS.',
                        icon: Icons.phone_android_outlined,
                        gradient: [Colors.redAccent, Colors.pinkAccent],
                      ),
                      const SizedBox(height: 12),
                      _buildHelpCard(
                        context,
                        title: 'Payments & Budgets',
                        description: 'Managing AgentCard issuance and Valeo Sentinel policies.',
                        icon: Icons.credit_card_outlined,
                        gradient: [Colors.tealAccent, Colors.lightGreenAccent],
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
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0D1B2A).withValues(alpha: 0.8),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FlexibleSpaceBar(
            centerTitle: true,
            title: Text(
              'HELP CENTER',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blueAccent.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: Colors.blueAccent,
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {}, // Navigate to detailed markdown page
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
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
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.3),
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
        const Divider(color: Colors.white10),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSupportButton(context, 'ClawHub', 'https://github.com/vmbbz/plawie'),
            const SizedBox(width: 20),
            _buildSupportButton(context, 'Discord', 'https://discord.gg/openclaw'),
          ],
        ),
      ],
    );
  }

  Widget _buildSupportButton(BuildContext context, String label, String url) {
    return TextButton.icon(
      onPressed: () => launchUrl(Uri.parse(url)),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.5),
        textStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
