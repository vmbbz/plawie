import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/solana_service.dart';
import '../widgets/status_card.dart';

class SolanaScreen extends StatefulWidget {
  const SolanaScreen({super.key});

  @override
  State<SolanaScreen> createState() => _SolanaScreenState();
}

class _SolanaScreenState extends State<SolanaScreen> {
  final SolanaService _solanaService = SolanaService();

  @override
  void initState() {
    super.initState();
    _initializeSolana();
  }

  Future<void> _initializeSolana() async {
    try {
      await _solanaService.initialize();
      setState(() {});
    } catch (e) {
      // Handle initialization error
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solana'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Solana Header with gradient
            Container(
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
                                  ? 'Connected: ${_solanaService.publicKey?.substring(0, 8) ?? ''}...'
                                  : 'Not Connected',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
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
            
            StatusCard(
              title: 'Create Wallet',
              subtitle: 'Generate new Solana wallet',
              icon: Icons.add_circle_outline,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCreateWalletDialog(),
            ),
            
            StatusCard(
              title: 'Import Wallet',
              subtitle: 'Import existing wallet',
              icon: Icons.file_download,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showImportWalletDialog(),
            ),
            
            StatusCard(
              title: 'Send Transaction',
              subtitle: 'Send SOL or tokens',
              icon: Icons.send,
              trailing: const Icon(Icons.chevron_right),
              onTap: _solanaService.isConnected 
                  ? () => _showSendTransactionDialog()
                  : null,
            ),
            
            StatusCard(
              title: 'Receive',
              subtitle: 'Get your wallet address',
              icon: Icons.qr_code,
              trailing: const Icon(Icons.chevron_right),
              onTap: _solanaService.isConnected 
                  ? () => _showReceiveDialog()
                  : null,
            ),
            
            const SizedBox(height: 24),
            
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
              subtitle: 'Swap tokens on Solana',
              icon: Icons.swap_horiz,
              trailing: const Icon(Icons.chevron_right),
              onTap: _solanaService.isConnected 
                  ? () => _showJupiterSwapDialog()
                  : null,
            ),
            
            StatusCard(
              title: 'Token Accounts',
              subtitle: 'View your token balances',
              icon: Icons.account_balance,
              trailing: const Icon(Icons.chevron_right),
              onTap: _solanaService.isConnected 
                  ? () => _showTokenAccountsDialog()
                  : null,
            ),
            
            const SizedBox(height: 24),
            
            // Wallet Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _solanaService.isConnected ? Icons.check_circle : Icons.warning,
                        color: _solanaService.isConnected 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Wallet Status',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _solanaService.isConnected 
                        ? 'Wallet is ready for transactions'
                        : 'Create or import a wallet to get started',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateWalletDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Wallet'),
        content: const Text('This will create a new Solana wallet. Make sure to backup your private key securely.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await _solanaService.createWallet();
              if (success) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Wallet created successfully')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showSendTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Transaction'),
        content: const Text('Send transaction feature will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showImportWalletDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Wallet'),
        content: const Text('Wallet import feature will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showReceiveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive SOL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _solanaService.publicKey ?? 'No wallet',
                style: GoogleFonts.jetBrainsMono(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Share this address to receive SOL or tokens'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showJupiterSwapDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jupiter Swap'),
        content: const Text('Jupiter swap integration will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTokenAccountsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Token Accounts'),
        content: const Text('Token accounts view will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
