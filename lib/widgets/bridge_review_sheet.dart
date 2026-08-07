import 'package:flutter/material.dart';

import '../services/bridge/bridge_funding_controller.dart';
import '../services/bridge/bridge_models.dart';

final class BridgeReviewSheet extends StatelessWidget {
  const BridgeReviewSheet({
    super.key,
    required this.receipt,
    required this.reviewKind,
    required this.sourceChainName,
    required this.sourceAmountDisplay,
    required this.minimumOutputDisplay,
  });

  final BridgeFundingReceipt receipt;
  final BridgeReviewKind reviewKind;
  final String sourceChainName;
  final String sourceAmountDisplay;
  final String minimumOutputDisplay;

  static Future<bool> show(
    BuildContext context, {
    required BridgeFundingReceipt receipt,
    required BridgeReviewKind reviewKind,
    required String sourceChainName,
    required String sourceAmountDisplay,
    required String minimumOutputDisplay,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => BridgeReviewSheet(
          receipt: receipt,
          reviewKind: reviewKind,
          sourceChainName: sourceChainName,
          sourceAmountDisplay: sourceAmountDisplay,
          minimumOutputDisplay: minimumOutputDisplay,
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final approval = reviewKind == BridgeReviewKind.allowance;
    final direct = receipt.provider == 'direct_base';
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              approval ? 'Review exact token approval' : 'Review Base funding',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              approval
                  ? 'Approve exactly $sourceAmountDisplay ${receipt.sourceTokenSymbol} for this route. This approval does not bridge funds.'
                  : '$sourceAmountDisplay ${receipt.sourceTokenSymbol} on $sourceChainName → at least $minimumOutputDisplay USDC on Base.',
            ),
            const SizedBox(height: 12),
            _ReviewRow(label: 'Source wallet', value: receipt.sourceAddress),
            _ReviewRow(
              label: 'Base destination',
              value: receipt.baseDestinationAddress,
            ),
            if (!approval)
              _ReviewRow(
                label: 'Route',
                value: direct
                    ? 'Direct transfer on Base — no bridge provider'
                    : receipt.routeTool ?? receipt.provider,
              ),
            const SizedBox(height: 12),
            Text(
              approval
                  ? 'Plawie will request one exact allowance transaction. Your external wallet shows the final network fee.'
                  : 'Verify every field here and again in your external wallet. Plawie never treats chat text as approval.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Not now'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    approval ? 'Approve exact allowance' : 'Approve in wallet',
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

final class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            SelectableText(value ?? 'Unavailable'),
          ],
        ),
      );
}
