import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';
import '../../models/gateway_state.dart';
import '../../models/clawhub_skill.dart';
import '../../app.dart';
import '../../widgets/glass_card.dart';
import '../../services/clawhub_service.dart';
import '../../services/local_llm_service.dart';
import '../../services/native_bridge.dart';
import '../../services/openclaw_service.dart';
import 'skills/agent_wallet_page.dart';
import 'skills/agent_work_page.dart';
import 'skills/agent_credit_page.dart';
import 'skills/agent_calls_page.dart';
import 'skills/agent_moonpay_page.dart';
import 'local_llm_screen.dart';
import '../solana_screen.dart';
import 'bot_method_explorer.dart';
import 'skills/skill_config_editor.dart';
import 'skills/skill_detail_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Premium skill metadata catalogue — always rendered as cards in My Skills.
// Installed cards (confirmed by gateway) show ACTIVE badge + navigate on tap.
// Uninstalled cards show INSTALL badge + install prompt on tap, with an
// Explore button to open the rich stub page before installing.
// ─────────────────────────────────────────────────────────────────────────────

const _premiumSkills = [
  _SkillEntry(
    id: 'agent-card',
    title: 'Wallet',
    subtitle: 'AgentCard.ai',
    description:
        'Issue virtual Visa cards, manage balances, and make autonomous payments for your AI agent.',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF3D52D5),
    tooltip:
        'AgentCard.ai gives your agent a virtual Visa card with real spending power. Your agent can create cards, top them up, check balances, and make autonomous payments — all on-chain on Base.',
  ),
  _SkillEntry(
    id: 'molt-launch',
    title: 'Work',
    subtitle: 'MoltLaunch',
    description:
        'Get hired for AI agent work. Escrow payments on Base chain. ERC-8004 identity + reputation.',
    icon: Icons.work_rounded,
    color: Colors.orangeAccent,
    tooltip:
        'MoltLaunch is an on-chain job marketplace for AI agents. Your agent gets an ERC-8004 identity NFT on Base, can browse posted jobs, bid, and receive ETH escrow payments on completion.',
  ),
  _SkillEntry(
    id: 'valeo-sentinel',
    title: 'Credit',
    subtitle: 'Valeo Sentinel',
    description:
        'x402 spending policy for autonomous agents — per-call, hourly & daily budget caps.',
    icon: Icons.credit_score_rounded,
    color: AppColors.statusGreen,
    tooltip:
        'Valeo Sentinel enforces x402 protocol spending rules on your agent. Set per-call, hourly, daily, and lifetime USD budget caps. Every payment is audit-logged on-chain so you can review exactly what your agent spent.',
  ),
  _SkillEntry(
    id: 'twilio-voice',
    title: 'Calls',
    subtitle: 'Twilio AI',
    description:
        'ConversationRelay voice orchestration — inbound/outbound with real-time AI transcription.',
    icon: Icons.phone_android_rounded,
    color: Colors.redAccent,
    tooltip:
        'Your agent can make and receive phone calls, transcribe conversations in real-time using Deepgram, and orchestrate AI-driven call flows via Twilio ConversationRelay.',
  ),
  _SkillEntry(
    id: 'moonpay',
    title: 'Finance',
    subtitle: 'MoonPay',
    description:
        'Verified agent bank account + 30 financial skills: swap, bridge, buy/sell, DCA, live prices.',
    icon: Icons.currency_exchange_rounded,
    color: Color(0xFF7B2FBE),
    tooltip:
        'Give your agent a verified bank account. It can swap tokens, bridge cross-chain, buy/sell crypto via fiat, check portfolio, and run DCA strategies — all from natural language commands in chat.',
  ),
  _SkillEntry(
    id: 'local-llm',
    title: 'Local LLM',
    subtitle: 'llama-server',
    description:
        'Run a free, offline LLM on-device via llama-server inside PRoot. No API key. No internet. Total privacy.',
    icon: Icons.memory_rounded,
    color: Color(0xFF0097A7),
    tooltip:
        'Downloads a GGUF model (Qwen2.5-1.5B recommended) and runs llama-server as a sibling process inside PRoot. OpenClaw routes via the gateway when enabled. CPU-only for stability.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Root widget
// ─────────────────────────────────────────────────────────────────────────────

class SkillsManager extends StatefulWidget {
  const SkillsManager({super.key});

  @override
  State<SkillsManager> createState() => _SkillsManagerState();
}

class _SkillsManagerState extends State<SkillsManager>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  StreamSubscription<LocalLlmState>? _llmSubscription;
  LocalLlmState _llmState = const LocalLlmState();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _llmSubscription = LocalLlmService().stateStream.listen((s) {
      if (mounted) setState(() => _llmState = s);
    });
    _llmState = LocalLlmService().state;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _llmSubscription?.cancel();
    super.dispose();
  }

  // ── Shared install logic (called from My Skills + Discover) ────────────────

  Future<void> _installSkill(
    BuildContext context,
    _SkillEntry skill,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final provider = Provider.of<GatewayProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _InstallSheet(skillTitle: skill.title),
    );

    try {
      final installCmd =
          await OpenClawCommandService.getSkillInstallCommand(skill.id);
      String cliResult;
      try {
        cliResult = await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" '
          '&& $installCmd',
          timeout: 45,
        );
      } catch (_) {
        cliResult = 'error:';
      }
      if (cliResult.toLowerCase().contains('error:') ||
          cliResult.toLowerCase().contains('too many arguments') ||
          cliResult.toLowerCase().contains('unknown command')) {
        cliResult = await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" '
          '&& npx --yes clawhub install ${skill.id}',
          timeout: 60,
        );
      }
      if (provider.state.status == GatewayStatus.running) {
        await OpenClawCommandService.reloadGateway();
      }
      ClawHubService.instance.invalidateCache();
      navigator.pop();
      final lower = cliResult.toLowerCase();
      if (!lower.contains('error:') && !lower.contains('failed')) {
        messenger.showSnackBar(SnackBar(
          content: Text('${skill.title} installed'),
          backgroundColor: AppColors.statusGreen,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        final rateLimitMatch = RegExp(r'reset in (\d+)s').firstMatch(cliResult);
        messenger.showSnackBar(SnackBar(
          content: Text(rateLimitMatch != null
              ? 'Rate limited — try again in ${rateLimitMatch.group(1)}s'
              : 'Install failed: $cliResult'),
          backgroundColor: AppColors.statusAmber,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Could not install ${skill.title}: $e'),
        backgroundColor: AppColors.statusRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Install a skill discovered via the Discover tab (slug is registry-verified).
  Future<void> _installBySlug(
    BuildContext context,
    String slug,
    String displayTitle,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final provider = Provider.of<GatewayProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _InstallSheet(skillTitle: displayTitle),
    );

    try {
      final installCmd =
          await OpenClawCommandService.getSkillInstallCommand(slug);
      String cliResult;
      try {
        cliResult = await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" '
          '&& $installCmd',
          timeout: 60,
        );
      } catch (_) {
        cliResult = await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" '
          '&& npx --yes clawhub install $slug',
          timeout: 60,
        );
      }
      if (provider.state.status == GatewayStatus.running) {
        await OpenClawCommandService.reloadGateway();
      }
      ClawHubService.instance.invalidateCache();
      navigator.pop();
      final lower = cliResult.toLowerCase();
      if (!lower.contains('error:') && !lower.contains('failed')) {
        messenger.showSnackBar(SnackBar(
          content: Text('$displayTitle installed'),
          backgroundColor: AppColors.statusGreen,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        final rl = RegExp(r'reset in (\d+)s').firstMatch(cliResult);
        messenger.showSnackBar(SnackBar(
          content: Text(rl != null
              ? 'Rate limited — try again in ${rl.group(1)}s'
              : 'Install failed: $cliResult'),
          backgroundColor: AppColors.statusAmber,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('Could not install $displayTitle: $e'),
        backgroundColor: AppColors.statusRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _navigateToSkillPage(BuildContext context, String skillId) {
    Widget? page;
    switch (skillId) {
      case 'agent-card':
        page = const AgentWalletPage();
      case 'molt-launch':
        page = const AgentWorkPage();
      case 'valeo-sentinel':
        page = const AgentCreditPage();
      case 'twilio-voice':
        page = const AgentCallsPage();
      case 'moonpay':
        page = const AgentMoonPayPage();
      case 'local-llm':
        page = const LocalLlmScreen();
    }
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
    }
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
        onExplore: () {
          Navigator.pop(context);
          _navigateToSkillPage(context, skill.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const NebulaBg(),
          NestedScrollView(
            headerSliverBuilder: (ctx, _) => [
              _buildAppBar(ctx),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _MySkillsTab(
                  llmState: _llmState,
                  premiumSkills: _premiumSkills,
                  onInstall: (skill) => _installSkill(context, skill),
                  onNavigate: (id) => _navigateToSkillPage(context, id),
                  onShowPrompt: (skill) => _showInstallPrompt(context, skill),
                ),
                _DiscoverTab(
                  onInstall: (slug, title) =>
                      _installBySlug(context, slug, title),
                ),
                const _ToolsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 90,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: FlexibleSpaceBar(
            background: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/app_icon_official.svg',
            width: 18,
            height: 18,
            colorFilter:
                const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: 10),
          Text(
            'AGENT SKILLS',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 3.0,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          tooltip: 'Refresh',
          onPressed: () {
            Provider.of<GatewayProvider>(context, listen: false).checkHealth();
            ClawHubService.instance.invalidateCache();
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: AppColors.statusGreen,
        unselectedLabelColor: Colors.white38,
        indicatorColor: AppColors.statusGreen,
        indicatorWeight: 2,
        labelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.2),
        tabs: const [
          Tab(text: 'MY SKILLS'),
          Tab(text: 'DISCOVER'),
          Tab(text: 'TOOLS'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — My Skills
// Shows installed skills (live from gateway) + Local LLM + Solana.
// Premium cards appear ONLY when the gateway confirms they are installed.
// ─────────────────────────────────────────────────────────────────────────────

class _MySkillsTab extends StatefulWidget {
  final LocalLlmState llmState;
  final List<_SkillEntry> premiumSkills;
  final void Function(_SkillEntry) onInstall;
  final void Function(String skillId) onNavigate;
  final void Function(_SkillEntry) onShowPrompt;

  const _MySkillsTab({
    required this.llmState,
    required this.premiumSkills,
    required this.onInstall,
    required this.onNavigate,
    required this.onShowPrompt,
  });

  @override
  State<_MySkillsTab> createState() => _MySkillsTabState();
}

class _MySkillsTabState extends State<_MySkillsTab> {
  List<String>? _offlineInstalledIds;

  @override
  void initState() {
    super.initState();
    _loadOfflineInstalled();
  }

  Future<void> _loadOfflineInstalled() async {
    final ids = await OpenClawCommandService.getInstalledSkills();
    if (mounted) setState(() => _offlineInstalledIds = ids);
  }

  @override
  Widget build(BuildContext context) {
    final gatewayState = context.watch<GatewayProvider>().state;
    final rawSkills = gatewayState.activeSkills ?? [];
    final isLoading = gatewayState.status == GatewayStatus.starting;

    // Build installed ID set from gateway live data; fall back to CLI result
    final installedIds = rawSkills.isNotEmpty
        ? rawSkills
            .map((s) =>
                (s['id'] ?? s['name'] ?? s['skillId'])
                    ?.toString()
                    .toLowerCase() ??
                '')
            .where((id) => id.isNotEmpty)
            .toSet()
        : (_offlineInstalledIds?.toSet() ?? <String>{});

    // 1. All gateway-confirmed installed skills (enriched with premium metadata
    //    where the ID matches; blueGrey fallback card for non-premium plugins).
    final dynamicInstalled = rawSkills.map((s) {
      final id =
          (s['id'] ?? s['name'] ?? s['skillId'])?.toString().toLowerCase() ??
              '';
      return widget.premiumSkills.firstWhere(
        (p) =>
            p.id == id || id.contains(p.id.replaceAll('-', '_')),
        orElse: () {
          final title = (s['title'] ?? s['name'] ?? id).toString();
          final author = (s['author'] ?? 'Plugin').toString();
          final String desc;
          if (s['description'] != null && s['description'].toString().isNotEmpty) {
             desc = s['description'].toString();
          } else {
             desc = 'An installed OpenClaw skill.';
          }
          return _SkillEntry(
            id: id,
            title: title,
            subtitle: author,
            description: desc,
            icon: Icons.extension_rounded,
            color: Colors.blueGrey,
          );
        },
      );
    }).where((s) => s.id.isNotEmpty && s.id != 'local-llm').toList();

    // 2. Uninstalled premium catalogue — appended below so the grid always
    //    shows all 6 premium skill tiles even when none are installed yet.
    final availableCatalog = widget.premiumSkills
        .where((p) => p.id != 'local-llm')
        .where((p) => !dynamicInstalled.any((d) => d.id == p.id))
        .toList();

    // 3. Merged: installed first (with active border), uninstalled catalog below.
    final mergedSkills = [...dynamicInstalled, ...availableCatalog];

    return CustomScrollView(
      slivers: [
        // ── Local LLM — always pinned ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('PINNED'),
                const SizedBox(height: 12),
                _LocalLlmCard(
                  llmState: widget.llmState,
                  onTap: () => widget.onNavigate('local-llm'),
                ),
              ],
            ),
          ),
        ),
        // ── Premium skills grid — always shows all cards ─────────────────
        // Uses SliverToBoxAdapter + LayoutBuilder-based grid to avoid the
        // SliverGrid zero-height bug inside NestedScrollView bodies.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionLabel('PREMIUM AGENT SERVICES'),
                    if (gatewayState.status == GatewayStatus.running)
                      GestureDetector(
                        onTap: () {
                          context.read<GatewayProvider>().refreshRpcDiscovery();
                          _loadOfflineInstalled();
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.refresh, size: 13, color: AppColors.statusGreen),
                            const SizedBox(width: 4),
                            Text('REFRESH', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.statusGreen.withValues(alpha: 0.85))),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardW = (constraints.maxWidth - 14) / 2;
                    final cardH = cardW / 1.05;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        for (final skill in mergedSkills)
                          SizedBox(
                            width: cardW,
                            height: cardH,
                            child: _ServiceCard(
                              skill: skill,
                              isInstalled: installedIds.contains(skill.id) ||
                                  installedIds.any((id) =>
                                      id.contains(skill.id) ||
                                      id.contains(
                                          skill.id.replaceAll('-', '_'))),
                              onTap: () {
                                final installed =
                                    installedIds.contains(skill.id) ||
                                        installedIds.any((id) =>
                                            id.contains(skill.id) ||
                                            id.contains(skill.id
                                                .replaceAll('-', '_')));
                                // Always open detail sheet first — shows live
                                // stats. Sheet has Open / Install CTA inside.
                                showSkillDetailSheet(
                                  context,
                                  slug: skill.id,
                                  initialName: skill.title,
                                  initialDescription: skill.description,
                                  isInstalled: installed,
                                  accentColor: skill.color,
                                  icon: skill.icon,
                                  onInstall: installed
                                      ? null
                                      : (slug, name) async =>
                                          widget.onShowPrompt(skill),
                                );
                              },
                            ),
                          ),
                      ],

                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // ── MoltLaunch register banner ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _MoltLaunchBanner(
              isInstalled: installedIds.any((id) => id.contains('molt')),
              onRegister: () => widget.onNavigate('molt-launch'),
            ),
          ),
        ),
        // ── Solana built-in ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: _SolanaBuiltInCard(),
          ),
        ),
        // ── Workspace config (raw editor) ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
            child: _sectionLabel('WORKSPACE CONFIG  ·  2-WAY SYNC'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: _buildWorkspaceList(rawSkills, isLoading),
        ),
      ],
    );
  }

  Widget _buildWorkspaceList(
    List<Map<String, dynamic>> rawSkills,
    bool isLoading,
  ) {
    if (isLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        )),
      );
    }
    if (rawSkills.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: const Center(
            child: Text(
              'No active skills detected on gateway.',
              style: TextStyle(color: AppColors.statusGrey, fontSize: 12),
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final skill = rawSkills[i];
          final skillId =
              (skill['id'] ?? skill['name'] ?? skill['skillId'])
                  ?.toString()
                  .toLowerCase() ??
                  '';
          final skillTitle =
              (skill['title'] ?? skill['name'] ?? skillId).toString();
          final skillDesc = (skill['description'] ?? 'SKILL.yaml Workspace Binding').toString();
          final isPremium =
              _premiumSkills.any((s) => s.id == skillId);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isPremium ? AppColors.statusGreen : Colors.blueGrey)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPremium
                        ? Icons.verified_rounded
                        : Icons.extension_rounded,
                    color: isPremium
                        ? AppColors.statusGreen
                        : AppColors.statusGrey,
                    size: 18,
                  ),
                ),
                title: Text(
                  skillTitle,
                  style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  skillDesc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.4)),
                ),
                // Tap → detail sheet with edit shortcut
                onTap: () => showSkillDetailSheet(
                  context,
                  slug: skillId,
                  initialName: skillTitle,
                  initialDescription: skillDesc,
                  isInstalled: true,
                  accentColor: isPremium
                      ? AppColors.statusGreen
                      : Colors.blueGrey,
                  icon: isPremium
                      ? Icons.verified_rounded
                      : Icons.extension_rounded,
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            SkillConfigEditor(skillId: skillId)),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Info chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          size: 14, color: Colors.white54),
                    ),
                    const SizedBox(width: 6),
                    // Edit chip
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SkillConfigEditor(skillId: skillId)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_document,
                                size: 13, color: Colors.white70),
                            SizedBox(width: 5),
                            Text('EDIT',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: rawSkills.length,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Discover
// Live ClawHub registry search with debounce, rate-limit countdown, and
// one-tap install.
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoverTab extends StatefulWidget {
  final Future<void> Function(String slug, String title) onInstall;

  const _DiscoverTab({required this.onInstall});

  @override
  State<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<_DiscoverTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  Timer? _countdownTimer;

  List<ClawHubSkill> _results = [];
  bool _loading = false;
  bool _searched = false;
  int _rateLimitCountdown = 0;
  Set<String> _installedSlugs = {};

  // Curated featured slugs shown before the user searches.
  // These are confirmed to exist in the ClawHub NPM registry
  // (all appear in the user's active gateway skills list).
  static const _featuredSlugs = <String>[
    'weather',
    'github',
    'coding-agent',
    'summarize',
    'session-logs',
    'voice-call',
    'tmux',
    'notion',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Chain: load installed slugs first, then featured, so isInstalled is
    // accurate on the first render.
    _loadInstalledThenFeatured();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Loads installed slugs, then pre-populates the featured list.
  Future<void> _loadInstalledThenFeatured() async {
    final ids = await OpenClawCommandService.getInstalledSkills();
    if (!mounted) return;
    setState(() => _installedSlugs = ids.toSet());
    await _loadFeatured();
  }

  /// Refreshes the installed-slug set and re-marks all current results.
  /// Called after a successful install so the ACTIVE badge updates immediately.
  Future<void> _refreshInstalledStatus() async {
    final ids = await OpenClawCommandService.getInstalledSkills();
    if (!mounted) return;
    setState(() {
      _installedSlugs = ids.toSet();
      _results = _results
          .map((s) => s.copyWith(isInstalled: _installedSlugs.contains(s.slug)))
          .toList();
    });
  }

  Future<void> _loadFeatured() async {
    if (_searched) return;
    setState(() => _loading = true);
    try {
      final results = await ClawHubService.instance.fetchFeatured(
        _featuredSlugs,
        installedSlugs: _installedSlugs,
      );
      if (mounted && !_searched) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && !_searched) {
        setState(() {
          _results = [];
          _loading = false;
        });
      }
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      // Don't zero _results here — _loadFeatured will replace them, avoiding
      // a flash of empty state between clear and featured load completing.
      setState(() => _searched = false);
      _loadFeatured();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _doSearch(query));
  }

  Future<void> _doSearch(String query) async {
    if (ClawHubService.instance.isRateLimited) {
      _startCountdown(ClawHubService.instance.secondsUntilReset);
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final results = await ClawHubService.instance.search(
        query,
        installedSlugs: _installedSlugs,
      );
      if (ClawHubService.instance.isRateLimited) {
        _startCountdown(ClawHubService.instance.secondsUntilReset);
      }
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
         _results = [];
         _loading = false;
      });
    }
  }

  void _startCountdown(int seconds) {
    if (!mounted) return;
    setState(() => _rateLimitCountdown = seconds);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _rateLimitCountdown = (_rateLimitCountdown - 1).clamp(0, 9999);
        if (_rateLimitCountdown == 0) t.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // ── Search bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onQueryChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search ClawHub registry…',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Colors.white38, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: Colors.white38, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // ── Rate limit banner ───────────────────────────────────────────────
        if (_rateLimitCountdown > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _RateLimitBanner(secondsLeft: _rateLimitCountdown),
          ),
        // ── Section label ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _sectionLabel(_searched ? 'SEARCH RESULTS' : 'FEATURED'),
          ),
        ),
        // ── Results ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2))
              : _results.isEmpty
                  ? _EmptyState(
                      icon: Icons.travel_explore_rounded,
                      message: _searched
                          ? 'No skills found for "${_searchCtrl.text}"'
                          : 'Type to search the ClawHub registry',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) => _DiscoverCard(
                        skill: _results[i],
                        onInstall: _rateLimitCountdown > 0
                            ? null
                            : () async {
                                await widget.onInstall(
                                  _results[i].slug,
                                  _results[i].name,
                                );
                                await _refreshInstalledStatus();
                              },
                      ),
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Tools
//
// SKILLS vs TOOLS — the distinction that matters:
//
//   SKILLS   = npm packages that give the agent NEW CAPABILITIES
//              (weather, github, voice-call, coding-agent, ...)
//              Installed via: openclaw skills install <name>
//              Live in:       node_modules/@openclaw/<name>/
//
//   TOOLS    = PRIMITIVES the agent is PERMITTED to invoke
//              (browser, computer, files, search, shell, ...)
//              Configured in: openclaw.json → tools.allow[]
//              Think of them as the agent's OS-level permissions.
//              Skills USE tools. They're different layers.
//
// This tab shows both:
//   • Gateway tools   — from openclaw.json → live gateway capabilities
//   • Custom skills   — your device-native skills (avatar, TTS, hardware)
// ─────────────────────────────────────────────────────────────────────────────

// Full catalog of known OpenClaw primitive tools with descriptions.
const _toolCatalog = <String, _ToolMeta>{
  'browser':       _ToolMeta('Web Browser',       'Navigate URLs, extract content, fill forms', Icons.language_rounded,        'core'),
  'computer':      _ToolMeta('Computer Use',       'Execute shell commands and scripts',          Icons.code_rounded,             'core'),
  'files':         _ToolMeta('File System',         'Read, write and list local files',            Icons.folder_open_rounded,      'core'),
  'memory':        _ToolMeta('Memory Store',        'Persist facts and recall context across sessions', Icons.psychology_rounded,  'core'),
  'search':        _ToolMeta('Web Search',          'Search the web and fetch results',            Icons.search_rounded,           'network'),
  'image':         _ToolMeta('Image Generation',    'Generate images via local or cloud model',    Icons.palette_rounded,          'ai'),
  'canvas':        _ToolMeta('Canvas / Web UI',     'Render interactive web UIs in the canvas',   Icons.draw_rounded,             'ui'),
  'solana':        _ToolMeta('Solana Web3',         'Sign transactions and query on-chain data',   Icons.currency_bitcoin_rounded, 'web3'),
  'calculator':    _ToolMeta('Calculator',          'Evaluate mathematical expressions',           Icons.calculate_rounded,        'core'),
  'calendar':      _ToolMeta('Calendar',            'Read and create calendar events',             Icons.calendar_today_rounded,   'device'),
  'weather':       _ToolMeta('Weather',             'Fetch current conditions and forecasts',      Icons.cloud_rounded,            'network'),
  'shell':         _ToolMeta('Terminal Shell',      'Run arbitrary shell commands in PRoot',       Icons.terminal_rounded,         'core'),
  'twilio':        _ToolMeta('Twilio Voice',        'Make/receive calls via ConversationRelay',    Icons.phone_rounded,            'network'),
  'crypto':        _ToolMeta('Crypto Prices',       'Fetch live token prices and market data',     Icons.currency_exchange_rounded,'network'),
  'camera':        _ToolMeta('Camera',              'Capture photos and video via device camera',  Icons.camera_alt_rounded,       'device'),
  'location':      _ToolMeta('Location',            'Read device GPS coordinates',                 Icons.location_on_rounded,      'device'),
  'screen':        _ToolMeta('Screen Recording',    'Record or share the device screen',           Icons.screen_share_rounded,     'device'),
  'haptic':        _ToolMeta('Haptics',             'Trigger vibration and haptic patterns',       Icons.vibration_rounded,        'device'),
  'sensor':        _ToolMeta('Sensors',             'Read accelerometer, gyroscope, barometer',    Icons.sensors_rounded,          'device'),
};

const _categoryColors = <String, Color>{
  'core':    Color(0xFF4CAF50),
  'network': Color(0xFF2196F3),
  'ai':      Color(0xFF9C27B0),
  'web3':    Color(0xFF9945FF),
  'device':  Color(0xFFFF9800),
  'ui':      Color(0xFF00BCD4),
};

/// Metadata entry for the tool catalog.
class _ToolMeta {
  final String label;
  final String description;
  final IconData icon;
  final String category;
  const _ToolMeta(this.label, this.description, this.icon, this.category);
}

// Custom device-native skills (source: 'custom' in SkillsService)
const _customSkills = <_CustomSkillInfo>[
  _CustomSkillInfo(
    id: 'avatar-control',
    label: 'Avatar Control',
    description: 'Switch 3D VRM model, trigger gestures (wave, nod, bow…), set facial emotions. Wired to the live VrmAvatarWidget via AgentSkillServer.',
    icon: Icons.face_retouching_natural_rounded,
    actions: ['change_model', 'play_gesture', 'set_emotion', 'get_status'],
  ),
  _CustomSkillInfo(
    id: 'tts-voice',
    label: 'TTS Voice Control',
    description: 'Switch TTS engine (Piper / ElevenLabs / OpenAI / Native), change voice, or speak text from the agent. Wired to TtsService.',
    icon: Icons.record_voice_over_rounded,
    actions: ['set_engine', 'set_voice', 'speak', 'stop', 'get_status'],
  ),
  _CustomSkillInfo(
    id: 'device-node',
    label: 'Device Control',
    description: 'Vibrate, toggle flashlight, read battery level, get GPS, read sensors. Powered by the NodeProvider hardware capability layer.',
    icon: Icons.phonelink_setup_rounded,
    actions: ['vibrate', 'flashlight_on', 'flashlight_off', 'get_battery', 'get_location', 'read_sensor'],
  ),
];

class _CustomSkillInfo {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final List<String> actions;
  const _CustomSkillInfo({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.actions,
  });
}

class _ToolsTab extends StatefulWidget {
  const _ToolsTab();

  @override
  State<_ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<_ToolsTab> {
  // All 19 known tools always shown. _enabledTools reflects tools.allow in config.
  // Loaded once at init; updated immediately on toggle (optimistic UI).
  Set<String> _enabledTools = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEnabled();
  }

  Future<void> _loadEnabled() async {
    final tools = await OpenClawCommandService.getCoreTools();
    if (mounted) {
      setState(() {
        _enabledTools = tools.toSet();
        _loading = false;
      });
    }
  }

  Future<void> _toggle(String toolId) async {
    // Optimistic update — flip immediately, persist in background
    final newSet = Set<String>.from(_enabledTools);
    if (newSet.contains(toolId)) {
      newSet.remove(toolId);
    } else {
      newSet.add(toolId);
    }
    setState(() => _enabledTools = newSet);
    await OpenClawCommandService.saveToolsAllow(newSet.toList()..sort());
  }

  _ToolMeta _metaFor(String toolId) {
    final lower = toolId.toLowerCase();
    for (final entry in _toolCatalog.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return _ToolMeta(toolId, 'OpenClaw gateway tool', Icons.extension_rounded, 'core');
  }

  @override
  Widget build(BuildContext context) {
    final gatewayState = context.watch<GatewayProvider>().state;
    final isOffline = gatewayState.status == GatewayStatus.stopped;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // Always show all 19 known tools from the catalog so the user can
    // enable/disable them even when openclaw.json tools.allow is empty.
    // Live gateway capabilities are used ONLY to update _enabledTools on connect.
    final liveCapabilities = gatewayState.capabilities;
    if (liveCapabilities != null && liveCapabilities.isNotEmpty) {
      // Sync enabled set with what the running gateway actually exposes
      final liveSet = liveCapabilities.toSet();
      if (liveSet != _enabledTools) {
        // Schedule after build to avoid setState-during-build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && liveSet != _enabledTools) {
            setState(() => _enabledTools = liveSet);
          }
        });
      }
    }

    // Always use full catalog — never show empty state
    final allToolIds = _toolCatalog.keys.toList();

        return CustomScrollView(
          slivers: [
            // ── Skills–Tools explainer ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('CAPABILITY LAYER'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _pill('SKILLS', const Color(0xFF4CAF50)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'npm packages that give the agent new capabilities',
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _pill('TOOLS', const Color(0xFF2196F3)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'OS-level primitives the agent is permitted to invoke\n(configured in openclaw.json → tools.allow)',
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55), height: 1.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _pill('CUSTOM', const Color(0xFFFF9800)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'App-native skills bridged via AgentSkillServer (127.0.0.1:8765)',
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Custom device-native skills ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _sectionLabel('CUSTOM APP SKILLS'),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  'Device-native skills wired directly into the Flutter app — executed via AgentSkillServer on loopback port 8765.',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.38), height: 1.5),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CustomSkillCard(info: _customSkills[i]),
                  ),
                  childCount: _customSkills.length,
                ),
              ),
            ),

            // ── Gateway tools header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionLabel('GATEWAY TOOLS (openclaw.json)'),
                    if (!isOffline)
                      GestureDetector(
                        onTap: () {
                          context.read<GatewayProvider>().refreshRpcDiscovery();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Refreshing gateway tools…'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.refresh, size: 13, color: AppColors.statusGreen),
                            const SizedBox(width: 4),
                            Text('REFRESH',
                                style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    color: AppColors.statusGreen.withValues(alpha: 0.85))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  'Primitive capabilities the agent can invoke. Edit tools.allow in openclaw.json to add or remove.',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.38), height: 1.5),
                ),
              ),
            ),

            // ── Gateway offline notice ───────────────────────────────────
            if (isOffline)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.statusAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.power_off_rounded, size: 14, color: AppColors.statusAmber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gateway offline — showing last known config',
                            style: TextStyle(fontSize: 12, color: AppColors.statusAmber),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Tool cards — all 19 always shown with enable/disable toggles ──
            // Each tool maps to a _ToolCard with an inline Switch that writes to
            // openclaw.json → tools.allow via OpenClawCommandService.saveToolsAllow.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final toolId = allToolIds[i];
                    final enabled = _enabledTools.contains(toolId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ToolCard(
                        toolId: toolId,
                        meta: _metaFor(toolId),
                        isEnabled: enabled,
                        onToggle: () => _toggle(toolId),
                      ),
                    );
                  },
                  childCount: allToolIds.length,
                ),
              ),
            ),

            // ── RPC explorer quick-jump ───────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BotMethodExplorer(initialFilter: 'skills')),
                  ),
                  icon: const Icon(Icons.terminal_rounded, size: 18, color: Colors.purpleAccent),
                  label: Text(
                    'EXPLORE RPC METHODS',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.purpleAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    side: BorderSide(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
          ],
        );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
}


// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

Widget _sectionLabel(String text) => Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 10,
        letterSpacing: 2.0,
        color: AppColors.statusGreen.withValues(alpha: 0.85),
      ),
    );

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.statusGrey, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      );
}

class _RateLimitBanner extends StatelessWidget {
  final int secondsLeft;
  const _RateLimitBanner({required this.secondsLeft});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.statusAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.statusAmber.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_bottom_rounded,
                size: 14, color: AppColors.statusAmber),
            const SizedBox(width: 8),
            const Text(
              'ClawHub rate limited — resets in',
              style: TextStyle(fontSize: 12, color: AppColors.statusAmber),
            ),
            const Spacer(),
            Text(
              '${secondsLeft}s',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.statusAmber,
              ),
            ),
          ],
        ),
      );
}

// ── Installed skill card (My Skills grid) ────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final _SkillEntry skill;
  final bool isInstalled;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.skill,
    required this.isInstalled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isInstalled
              ? skill.color.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
          width: isInstalled ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: skill.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(skill.icon, color: skill.color, size: 20),
                    ),
                    const Spacer(),
                    Text(
                      skill.title,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skill.subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),
                    if (skill.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        skill.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            height: 1.2),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isInstalled
                        ? skill.color.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isInstalled
                          ? skill.color.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    isInstalled ? 'ACTIVE' : 'INSTALL',
                    style: TextStyle(
                      color: isInstalled ? skill.color : Colors.white54,
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
      ),
    );
  }
}

// ── Discover result card ──────────────────────────────────────────────────────

class _DiscoverCard extends StatelessWidget {
  final ClawHubSkill skill;
  final VoidCallback? onInstall;

  const _DiscoverCard({required this.skill, required this.onInstall});

  // Icon heuristics for known slug patterns
  IconData _iconFor(String slug) {
    final s = slug.toLowerCase();
    if (s.contains('weather')) return Icons.cloud_rounded;
    if (s.contains('github') || s.contains('git')) return Icons.code_rounded;
    if (s.contains('notion')) return Icons.article_rounded;
    if (s.contains('tmux') || s.contains('shell')) return Icons.terminal_rounded;
    if (s.contains('voice') || s.contains('call')) return Icons.phone_rounded;
    if (s.contains('search') || s.contains('web')) return Icons.search_rounded;
    if (s.contains('coding') || s.contains('code')) return Icons.developer_mode_rounded;
    if (s.contains('summar') || s.contains('text')) return Icons.summarize_rounded;
    if (s.contains('session') || s.contains('log')) return Icons.history_rounded;
    if (s.contains('calendar')) return Icons.calendar_today_rounded;
    if (s.contains('email') || s.contains('mail')) return Icons.mail_rounded;
    if (s.contains('file') || s.contains('folder')) return Icons.folder_rounded;
    if (s.contains('crypto') || s.contains('solana')) return Icons.currency_bitcoin_rounded;
    if (s.contains('image') || s.contains('photo')) return Icons.image_rounded;
    return Icons.extension_rounded;
  }

  Color _colorFor(String slug) {
    final s = slug.toLowerCase();
    if (s.contains('weather')) return const Color(0xFF2196F3);
    if (s.contains('github') || s.contains('git')) return const Color(0xFF6E40C9);
    if (s.contains('notion')) return Colors.white;
    if (s.contains('tmux') || s.contains('shell')) return const Color(0xFF4CAF50);
    if (s.contains('voice') || s.contains('call')) return const Color(0xFFF44336);
    if (s.contains('coding')) return const Color(0xFF00BCD4);
    if (s.contains('summar')) return const Color(0xFFFF9800);
    return AppColors.statusGreen;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(skill.slug);
    final icon  = _iconFor(skill.slug);

    return GestureDetector(
      onTap: () => showSkillDetailSheet(
        context,
        slug: skill.slug,
        initialName: skill.name.isNotEmpty ? skill.name : skill.slug,
        initialDescription: skill.description,
        isInstalled: skill.isInstalled,
        accentColor: color,
        icon: icon,
        onInstall: onInstall != null
            ? (slug, name) async => onInstall!()
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: skill.isInstalled
              ? color.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: skill.isInstalled
                ? color.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            // Name + meta + stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          skill.name.isNotEmpty ? skill.name : skill.slug,
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white),
                        ),
                      ),
                      if (skill.isInstalled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text('ACTIVE',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                  if (skill.version.isNotEmpty || skill.author.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (skill.version.isNotEmpty) 'v${skill.version}',
                        if (skill.author.isNotEmpty) skill.author,
                      ].join(' · '),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.32),
                          fontSize: 10),
                    ),
                  ],
                  if (skill.description.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      skill.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          height: 1.4),
                    ),
                  ],
                  // Live stats mini-row
                  if (skill.hasStats) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (skill.stars != null)
                          _miniStat(Icons.star_rounded,
                              _fmt(skill.stars!), const Color(0xFFFFC107)),
                        if (skill.currentInstalls != null) ...[
                          const SizedBox(width: 10),
                          _miniStat(Icons.devices_rounded,
                              _fmt(skill.currentInstalls!), AppColors.statusGreen),
                        ],
                        if (skill.downloadCount != null) ...[
                          const SizedBox(width: 10),
                          _miniStat(Icons.download_rounded,
                              _fmt(skill.downloadCount!), const Color(0xFF2196F3)),
                        ],
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            size: 16, color: Colors.white.withValues(alpha: 0.18)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // GET button (quick install, no sheet)
            if (!skill.isInstalled && onInstall != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onInstall,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'GET',
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String val, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 3),
          Text(val,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600)),
        ],
      );

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
    return n.toString();
  }
}

// ── Tool row (Tools tab) ──────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Tool card — gateway primitive tool with category badge + description
// ─────────────────────────────────────────────────────────────────────────────

class _ToolCard extends StatelessWidget {
  final String toolId;
  final _ToolMeta meta;
  // When provided, shows a toggle Switch instead of the info chevron.
  // isEnabled reflects current tools.allow state; onToggle writes the change.
  final bool? isEnabled;
  final VoidCallback? onToggle;
  const _ToolCard({
    required this.toolId,
    required this.meta,
    this.isEnabled,
    this.onToggle,
  });

  void _showToolDetail(BuildContext context) {
    final catColor = _categoryColors[meta.category] ?? AppColors.statusGreen;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F1117),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: catColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(meta.icon, color: catColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meta.label,
                          style: GoogleFonts.outfit(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${meta.category.toUpperCase()} TOOL  ·  ALWAYS ON',
                          style: TextStyle(
                              color: catColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // What is this?
            Text('What this tool does',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.white.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Text(
              meta.description,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.6),
            ),
            const SizedBox(height: 18),
            // Explanation card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Colors.white38),
                    const SizedBox(width: 6),
                    Text('Skills vs Tools',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.55))),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Tools are OS-level permissions that the agent is '
                    'allowed to use. Skills USE these tools to perform '
                    'tasks. Configure which tools are active by editing '
                    'tools.allow[] in openclaw.json.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                        height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Config snippet
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(children: [
                const Icon(Icons.terminal_rounded,
                    size: 13, color: Colors.white38),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'tools.allow[] → "$toolId"',
                    style: GoogleFonts.firaCode(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Got it'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColors[meta.category] ?? AppColors.statusGreen;
    return GestureDetector(
      onTap: () => _showToolDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, size: 16, color: catColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        meta.label,
                        style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          meta.category.toUpperCase(),
                          style: TextStyle(
                              color: catColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.description,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Toggle switch when onToggle provided, otherwise info chevron
            if (onToggle != null)
              Transform.scale(
                scale: 0.78,
                child: Switch(
                  value: isEnabled ?? false,
                  onChanged: (_) => onToggle!(),
                  activeThumbColor: catColor,
                  activeTrackColor: catColor.withValues(alpha: 0.25),
                  inactiveThumbColor: Colors.white24,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.18)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom skill card — app-native skill with action chips
// ─────────────────────────────────────────────────────────────────────────────

class _CustomSkillCard extends StatelessWidget {
  final _CustomSkillInfo info;
  const _CustomSkillCard({required this.info});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFF9800);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(info.icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.label,
                        style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(
                      'AgentSkillServer · 127.0.0.1:8765',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.35),
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'CUSTOM',
                  style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            info.description,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: info.actions
                .map((a) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        a,
                        style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Local LLM pinned card ─────────────────────────────────────────────────────

class _LocalLlmCard extends StatelessWidget {
  final LocalLlmState llmState;
  final VoidCallback onTap;
  const _LocalLlmCard({required this.llmState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0097A7);
    final status = llmState.status;
    final badgeText = status == LocalLlmStatus.ready
        ? 'READY'
        : status == LocalLlmStatus.downloading
            ? '${(llmState.downloadProgress * 100).toInt()}%'
            : status == LocalLlmStatus.installing
                ? 'BUILDING'
                : status == LocalLlmStatus.error
                    ? 'ERROR'
                    : 'OFFLINE';
    final badgeColor = status == LocalLlmStatus.ready
        ? AppColors.statusGreen
        : status == LocalLlmStatus.error
            ? AppColors.statusRed
            : status == LocalLlmStatus.idle
                ? Colors.white38
                : Colors.blueAccent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.memory_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Local LLM',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    'llama-server · on-device · no API key',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11),
                  ),
                  if (llmState.errorMessage != null &&
                      status != LocalLlmStatus.idle) ...[
                    const SizedBox(height: 4),
                    Text(
                      llmState.errorMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.statusGrey, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── MoltLaunch register banner ────────────────────────────────────────────────

class _MoltLaunchBanner extends StatelessWidget {
  final bool isInstalled;
  final VoidCallback onRegister;
  const _MoltLaunchBanner(
      {required this.isInstalled, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    if (isInstalled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded,
                color: Colors.orange, size: 16),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'MoltLaunch agent registered · Work skill active',
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
    // Preview state — page exists, tap to open it
    return GestureDetector(
      onTap: onRegister,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.orange.withValues(alpha: 0.06),
            Colors.deepOrange.withValues(alpha: 0.03),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
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
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MoltLaunch — On-chain Agent Jobs',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 2),
                  Text(
                    'AI job marketplace · ERC-8004 identity · ETH escrow on Base',
                    style: TextStyle(
                        color: AppColors.statusGrey, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.orange, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Solana built-in card ──────────────────────────────────────────────────────

class _SolanaBuiltInCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SolanaScreen())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF9945FF).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF9945FF), Color(0xFF14F195)]),
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
                    'Send SOL, swap via Jupiter DEX, view balances. No install needed.',
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
  final String? tooltip;

  const _SkillEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    this.tooltip,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheets
// ─────────────────────────────────────────────────────────────────────────────

class _InstallPromptSheet extends StatelessWidget {
  final _SkillEntry skill;
  final VoidCallback onInstall;
  final VoidCallback? onExplore;

  const _InstallPromptSheet({
    required this.skill,
    required this.onInstall,
    this.onExplore,
  });

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
                    Text(skill.title,
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800, fontSize: 20)),
                    Text(skill.subtitle,
                        style: const TextStyle(
                            color: AppColors.statusGrey, fontSize: 13)),
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
              child: Text(skill.description,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.statusGrey)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
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
                      style: TextStyle(
                          fontSize: 12, color: AppColors.statusAmber),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (onExplore != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onExplore,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Explore'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  )
                else
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
              'Installing $skillTitle…',
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
