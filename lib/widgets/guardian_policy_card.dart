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

    final policy = _policy ?? GuardianPolicy.defaultPolicy();
    final dailyCap = policy.dailyLimitUsdc;
    final progress = dailyCap > 0 ? (_dailySpent / dailyCap).clamp(0.0, 1.0) : 0.0;
    final remaining = (dailyCap - _dailySpent).clamp(0.0, dailyCap);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0052FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF0052FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Plawie Guardian',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.green.withOpacity(0.4)),
                            ),
                            child: const Text(
                              'SIBYL RECALLED',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Base L2 Financial Safety Shield',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.grey, size: 18),
                  onPressed: _loadPolicy,
                  tooltip: 'Refresh Recall',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
                IconButton(
                  icon: Icon(
                    _collapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _collapsed = !_collapsed),
                  tooltip: _collapsed ? 'Expand details' : 'Collapse details',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
                if (widget.onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                    onPressed: widget.onDismiss,
                    tooltip: 'Dismiss Card',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
              ],
            ),
            if (!_collapsed) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Spend: \$${_dailySpent.toStringAsFixed(2)} / \$${dailyCap.toStringAsFixed(2)} USDC',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '\$${remaining.toStringAsFixed(2)} remaining',
                    style: TextStyle(
                      color: remaining > 0 ? Colors.cyanAccent : Colors.redAccent,
                      fontSize: 12,
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
                  minHeight: 6,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Per-Tx Cap',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\$${policy.singleTxLimitUsdc.toStringAsFixed(2)} USDC',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Allowlist',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            policy.allowedRecipients.isEmpty
                                ? 'Human Review'
                                : '${policy.allowedRecipients.length} Recipient(s)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
