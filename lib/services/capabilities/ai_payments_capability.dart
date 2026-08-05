import '../../models/node_frame.dart';
import '../ai_payment_provider_catalog.dart';
import '../base_service.dart';
import '../provider_balance_service.dart';
import '../x402_payment_service.dart';
import '../x402_payment_transport_service.dart';
import 'capability_handler.dart';

/// Read-only agent view of wallet-funded AI payments.
///
/// There is deliberately no approve/sign/submit command. An agent can explain
/// status and prepare the user to open the Base page, but only visible Flutter
/// UI can mint an approval ticket and only Android can unlock the key.
class AiPaymentsCapability extends CapabilityHandler {
  AiPaymentsCapability({
    BaseService? baseService,
    ProviderBalanceService? balances,
    X402PaymentReceiptStore? receiptStore,
  })  : _base = baseService ?? BaseService(),
        _balances = balances ?? ProviderBalanceService.instance,
        _receiptStore = receiptStore ?? X402PaymentReceiptStore();

  final BaseService _base;
  final ProviderBalanceService _balances;
  final X402PaymentReceiptStore _receiptStore;

  @override
  String get name => 'payments';

  @override
  List<String> get commands => const <String>[
        'capabilities',
        'status',
        'receipts',
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
          'bridge': false,
        },
        'humanApprovalContract':
            'Every payment requires the visible Base-page approval button and a fresh Android device unlock. Chat text is never approval.',
      };

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
          .map((receipt) => receipt.toJson())
          .toList(growable: false),
      'redacted': true,
      'containsSignatures': false,
      'mayApproveOrSpend': false,
    });
  }
}
