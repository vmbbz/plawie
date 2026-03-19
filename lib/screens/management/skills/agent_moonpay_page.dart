import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app.dart';
import '../../../services/gateway_skill_proxy.dart';

/// MoonPay Agents — Skill Detail Page
///
/// MoonPay gives your AI agent a verified bank account + 30+ financial skills
/// via the @moonpay/cli MCP server. Once connected in OpenClaw, the agent gains
/// natural-language access to:
///   • Portfolio checks across ETH/BTC/SOL/USDC
///   • Token swaps (on-chain), cross-chain bridges
///   • Fiat buy/sell onramps
///   • Dollar-cost averaging (DCA) strategies
///   • Live market prices
///
/// MoonPay CLI runs as an MCP server inside your gateway:
///   npm install -g @moonpay/cli
///   mp login && mp wallet create MyWallet
///   (configure in openclaw.yaml → mcp.servers)
///
/// AGENT PROMPT GUIDE (inject into system prompt for maximum capability):
/// ───────────────────────────────────────────────────────────────────────
/// You have access to the MoonPay financial toolkit via MCP.
/// Commands you can call:
///   moonpay.get_portfolio — list all wallet balances across chains
///   moonpay.get_price { token } — current USD price + 24h change
///   moonpay.swap { from_token, to_token, amount } — execute on-chain swap
///   moonpay.bridge { token, from_chain, to_chain, amount } — cross-chain bridge
///   moonpay.buy { token, amount_usd } — fiat onramp
///   moonpay.sell { token, amount } — fiat offramp
///   moonpay.dca_list — list active DCA strategies
///   moonpay.dca_create { token, amount_usd, frequency } — new DCA strategy
/// Always confirm with the user before executing swaps, bridges or buys.
/// ───────────────────────────────────────────────────────────────────────

class AgentMoonPayPage extends StatefulWidget {
  const AgentMoonPayPage({super.key});

  @override
  State<AgentMoonPayPage> createState() => _AgentMoonPayPageState();
}

class _AgentMoonPayPageState extends State<AgentMoonPayPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isMoonPayConnected = false;
  String? _errorMessage;

  // Portfolio data
  List<_WalletBalance> _balances = [];
  double _totalUsdValue = 0;

  // Market prices
  List<_TokenPrice> _prices = [];

  // DCA strategies
  List<_DcaStrategy> _dcaStrategies = [];

  late final AnimationController _shimmerController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final proxy = GatewaySkillProxy();
    if (!proxy.isAttached) {
      setState(() {
        _isLoading = false;
        _isMoonPayConnected = false;
        _errorMessage = 'Gateway not connected. Start the gateway to load MoonPay data.';
        _balances = _offlineBalances();
        _prices = _offlinePrices();
        _dcaStrategies = [];
      });
      return;
    }

    try {
      // Fetch portfolio
      final portfolioResult = await proxy.execute('moonpay', 'get_portfolio');
      final wallets = portfolioResult['wallets'] as List? ?? [];
      final List<_WalletBalance> balances = [];
      double total = 0;
      for (final w in wallets) {
        final chainBalances = w['balances'] as List? ?? [];
        for (final b in chainBalances) {
          final usd = (b['usd_value'] as num?)?.toDouble() ?? 0;
          total += usd;
          balances.add(_WalletBalance(
            chain: w['chain']?.toString() ?? '?',
            token: b['token']?.toString() ?? '?',
            amount: (b['amount'] as num?)?.toDouble() ?? 0,
            usdValue: usd,
          ));
        }
      }

      // Fetch prices
      final priceResult = await proxy.execute('moonpay', 'get_price', params: {
        'tokens': ['ETH', 'BTC', 'SOL', 'USDC'],
      });
      final rawPrices = priceResult['prices'] as List? ?? [];
      final prices = rawPrices.map((p) => _TokenPrice(
        token: p['token']?.toString() ?? '',
        usd: (p['usd'] as num?)?.toDouble() ?? 0,
        change24h: (p['change_24h'] as num?)?.toDouble() ?? 0,
      )).toList();

      // Fetch DCA strategies
      final dcaResult = await proxy.execute('moonpay', 'dca_list');
      final rawDca = dcaResult['strategies'] as List? ?? [];
      final dcaStrategies = rawDca.map((d) => _DcaStrategy(
        id: d['id']?.toString() ?? '',
        token: d['token']?.toString() ?? '',
        amountUsd: (d['amount_usd'] as num?)?.toDouble() ?? 0,
        frequency: d['frequency']?.toString() ?? '',
        nextRun: d['next_run']?.toString() ?? '',
        active: d['active'] as bool? ?? false,
      )).toList();

      setState(() {
        _isLoading = false;
        _isMoonPayConnected = true;
        _balances = balances.isEmpty ? _offlineBalances() : balances;
        _totalUsdValue = total;
        _prices = prices.isEmpty ? _offlinePrices() : prices;
        _dcaStrategies = dcaStrategies;
      });
    } on SkillProxyException catch (e) {
      setState(() {
        _isLoading = false;
        _isMoonPayConnected = false;
        _errorMessage = e.message;
        _balances = _offlineBalances();
        _prices = _offlinePrices();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isMoonPayConnected = false;
        _errorMessage = 'MoonPay CLI not configured. Run: npm install -g @moonpay/cli';
        _balances = _offlineBalances();
        _prices = _offlinePrices();
      });
    }
  }

  List<_WalletBalance> _offlineBalances() => [
    _WalletBalance(chain: 'Ethereum', token: 'ETH', amount: 0, usdValue: 0),
    _WalletBalance(chain: 'Base', token: 'USDC', amount: 0, usdValue: 0),
    _WalletBalance(chain: 'Bitcoin', token: 'BTC', amount: 0, usdValue: 0),
  ];

  List<_TokenPrice> _offlinePrices() => [
    _TokenPrice(token: 'ETH', usd: 0, change24h: 0),
    _TokenPrice(token: 'BTC', usd: 0, change24h: 0),
    _TokenPrice(token: 'SOL', usd: 0, change24h: 0),
    _TokenPrice(token: 'USDC', usd: 1.00, change24h: 0),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildInfoBanner()),
          if (_errorMessage != null)
            SliverToBoxAdapter(child: _buildErrorBanner()),
          SliverToBoxAdapter(child: _buildPortfolioCard()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverToBoxAdapter(child: _buildPricesSection()),
          if (_dcaStrategies.isNotEmpty)
            SliverToBoxAdapter(child: _buildDcaSection()),
          SliverToBoxAdapter(child: _buildAgentPromptCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: const Color(0xFF0A0F1E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7B2FBE), Color(0xFF1A0A3C), Color(0xFF0A0F1E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.currency_exchange_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MoonPay Agents',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _isMoonPayConnected
                                        ? AppColors.statusGreen
                                        : Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isMoonPayConnected ? 'Connected' : 'Not configured',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () => _showInfoDialog(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF7B2FBE).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF7B2FBE).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: Color(0xFF9B6FDE)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Give your agent a bank account + 30 financial skills. Tap to learn more.',
                  style: TextStyle(color: Color(0xFF9B6FDE), fontSize: 12),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: Color(0xFF9B6FDE)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Colors.orange, fontSize: 11)),
            ),
            GestureDetector(
              onTap: _loadData,
              child: const Icon(Icons.refresh_rounded,
                  size: 16, color: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1040), Color(0xFF0D1B2A)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: const Color(0xFF7B2FBE).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Portfolio',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('MULTI-CHAIN',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoading
                ? _buildShimmer(height: 36, width: 160)
                : Text(
                    '\$${_totalUsdValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
            const SizedBox(height: 16),
            ..._balances.take(5).map((b) => _buildBalanceRow(b)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(_WalletBalance b) {
    final color = _tokenColor(b.token);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(b.token.substring(0, b.token.length.clamp(0, 3)),
                  style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.token,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(b.chain,
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                b.usdValue > 0 ? '\$${b.usdValue.toStringAsFixed(2)}' : '—',
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                b.amount > 0 ? '${b.amount.toStringAsFixed(4)} ${b.token}' : '—',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction('Buy', Icons.add_circle_outline_rounded, const Color(0xFF00C49A)),
      _QuickAction('Sell', Icons.remove_circle_outline_rounded, Colors.redAccent),
      _QuickAction('Swap', Icons.swap_horiz_rounded, const Color(0xFF7B2FBE)),
      _QuickAction('Bridge', Icons.swap_calls_rounded, Colors.blueAccent),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: actions.map((a) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _showActionDialog(a.label),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: a.color.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Icon(a.icon, color: a.color, size: 22),
                    const SizedBox(height: 6),
                    Text(a.label,
                        style: TextStyle(
                            color: a.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildPricesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MARKET PRICES',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 12),
          ..._prices.map((p) => _buildPriceRow(p)),
        ],
      ),
    );
  }

  Widget _buildPriceRow(_TokenPrice p) {
    final isPositive = p.change24h >= 0;
    final changeColor = isPositive ? AppColors.statusGreen : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _tokenColor(p.token).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(p.token.substring(0, p.token.length.clamp(0, 3)),
                  style: TextStyle(
                      color: _tokenColor(p.token),
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(p.token,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                p.usd > 0 ? '\$${_formatPrice(p.usd)}' : '—',
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (p.change24h != 0)
                Text(
                  '${isPositive ? '+' : ''}${p.change24h.toStringAsFixed(2)}%',
                  style: TextStyle(color: changeColor, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDcaSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DCA STRATEGIES',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              GestureDetector(
                onTap: () => _showActionDialog('DCA Setup'),
                child: const Text('+ ADD',
                    style: TextStyle(
                        color: AppColors.statusGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._dcaStrategies.map((d) => _buildDcaRow(d)),
        ],
      ),
    );
  }

  Widget _buildDcaRow(_DcaStrategy d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: d.active
              ? AppColors.statusGreen.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.token,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('\$${d.amountUsd.toStringAsFixed(2)} • ${d.frequency}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                if (d.nextRun.isNotEmpty)
                  Text('Next: ${d.nextRun}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: d.active
                  ? AppColors.statusGreen.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              d.active ? 'ACTIVE' : 'PAUSED',
              style: TextStyle(
                color: d.active ? AppColors.statusGreen : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentPromptCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_outlined,
                      color: Colors.purpleAccent, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Agent Prompt Guide',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: _kAgentPrompt));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Prompt copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Icon(Icons.copy_rounded,
                      size: 16, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Text(
                _kAgentPrompt,
                style: TextStyle(
                    color: Colors.white60, fontSize: 11, height: 1.6,
                    fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer({required double height, required double width}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1 + (_shimmerController.value * 2), 0),
              end: Alignment(0 + (_shimmerController.value * 2), 0),
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _tokenColor(String token) {
    switch (token.toUpperCase()) {
      case 'ETH': return const Color(0xFF627EEA);
      case 'BTC': return const Color(0xFFF7931A);
      case 'SOL': return const Color(0xFF9945FF);
      case 'USDC': return const Color(0xFF2775CA);
      case 'USDT': return const Color(0xFF26A17B);
      default: return Colors.white38;
    }
  }

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1040),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('MoonPay Agents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            'MoonPay Agents gives your AI a verified bank account and 30+ financial skills.\n\n'
            '🔧 Setup:\n'
            '1. npm install -g @moonpay/cli\n'
            '2. mp login\n'
            '3. mp wallet create MyWallet\n'
            '4. Add to openclaw.yaml:\n'
            '   mcp:\n'
            '     servers:\n'
            '       - name: moonpay\n'
            '         command: mp\n'
            '         args: [mcp]\n'
            '5. mp skill install\n\n'
            '✅ Once connected, your agent can:\n'
            '• Check portfolio across chains\n'
            '• Execute token swaps on-chain\n'
            '• Bridge tokens cross-chain\n'
            '• Buy/sell via fiat onramps\n'
            '• Set up DCA strategies\n'
            '• Monitor live market prices\n\n'
            '🔒 Security: Private keys stay on your device. MoonPay CLI signs all transactions locally.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: AppColors.statusGreen)),
          ),
        ],
      ),
    );
  }

  void _showActionDialog(String action) {
    final hints = {
      'Buy': 'Ask your agent: "Buy \$50 of ETH" or "Buy 0.01 BTC"',
      'Sell': 'Ask your agent: "Sell 0.5 ETH to USD" or "Cash out my USDC"',
      'Swap': 'Ask your agent: "Swap 50 USDC to SOL" or "Exchange ETH for USDC"',
      'Bridge': 'Ask your agent: "Bridge 0.1 ETH from Ethereum to Base"',
      'DCA Setup': 'Ask your agent: "Set up weekly \$50 ETH purchases"',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hints[action] ?? 'Use the chat to trigger this action'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Agent prompt constant (injected into system prompt for maximum capability)
// ─────────────────────────────────────────────────────────────────────────────

const _kAgentPrompt = '''You have the MoonPay financial toolkit via MCP.
Use these commands:
• moonpay.get_portfolio — wallet balances across all chains
• moonpay.get_price {token} — live USD price + 24h change
• moonpay.swap {from_token, to_token, amount} — on-chain swap
• moonpay.bridge {token, from_chain, to_chain, amount} — bridge
• moonpay.buy {token, amount_usd} — fiat onramp
• moonpay.sell {token, amount} — fiat offramp
• moonpay.dca_list — active DCA strategies
• moonpay.dca_create {token, amount_usd, frequency} — new DCA
Always confirm swaps/buys/bridges with the user first.''';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _WalletBalance {
  final String chain;
  final String token;
  final double amount;
  final double usdValue;
  const _WalletBalance({required this.chain, required this.token, required this.amount, required this.usdValue});
}

class _TokenPrice {
  final String token;
  final double usd;
  final double change24h;
  const _TokenPrice({required this.token, required this.usd, required this.change24h});
}

class _DcaStrategy {
  final String id;
  final String token;
  final double amountUsd;
  final String frequency;
  final String nextRun;
  final bool active;
  const _DcaStrategy({required this.id, required this.token, required this.amountUsd, required this.frequency, required this.nextRun, required this.active});
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  const _QuickAction(this.label, this.icon, this.color);
}
