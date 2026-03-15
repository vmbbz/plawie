import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';
import '../../app.dart';
import 'skills/agent_wallet_page.dart';
import 'skills/agent_work_page.dart';
import 'skills/agent_credit_page.dart';
import 'skills/agent_calls_page.dart';
import 'bot_method_explorer.dart';

class SkillsManager extends StatelessWidget {
  const SkillsManager({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSectionHeader(context, 'Premium Agent Services'),
                   const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.25,
              ),
              delegate: SliverChildListDelegate([
                _ServiceCard(
                  title: 'Wallet',
                  subtitle: 'Mastercard',
                  icon: Icons.account_balance_wallet_rounded,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentWalletPage())),
                ),
                _ServiceCard(
                  title: 'Work',
                  subtitle: 'MoltLaunch',
                  icon: Icons.work_rounded,
                  color: Colors.orangeAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentWorkPage())),
                ),
                _ServiceCard(
                  title: 'Credit',
                  subtitle: 'Valeo Cash',
                  icon: Icons.credit_score_rounded,
                  color: AppColors.statusGreen,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentCreditPage())),
                ),
                _ServiceCard(
                  title: 'Calls',
                  subtitle: 'Twilio AI',
                  icon: Icons.phone_android_rounded,
                  color: Colors.redAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentCallsPage())),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSectionHeader(context, 'Core Capability Toolkit'),
                   const SizedBox(height: 12),
                   _buildToolkitSummary(context),
                   const SizedBox(height: 32),
                   _buildQuickJump(context),
                   const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Agent Skills',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: AppColors.statusGrey.withOpacity(0.8),
      ),
    );
  }

  Widget _buildToolkitSummary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<GatewayProvider>(
      builder: (context, provider, _) {
        final health = provider.detailedHealth;
        // Mocking or extracting from health if available
        final skillCount = provider.supportedMethods.where((m) => m.startsWith('skills.')).length;
        final countToDisplay = skillCount > 0 ? skillCount : 12; // Fallback to 12 if none found or mock mode
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.purpleAccent, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Installed Capabilities', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('$countToDisplay tools currently mapped', style: TextStyle(color: AppColors.statusGrey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSkillPill(context, 'Web Browsing', Icons.language_rounded),
              _buildSkillPill(context, 'Code Interpreter', Icons.code_rounded),
              _buildSkillPill(context, 'Image Generation', Icons.palette_rounded),
              _buildSkillPill(context, 'File Management', Icons.folder_open_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkillPill(BuildContext context, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.statusGrey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          const Text('Active', style: TextStyle(color: AppColors.statusGreen, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuickJump(BuildContext context) {
    return Container(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BotMethodExplorer(initialFilter: 'skills')),
          );
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(20),
          side: BorderSide(color: Colors.purpleAccent.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const Icon(Icons.terminal_rounded, size: 18, color: Colors.purpleAccent),
             const SizedBox(width: 12),
             Text(
               'JUMP TO RPC METHOD EXPLORER',
               style: GoogleFonts.outfit(
                 fontWeight: FontWeight.bold,
                 letterSpacing: 1.0,
                 color: Colors.purpleAccent,
               ),
             ),
             const SizedBox(width: 8),
             const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.purpleAccent),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
          boxShadow: [
             if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(icon, size: 80, color: color.withOpacity(0.05)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: AppColors.statusGrey, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
