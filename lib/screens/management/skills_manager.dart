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
import '../solana_screen.dart';
import 'bot_method_explorer.dart';

/// Catalogue of premium skills we offer, mapped to their OpenClaw skill names.
/// These are the 4 special skills the user explicitly wants to surface.
const _premiumSkills = [
  _SkillEntry(
    id: 'agent_card',
    title: 'Wallet',
    subtitle: 'AgentCard.ai',
    description: 'Issue virtual Visa cards, manage balances, and make autonomous payments for your AI agent.',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF3D52D5), // AgentCard navy
  ),
  _SkillEntry(
    id: 'molt_launch',
    title: 'Work',
    subtitle: 'MoltLaunch',
    description: 'Get hired for AI agent work. Escrow payments on Base chain. ERC-8004 identity + reputation.',
    icon: Icons.work_rounded,
    color: Colors.orangeAccent,
  ),
  _SkillEntry(
    id: 'valeo_sentinel',
    title: 'Credit',
    subtitle: 'Valeo Sentinel',
    description: 'x402 spending policy for autonomous agents — per-call, hourly & daily budget caps.',
    icon: Icons.credit_score_rounded,
    color: AppColors.statusGreen,
  ),
  _SkillEntry(
    id: 'twilio_voice',
    title: 'Calls',
    subtitle: 'Twilio AI',
    description: 'ConversationRelay voice orchestration — inbound/outbound with real-time AI transcription.',
    icon: Icons.phone_android_rounded,
    color: Colors.redAccent,
  ),
];

/// Default OpenClaw built-in capabilities (factual, based on OpenClaw core tools).
const _defaultCapabilities = [
  _CapabilityEntry('Web Browsing', Icons.language_rounded, 'browser'),
  _CapabilityEntry('Code Interpreter', Icons.code_rounded, 'computer'),
  _CapabilityEntry('File Management', Icons.folder_open_rounded, 'files'),
  _CapabilityEntry('Persistent Memory', Icons.memory_rounded, 'memory'),
  _CapabilityEntry('Image Generation', Icons.palette_rounded, 'image'),
  _CapabilityEntry('Solana Wallet', Icons.currency_bitcoin_rounded, 'solana'),
];

class SkillsManager extends StatefulWidget {
  const SkillsManager({super.key});

  @override
  State<SkillsManager> createState() => _SkillsManagerState();
}

class _SkillsManagerState extends State<SkillsManager> {
  bool _isLoading = true;
  Set<String> _installedSkillIds = {};
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadInstalledSkills();
  }

  /// Fetches the list of installed skills from the OpenClaw gateway via skills.list RPC.
  /// Normalises the result to a set of lowercase skill identifiers for easy lookup.
  Future<void> _loadInstalledSkills() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final provider = Provider.of<GatewayProvider>(context, listen: false);
      final result = await provider.invoke('skills.list');

      if (result['ok'] == true) {
        final payload = result['payload'];
        final rawList = payload is List
            ? payload
            : (payload is Map ? (payload['skills'] ?? payload['items'] ?? []) : []);

        final ids = <String>{};
        for (final skill in rawList as List) {
          final id = (skill is Map
                  ? (skill['id'] ?? skill['name'] ?? skill['skillId'])
                  : skill)
              ?.toString()
              .toLowerCase() ??
              '';
          if (id.isNotEmpty) ids.add(id);
        }
        setState(() => _installedSkillIds = ids);
      } else {
        // Non-fatal: gateway may not support skills.list yet — show all as uninstalled
        setState(() => _loadError = 'Gateway offline or skills.list unavailable.');
      }
    } catch (_) {
      // Also non-fatal — gateway might not be running
      setState(() => _loadError = 'Could not reach gateway — showing discovery mode.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isInstalled(_SkillEntry skill) {
    return _installedSkillIds.any((id) => id.contains(skill.id));
  }

  /// Initiates skill installation via the skills.install RPC.
  Future<void> _installSkill(BuildContext context, _SkillEntry skill) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show installing bottom sheet
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _InstallSheet(skillTitle: skill.title),
    );

    try {
      final provider = Provider.of<GatewayProvider>(context, listen: false);
      final result = await provider.invoke('skills.install', {
        'name': skill.id,
        'installId': '${skill.id}_${DateTime.now().millisecondsSinceEpoch}',
      });

      navigator.pop(); // Close the bottom sheet

      if (result['ok'] == true) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ ${skill.title} skill installed successfully!'),
            backgroundColor: AppColors.statusGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh installed skills list
        _loadInstalledSkills();
      } else {
        final errMsg = result['error']?['message']?.toString() ??
            result['payload']?['error']?.toString() ??
            'Installation failed. Please try again.';
        messenger.showSnackBar(
          SnackBar(
            content: Text('⚠️ $errMsg'),
            backgroundColor: AppColors.statusAmber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Could not install ${skill.title}: $e'),
          backgroundColor: AppColors.statusRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToSkillPage(BuildContext context, _SkillEntry skill) {
    Widget page;
    switch (skill.id) {
      case 'agent_card':
        page = const AgentWalletPage();
        break;
      case 'molt_launch':
        page = const AgentWorkPage();
        break;
      case 'valeo_sentinel':
        page = const AgentCreditPage();
        break;
      case 'twilio_voice':
        page = const AgentCallsPage();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Premium Agent Services'),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to activate • Expands your bot\'s real-world capabilities',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.statusGrey),
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 10),
                    _buildOfflineBanner(context),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Premium skill cards grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate([
                for (final skill in _premiumSkills)
                  _ServiceCard(
                    skill: skill,
                    isInstalled: _isInstalled(skill),
                    isLoading: _isLoading,
                    onTap: () {
                      if (_isInstalled(skill)) {
                        _navigateToSkillPage(context, skill);
                      } else {
                        _showInstallPrompt(context, skill);
                      }
                    },
                  ),
              ]),
            ),
          ),
          // Register Agent on MoltLaunch — shown below the Work card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _buildMoltLaunchRegisterBanner(context),
            ),
          ),
          // Solana built-in section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
              child: _buildSolanaBuiltInCard(context),
            ),
          ),
          // Core capabilities section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Core Capability Toolkit'),
                  const SizedBox(height: 6),
                  Text(
                    'Built-in tools available in every OpenClaw gateway',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.statusGrey),
                  ),
                  const SizedBox(height: 12),
                  _buildCoreToolkit(context),
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

  void _showInstallPrompt(BuildContext context, _SkillEntry skill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InstallPromptSheet(
        skill: skill,
        onInstall: () {
          Navigator.pop(context);
          _installSkill(context, skill);
        },
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 16, color: AppColors.statusAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loadError!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.statusAmber),
            ),
          ),
          GestureDetector(
            onTap: _loadInstalledSkills,
            child: const Icon(Icons.refresh,
                size: 16, color: AppColors.statusAmber),
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
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh skills',
          onPressed: _loadInstalledSkills,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.statusGrey.withValues(alpha: 0.8),
          ),
    );
  }


  Widget _buildCapabilityPill(BuildContext context, _CapabilityEntry cap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Icon(cap.icon, size: 14, color: AppColors.statusGrey),
          const SizedBox(width: 8),
          Text(cap.label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.statusGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'ACTIVE',
              style: TextStyle(
                  color: AppColors.statusGreen,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreToolkit(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_mosaic_rounded,
                    color: Colors.purpleAccent, size: 20),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OpenClaw Core Tools',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${_defaultCapabilities.length} tools always available',
                    style: const TextStyle(
                        color: AppColors.statusGrey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...(_defaultCapabilities
              .map((cap) => _buildCapabilityPill(context, cap))),
        ],
      ),
    );
  }

  Widget _buildQuickJump(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const BotMethodExplorer(initialFilter: 'skills')),
          );
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(20),
          side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.3)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.terminal_rounded,
                size: 18, color: Colors.purpleAccent),
            const SizedBox(width: 12),
            Text(
              'EXPLORE RPC SKILL METHODS',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.purpleAccent,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.purpleAccent),
          ],
        ),
      ),
    );
  }

  /// Contextual banner below the Work card — directs user to register their
  /// OpenClaw agent on MoltLaunch to accept on-chain jobs.
  /// Shown inline on the skills page so the CTA is in context.
  Widget _buildMoltLaunchRegisterBanner(BuildContext context) {
    final workSkill = _premiumSkills.firstWhere((s) => s.id == 'molt_launch');
    final isInstalled = _isInstalled(workSkill);

    if (isInstalled) {
      // Already registered — show a compact status row
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Colors.orange, size: 16),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'MoltLaunch agent registered • Work skill active',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
            TextButton(
              child: const Text('View', style: TextStyle(fontSize: 12)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AgentWorkPage())),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.orange.withValues(alpha: 0.08),
          Colors.deepOrange.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.work_outline_rounded,
                color: Colors.orange, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Register as a MoltLaunch Agent',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  'ERC-8004 identity on Base chain\n\u2022 ETH escrow \u2022 0\u2013100 on-chain reputation',
                  style: TextStyle(
                      color: AppColors.statusGrey.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              // Install the Work skill first if not yet installed, then navigate
              _showInstallPrompt(context, workSkill);
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  /// Solana built-in card — surfaced on the skills page so users know
  /// the Solana wallet is wired by default (ship with the APK, not an add-on).
  /// Provides a direct shortcut tap to open SolanaScreen from here.
  Widget _buildSolanaBuiltInCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SolanaScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF9945FF).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9945FF), Color(0xFF14F195)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.currency_bitcoin_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Solana Wallet',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statusGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('BUILT-IN',
                            style: TextStyle(
                                color: AppColors.statusGreen,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Send SOL, swap via Jupiter DEX, view balances. Wired on first run \u2014 no install needed.',
                    style: TextStyle(
                        color: AppColors.statusGrey.withValues(alpha: 0.9),
                        fontSize: 11,
                        height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.statusGrey, size: 20),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _SkillEntry {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  const _SkillEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _CapabilityEntry {
  final String label;
  final IconData icon;
  final String key;
  const _CapabilityEntry(this.label, this.icon, this.key);
}

// ─────────────────────────────────────────────────────────────────────────────
// Service Card with install state
// ─────────────────────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final _SkillEntry skill;
  final bool isInstalled;
  final bool isLoading;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.skill,
    required this.isInstalled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isInstalled
                ? skill.color.withValues(alpha: 0.4)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05)),
            width: isInstalled ? 1.5 : 1.0,
          ),
          boxShadow: isInstalled
              ? [
                  BoxShadow(
                    color: skill.color.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Stack(
          children: [
            // Ghost background icon
            Positioned(
              right: -8,
              top: -8,
              child: Icon(skill.icon,
                  size: 80, color: skill.color.withValues(alpha: 0.04)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Skill icon
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: skill.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(skill.icon, color: skill.color, size: 20),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    skill.title,
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    skill.subtitle,
                    style: const TextStyle(
                        color: AppColors.statusGrey, fontSize: 10),
                  ),
                ],
              ),
            ),
            // Status badge
            Positioned(
              top: 12,
              right: 12,
              child: isLoading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: skill.color.withValues(alpha: 0.6)),
                    )
                  : isInstalled
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: skill.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: skill.color,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: const Text(
                            'INSTALL',
                            style: TextStyle(
                              color: AppColors.statusGrey,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Install Prompt Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InstallPromptSheet extends StatelessWidget {
  final _SkillEntry skill;
  final VoidCallback onInstall;

  const _InstallPromptSheet({required this.skill, required this.onInstall});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2433) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: skill.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(skill.icon, color: skill.color, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.title,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                    Text(
                      skill.subtitle,
                      style: const TextStyle(
                          color: AppColors.statusGrey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                skill.description,
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.statusGrey),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.statusAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.statusAmber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Skill will be installed into your running OpenClaw gateway instance.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.statusAmber),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onInstall,
                    icon: Icon(skill.icon, size: 18),
                    label: Text('Install ${skill.title}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: skill.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Installing progress sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InstallSheet extends StatelessWidget {
  final String skillTitle;
  const _InstallSheet({required this.skillTitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C2433)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.statusGreen),
            const SizedBox(height: 20),
            Text(
              'Installing $skillTitle...',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Communicating with your OpenClaw gateway',
              style: TextStyle(color: AppColors.statusGrey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
