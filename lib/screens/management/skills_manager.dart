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

// ─────────────────────────────────────────────────────────────────────────────
// Premium skill metadata catalogue.
// Used ONLY as a display-metadata lookup — never as an "available to install"
// list.  Skills appear in My Skills only when the gateway confirms they are
// installed.  Skills marked comingSoon=true show an info sheet instead of an
// install prompt until their ClawHub registry slug is confirmed.
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
    comingSoon: true,
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
    comingSoon: true,
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
    comingSoon: true,
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
    comingSoon: true,
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
        'Downloads a GGUF model (Qwen2.5-1.5B recommended) and runs llama-server as a sibling process inside PRoot. OpenClaw routes to localhost:8081 when enabled. CPU-only for stability.',
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
    if (skill.comingSoon) {
      _showInstallPrompt(context, skill);
      return;
    }
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
    if (skill.comingSoon) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _ComingSoonSheet(skill: skill),
      );
      return;
    }
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
        orElse: () => _SkillEntry(
          id: id,
          title: (s['title'] ?? s['name'] ?? id).toString(),
          subtitle: (s['author'] ?? 'Plugin').toString(),
          description:
              (s['description'] ?? 'An installed OpenClaw skill.').toString(),
          icon: Icons.extension_rounded,
          color: Colors.blueGrey,
        ),
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
        // ── Premium skills grid — always shows all 6 cards ───────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
            child: _sectionLabel('PREMIUM AGENT SERVICES'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
            delegate: SliverChildListDelegate([
              for (final skill in mergedSkills)
                _ServiceCard(
                  skill: skill,
                  isInstalled: installedIds.contains(skill.id) ||
                      installedIds.any((id) =>
                          id.contains(skill.id) ||
                          id.contains(skill.id.replaceAll('-', '_'))),
                  onTap: () {
                    final installed = installedIds.contains(skill.id) ||
                        installedIds.any((id) =>
                            id.contains(skill.id) ||
                            id.contains(skill.id.replaceAll('-', '_')));
                    if (installed || skill.comingSoon) {
                      widget.onNavigate(skill.id);
                    } else {
                      widget.onShowPrompt(skill);
                    }
                  },
                ),
            ]),
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(
                  isPremium
                      ? Icons.verified_rounded
                      : Icons.extension_rounded,
                  color: isPremium
                      ? AppColors.statusGreen
                      : AppColors.statusGrey,
                  size: 20,
                ),
                title: Text(
                  skillTitle,
                  style: GoogleFonts.firaCode(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  skillDesc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.4)),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_document,
                          size: 14, color: Colors.white70),
                      SizedBox(width: 6),
                      Text('EDIT',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70)),
                    ],
                  ),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          SkillConfigEditor(skillId: skillId)),
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
  // These should be confirmed valid registry slugs (update as Grok verifies more).
  static const _featuredSlugs = <String>[
    'local-llm',
    'solana-agent',
    'browser-use',
    'code-sandbox',
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
      if (mounted) setState(() => _loading = false);
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
      if (mounted) setState(() => _loading = false);
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
// Live view of the gateway's openclaw.json tools.allow list.
// Zero hardcoding.
// ─────────────────────────────────────────────────────────────────────────────

class _ToolsTab extends StatefulWidget {
  const _ToolsTab();

  @override
  State<_ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<_ToolsTab> {
  // Stored once in initState so FutureBuilder never re-fires on gateway rebuilds.
  late final Future<List<String>> _toolsFuture;

  static const _iconMap = {
    'browser': Icons.language_rounded,
    'computer': Icons.code_rounded,
    'files': Icons.folder_open_rounded,
    'memory': Icons.memory_rounded,
    'image': Icons.palette_rounded,
    'solana': Icons.currency_bitcoin_rounded,
    'canvas': Icons.draw_rounded,
    'search': Icons.search_rounded,
    'calculator': Icons.calculate_rounded,
    'calendar': Icons.calendar_today_rounded,
    'weather': Icons.cloud_rounded,
    'crypto': Icons.currency_exchange_rounded,
    'twilio': Icons.phone_rounded,
    'shell': Icons.terminal_rounded,
  };

  @override
  void initState() {
    super.initState();
    _toolsFuture = OpenClawCommandService.getCoreTools();
  }

  IconData _iconFor(String toolId) {
    final lower = toolId.toLowerCase();
    for (final entry in _iconMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return Icons.extension_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _toolsFuture,
      builder: (context, snap) {
        final gatewayState = context.watch<GatewayProvider>().state;
        final isOffline = gatewayState.status == GatewayStatus.stopped;

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        // Prefer live gateway capabilities if available, fall back to config file
        final liveCapabilities = gatewayState.capabilities;
        final tools = liveCapabilities?.isNotEmpty == true
            ? liveCapabilities!
            : snap.data ?? [];

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('ACTIVE GATEWAY TOOLS'),
                    const SizedBox(height: 6),
                    Text(
                      'Tools enabled in your running OpenClaw instance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                    if (isOffline) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.statusAmber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.statusAmber
                                  .withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.power_off_rounded,
                                size: 14, color: AppColors.statusAmber),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Gateway offline — showing last known config',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.statusAmber),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (tools.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.build_circle_outlined,
                  message: isOffline
                      ? 'Start your gateway to view active tools'
                      : 'No tools listed in openclaw.json',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ToolRow(
                          toolId: tools[i], icon: _iconFor(tools[i])),
                    ),
                    childCount: tools.length,
                  ),
                ),
              ),
            // ── RPC explorer quick-jump ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BotMethodExplorer(
                            initialFilter: 'skills')),
                  ),
                  icon: const Icon(Icons.terminal_rounded,
                      size: 18, color: Colors.purpleAccent),
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
                    side: BorderSide(
                        color: Colors.purpleAccent.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
          child: Padding(
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
              ],
            ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: skill.isInstalled
              ? AppColors.statusGreen.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.extension_rounded,
                color: Colors.white54, size: 20),
          ),
          const SizedBox(width: 14),
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
                          color: AppColors.statusGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('ACTIVE',
                            style: TextStyle(
                                color: AppColors.statusGreen,
                                fontSize: 8,
                                fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
                if (skill.version.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${skill.slug}  ·  v${skill.version}'
                    '${skill.author.isNotEmpty ? "  ·  ${skill.author}" : ""}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10),
                  ),
                ],
                if (skill.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    skill.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!skill.isInstalled)
            TextButton(
              onPressed: onInstall,
              style: TextButton.styleFrom(
                backgroundColor:
                    AppColors.statusGreen.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'INSTALL',
                style: TextStyle(
                    color: AppColors.statusGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Tool row (Tools tab) ──────────────────────────────────────────────────────

class _ToolRow extends StatelessWidget {
  final String toolId;
  final IconData icon;
  const _ToolRow({required this.toolId, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: AppColors.statusGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              toolId,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
      );
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
  /// True when the ClawHub registry slug is unconfirmed.
  /// Shows an info sheet instead of an install prompt.
  final bool comingSoon;

  const _SkillEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    this.tooltip,
    this.comingSoon = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheets
// ─────────────────────────────────────────────────────────────────────────────

class _ComingSoonSheet extends StatelessWidget {
  final _SkillEntry skill;
  const _ComingSoonSheet({required this.skill});

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
                Expanded(
                  child: Column(
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
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.statusAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('SOON',
                      style: TextStyle(
                          color: AppColors.statusAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0)),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.statusAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.statusAmber.withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 16, color: AppColors.statusAmber),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This skill is coming soon. The install channel is being set up '
                      'with the provider — check the Discover tab after the next update.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.statusAmber,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallPromptSheet extends StatelessWidget {
  final _SkillEntry skill;
  final VoidCallback onInstall;

  const _InstallPromptSheet(
      {required this.skill, required this.onInstall});

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
