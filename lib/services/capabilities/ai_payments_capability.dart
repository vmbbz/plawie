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

  Map<String, dynamic> _capabilities() => <String, dynamic>{
        'network': AiPaymentProviderCatalog.networkLabel,
        'networkId': AiPaymentProviderCatalog.network,
        'asset': AiPaymentProviderCatalog.assetLabel,
        'assetContract': AiPaymentProviderCatalog.usdcContract,
        'maximumSinglePaymentUsd': 5,
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
          'approve': false,
          'unlockWallet': false,
          'sign': false,
          'broadcast': false,
          'bridgeQuote': true,
          'bridgeExecute': false,
        },
        'humanApprovalContract':
            'Every payment requires the visible Base-page approval button and a fresh Android device unlock. Chat text is never approval.',
      };

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
