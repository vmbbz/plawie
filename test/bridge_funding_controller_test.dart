import 'package:clawa/services/bridge/bridge_funding_controller.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/bridge_receipt_store.dart';
import 'package:clawa/services/bridge/evm_bridge_rpc_service.dart';
import 'package:clawa/services/bridge/external_wallet_session_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const typedAddress = '0x1111111111111111111111111111111111111111';
  const connectedAddress = '0x2222222222222222222222222222222222222222';
  const destination = '0x3333333333333333333333333333333333333333';
  const sourceToken = '0x4444444444444444444444444444444444444444';
  const spender = '0x5555555555555555555555555555555555555555';
  const sourceHash =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final now = DateTime.utc(2026, 8, 7, 12);

  late _MemoryReceiptPersistence persistence;
  late BridgeReceiptStore store;
  late _FakeQuoteProvider quotes;
  late _FakeWallet wallet;
  late _FakeRpc rpc;
  late _FakeBaseBalance baseBalance;

  setUp(() {
    persistence = _MemoryReceiptPersistence();
    store = BridgeReceiptStore.withPersistence(persistence);
    quotes = _FakeQuoteProvider();
    wallet = _FakeWallet(
      identity: _identity(
        chainId: BridgeConstants.ethereumChainId,
        address: connectedAddress,
      ),
    );
    rpc = _FakeRpc();
    baseBalance = _FakeBaseBalance();
  });

  BridgeFundingController controller({
    bool lifiEnabled = true,
    bool reownEnabled = true,
    String Function()? internalBaseAddress,
  }) =>
      BridgeFundingController(
        quoteProvider: quotes,
        wallet: wallet,
        receiptStore: store,
        rpc: rpc,
        baseBalance: baseBalance,
        internalBaseAddress: internalBaseAddress ?? () => destination,
        lifiConnectedEnabled: lifiEnabled,
        reownEvmEnabled: reownEnabled,
        clock: () => now,
        intentIdFactory: () => '0123456789abcdef0123456789abcdef',
      );

  test('connected account replaces typed address and review precedes wallet',
      () async {
    quotes.quotes.add(
      _quote(
        now: now,
        sourceAddress: connectedAddress,
        sourceToken: sourceToken,
        approvalAddress: spender,
      ),
    );
    rpc.allowances.add(BigInt.from(1000000));
    final service = controller();

    await service.prepareConnected(
      _request(
        sourceAddress: typedAddress,
        sourceToken: sourceToken,
      ),
    );

    expect(quotes.requests.single.sourceAddress, typedAddress);
    expect(quotes.connectedAddresses.single, connectedAddress);
    final receipt = store.activeReceipt!;
    expect(receipt.state, BridgeFundingState.awaitingPlawieReview);
    expect(receipt.sourceAddress, connectedAddress);
    expect(receipt.providerQuoteId, 'quote-1');
    expect(wallet.sentPayloads, isEmpty);
  });

  test('insufficient allowance gets its own exact review and requote',
      () async {
    quotes.quotes
      ..add(
        _quote(
          now: now,
          sourceAddress: connectedAddress,
          sourceToken: sourceToken,
          approvalAddress: spender,
          quoteId: 'quote-1',
        ),
      )
      ..add(
        _quote(
          now: now,
          sourceAddress: connectedAddress,
          sourceToken: sourceToken,
          approvalAddress: spender,
          quoteId: 'quote-2',
        ),
      );
    rpc.allowances
      ..add(BigInt.zero)
      ..add(BigInt.from(1000000));
    rpc.receipts.add(
      const EvmReceiptObservation(
        status: EvmReceiptStatus.succeeded,
        transactionHash: sourceHash,
        blockNumber: null,
      ),
    );
    wallet.onSend = (payload) {
      final persisted = store.activeReceipt!;
      expect(persisted.state, BridgeFundingState.awaitingExternalWallet);
      expect(persisted.reviewedPayloadHash, isNotNull);
      expect(payload.to, sourceToken);
      expect(
        payload.dataHex,
        rpc.encodeExactApproval(spender, BigInt.from(1000000)),
      );
    };
    final service = controller();

    await service.prepareConnected(
      _request(sourceAddress: typedAddress, sourceToken: sourceToken),
    );
    final intentId = store.activeReceipt!.intentId;
    expect(service.pendingReviewKind(intentId), BridgeReviewKind.allowance);

    await service.confirmEvmAllowance(intentId);

    expect(wallet.sentPayloads, hasLength(1));
    expect(quotes.quotesRequested, 2);
    expect(store.activeReceipt!.state, BridgeFundingState.awaitingPlawieReview);
    expect(store.activeReceipt!.providerQuoteId, 'quote-2');
    expect(service.pendingReviewKind(intentId), BridgeReviewKind.bridge);
  });

  test('native-token routes do not request allowance', () async {
    const native = '0x0000000000000000000000000000000000000000';
    quotes.quotes.add(
      _quote(
        now: now,
        sourceAddress: connectedAddress,
        sourceToken: native,
        approvalAddress: null,
        valueHex: '0xde0b6b3a7640000',
      ),
    );

    final service = controller();
    await service.prepareConnected(
      _request(sourceAddress: typedAddress, sourceToken: native, symbol: 'ETH'),
    );

    expect(rpc.allowanceRequests, isEmpty);
    expect(
      service.pendingReviewKind(store.activeReceipt!.intentId),
      BridgeReviewKind.bridge,
    );
  });

  test('bridge submission persists review and source hash before RPC polling',
      () async {
    quotes.quotes.add(
      _quote(
        now: now,
        sourceAddress: connectedAddress,
        sourceToken: sourceToken,
        approvalAddress: spender,
      ),
    );
    rpc.allowances.add(BigInt.from(1000000));
    rpc.receipts.add(
      const EvmReceiptObservation(
        status: EvmReceiptStatus.pending,
        transactionHash: sourceHash,
      ),
    );
    wallet.onSend = (_) {
      expect(
        store.activeReceipt!.state,
        BridgeFundingState.awaitingExternalWallet,
      );
      expect(store.activeReceipt!.reviewedPayloadHash, isNotNull);
    };
    rpc.onWaitForReceipt = (_) {
      expect(store.activeReceipt!.state, BridgeFundingState.submitted);
      expect(store.activeReceipt!.sourceTransactionHash, sourceHash);
    };
    final service = controller();

    await service.prepareConnected(
      _request(sourceAddress: typedAddress, sourceToken: sourceToken),
    );
    final intentId = store.activeReceipt!.intentId;
    await service.confirmConnectedBridge(intentId);

    expect(wallet.sentPayloads, hasLength(1));
    expect(rpc.receiptRequests, <String>[sourceHash]);
    expect(store.activeReceipt!.state, BridgeFundingState.sourcePending);
    await expectLater(
      service.confirmConnectedBridge(intentId),
      throwsA(_bridgeCode('bridge_confirmation_not_available')),
    );
    expect(wallet.sentPayloads, hasLength(1));
  });

  test('known wallet rejection returns to review without submitted state',
      () async {
    quotes.quotes.add(
      _quote(
        now: now,
        sourceAddress: connectedAddress,
        sourceToken: sourceToken,
        approvalAddress: spender,
      ),
    );
    rpc.allowances.add(BigInt.from(1000000));
    wallet.sendError = const ExternalWalletException('4001');
    final service = controller();

    await service.prepareConnected(
      _request(sourceAddress: typedAddress, sourceToken: sourceToken),
    );
    final intentId = store.activeReceipt!.intentId;
    await expectLater(
      service.confirmConnectedBridge(intentId),
      throwsA(isA<ExternalWalletException>()),
    );

    final receipt = store.activeReceipt!;
    expect(receipt.state, BridgeFundingState.awaitingPlawieReview);
    expect(receipt.sourceTransactionHash, isNull);
    expect(receipt.submissionOutcomeUnknown, isFalse);
  });

  test('process resume marks pre-hash wallet outcome unknown without resend',
      () async {
    final receipt = _receipt(
      now: now,
      state: BridgeFundingState.awaitingExternalWallet,
      reviewedPayloadHash:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    await store.upsert(receipt);
    final resumed = controller();

    await resumed.refreshStatus(receipt.intentId);

    expect(wallet.sentPayloads, isEmpty);
    expect(
        store.activeReceipt!.state, BridgeFundingState.awaitingExternalWallet);
    expect(store.activeReceipt!.submissionOutcomeUnknown, isTrue);
    expect(store.activeReceipt!.providerStatus, 'wallet_outcome_unknown');
  });

  test('Base USDC uses exact direct transfer with no LI.FI or allowance',
      () async {
    wallet.identity = _identity(
      chainId: BridgeConstants.baseChainId,
      address: connectedAddress,
    );
    rpc.receipts.add(
      const EvmReceiptObservation(
        status: EvmReceiptStatus.succeeded,
        transactionHash: sourceHash,
        blockNumber: null,
      ),
    );
    final service = controller(lifiEnabled: false);
    final request = _request(
      sourceAddress: typedAddress,
      sourceToken: BridgeConstants.baseUsdc,
      sourceChain: _baseChain,
    );

    await service.prepareConnected(request);
    final prepared = store.activeReceipt!;
    expect(prepared.provider, 'direct_base');
    expect(prepared.routeTool, 'direct_transfer');
    expect(prepared.minimumOutputUnits, request.amountUnits);
    expect(rpc.allowanceRequests, isEmpty);
    expect(quotes.quotesRequested, 0);

    await service.confirmConnectedBridge(prepared.intentId);

    final payload = wallet.sentPayloads.single;
    expect(payload.chainId, BridgeConstants.baseChainId);
    expect(payload.to.toLowerCase(), BridgeConstants.baseUsdc.toLowerCase());
    expect(payload.valueHex, '0x0');
    expect(
      payload.dataHex,
      rpc.encodeExactTransfer(destination, BigInt.from(1000000)),
    );
    expect(store.activeReceipt, isNull);
    final completed = store.receiptForIntent(prepared.intentId)!;
    expect(completed.state, BridgeFundingState.completed);
    expect(baseBalance.refreshCalls, 1);
  });

  test('non-USDC Base token never enters the direct path', () async {
    wallet.identity = _identity(
      chainId: BridgeConstants.baseChainId,
      address: connectedAddress,
    );
    final service = controller(lifiEnabled: false);

    await expectLater(
      service.prepareConnected(
        _request(
          sourceAddress: typedAddress,
          sourceToken: sourceToken,
          sourceChain: _baseChain,
        ),
      ),
      throwsA(_bridgeCode('lifi_connected_disabled')),
    );

    expect(quotes.quotesRequested, 0);
    expect(rpc.allowanceRequests, isEmpty);
  });

  test('changed internal Base destination invalidates final confirmation',
      () async {
    wallet.identity = _identity(
      chainId: BridgeConstants.baseChainId,
      address: connectedAddress,
    );
    var currentDestination = destination;
    final service = controller(
      lifiEnabled: false,
      internalBaseAddress: () => currentDestination,
    );
    await service.prepareConnected(
      _request(
        sourceAddress: typedAddress,
        sourceToken: BridgeConstants.baseUsdc,
        sourceChain: _baseChain,
      ),
    );
    currentDestination = '0x7777777777777777777777777777777777777777';

    await expectLater(
      service.confirmConnectedBridge(store.activeReceipt!.intentId),
      throwsA(_bridgeCode('base_destination_changed')),
    );
    expect(wallet.sentPayloads, isEmpty);
  });
}

Matcher _bridgeCode(String code) => isA<BridgeValidationException>()
    .having((error) => error.code, 'code', code);

const _ethereumChain = BridgeChain(
  id: BridgeConstants.ethereumChainId,
  key: 'eth',
  name: 'Ethereum',
  type: BridgeChainType.evm,
  nativeTokenSymbol: 'ETH',
);

const _baseChain = BridgeChain(
  id: BridgeConstants.baseChainId,
  key: 'bas',
  name: 'Base',
  type: BridgeChainType.evm,
  nativeTokenSymbol: 'ETH',
);

BridgeFundingRequest _request({
  required String sourceAddress,
  required String sourceToken,
  BridgeChain sourceChain = _ethereumChain,
  String symbol = 'USDC',
}) =>
    BridgeFundingRequest(
      method: BridgeFundingMethod.connectedWallet,
      sourceChain: sourceChain,
      sourceToken: BridgeToken(
        chainId: sourceChain.id,
        address: sourceToken,
        symbol: symbol,
        decimals: 6,
        solverDepositable: false,
      ),
      amount: '1',
      amountUnits: '1000000',
      baseDestinationAddress: '0x3333333333333333333333333333333333333333',
      sourceAddress: sourceAddress,
      selfCustodyConfirmed: true,
    );

BridgeExecutableQuote _quote({
  required DateTime now,
  required String sourceAddress,
  required String sourceToken,
  required String? approvalAddress,
  String quoteId = 'quote-1',
  String valueHex = '0x0',
}) {
  final request = _request(
    sourceAddress: sourceAddress,
    sourceToken: sourceToken,
    symbol: sourceToken == '0x0000000000000000000000000000000000000000'
        ? 'ETH'
        : 'USDC',
  );
  final payload = EvmBridgeExecutionPayload(
    chainId: BridgeConstants.ethereumChainId,
    from: sourceAddress,
    to: '0x6666666666666666666666666666666666666666',
    valueHex: valueHex,
    dataHex: '0x1234',
    gasLimitHex: '0x186a0',
    approvalAddress: approvalAddress,
  );
  return BridgeExecutableQuote(
    estimate: BridgeEstimate(
      provider: 'lifi',
      quoteId: quoteId,
      request: request,
      minimumOutputUnits: '990000',
      minimumOutputDisplay: '0.99',
      routeTool: 'across',
      quotedAt: now,
      expiresAt: now.add(const Duration(minutes: 1)),
      approvalAddress: approvalAddress,
    ),
    connectedSourceAddress: sourceAddress,
    destinationChainId: BridgeConstants.baseChainId,
    destinationToken: const BridgeToken(
      chainId: BridgeConstants.baseChainId,
      address: BridgeConstants.baseUsdc,
      symbol: 'USDC',
      decimals: 6,
      solverDepositable: false,
    ),
    payload: payload,
    fingerprint: _testPayloadFingerprint(payload),
  );
}

String _testPayloadFingerprint(EvmBridgeExecutionPayload payload) => sha256
    .convert(
      '${payload.chainId}|${payload.from.toLowerCase()}|'
              '${payload.to.toLowerCase()}|${payload.valueHex.toLowerCase()}|'
              '${payload.dataHex.toLowerCase()}'
          .codeUnits,
    )
    .toString();

ExternalWalletIdentity _identity({
  required int chainId,
  required String address,
}) =>
    ExternalWalletIdentity(
      transport: ExternalWalletTransport.reownEvm,
      walletLabel: 'Test Wallet',
      publicAddress: address,
      chainId: chainId,
      chainType: BridgeChainType.evm,
      approvedMethods: const <String>{'eth_sendTransaction'},
      approvedFeatures: const <String>{},
    );

BridgeFundingReceipt _receipt({
  required DateTime now,
  required BridgeFundingState state,
  required String reviewedPayloadHash,
}) =>
    BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: 'resume-intent',
      method: BridgeFundingMethod.connectedWallet,
      provider: 'lifi',
      state: state,
      sourceChainId: BridgeConstants.ethereumChainId,
      sourceTokenAddress: '0x4444444444444444444444444444444444444444',
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1000000',
      baseDestinationAddress: '0x3333333333333333333333333333333333333333',
      sourceAddress: '0x2222222222222222222222222222222222222222',
      providerQuoteId: 'quote-1',
      routeTool: 'across',
      minimumOutputUnits: '990000',
      walletTransport: ExternalWalletTransport.reownEvm,
      reviewedPayloadHash: reviewedPayloadHash,
      createdAt: now,
      updatedAt: now,
    );

final class _FakeQuoteProvider implements BridgeExecutableQuoteProvider {
  final List<BridgeExecutableQuote> quotes = <BridgeExecutableQuote>[];
  final List<BridgeFundingRequest> requests = <BridgeFundingRequest>[];
  final List<String> connectedAddresses = <String>[];
  int quotesRequested = 0;

  @override
  Future<BridgeExecutableQuote> executableQuote(
    BridgeFundingRequest request, {
    required String connectedSourceAddress,
  }) async {
    quotesRequested += 1;
    requests.add(request);
    connectedAddresses.add(connectedSourceAddress);
    return quotes.removeAt(0);
  }
}

final class _FakeWallet implements ExternalWalletSessionService {
  _FakeWallet({required this.identity});

  @override
  ExternalWalletIdentity? identity;
  final List<EvmBridgeExecutionPayload> sentPayloads =
      <EvmBridgeExecutionPayload>[];
  ExternalWalletException? sendError;
  void Function(EvmBridgeExecutionPayload payload)? onSend;

  @override
  Future<ExternalWalletIdentity> connect(
    BridgeChain chain, {
    ExternalWalletTransport? transport,
  }) async =>
      identity!;

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<ExternalWalletOption>> discover(BridgeChain chain) async =>
      const <ExternalWalletOption>[];

  @override
  Future<String> sendEvmTransaction(EvmBridgeExecutionPayload payload) async {
    sentPayloads.add(payload);
    onSend?.call(payload);
    final error = sendError;
    if (error != null) throw error;
    return '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  }

  @override
  Future<SolanaWalletSubmissionResult> submitSolanaTransaction(
    SolanaBridgeExecutionPayload payload,
  ) =>
      throw UnimplementedError();
}

final class _FakeRpc implements EvmBridgeRpc {
  final EvmBridgeRpcService _encoder = EvmBridgeRpcService(
    transport: _UnusedTransport(),
  );
  final List<BigInt> allowances = <BigInt>[];
  final List<Map<String, Object?>> allowanceRequests = <Map<String, Object?>>[];
  final List<EvmReceiptObservation> receipts = <EvmReceiptObservation>[];
  final List<String> receiptRequests = <String>[];
  void Function(String hash)? onWaitForReceipt;

  @override
  Future<BigInt> allowance({
    required int chainId,
    required String tokenAddress,
    required String owner,
    required String spender,
  }) async {
    allowanceRequests.add(<String, Object?>{
      'chainId': chainId,
      'token': tokenAddress,
      'owner': owner,
      'spender': spender,
    });
    return allowances.removeAt(0);
  }

  @override
  String encodeExactApproval(String spender, BigInt amount) =>
      _encoder.encodeExactApproval(spender, amount);

  @override
  String encodeExactTransfer(String destination, BigInt amount) =>
      _encoder.encodeExactTransfer(destination, amount);

  @override
  Future<BigInt> estimateGas(EvmBridgeExecutionPayload payload) async =>
      BigInt.from(100000);

  @override
  Future<EvmReceiptObservation> waitForReceipt({
    required int chainId,
    required String transactionHash,
  }) async {
    receiptRequests.add(transactionHash);
    onWaitForReceipt?.call(transactionHash);
    return receipts.removeAt(0);
  }
}

final class _FakeBaseBalance implements BaseBalanceRefreshService {
  int refreshCalls = 0;
  bool succeeds = true;

  @override
  Future<bool> refresh() async {
    refreshCalls += 1;
    return succeeds;
  }
}

final class _MemoryReceiptPersistence implements BridgeReceiptPersistence {
  @override
  String? activeBridgeReceiptJson;

  @override
  List<String> bridgeReceipts = <String>[];

  @override
  Future<bool> setActiveBridgeReceiptJson(String? value) async {
    activeBridgeReceiptJson = value;
    return true;
  }

  @override
  Future<bool> setBridgeReceipts(List<String> value) async {
    bridgeReceipts = List<String>.from(value);
    return true;
  }
}

final class _UnusedTransport implements EvmRpcTransport {
  @override
  Future<EvmRpcRawResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    required int maxBytes,
  }) =>
      throw StateError('unused');
}
