import 'ai_payment_provider_catalog.dart';
import 'x402_payment_service.dart';
import 'x402_payment_transport_service.dart';

enum ProviderTopUpFundingStage {
  selectingBase,
  requestingChallenge,
  checkingBalance,
  fundingRequired,
  verifyingFunding,
  requestingFreshChallenge,
  awaitingPaymentApproval,
  submittingPayment,
  cancelled,
}

class ProviderTopUpFundingException implements Exception {
  const ProviderTopUpFundingException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class ProviderFundingRequirement {
  const ProviderFundingRequirement({
    required this.provider,
    required this.requiredBaseUsdcUnits,
  });

  final AiPaymentProviderOption provider;
  final BigInt requiredBaseUsdcUnits;

  String get requiredBaseUsdcDisplay => _formatUsdcUnits(requiredBaseUsdcUnits);
}

typedef ProviderTopUpPrepare = Future<PreparedX402Payment> Function(
  AiPaymentProviderOption provider,
);
typedef ProviderTopUpReject = void Function(PreparedX402Payment payment);
typedef BaseUsdcBalanceRefresh = Future<BigInt> Function();
typedef ProviderFundingRequest = Future<bool> Function(
  ProviderFundingRequirement requirement,
);
typedef ProviderPaymentApproval = Future<bool> Function(
  PreparedX402Payment payment,
);
typedef ProviderPaymentSubmit = Future<X402PaymentReceipt> Function(
  PreparedX402Payment payment,
);
typedef ProviderTopUpProgress = void Function(
  ProviderTopUpFundingStage stage,
);

/// Coordinates funding and payment without allowing a provider challenge,
/// approval, or signature to survive a bridge operation.
class ProviderTopUpFundingCoordinator {
  const ProviderTopUpFundingCoordinator({
    required ProviderTopUpPrepare prepare,
    required ProviderTopUpReject reject,
    required Future<void> Function() selectBaseMainnet,
    required BaseUsdcBalanceRefresh refreshBaseUsdcBalance,
    required ProviderFundingRequest requestFunding,
    required ProviderPaymentApproval requestPaymentApproval,
    required ProviderPaymentSubmit submitPayment,
  })  : _prepare = prepare,
        _reject = reject,
        _selectBaseMainnet = selectBaseMainnet,
        _refreshBaseUsdcBalance = refreshBaseUsdcBalance,
        _requestFunding = requestFunding,
        _requestPaymentApproval = requestPaymentApproval,
        _submitPayment = submitPayment;

  final ProviderTopUpPrepare _prepare;
  final ProviderTopUpReject _reject;
  final Future<void> Function() _selectBaseMainnet;
  final BaseUsdcBalanceRefresh _refreshBaseUsdcBalance;
  final ProviderFundingRequest _requestFunding;
  final ProviderPaymentApproval _requestPaymentApproval;
  final ProviderPaymentSubmit _submitPayment;

  Future<X402PaymentReceipt?> run(
    AiPaymentProviderOption provider, {
    ProviderTopUpProgress? onProgress,
  }) async {
    PreparedX402Payment? pending;
    try {
      onProgress?.call(ProviderTopUpFundingStage.selectingBase);
      await _selectBaseMainnet();

      onProgress?.call(ProviderTopUpFundingStage.requestingChallenge);
      pending = await _prepare(provider);
      final firstRequired = pending.intent.challenge.requirement.amountUnits;

      onProgress?.call(ProviderTopUpFundingStage.checkingBalance);
      var available = await _refreshBaseUsdcBalance();
      if (available < firstRequired) {
        _reject(pending);
        pending = null;

        onProgress?.call(ProviderTopUpFundingStage.fundingRequired);
        final completed = await _requestFunding(
          ProviderFundingRequirement(
            provider: provider,
            requiredBaseUsdcUnits: firstRequired,
          ),
        );
        if (!completed) {
          onProgress?.call(ProviderTopUpFundingStage.cancelled);
          return null;
        }

        onProgress?.call(ProviderTopUpFundingStage.verifyingFunding);
        await _selectBaseMainnet();
        available = await _refreshBaseUsdcBalance();
        if (available < firstRequired) {
          throw const ProviderTopUpFundingException(
            'BASE_USDC_STILL_INSUFFICIENT',
            'Funding completed, but the refreshed Base USDC balance is still below the required amount.',
          );
        }

        onProgress?.call(ProviderTopUpFundingStage.requestingFreshChallenge);
        pending = await _prepare(provider);
        final freshRequired = pending.intent.challenge.requirement.amountUnits;
        if (available < freshRequired) {
          _reject(pending);
          pending = null;
          throw const ProviderTopUpFundingException(
            'FRESH_CHALLENGE_EXCEEDS_BALANCE',
            'The provider returned a new amount that exceeds the refreshed Base USDC balance.',
          );
        }
      }

      onProgress?.call(ProviderTopUpFundingStage.awaitingPaymentApproval);
      final approved = await _requestPaymentApproval(pending);
      if (!approved) {
        _reject(pending);
        pending = null;
        onProgress?.call(ProviderTopUpFundingStage.cancelled);
        return null;
      }

      onProgress?.call(ProviderTopUpFundingStage.submittingPayment);
      final approvedPayment = pending;
      pending = null;
      return await _submitPayment(approvedPayment);
    } finally {
      if (pending != null) _reject(pending);
    }
  }
}

String _formatUsdcUnits(BigInt units) {
  final whole = units ~/ BigInt.from(1000000);
  final fraction = (units % BigInt.from(1000000))
      .toString()
      .padLeft(6, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
}
