import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/bridge/bridge_models.dart';

enum RelayDepositSheetAction { close, hide }

final class RelayDepositSheet extends StatefulWidget {
  const RelayDepositSheet({
    super.key,
    required this.instruction,
    required this.onCopy,
    this.clock = DateTime.now,
  });

  final RelayDepositInstruction instruction;
  final Future<void> Function(String text) onCopy;
  final DateTime Function() clock;

  static Future<RelayDepositSheetAction> show(
    BuildContext context, {
    required RelayDepositInstruction instruction,
    required Future<void> Function(String text) onCopy,
    DateTime Function() clock = DateTime.now,
  }) async =>
      await showModalBottomSheet<RelayDepositSheetAction>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => RelayDepositSheet(
          instruction: instruction,
          onCopy: onCopy,
          clock: clock,
        ),
      ) ??
      RelayDepositSheetAction.close;

  @override
  State<RelayDepositSheet> createState() => _RelayDepositSheetState();
}

final class _RelayDepositSheetState extends State<RelayDepositSheet> {
  Timer? _timer;

  bool get _expired => !widget.clock().toUtc().isBefore(
        widget.instruction.expiresAt.toUtc(),
      );

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.instruction.request;
    final remaining =
        widget.instruction.expiresAt.toUtc().difference(widget.clock().toUtc());
    final minutes = remaining.isNegative ? 0 : remaining.inMinutes;
    final seconds = remaining.isNegative ? 0 : remaining.inSeconds % 60;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _expired ? 'Deposit instruction expired' : 'Send exact amount',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _expired
                  ? 'Do not send funds to this address. Keep it only for status tracking.'
                  : '${request.amount} ${request.sourceToken.symbol} on ${request.sourceChain.name}',
              style: TextStyle(
                color: _expired ? Colors.orangeAccent : null,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!_expired)
              Text(
                'Expires in ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              ),
            const SizedBox(height: 16),
            if (_expired) ...[
              Text(
                'Expired address hidden to prevent reuse: ${_shortAddress(widget.instruction.depositAddress)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ] else ...[
              Semantics(
                label: 'Deposit address QR code. Address only.',
                image: true,
                child: Center(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: QrImageView(
                        data: widget.instruction.depositAddress,
                        size: 190,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Address only — send the exact token and amount shown above.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              SelectableText(
                widget.instruction.depositAddress,
                textAlign: TextAlign.center,
              ),
              Align(
                child: TextButton.icon(
                  onPressed: () async {
                    await widget.onCopy(widget.instruction.depositAddress);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deposit address copied.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy address'),
                ),
              ),
            ],
            const Divider(height: 24),
            _InstructionRow(
              label: 'Base destination',
              value: request.baseDestinationAddress,
            ),
            _InstructionRow(
              label: 'Personal refund address',
              value: request.refundAddress ?? 'Missing',
            ),
            _InstructionRow(
              label: 'Minimum Base USDC',
              value: widget.instruction.minimumOutputDisplay,
            ),
            const SizedBox(height: 8),
            const Text(
              'Wrong chain, token, or amount can be unrecoverable. Status changes only when Relay observes the transfer; there is no local sent confirmation.',
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    RelayDepositSheetAction.hide,
                  ),
                  child: const Text('Hide instructions'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    RelayDepositSheetAction.close,
                  ),
                  child: const Text('Keep tracking'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _shortAddress(String address) {
  if (address.length <= 14) return address;
  return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
}

final class _InstructionRow extends StatelessWidget {
  const _InstructionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            SelectableText(value),
          ],
        ),
      );
}
