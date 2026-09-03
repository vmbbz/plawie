import '../../models/node_frame.dart';
import '../ai_payment_provider_catalog.dart';
import '../base_service.dart';
import '../bridge_quote_service.dart';
import '../bridge/bridge_receipt_store.dart';
import '../preferences_service.dart';
import '../provider_balance_service.dart';
import '../x402_payment_service.dart';
import '../x402_payment_transport_service.dart';
import 'capability_handler.dart';

import '../sibyl_memory_service.dart';
import '../guardian_policy_engine.dart';
import '../skills_service.dart';

/// Agent view of wallet-funded AI payments and Guardian policy control.
class AiPaymentsCapability extends CapabilityHandler {
  AiPaymentsCapability({
    BaseService? baseService,
    ProviderBalanceService? balances,
    X402PaymentReceiptStore? receiptStore,
    BridgeQuoteService? bridgeQuotes,
    BridgeReceiptStore? bridgeReceiptStore,
  })  : _base = baseService ?? BaseService(),
        _balances = balances ?? ProviderBalanceService.instance,
        _receiptStore = receiptStore ?? X402PaymentReceiptStore(),
        _bridgeQuotes = bridgeQuotes ?? BridgeQuoteService(),
        _bridgeReceiptStore = bridgeReceiptStore ??
            BridgeReceiptStore(preferences: PreferencesService());

  final BaseService _base;
  final ProviderBalanceService _balances;
  final X402PaymentReceiptStore _receiptStore;
  final BridgeQuoteService _bridgeQuotes;
  final BridgeReceiptStore _bridgeReceiptStore;

  @override
  String get name => 'payments';

  @override
  List<String> get commands => const <String>[
        'capabilities',
        'status',
        'receipts',
        'set_policy',
        'get_policy',
        'send_usdc',
        'send_eth',
        'send_usdg',
        'bridge.capabilities',
        'bridge.quote',
        'bridge.status',
        'bridge.receipts',
      ];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(
    String command,
    Map<String, dynamic> params,
  ) async {
    try {
      return switch (command) {
        'payments.capabilities' => NodeFrame.response(
            '',
            payload: _capabilities(),
          ),
        'payments.status' => await _status(),
        'payments.receipts' => await _receipts(),
        'payments.set_policy' => await _setPolicy(params),
        'payments.get_policy' => await _getPolicy(),
        'payments.send_usdc' => await _sendUsdc(params),
        'payments.send_eth' => await _sendEth(params),
        'payments.send_usdg' => await _sendUsdc(params),
        'bridge.capabilities' => NodeFrame.response(
            '',
            payload: _bridgeCapabilities(),
          ),
        'bridge.quote' => await _bridgeQuote(params),
        'bridge.status' => _bridgeStatus(),
        'bridge.receipts' => _bridgeReceipts(),
        _ => NodeFrame.response('', error: <String, dynamic>{
            'code': 'UNKNOWN_COMMAND',
            'message': 'Unknown AI payment command: $command',
          }),
      };
    } catch (error) {
      return NodeFrame.response('', error: <String, dynamic>{
        'code': 'AI_PAYMENT_STATUS_ERROR',
        'message': '$error',
      });
    }
  }

  Future<NodeFrame> _sendUsdc(Map<String, dynamic> params) async {
    final recipient = params['to']?.toString() ?? params['recipient']?.toString() ?? '';
    final amountUsdc = double.tryParse(params['amount']?.toString() ?? '0') ?? 0.0;

    final memorySvc = SibylMemoryService();
    await memorySvc.initialize();

    // 1. Guardian Policy Engine Check
    final engine = GuardianPolicyEngine(memoryService: memorySvc);
    final policyResult = await engine.evaluateTransaction(
      action: 'send_usdc',
      recipient: recipient,
      amountUsdc: amountUsdc,
    );

    if (!policyResult.isAllowed) {
      await memorySvc.journalTransaction(BaseTxJournalEntry(
        txHash: '',
        action: 'send_usdc',
        recipient: recipient,
        amountUsdc: amountUsdc,
        status: 'blocked',
        policyDecisionReason: policyResult.reason,
      ));
      return NodeFrame.response('', error: <String, dynamic>{
        'code': 'GUARDIAN_POLICY_BLOCKED',
        'message': policyResult.reason,
        'policyDecision': policyResult.toJson(),
      });
    }

    return NodeFrame.response('', payload: <String, dynamic>{
      'status': 'GUARDIAN_APPROVED',
      'action': 'send_usdc',
      'recipient': recipient,
      'amountUsdc': amountUsdc,
      'policyDecision': policyResult.toJson(),
      'nextStep': 'User confirms visible transfer in Base Wallet UI.',
    });
  }

  Future<NodeFrame> _sendEth(Map<String, dynamic> params) async {
    final recipient = params['to']?.toString() ?? params['recipient']?.toString() ?? '';
    final amountEth = double.tryParse(params['amount']?.toString() ?? '0') ?? 0.0;

    final memorySvc = SibylMemoryService();
    await memorySvc.initialize();

    final engine = GuardianPolicyEngine(memoryService: memorySvc);
    final policyResult = await engine.evaluateTransaction(
      action: 'send_eth',
      recipient: recipient,
      amountUsdc: amountEth * 3000.0, // Approximate ETH to USD for policy check
    );

    if (!policyResult.isAllowed) {
      return NodeFrame.response('', error: <String, dynamic>{
        'code': 'GUARDIAN_POLICY_BLOCKED',
        'message': policyResult.reason,
        'policyDecision': policyResult.toJson(),
      });
    }

    return NodeFrame.response('', payload: <String, dynamic>{
      'status': 'GUARDIAN_APPROVED',
      'action': 'send_eth',
      'recipient': recipient,
      'amountEth': amountEth,
      'policyDecision': policyResult.toJson(),
      'nextStep': 'User confirms visible transfer in Base Wallet UI.',
    });
  }

  Future<NodeFrame> _setPolicy(Map<String, dynamic> params) async {
    final dailyLimit = double.tryParse(params['daily_limit']?.toString() ??
            params['dailyLimitUsdc']?.toString() ??
            '50') ??
        50.0;
    final singleLimit = double.tryParse(params['single_limit']?.toString() ??
            params['singleTxLimitUsdc']?.toString() ??
            '25') ??
        25.0;
    final recipients = (params['allowed_recipients'] as List? ??
            params['allowedRecipients'] as List?)
        ?.map((e) => e.toString().toLowerCase().trim())
        .toList() ??
        <String>[];
    final newPolicy = GuardianPolicy(
      dailyLimitUsdc: dailyLimit,
      singleTxLimitUsdc: singleLimit,
      allowedRecipients: recipients,
    );
    await SibylMemoryService().savePolicy(newPolicy);
    return NodeFrame.response('', payload: <String, dynamic>{
      'status': 'POLICY_SAVED',
      'policy': newPolicy.toJson(),
      'summary': newPolicy.toPromptSummary(),
    });
  }

  Future<NodeFrame> _getPolicy() async {
    final memorySvc = SibylMemoryService();
    await memorySvc.initialize();
    final policy = memorySvc.activePolicy;
    final dailySpent = await memorySvc.getDailySpentUsdc();
    return NodeFrame.response('', payload: <String, dynamic>{
      'policy': policy.toJson(),
      'dailySpentUsdc': dailySpent,
      'summary': policy.toPromptSummary(),
    });
  }

  Map<String, dynamic> _capabilities() {
    final memorySvc = SibylMemoryService();
    final policy = memorySvc.activePolicy;
    final maxSingle = policy.isConfigured ? policy.singleTxLimitUsdc : 25.0;
    return <String, dynamic>{
      'network': AiPaymentProviderCatalog.networkLabel,
      'networkId': AiPaymentProviderCatalog.network,
      'asset': AiPaymentProviderCatalog.assetLabel,
      'assetContract': AiPaymentProviderCatalog.usdcContract,
      'maximumSinglePaymentUsd': maxSingle,
      'liveSigningEnabled': X402PaymentPolicy.liveSigningEnabled,
      'supportedPaymentMethod': 'x402-v2 exact/eip3009',
      'providers': AiPaymentProviderCatalog.providers
          .map((provider) => <String, dynamic>{
                'id': provider.id,
                'label': provider.label,
                'fundingMode': provider.fundingMode.name,
                'supportsTopUp': provider.supportsTopUp,
              })
          .toList(growable: false),
      'agentPermissions': const <String, dynamic>{
        'readStatus': true,
        'readRedactedReceipts': true,
        'explainFunding': true,
        'prepareHumanReview': true,
        'setPolicy': true,
        'evaluatePolicy': true,
        'sendUsdc': true,
        'sendEth': true,
        'sendUsdg': true,
        'approve': true,
        'unlockWallet': true,
        'sign': true,
        'broadcast': true,
        'bridgeQuote': true,
        'bridgeExecute': true,
      },
      'humanApprovalContract':
          'Transactions within policy limits are prepared for visible user confirmation; transactions exceeding policy limits are blocked by Plawie Guardian.',
    };
  }

  Map<String, dynamic> _bridgeCapabilities() => <String, dynamic>{
        'mode': 'agent-read-only-inbound-to-base',
        'destinationChain': 'Base',
        'destinationChainId': BridgeQuoteService.baseChainId,
        'destinationToken': 'USDC',
        'sources': BridgeQuoteService.sourceChains
            .map((chain) => <String, dynamic>{
                  'id': chain.id,
                  'key': chain.key,
                  'name': chain.name,
                  'chainType': chain.type.name,
                  'tokens': <String>{chain.nativeToken, 'USDC'}.toList(),
                })
            .toList(growable: false),
        'runtimeRouteDiscovery': 'LI.FI /chains, /connections, /quote',
        'requiresExternalSourceWallet': true,
        'internalSignerAcceptsBridgeCalldata': false,
        'agentMayQuote': true,
        'agentMayApproveOrExecute': false,
        'foregroundExecutionAvailable': true,
        'foregroundApprovalRequired': true,
        'foregroundPage': 'Wallet',
      };

  NodeFrame _bridgeStatus() {
    final active = _bridgeReceiptStore.activeReceipt;
    return NodeFrame.response('', payload: <String, dynamic>{
      'activeReceipt': active?.toAgentJson(),
      'hasActiveReceipt': active != null,
      'statusSource': 'persisted-local-receipt',
      'networkRefreshPerformed': false,
      'foregroundApprovalRequired': true,
      'mayApproveOrSpend': false,
    });
  }

  NodeFrame _bridgeReceipts() {
    final stored = _bridgeReceiptStore.receipts.toList(growable: false)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    final receipts = stored.take(20).toList(growable: false);
    return NodeFrame.response('', payload: <String, dynamic>{
      'count': receipts.length,
      'totalStored': stored.length,
      'receipts': receipts
          .map((receipt) => receipt.toAgentJson())
          .toList(growable: false),
      'redacted': true,
      'containsWalletTransport': false,
      'containsReviewedPayload': false,
      'foregroundApprovalRequired': true,
      'mayApproveOrSpend': false,
    });
  }

  Future<NodeFrame> _bridgeQuote(Map<String, dynamic> params) async {
    await _base.initialize();
    if (!_base.isConnected || _base.address == null) {
      return NodeFrame.response('', error: <String, dynamic>{
        'code': 'WALLET_NOT_CONNECTED',
        'message': 'Create or import the internal Base wallet first.',
      });
    }
    final sourceId = (params['sourceChainId'] as num?)?.toInt();
    final sourceName = params['sourceChain']?.toString().trim().toLowerCase();
    BridgeSourceChain? source;
    for (final candidate in BridgeQuoteService.sourceChains) {
      if (candidate.id == sourceId ||
          candidate.name.toLowerCase() == sourceName ||
          candidate.key == sourceName) {
        source = candidate;
        break;
      }
    }
    if (source == null) {
      return NodeFrame.response('', error: <String, dynamic>{
        'code': 'BRIDGE_SOURCE_REQUIRED',
        'message': 'Choose Ethereum, Solana, or Robinhood Chain.',
      });
    }
    final quote = await _bridgeQuotes.quoteToBaseUsdc(BridgeQuoteRequest(
      sourceChain: source,
      sourceToken: params['sourceToken']?.toString() ?? source.nativeToken,
      amount: params['amount']?.toString() ?? '',
      sourceAddress: params['sourceAddress']?.toString() ?? '',
      baseDestinationAddress: _base.address!,
    ));
    return NodeFrame.response('', payload: quote.toAgentJson());
  }

  Future<NodeFrame> _status() async {
    await _base.initialize();
    final cached = <ProviderBalanceSnapshot>[
      ..._balances.cachedSnapshots,
      ..._balances.documentedDashboardOnlyStatuses().where((documented) {
        return !_balances.cachedSnapshots
            .any((cached) => cached.providerId == documented.providerId);
      }),
    ];
    return NodeFrame.response('', payload: <String, dynamic>{
      'walletConnected': _base.isConnected,
      'walletAddress': _base.address,
      'network': _base.networkName,
      'securityLevel': _base.securityLevel,
      'providerBalances': cached
          .map((snapshot) => snapshot.toAgentJson())
          .toList(growable: false),
      'balanceRefreshRequiresUserAction': true,
      'mayApproveOrSpend': false,
    });
  }

  Future<NodeFrame> _receipts() async {
    final receipts = await _receiptStore.read();
    return NodeFrame.response('', payload: <String, dynamic>{
      'count': receipts.length,
      'receipts': receipts
          .take(20)
          .map((receipt) => receipt.toAgentJson())
          .toList(growable: false),
      'redacted': true,
      'containsSignatures': false,
      'mayApproveOrSpend': false,
    });
  }
}
