import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:decimal/decimal.dart';
import '../services/solana_service.dart';
import '../services/jupiter_service.dart';

/// Transaction Confirmation Dialog
class TransactionConfirmationDialog extends StatefulWidget {
  final String transactionType;
  final String fromToken;
  final String toToken;
  final Decimal amount;
  final String recipient;
  final double slippage;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const TransactionConfirmationDialog({
    super.key,
    required this.transactionType,
    required this.fromToken,
    required this.toToken,
    required this.amount,
    required this.recipient,
    required this.slippage,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<TransactionConfirmationDialog> createState() => _TransactionConfirmationDialogState();
}

class _TransactionConfirmationDialogState extends State<TransactionConfirmationDialog>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: const Color(0xFF2d2d44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildTransactionDetails(),
              const SizedBox(height: 20),
              _buildWarningMessage(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getTransactionColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTransactionIcon(),
            color: _getTransactionColor(),
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.transactionType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Review transaction details',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: widget.onCancel,
          icon: const Icon(Icons.close, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildTransactionDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3d3d52)),
      ),
      child: Column(
        children: [
          _buildDetailRow('From', widget.fromToken),
          const SizedBox(height: 8),
          _buildDetailRow('Amount', '${widget.amount.toStringAsFixed(4)} ${widget.fromToken}'),
          const SizedBox(height: 8),
          _buildDetailRow('To', widget.toToken),
          if (widget.recipient.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Recipient', widget.recipient),
          ],
          const SizedBox(height: 8),
          _buildDetailRow('Slippage', '${widget.slippage.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningMessage() {
    return Container(
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
              'This transaction is irreversible. Please verify all details before confirming.',
              style: TextStyle(
                color: Colors.orange.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isConfirming ? null : widget.onCancel,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isConfirming ? null : _handleConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getTransactionColor(),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isConfirming
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Confirm'),
          ),
        ),
      ],
    );
  }

  Color _getTransactionColor() {
    switch (widget.transactionType) {
      case 'Swap':
        return Colors.blue;
      case 'Send':
        return Colors.green;
      case 'Limit Order':
        return Colors.purple;
      case 'DCA':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getTransactionIcon() {
    switch (widget.transactionType) {
      case 'Swap':
        return Icons.swap_horiz;
      case 'Send':
        return Icons.send;
      case 'Limit Order':
        return Icons.price_change;
      case 'DCA':
        return Icons.trending_up;
      default:
        return Icons.swap_horiz;
    }
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _isConfirming = true;
    });

    try {
      // Haptic feedback
      await HapticFeedback.lightImpact();
      
      // Delay for user experience
      await Future.delayed(const Duration(milliseconds: 500));
      
      widget.onConfirm();
    } catch (e) {
      setState(() {
        _isConfirming = false;
      });
    }
  }
}

/// Swap Transaction Screen
class SwapTransactionScreen extends StatefulWidget {
  const SwapTransactionScreen({super.key});

  @override
  State<SwapTransactionScreen> createState() => _SwapTransactionScreenState();
}

class _SwapTransactionScreenState extends State<SwapTransactionScreen> {
  final SolanaService _solanaService = SolanaService();
  final JupiterService _jupiterService = JupiterService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  
  String _fromToken = 'SOL';
  String _toToken = 'USDC';
  double _slippage = 1.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('Swap Tokens'),
        backgroundColor: const Color(0xFF2d2d44),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTokenSelector(),
            const SizedBox(height: 20),
            _buildAmountInput(),
            const SizedBox(height: 20),
            _buildSlippageSlider(),
            const SizedBox(height: 20),
            _buildSwapButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d44),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3d3d52)),
      ),
      child: Column(
        children: [
          _buildTokenRow('From', _fromToken, () => _showTokenSelector(true)),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF3d3d52)),
          const SizedBox(height: 16),
          _buildTokenRow('To', _toToken, () => _showTokenSelector(false)),
        ],
      ),
    );
  }

  Widget _buildTokenRow(String label, String token, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              Text(
                token,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down, color: Colors.white54),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d44),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3d3d52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Amount',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '0.0',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3d3d52)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3d3d52)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6366f1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlippageSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d44),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3d3d52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Slippage Tolerance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${_slippage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: _slippage,
            min: 0.1,
            max: 10.0,
            divisions: 99,
            activeColor: Colors.blue,
            inactiveColor: const Color(0xFF3d3d52),
            onChanged: (value) {
              setState(() {
                _slippage = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwapButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSwap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Swap Tokens',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  void _showTokenSelector(bool isFromToken) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2d2d44),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TokenSelectorSheet(
        selectedToken: isFromToken ? _fromToken : _toToken,
        onTokenSelected: (token) {
          setState(() {
            if (isFromToken) {
              _fromToken = token;
            } else {
              _toToken = token;
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _handleSwap() async {
    final amount = _amountController.text.trim();
    if (amount.isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amountDecimal = Decimal.tryParse(amount);
    if (amountDecimal == null || amountDecimal <= Decimal.zero) {
      _showError('Please enter a valid amount');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => TransactionConfirmationDialog(
        transactionType: 'Swap',
        fromToken: _fromToken,
        toToken: _toToken,
        amount: amountDecimal,
        recipient: '',
        slippage: _slippage,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );

    if (confirmed == true) {
      await _executeSwap();
    }
  }

  Future<void> _executeSwap() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get Jupiter quote
      final quote = await _jupiterService.getSwapQuote(
        inputMint: _getTokenMint(_fromToken),
        outputMint: _getTokenMint(_toToken),
        amount: _amountController.text,
        slippageBps: (_slippage * 100).round().toDouble(),
      );

      // Create swap transaction
      final swapTx = await _jupiterService.createSwapTransaction(
        quote: quote,
        userPublicKey: _solanaService.publicKey!,
      );

      // Send transaction
      final signature = await _solanaService.sendTransaction(swapTx.swapTransaction);

      _showSuccess('Swap completed successfully. Signature: ${signature.substring(0, 8)}...');
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Swap failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTokenMint(String token) {
    const tokenMints = {
      'SOL': '11111111111111111111111111111111',
      'USDC': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      'USDT': 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
    };
    return tokenMints[token] ?? '';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Token Selector Bottom Sheet
class TokenSelectorSheet extends StatelessWidget {
  final String selectedToken;
  final Function(String) onTokenSelected;

  const TokenSelectorSheet({
    super.key,
    required this.selectedToken,
    required this.onTokenSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = [
      'SOL',
      'USDC',
      'USDT',
      'RAY',
      'SRM',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Token',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ...tokens.map((token) => _buildTokenOption(context, token)),
        ],
      ),
    );
  }

  Widget _buildTokenOption(BuildContext context, String token) {
    final isSelected = token == selectedToken;
    
    return InkWell(
      onTap: () => onTokenSelected(token),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getTokenColor(token),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  token.substring(0, 2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                token,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Color _getTokenColor(String token) {
    switch (token) {
      case 'SOL':
        return Colors.purple;
      case 'USDC':
        return Colors.blue;
      case 'USDT':
        return Colors.green;
      case 'RAY':
        return Colors.orange;
      case 'SRM':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
