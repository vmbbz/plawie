import 'dart:async';
import 'sibyl_memory_service.dart';

class PolicyEvaluationResult {
  final bool isAllowed;
  final String reason;
  final double requestedAmountUsdc;
  final double currentDailySpentUsdc;
  final double dailyLimitUsdc;
  final double singleTxLimitUsdc;

  const PolicyEvaluationResult({
    required this.isAllowed,
    required this.reason,
    required this.requestedAmountUsdc,
    required this.currentDailySpentUsdc,
    required this.dailyLimitUsdc,
    required this.singleTxLimitUsdc,
  });

  factory PolicyEvaluationResult.allow({
    required String reason,
    required double requestedAmountUsdc,
    required double currentDailySpentUsdc,
    required double dailyLimitUsdc,
    required double singleTxLimitUsdc,
  }) =>
      PolicyEvaluationResult(
        isAllowed: true,
        reason: reason,
        requestedAmountUsdc: requestedAmountUsdc,
        currentDailySpentUsdc: currentDailySpentUsdc,
        dailyLimitUsdc: dailyLimitUsdc,
        singleTxLimitUsdc: singleTxLimitUsdc,
      );

  factory PolicyEvaluationResult.reject({
    required String reason,
    required double requestedAmountUsdc,
    required double currentDailySpentUsdc,
    required double dailyLimitUsdc,
    required double singleTxLimitUsdc,
  }) =>
      PolicyEvaluationResult(
        isAllowed: false,
        reason: reason,
        requestedAmountUsdc: requestedAmountUsdc,
        currentDailySpentUsdc: currentDailySpentUsdc,
        dailyLimitUsdc: dailyLimitUsdc,
        singleTxLimitUsdc: singleTxLimitUsdc,
      );

  Map<String, dynamic> toJson() => {
        'isAllowed': isAllowed,
        'reason': reason,
        'requestedAmountUsdc': requestedAmountUsdc,
        'currentDailySpentUsdc': currentDailySpentUsdc,
        'dailyLimitUsdc': dailyLimitUsdc,
        'singleTxLimitUsdc': singleTxLimitUsdc,
      };
}

/// Evaluates proposed transactions against active Sibyl Memory policies
class GuardianPolicyEngine {
  final SibylMemoryService _memoryService;

  GuardianPolicyEngine({SibylMemoryService? memoryService})
      : _memoryService = memoryService ?? SibylMemoryService();

  /// Evaluate transaction request against active policy and daily spent total
  Future<PolicyEvaluationResult> evaluateTransaction({
    required String action,
    required String recipient,
    required double amountUsdc,
  }) async {
    final policy = _memoryService.activePolicy;
    final dailySpent = await _memoryService.getDailySpentUsdc();

    // 1. Single transaction limit check
    if (amountUsdc > policy.singleTxLimitUsdc) {
      return PolicyEvaluationResult.reject(
        reason:
            'BLOCKED BY GUARDIAN POLICY: Requested \$${amountUsdc.toStringAsFixed(2)} USDC exceeds single-transaction limit of \$${policy.singleTxLimitUsdc.toStringAsFixed(2)} USDC.',
        requestedAmountUsdc: amountUsdc,
        currentDailySpentUsdc: dailySpent,
        dailyLimitUsdc: policy.dailyLimitUsdc,
        singleTxLimitUsdc: policy.singleTxLimitUsdc,
      );
    }

    // 2. Cumulative daily cap check
    final projectedDaily = dailySpent + amountUsdc;
    if (projectedDaily > policy.dailyLimitUsdc) {
      return PolicyEvaluationResult.reject(
        reason:
            'BLOCKED BY GUARDIAN POLICY: Transfer of \$${amountUsdc.toStringAsFixed(2)} USDC exceeds daily spending limit of \$${policy.dailyLimitUsdc.toStringAsFixed(2)} USDC (already spent \$${dailySpent.toStringAsFixed(2)} USDC today).',
        requestedAmountUsdc: amountUsdc,
        currentDailySpentUsdc: dailySpent,
        dailyLimitUsdc: policy.dailyLimitUsdc,
        singleTxLimitUsdc: policy.singleTxLimitUsdc,
      );
    }

    // 3. Recipient allowlist check (if allowlist is set)
    final cleanRecipient = recipient.trim().toLowerCase();
    if (policy.allowedRecipients.isNotEmpty) {
      final isAllowedRecipient = policy.allowedRecipients.any(
        (allowed) => allowed.toLowerCase() == cleanRecipient,
      );

      if (!isAllowedRecipient) {
        return PolicyEvaluationResult.reject(
          reason:
              'BLOCKED BY GUARDIAN POLICY: Recipient "$recipient" is not in your approved allowlist.',
          requestedAmountUsdc: amountUsdc,
          currentDailySpentUsdc: dailySpent,
          dailyLimitUsdc: policy.dailyLimitUsdc,
          singleTxLimitUsdc: policy.singleTxLimitUsdc,
        );
      }
    }

    // 4. Policy check passed
    return PolicyEvaluationResult.allow(
      reason:
          'POLICY APPROVED: \$${amountUsdc.toStringAsFixed(2)} USDC transfer to $recipient is within policy caps (Daily: \$${dailySpent.toStringAsFixed(2)}/\$${policy.dailyLimitUsdc.toStringAsFixed(2)} USDC).',
      requestedAmountUsdc: amountUsdc,
      currentDailySpentUsdc: dailySpent,
      dailyLimitUsdc: policy.dailyLimitUsdc,
      singleTxLimitUsdc: policy.singleTxLimitUsdc,
    );
  }
}
