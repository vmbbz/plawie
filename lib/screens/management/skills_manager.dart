import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';
import '../../models/gateway_state.dart';
import '../../app.dart';
import '../../widgets/glass_card.dart';
import 'skills/agent_wallet_page.dart';
import 'skills/agent_work_page.dart';
import 'skills/agent_credit_page.dart';
import 'skills/agent_calls_page.dart';
import 'skills/agent_moonpay_page.dart';
import 'local_llm_screen.dart';
import '../../services/local_llm_service.dart';
import '../solana_screen.dart';
import 'bot_method_explorer.dart';
import 'skills/skill_config_editor.dart';
import '../../services/native_bridge.dart';
import '../../services/openclaw_service.dart';
import 'dart:async';

/// Catalogue of premium skills we offer, mapped to their OpenClaw skill names.
/// These are the 4 special skills the user explicitly wants to surface.
const _premiumSkills = [
  _SkillEntry(
    id: 'agent-card',
    title: 'Wallet',
    subtitle: 'AgentCard.ai',
    description: 'Issue virtual Visa cards, manage balances, and make autonomous payments for your AI agent.',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF3D52D5), // AgentCard navy
    tooltip: 'AgentCard.ai gives your agent a virtual Visa card with real spending power. Your agent can create cards, top them up, check balances, and make autonomous payments — all on-chain on Base.',
  ),
  _SkillEntry(
    id: 'molt-launch',
    title: 'Work',
    subtitle: 'MoltLaunch',
    description: 'Get hired for AI agent work. Escrow payments on Base chain. ERC-8004 identity + reputation.',
    icon: Icons.work_rounded,
    color: Colors.orangeAccent,
    tooltip: 'MoltLaunch is an on-chain job marketplace for AI agents. Your agent gets an ERC-8004 identity NFT on Base, can browse posted jobs, bid, and receive ETH escrow payments on completion.',
  ),
  _SkillEntry(
    id: 'valeo-sentinel',
    title: 'Credit',
    subtitle: 'Valeo Sentinel',
    description: 'x402 spending policy for autonomous agents — per-call, hourly & daily budget caps.',
    icon: Icons.credit_score_rounded,
    color: AppColors.statusGreen,
    tooltip: 'Valeo Sentinel enforces x402 protocol spending rules on your agent. Set per-call, hourly, daily, and lifetime USD budget caps. Every payment is audit-logged on-chain so you can review exactly what your agent spent.',
  ),
  _SkillEntry(
    id: 'twilio-voice',
    title: 'Calls',
    subtitle: 'Twilio AI',
    description: 'ConversationRelay voice orchestration — inbound/outbound with real-time AI transcription.',
    icon: Icons.phone_android_rounded,
    color: Colors.redAccent,
    tooltip: 'Your agent can make and receive phone calls, transcribe conversations in real-time using Deepgram, and orchestrate AI-driven call flows via Twilio ConversationRelay.',
  ),
  _SkillEntry(
    id: 'moonpay',
    title: 'Finance',
    subtitle: 'MoonPay',
    description: 'Verified agent bank account + 30 financial skills: swap, bridge, buy/sell, DCA, live prices.',
    icon: Icons.currency_exchange_rounded,
    color: Color(0xFF7B2FBE),
    tooltip: 'Give your agent a verified bank account. It can swap tokens, bridge cross-chain, buy/sell crypto via fiat, check portfolio, and run DCA strategies — all from natural language commands in chat.',
  ),
  _SkillEntry(
    id: 'local-llm',
    title: 'Local LLM',
    subtitle: 'llama-server',
    description: 'Run a free, offline LLM on-device via llama-server inside PRoot. No API key. No internet. Total privacy.',
    icon: Icons.memory_rounded,
    color: Color(0xFF0097A7),
    tooltip: 'Downloads a GGUF model (Qwen2.5-1.5B recommended) and runs llama-server as a sibling process inside PRoot. OpenClaw routes to localhost:8081 when enabled. CPU-only for stability. Thread count adjustable. Automatic cloud fallback if the server is offline.',
  ),
];

/// Fallback OpenClaw built-in capabilities (factual, used when gateway is offline).
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
  String? _loadError;
  StreamSubscription<LocalLlmState>? _llmSubscription;
  LocalLlmState _llmState = const LocalLlmState();

  @override
  void initState() {
    super.initState();
    
    // Listen to local LLM state for reactive "Premium" card updates
    _llmSubscription = LocalLlmService().stateStream.listen((state) {
      if (mounted) setState(() => _llmState = state);
    });
    // Set initial state
    _llmState = LocalLlmService().state;
  }

  @override
  void dispose() {
    _llmSubscription?.cancel();
    super.dispose();
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
      
      // Execute the native CLI installer inside PRoot.
      // runInProot throws PlatformException on non-zero exit, so wrap each attempt in try/catch.
      final installCmd = await OpenClawCommandService.getSkillInstallCommand(skill.id);
      String cliResult;
      try {
        cliResult = await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && $installCmd',
          timeout: 45,
        );
      } catch (_) {
        // Stage 1 failed (e.g. 'unknown command skill' on older gateways) — fall through to clawhub
        cliResult = 'error:';
      }
      // Fallback: if version-specific syntax failed, try npx clawhub install
      if (cliResult.toLowerCase().contains('error:') ||
          cliResult.toLowerCase().contains('too many arguments') ||
          cliResult.toLowerCase().contains('unknown command')) {
        cliResult = await NativeBridge.runInProot(
          'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && npx clawhub install ${skill.id}',
          timeout: 60,
        );
      }

      // We still invoke the RPC so the running gateway daemon hot-reloads the skill into memory
      Map<String, dynamic> rpcResult = {};
      try {
        if (provider.state.status == GatewayStatus.running) {
          rpcResult = await provider.invoke('skills.install', {
            'name': skill.id,
            'installId': '${skill.id}_${DateTime.now().millisecondsSinceEpoch}',
          });
        }
      } catch (e) {
        // Ignore RPC failures if CLI succeeded
      }

      navigator.pop(); // Close the bottom sheet

      // Consider it a success if the CLI didn't throw an exception and didn't output an obvious error
      final lowerResult = cliResult.toLowerCase();
      if (!lowerResult.contains('error:') && !lowerResult.contains('failed')) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ ${skill.title} skill installed successfully!'),
            backgroundColor: AppColors.statusGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Refresh local UI instantly without waiting on gateway loops
      } else {
        final errMsg = rpcResult['error']?['message']?.toString() ??
            rpcResult['payload']?['error']?.toString() ??
            'CLI Output: $cliResult';
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
      case 'agent-card':
        page = const AgentWalletPage();
        break;
      case 'molt-launch':
        page = const AgentWorkPage();
        break;
      case 'valeo-sentinel':
        page = const AgentCreditPage();
        break;
      case 'twilio-voice':
        page = const AgentCallsPage();
        break;
      case 'moonpay':
        page = const AgentMoonPayPage();
        break;
      case 'local-llm':
        page = const LocalLlmScreen();
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final gatewayState = context.watch<GatewayProvider>().state;
    final rawSkills = gatewayState.activeSkills ?? [];
    
    final installedSkillIds = rawSkills
        .map((s) => (s['id'] ?? s['name'] ?? s['skillId'])?.toString().toLowerCase() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final bool isGatewayLoading = gatewayState.status == GatewayStatus.starting;

    // 1. Dynamic Map of Installed Skills (borrowing aesthetic from premium catalogue if available)
    final List<_SkillEntry> dynamicInstalledSkills = rawSkills.map((s) {
      final id = (s['id'] ?? s['name'] ?? s['skillId'])?.toString().toLowerCase() ?? '';
      
      final known = _premiumSkills.firstWhere(
        (p) => p.id == id,
        orElse: () => _SkillEntry(
          id: id,
          title: (s['title'] ?? s['name'] ?? id).toString(),
          subtitle: (s['author'] ?? 'Plugin').toString(),
          description: (s['description'] ?? 'An OpenClaw integrated skill.').toString(),
          icon: Icons.extension_rounded,
          color: Colors.blueGrey,
          tooltip: (s['description'] ?? 'An OpenClaw integrated skill.').toString(),
        ),
      );

      return _SkillEntry(
        id: known.id,
        title: s['title'] != null ? s['title'].toString() : known.title,
        subtitle: s['name'] != null ? s['name'].toString() : known.subtitle,
        description: s['description'] != null ? s['description'].toString() : known.description,
        icon: known.icon,
        color: known.color,
        tooltip: s['description'] != null ? s['description'].toString() : known.tooltip,
      );
    }).where((s) => s.id.isNotEmpty).toList();

    // 2. Uninstalled Premium Catalogue
    final List<_SkillEntry> availableCatalog = _premiumSkills
        .where((p) => !_isInstalled(installedSkillIds, p))
        .toList();

    // 3. Merged List for UI
    final List<_SkillEntry> mergedSkills = [
      ...dynamicInstalledSkills,
      ...availableCatalog,
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Nebula background
          const NebulaBg(),
          // Scrollable content
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(context, 'Premium Agent Services'),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to activate • Expands your bot\'s real-world capabilities',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
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
                        isInstalled: _isInstalled(installedSkillIds, skill),
                        isLoading: isGatewayLoading,
                        llmState: _llmState,
                        onTap: () {
                          if (_isInstalled(installedSkillIds, skill)) {
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
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _buildMoltLaunchRegisterBanner(context, installedSkillIds),
                ),
              ),
              // Solana built-in section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                  child: _buildSolanaBuiltInCard(context),
                ),
              ),
              // Core capabilities section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(context, 'Core Capability Toolkit'),
                      const SizedBox(height: 6),
                      Text(
                        'Built-in tools available in every OpenClaw gateway',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCoreToolkit(context, gatewayState.capabilities),
                      const SizedBox(height: 32),
                      _buildQuickJump(context),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              // Dynamic Installed Skills (2-way editor)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(context, 'Workspace Configurations (2-Way Sync)'),
                      const SizedBox(height: 6),
                      Text(
                        'Directly edit raw SKILL.yaml and configuration manifests for installed items on the OpenClaw instance.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildRawInstalledSkillsList(context, rawSkills, isGatewayLoading),
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

  Widget _buildRawInstalledSkillsList(BuildContext context, List<Map<String, dynamic>> rawSkills, bool isLoading) {
    if (isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      ));
    }
    
    if (rawSkills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Center(
          child: Text('No active skills detected on gateway.', style: TextStyle(color: AppColors.statusGrey, fontSize: 12)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rawSkills.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final skill = rawSkills[index];
        final skillId = (skill['id'] ?? skill['name'] ?? skill['skillId'])?.toString().toLowerCase() ?? '';
        final skillTitle = (skill['title'] ?? skill['name'] ?? skillId).toString();
        final skillDesc = (skill['description'] ?? 'SKILL.yaml Workspace Binding').toString();
        
        final isPremium = _premiumSkills.any((s) => s.id == skillId);
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(
              isPremium ? Icons.verified_rounded : Icons.extension_rounded, 
              color: isPremium ? AppColors.statusGreen : AppColors.statusGrey,
              size: 20
            ),
            title: Text(skillTitle, style: GoogleFonts.firaCode(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(skillDesc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_document, size: 14, color: Colors.white70),
                  SizedBox(width: 6),
                  Text('EDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70)),
                ],
              ),
            ),
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => SkillConfigEditor(skillId: skillId))
              );
            },
          ),
        );
      },
    );
  }

  bool _isInstalled(Set<String> installedSkillIds, _SkillEntry skill) {
    // Normalize comparison to handle package variations (matching hyphens vs underscores)
    final searchId = skill.id.replaceAll('_', '-');
    return installedSkillIds.any((id) => 
      id.contains(searchId) || 
      id.contains(skill.id.replaceAll('-', '_'))
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 10,
        letterSpacing: 2.0,
        color: AppColors.statusGreen.withValues(alpha: 0.85),
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
            onTap: () => Provider.of<GatewayProvider>(context, listen: false).checkHealth(),
            child: const Icon(Icons.refresh,
                size: 16, color: AppColors.statusAmber),
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
            'AGENT SKILLS',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 3.0,
              color: Colors.white,
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
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          tooltip: 'Refresh skills',
          onPressed: () => Provider.of<GatewayProvider>(context, listen: false).checkHealth(),
        ),
      ],
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

  Widget _buildCoreToolkit(BuildContext context, List<String>? liveCapabilities) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use live capabilities if available, otherwise fallback to defaults
    final caps = <Widget>[];
    if (liveCapabilities != null && liveCapabilities.isNotEmpty) {
      for (final capName in liveCapabilities) {
        // Map string names to icons if possible, or use a generic extension icon
        IconData icon;
        if (capName.contains('browser')) icon = Icons.language_rounded;
        else if (capName.contains('computer')) icon = Icons.code_rounded;
        else if (capName.contains('files')) icon = Icons.folder_open_rounded;
        else if (capName.contains('memory')) icon = Icons.memory_rounded;
        else if (capName.contains('image')) icon = Icons.palette_rounded;
        else if (capName.contains('solana')) icon = Icons.currency_bitcoin_rounded;
        else icon = Icons.extension_rounded;
        
        caps.add(_buildCapabilityPill(context, _CapabilityEntry(capName, icon, capName)));
      }
    } else {
      caps.addAll(_defaultCapabilities.map((cap) => _buildCapabilityPill(context, cap)));
    }

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
                    '${liveCapabilities?.length ?? _defaultCapabilities.length} tools always available',
                    style: const TextStyle(
                        color: AppColors.statusGrey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...caps,
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
  Widget _buildMoltLaunchRegisterBanner(BuildContext context, Set<String> installedSkillIds) {
    final workSkill = _premiumSkills.firstWhere((s) => s.id == 'molt-launch');
    final isInstalled = installedSkillIds.any((id) => id.contains(workSkill.id));

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

class _CapabilityEntry {
  final String label;
  final IconData icon;
  final String id;
  const _CapabilityEntry(this.label, this.icon, this.id);
}

class _ServiceCard extends StatelessWidget {
  final _SkillEntry skill;
  final bool isInstalled;
  final bool isLoading;
  final LocalLlmState llmState;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.skill,
    required this.isInstalled,
    required this.isLoading,
    required this.llmState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReady = isInstalled || (skill.id == 'local_llm' && llmState.status == LocalLlmStatus.ready);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isReady ? skill.color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
          width: isReady ? 1.5 : 1.0,
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skill.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white24),
                      )
                    : isInstalled
                        ? _buildBadge(skill.color, 'ACTIVE')
                        : (skill.id == 'local_llm' && llmState.status != LocalLlmStatus.idle)
                            ? _buildLlmBadge(llmState)
                            : _buildBadge(Colors.white.withValues(alpha: 0.4), 'INSTALL'),
              ),
              if (skill.tooltip != null)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: skill.color.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildLlmBadge(LocalLlmState state) {
    final color = state.status == LocalLlmStatus.ready ? AppColors.statusGreen : Colors.blueAccent;
    final text = state.status == LocalLlmStatus.ready 
        ? 'READY' 
        : state.status == LocalLlmStatus.downloading 
            ? '${(state.downloadProgress * 100).toInt()}%' 
            : 'STARTING';
    return _buildBadge(color, text);
  }
}


/// Overlay that shows a tooltip over the skill card for 4 seconds
class _SkillTooltipOverlay extends StatefulWidget {
  final String message;
  final Color color;
  const _SkillTooltipOverlay({required this.message, required this.color});

  @override
  State<_SkillTooltipOverlay> createState() => _SkillTooltipOverlayState();
}

class _SkillTooltipOverlayState extends State<_SkillTooltipOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _opacity,
          child: Align(
            alignment: const Alignment(0, 0.4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E).withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.color.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.psychology_outlined, color: widget.color, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
