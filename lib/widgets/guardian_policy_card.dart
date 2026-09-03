import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sibyl_memory_service.dart';

class GuardianPolicyCard extends StatefulWidget {
  final VoidCallback? onDismiss;
  final bool initiallyCollapsed;

  const GuardianPolicyCard({
    super.key,
    this.onDismiss,
    this.initiallyCollapsed = false,
  });

  @override
  State<GuardianPolicyCard> createState() => _GuardianPolicyCardState();
}

class _GuardianPolicyCardState extends State<GuardianPolicyCard> {
  final SibylMemoryService _memoryService = SibylMemoryService();
  GuardianPolicy? _policy;
  double _dailySpent = 0.0;
  bool _loading = true;
  late bool _collapsed;
  StreamSubscription<GuardianPolicy>? _policySub;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.initiallyCollapsed;
    _loadPolicy();
    _policySub = _memoryService.policyStream.listen((updatedPolicy) {
      if (mounted) {
        setState(() {
          _policy = updatedPolicy;
        });
        _refreshSpent();
      }
    });
  }

  @override
  void dispose() {
    _policySub?.cancel();
    super.dispose();
  }

  Future<void> _loadPolicy() async {
    setState(() => _loading = true);
    await _memoryService.initialize();
    final policy = _memoryService.activePolicy;
    final spent = await _memoryService.getDailySpentUsdc();
    if (mounted) {
      setState(() {
        _policy = policy;
        _dailySpent = spent;
        _loading = false;
      });
    }
  }

  Future<void> _refreshSpent() async {
    final spent = await _memoryService.getDailySpentUsdc();
    if (mounted) {
      setState(() {
        _dailySpent = spent;
      });
    }
  }

  Future<void> _resetPolicyForDemo() async {
    await _memoryService.clearPolicy();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Financial policy reset to unconfigured state for demo recording.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: const Row(
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Recalling Sibyl Memory...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final policy = _policy ?? GuardianPolicy.unconfigured();
    final isConfigured = policy.isConfigured;
    final dailyCap = policy.dailyLimitUsdc;
    final progress = dailyCap > 0 ? (_dailySpent / dailyCap).clamp(0.0, 1.0) : 0.0;
    final remaining = (dailyCap - _dailySpent).clamp(0.0, dailyCap);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfigured ? const Color(0xFF30363D) : Colors.amber.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isConfigured
                        ? const Color(0xFF0052FF).withOpacity(0.15)
                        : Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: isConfigured ? const Color(0xFF0052FF) : Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          const Text(
                            'Plawie Guardian',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isConfigured
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isConfigured
                                    ? Colors.green.withOpacity(0.4)
                                    : Colors.amber.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              isConfigured ? 'SIBYL RECALLED' : 'UNCONFIGURED',
                              style: TextStyle(
                                color: isConfigured
                                    ? Colors.greenAccent
                                    : Colors.amberAccent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isConfigured
                            ? 'Base L2 Financial Safety Shield'
                            : 'No policy stored in Sibyl Memory',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isConfigured)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 16),
                        onPressed: _resetPolicyForDemo,
                        tooltip: 'Reset Policy for Demo Prep',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.grey, size: 16),
                      onPressed: _loadPolicy,
                      tooltip: 'Refresh Recall',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    IconButton(
                      icon: Icon(
                        _collapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                        color: Colors.grey,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _collapsed = !_collapsed),
                      tooltip: _collapsed ? 'Expand details' : 'Collapse details',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    if (widget.onDismiss != null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                        onPressed: widget.onDismiss,
                        tooltip: 'Dismiss Card',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                  ],
                ),
              ],
            ),
            if (!_collapsed) ...[
              const SizedBox(height: 10),
              if (!isConfigured) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amberAccent, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ask Plawie: "Set my spending policy to max \$50 daily and \$25 per transaction cap."',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Daily Spend: \$${_dailySpent.toStringAsFixed(2)} / \$${dailyCap.toStringAsFixed(2)} USDC',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '\$${remaining.toStringAsFixed(2)} remaining',
                      style: TextStyle(
                        color: remaining > 0 ? Colors.cyanAccent : Colors.redAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: const Color(0xFF21262D),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0
                          ? Colors.redAccent
                          : (progress > 0.7
                              ? Colors.orangeAccent
                              : const Color(0xFF0052FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Per-Tx Cap',
                              style: TextStyle(color: Colors.grey, fontSize: 9.5),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '\$${policy.singleTxLimitUsdc.toStringAsFixed(2)} USDC',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF21262D),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Allowlist',
                              style: TextStyle(color: Colors.grey, fontSize: 9.5),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              policy.allowedRecipients.isEmpty
                                  ? 'Human Review'
                                  : '${policy.allowedRecipients.length} Recipient(s)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ]
            ]
          ],
        ),
      ),
    );
  }
}
