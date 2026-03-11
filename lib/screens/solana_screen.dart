import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:decimal/decimal.dart';
import '../services/solana_service.dart';
import '../widgets/status_card.dart';
import 'transaction_confirmation_screen.dart';

class SolanaScreen extends StatefulWidget {
  const SolanaScreen({super.key});

  @override
  State<SolanaScreen> createState() => _SolanaScreenState();
}

class _SolanaScreenState extends State<SolanaScreen> {
  final SolanaService _solanaService = SolanaService();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeSolana();
  }

  Future<void> _initializeSolana() async {
    setState(() => _isLoading = true);
    try {
      await _solanaService.initialize();
      if (_solanaService.isConnected) {
        await _solanaService.refreshBalance();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshBalance() async {
    if (!_solanaService.isConnected) return;
    setState(() => _isLoading = true);
    try {
      await _solanaService.refreshBalance();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solana'),
        actions: [
          // Network toggle
          PopupMenuButton<bool>(
            icon: Icon(
              Icons.public,
              color: _solanaService.useDevnet
                  ? Colors.orange
                  : Colors.green.shade400,
            ),
            tooltip: 'Network: ${_solanaService.networkName}',
            onSelected: (useDevnet) async {
              await _solanaService.setNetwork(devnet: useDevnet);
              setState(() {});
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: true,
                child: Row(
                  children: [
                    Icon(Icons.science,
                        color: _solanaService.useDevnet
                            ? Colors.orange
                            : Colors.grey,
                        size: 20),
                    const SizedBox(width: 8),
                    const Text('Devnet (Testing)'),
                    if (_solanaService.useDevnet) ...[
                      const Spacer(),
                      const Icon(Icons.check, size: 18),
                    ]
                  ],
                ),
              ),
              PopupMenuItem(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.public,
                        color: !_solanaService.useDevnet
                            ? Colors.green
                            : Colors.grey,
                        size: 20),
                    const SizedBox(width: 8),
                    const Text('Mainnet'),
                    if (!_solanaService.useDevnet) ...[
                      const Spacer(),
                      const Icon(Icons.check, size: 18),
                    ]
                  ],
                ),
              ),
            ],
          ),
          if (_solanaService.isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshBalance,
              tooltip: 'Refresh balance',
            ),
        ],
      ),
      body: _isLoading && !_solanaService.isConnected
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshBalance,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet header with real balance
                    _buildWalletHeader(theme),

                    const SizedBox(height: 24),

                    // Network indicator
                    _buildNetworkBanner(theme),

                    const SizedBox(height: 16),

                    // Wallet Actions
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'WALLET ACTIONS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    if (!_solanaService.isConnected) ...[
                      StatusCard(
                        title: 'Create Wallet',
                        subtitle: 'Generate new Solana keypair',
                        icon: Icons.add_circle_outline,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showCreateWalletDialog(),
                      ),
                      StatusCard(
                        title: 'Import Wallet',
                        subtitle: 'Import from private key',
                        icon: Icons.file_download,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showImportWalletDialog(),
                      ),
                    ],

                    if (_solanaService.isConnected) ...[
                      StatusCard(
                        title: 'Send SOL',
                        subtitle: 'Transfer SOL to an address',
                        icon: Icons.send,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showSendSolDialog(),
                      ),
                      StatusCard(
                        title: 'Receive',
                        subtitle: 'Show your wallet address',
                        icon: Icons.qr_code,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showReceiveDialog(),
                      ),

                      const SizedBox(height: 24),

                      // DeFi Actions
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'DEFI ACTIONS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      StatusCard(
                        title: 'Jupiter Swap',
                        subtitle: 'Swap tokens via Jupiter DEX',
                        icon: Icons.swap_horiz,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SwapTransactionScreen(),
                          ),
                        ),
                      ),
                      StatusCard(
                        title: 'Token Accounts',
                        subtitle: 'View your token balances',
                        icon: Icons.account_balance,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showTokenAccountsDialog(),
                      ),

                      const SizedBox(height: 24),

                      // Transaction History
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'RECENT TRANSACTIONS',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      _buildTransactionHistory(theme),

                      const SizedBox(height: 24),

                      // Wallet management
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'WALLET MANAGEMENT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      StatusCard(
                        title: 'Export Private Key',
                        subtitle: 'View and copy your private key',
                        icon: Icons.vpn_key,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showExportKeyDialog(),
                      ),
                      StatusCard(
                        title: 'Disconnect Wallet',
                        subtitle: 'Remove wallet from this device',
                        icon: Icons.logout,
                        trailing: Icon(Icons.chevron_right,
                            color: theme.colorScheme.error),
                        onTap: () => _showDisconnectDialog(),
                      ),
                    ],

                    // Error display
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: theme.colorScheme.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () =>
                                  setState(() => _error = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWalletHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade400,
            Colors.purple.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solana Wallet',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _solanaService.isConnected
                          ? '${_solanaService.publicKey?.substring(0, 4) ?? ''}...${_solanaService.publicKey?.substring((_solanaService.publicKey?.length ?? 4) - 4) ?? ''}'
                          : 'Not Connected',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (_solanaService.isConnected)
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                  tooltip: 'Copy address',
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _solanaService.publicKey ?? ''),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Address copied')),
                    );
                  },
                ),
            ],
          ),
          if (_solanaService.isConnected) ...[
            const SizedBox(height: 20),
            Text(
              '${_solanaService.solBalance.toStringAsFixed(4)} SOL',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkBanner(ThemeData theme) {
    final isDevnet = _solanaService.useDevnet;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDevnet
            ? Colors.orange.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDevnet
              ? Colors.orange.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDevnet ? Icons.science : Icons.public,
            color: isDevnet ? Colors.orange : Colors.green,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isDevnet
                ? 'Devnet — Test tokens only, no real value'
                : 'Mainnet — Real SOL, real transactions',
            style: TextStyle(
              color: isDevnet ? Colors.orange : Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionHistory(ThemeData theme) {
    return FutureBuilder<List<TransactionInfo>>(
      future: _solanaService.isConnected
          ? _solanaService.getTransactionHistory(limit: 5)
          : Future.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long,
                    color: theme.colorScheme.onSurfaceVariant, size: 32),
                const SizedBox(height: 8),
                Text(
                  'No transactions yet',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: transactions.map((tx) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    tx.status == 'confirmed' || tx.status == 'finalized'
                        ? Icons.check_circle
                        : Icons.pending,
                    color: tx.status == 'confirmed' || tx.status == 'finalized'
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tx.signature.substring(0, 8)}...${tx.signature.substring(tx.signature.length - 8)}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTimestamp(tx.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    tooltip: 'View on Solscan',
                    onPressed: () {
                      // Could open Solscan URL
                      Clipboard.setData(
                          ClipboardData(text: tx.signature));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Signature copied')),
                      );
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  Dialogs — Create Wallet
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _showCreateWalletDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will generate a new Solana keypair on your device.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Make sure to export and back up your private key after creation. If you lose it, your funds are gone forever.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _isLoading = true);
              final success = await _solanaService.createWallet();
              if (success && mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Wallet created: ${_solanaService.publicKey?.substring(0, 8)}...'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Prompt to export key
                _showExportKeyDialog();
              } else {
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  Dialogs — Import Wallet
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _showImportWalletDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your base58-encoded private key:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Paste private key...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              style: GoogleFonts.jetBrainsMono(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Never share your private key. It will be stored securely on this device only.',
                      style: TextStyle(fontSize: 11, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) return;
              Navigator.of(context).pop();
              setState(() => _isLoading = true);
              final success = await _solanaService.connectWallet(key);
              if (success && mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Wallet imported: ${_solanaService.publicKey?.substring(0, 8)}...'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                setState(() {
                  _isLoading = false;
                  _error = 'Failed to import wallet. Check the private key format.';
                });
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  Dialogs — Send SOL
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _showSendSolDialog() {
    final recipientController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send SOL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available: ${_solanaService.solBalance.toStringAsFixed(4)} SOL',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: recipientController,
              decoration: const InputDecoration(
                labelText: 'Recipient Address',
                hintText: 'Solana address...',
                border: OutlineInputBorder(),
              ),
              style: GoogleFonts.jetBrainsMono(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (SOL)',
                hintText: '0.0',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Transactions are irreversible. Double-check the address.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final recipient = recipientController.text.trim();
              final amountStr = amountController.text.trim();
              if (recipient.isEmpty || amountStr.isEmpty) return;

              final amount = Decimal.tryParse(amountStr);
              if (amount == null || amount <= Decimal.zero) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(dialogContext).pop();

              // Show confirmation
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => TransactionConfirmationDialog(
                  transactionType: 'Send',
                  fromToken: 'SOL',
                  toToken: 'SOL',
                  amount: amount,
                  recipient: recipient,
                  slippage: 0,
                  onConfirm: () => Navigator.pop(ctx, true),
                  onCancel: () => Navigator.pop(ctx, false),
                ),
              );

              if (confirmed == true) {
                setState(() => _isLoading = true);
                try {
                  final sig = await _solanaService.sendSol(
                    recipientAddress: recipient,
                    amountSol: amount,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Sent! Signature: ${sig.substring(0, 8)}...'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _error = 'Send failed: $e');
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Review & Send'),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  Dialogs — Receive
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _showReceiveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive SOL / Tokens'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: SelectableText(
                _solanaService.publicKey ?? '',
                style: GoogleFonts.jetBrainsMono(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share this address to receive SOL or SPL tokens',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Network: ${_solanaService.networkName}',
              style: TextStyle(
                fontSize: 12,
                color: _solanaService.useDevnet
                    ? Colors.orange
                    : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: _solanaService.publicKey ?? ''),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address copied')),
              );
            },
            child: const Text('Copy Address'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  Dialogs — Token Accounts
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _showTokenAccountsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Token Accounts'),
          content: SizedBox(
            width: double.maxFinite,
            child: _solanaService.tokenBalances.isEmpty
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.token, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No SPL tokens found'),
                      SizedBox(height: 4),
                      Text(
                        'Transfer tokens to your wallet to see them here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _solanaService.tokenBalances.length,
                    itemBuilder: (context, index) {
                      final token = _solanaService.tokenBalances[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.withOpacity(0.2),
                          child: Text(
                            token.mint.substring(0, 2),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          '${token.mint.substring(0, 4)}...${token.mint.substring(token.mint.length - 4)}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 12),
                        ),
                        trailing: Text(
                          token.uiAmount.toStringAsFixed(
                              token.decimals > 6 ? 6 : token.decimals),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  Dialogs — Export Private Key
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _showExportKeyDialog() async {
    final key = await _solanaService.exportPrivateKey();
    if (key == null || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Private Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Never share your private key. Anyone with this key has full control of your wallet.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: SelectableText(
                key,
                style: GoogleFonts.jetBrainsMono(fontSize: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Private key copied')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  Dialogs — Disconnect
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Wallet'),
        content: const Text(
          'This will remove the wallet from this device. Make sure you have backed up your private key first. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              await _solanaService.disconnectWallet();
              if (mounted) setState(() {});
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
