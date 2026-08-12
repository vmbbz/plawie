import 'dart:async';
import 'dart:typed_data';

import 'package:clawa/services/bridge/bridge_funding_controller.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/bridge_receipt_store.dart';
import 'package:clawa/services/bridge/evm_bridge_rpc_service.dart';
import 'package:clawa/services/bridge/external_wallet_session_service.dart';
import 'package:clawa/services/bridge/lifi_status_service.dart';
import 'package:clawa/services/bridge/relay_deposit_service.dart';
import 'package:clawa/services/bridge/solana_rpc_broadcaster.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/solana_transaction_fixture.dart';

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
  late _FakeLifiStatus lifiStatus;
  late _FakeSolanaRpc solanaRpc;
  late _FakeRelayDeposit relay;
  late SolanaTransactionFixture solanaFixture;

  setUp(() async {
    solanaFixture = await SolanaTransactionFixture.create();
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
    lifiStatus = _FakeLifiStatus();
    solanaRpc = _FakeSolanaRpc();
    relay = _FakeRelayDeposit();
  });

  BridgeFundingController controller({
    bool lifiEnabled = true,
    bool reownEnabled = true,
    String Function()? internalBaseAddress,
    Future<void> Function(Duration)? delay,
    bool Function()? isForeground,
    bool relayEnabled = true,
  }) =>
      BridgeFundingController(
        quoteProvider: quotes,
        wallet: wallet,
        receiptStore: store,
        rpc: rpc,
        solanaRpc: solanaRpc,
        lifiStatus: lifiStatus,
        relay: relay,
        baseBalance: baseBalance,
        internalBaseAddress: internalBaseAddress ?? () => destination,
        lifiConnectedEnabled: lifiEnabled,
        relayDepositEnabled: relayEnabled,
        reownEvmEnabled: reownEnabled,
        solanaMwaEnabled: true,
        reownSolanaFallbackEnabled: true,
        delay: delay,
        isForeground: isForeground,
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

  test('explicit wallet transport replaces a different unsent live session',
      () async {
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signTransaction'},
      transport: ExternalWalletTransport.reownSolanaPhantom,
    );
    wallet.connectIdentity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signTransaction'},
    );
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));

    await controller().prepareConnected(
      _solanaRequest(solanaFixture),
      transport: ExternalWalletTransport.solanaMwa,
    );

    expect(wallet.disconnectCalls, 1);
    expect(wallet.connectTransports, <ExternalWalletTransport?>[
      ExternalWalletTransport.solanaMwa,
    ]);
    expect(store.activeReceipt!.walletTransport,
        ExternalWalletTransport.solanaMwa);
  });

  test('changing source chain disconnects a stale wallet session first',
      () async {
    wallet.connectIdentity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signTransaction'},
    );
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));

    await controller().prepareConnected(_solanaRequest(solanaFixture));

    expect(wallet.disconnectCalls, 1);
    expect(wallet.connectTransports, <ExternalWalletTransport?>[null]);
    expect(store.activeReceipt!.sourceChainId, BridgeConstants.solanaChainId);
  });

  test('external wallet can change only when no funding receipt is active',
      () async {
    final service = controller();

    await service.disconnectExternalWallet();
    expect(wallet.disconnectCalls, 1);
    expect(service.connectedExternalWallet, isNull);

    wallet.identity = _identity(
      chainId: BridgeConstants.ethereumChainId,
      address: connectedAddress,
    );
    quotes.quotes.add(
      _quote(
        now: now,
        sourceAddress: connectedAddress,
        sourceToken: sourceToken,
        approvalAddress: spender,
      ),
    );
    rpc.allowances.add(BigInt.from(1000000));
    await service.prepareConnected(
      _request(sourceAddress: typedAddress, sourceToken: sourceToken),
    );

    await expectLater(
      service.disconnectExternalWallet(),
      throwsA(_bridgeCode('active_bridge_receipt_exists')),
    );
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
    baseBalance.onRefresh = () {
      final settled = store.receiptForIntent(prepared.intentId)!;
      expect(settled.state, BridgeFundingState.completed);
      expect(settled.balanceRefreshPending, isTrue);
    };

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

  test('direct Base settlement remains completed when balance refresh fails',
      () async {
    wallet.identity = _identity(
      chainId: BridgeConstants.baseChainId,
      address: connectedAddress,
    );
    rpc.receipts.add(
      const EvmReceiptObservation(
        status: EvmReceiptStatus.succeeded,
        transactionHash: sourceHash,
      ),
    );
    baseBalance.succeeds = false;
    final service = controller(lifiEnabled: false);

    await service.prepareConnected(
      _request(
        sourceAddress: typedAddress,
        sourceToken: BridgeConstants.baseUsdc,
        sourceChain: _baseChain,
      ),
    );
    final intentId = store.activeReceipt!.intentId;
    await service.confirmConnectedBridge(intentId);

    final completed = store.receiptForIntent(intentId)!;
    expect(completed.state, BridgeFundingState.completed);
    expect(completed.balanceRefreshPending, isTrue);
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

  test('Solana sign-only freezes review and broadcasts verified bytes once',
      () async {
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signTransaction'},
    );
    wallet.solanaResult = SignedSolanaTransaction(
      solanaFixture.signedTransaction,
    );
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));
    solanaRpc
      ..broadcastResult = solanaFixture.signature
      ..observations.add(
        SolanaSignatureObservation(
          signature: solanaFixture.signature,
          status: SolanaSignatureStatus.processed,
          slot: 10,
        ),
      );
    wallet.onSolanaSubmit = (_) {
      final receipt = store.activeReceipt!;
      expect(receipt.state, BridgeFundingState.awaitingExternalWallet);
      expect(receipt.reviewedPayloadHash,
          sha256.convert(solanaFixture.message).toString());
      expect(receipt.sourceBlockhash, solanaFixture.blockhash);
      expect(receipt.sourceTransactionHash, isNull);
    };
    solanaRpc.onBroadcast = (_) {
      final receipt = store.activeReceipt!;
      expect(receipt.state, BridgeFundingState.awaitingExternalWallet);
      expect(receipt.sourceTransactionHash, solanaFixture.signature);
      expect(receipt.submissionOutcomeUnknown, isFalse);
    };
    solanaRpc.onStatus = (_) {
      final receipt = store.activeReceipt!;
      expect(receipt.state, BridgeFundingState.submitted);
      expect(receipt.sourceTransactionHash, solanaFixture.signature);
    };
    final service = controller();

    await service.prepareConnected(_solanaRequest(solanaFixture));
    final intentId = store.activeReceipt!.intentId;
    expect(service.pendingReviewKind(intentId), BridgeReviewKind.bridge);
    await service.confirmConnectedBridge(intentId);

    expect(wallet.solanaSubmissions, hasLength(1));
    expect(solanaRpc.broadcasts.single, solanaFixture.signedTransaction);
    expect(solanaRpc.statusRequests, <String>[solanaFixture.signature]);
    expect(store.activeReceipt!.state, BridgeFundingState.sourcePending);
    await expectLater(
      service.confirmConnectedBridge(intentId),
      throwsA(_bridgeCode('bridge_confirmation_not_available')),
    );
    expect(wallet.solanaSubmissions, hasLength(1));
    expect(solanaRpc.broadcasts, hasLength(1));
  });

  test('Solana MWA prefers sign-and-send when sign-only is also advertised',
      () async {
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{
        'solana_signTransaction',
        'solana_signAndSendTransaction',
      },
    );
    wallet.solanaResult = SubmittedSolanaTransaction(solanaFixture.signature);
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));
    solanaRpc.observations.add(
      SolanaSignatureObservation(
        signature: solanaFixture.signature,
        status: SolanaSignatureStatus.confirmed,
        slot: 11,
      ),
    );
    solanaRpc.onStatus = (_) {
      final receipt = store.activeReceipt!;
      expect(receipt.state, BridgeFundingState.submitted);
      expect(receipt.sourceTransactionHash, solanaFixture.signature);
    };
    final service = controller();

    await service.prepareConnected(_solanaRequest(solanaFixture));
    await service.confirmConnectedBridge(store.activeReceipt!.intentId);

    expect(wallet.solanaSubmissions, hasLength(1));
    expect(solanaRpc.broadcasts, isEmpty);
    expect(solanaRpc.statusRequests, <String>[solanaFixture.signature]);
    expect(store.activeReceipt!.state, BridgeFundingState.sourcePending);
  });

  test(
      'ambiguous Solana sign-and-send remains active and cannot retry or cancel',
      () async {
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signAndSendTransaction'},
    );
    wallet.solanaError = const ExternalWalletException('wallet_request_failed');
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));
    final service = controller();

    await service.prepareConnected(_solanaRequest(solanaFixture));
    final intentId = store.activeReceipt!.intentId;
    await expectLater(
      service.confirmConnectedBridge(intentId),
      throwsA(isA<ExternalWalletException>()),
    );

    final receipt = store.activeReceipt!;
    expect(receipt.state, BridgeFundingState.awaitingExternalWallet);
    expect(receipt.sourceTransactionHash, isNull);
    expect(receipt.submissionOutcomeUnknown, isTrue);
    await expectLater(
      service.confirmConnectedBridge(intentId),
      throwsA(_bridgeCode('bridge_confirmation_not_available')),
    );
    await expectLater(
      service.cancelBeforeSubmission(intentId),
      throwsA(_bridgeCode('bridge_cancellation_not_available')),
    );
    expect(wallet.solanaSubmissions, hasLength(1));
    expect(solanaRpc.broadcasts, isEmpty);
  });

  test(
      'malformed sign-and-send evidence is outcome-unknown and never broadcasts',
      () async {
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signAndSendTransaction'},
    );
    wallet.solanaResult = const SubmittedSolanaTransaction('not-base58');
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));
    final service = controller();

    await service.prepareConnected(_solanaRequest(solanaFixture));
    await expectLater(
      service.confirmConnectedBridge(store.activeReceipt!.intentId),
      throwsA(isA<BridgeValidationException>()),
    );

    expect(store.activeReceipt!.submissionOutcomeUnknown, isTrue);
    expect(store.activeReceipt!.sourceTransactionHash, isNull);
    expect(solanaRpc.broadcasts, isEmpty);
    expect(solanaRpc.statusRequests, isEmpty);
  });

  test('invalid sign-only bytes safely return to review without broadcasting',
      () async {
    final invalidSigned = Uint8List.fromList(solanaFixture.signedTransaction)
      ..[1] ^= 1;
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signTransaction'},
      transport: ExternalWalletTransport.reownSolanaPhantom,
    );
    wallet.solanaResult = SignedSolanaTransaction(invalidSigned);
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));
    final service = controller();

    await service.prepareConnected(_solanaRequest(solanaFixture));
    await expectLater(
      service.confirmConnectedBridge(store.activeReceipt!.intentId),
      throwsA(_bridgeCode('solana_signature_invalid')),
    );

    expect(store.activeReceipt!.state, BridgeFundingState.awaitingPlawieReview);
    expect(store.activeReceipt!.submissionOutcomeUnknown, isFalse);
    expect(solanaRpc.broadcasts, isEmpty);
  });

  test('Solana broadcast timeout recovers by status and never rebroadcasts',
      () async {
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signTransaction'},
    );
    wallet.solanaResult = SignedSolanaTransaction(
      solanaFixture.signedTransaction,
    );
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));
    solanaRpc.broadcastError = const SolanaRpcException(
      'timeout',
      outcomeUnknown: true,
    );
    final service = controller();

    await service.prepareConnected(_solanaRequest(solanaFixture));
    final intentId = store.activeReceipt!.intentId;
    await expectLater(
      service.confirmConnectedBridge(intentId),
      throwsA(isA<SolanaRpcException>()),
    );

    expect(
        store.activeReceipt!.state, BridgeFundingState.awaitingExternalWallet);
    expect(store.activeReceipt!.sourceTransactionHash, solanaFixture.signature);
    expect(store.activeReceipt!.submissionOutcomeUnknown, isTrue);
    solanaRpc
      ..broadcastError = null
      ..observations.add(
        SolanaSignatureObservation(
          signature: solanaFixture.signature,
          status: SolanaSignatureStatus.processed,
          slot: 13,
        ),
      );

    await service.refreshStatus(intentId);

    expect(store.activeReceipt!.state, BridgeFundingState.sourcePending);
    expect(store.activeReceipt!.submissionOutcomeUnknown, isFalse);
    expect(solanaRpc.broadcasts, hasLength(1));
    expect(solanaRpc.statusRequests, <String>[solanaFixture.signature]);
    await expectLater(
      service.confirmConnectedBridge(intentId),
      throwsA(_bridgeCode('bridge_confirmation_not_available')),
    );
    expect(solanaRpc.broadcasts, hasLength(1));
  });

  test('changed Solana wallet method invalidates review without wallet action',
      () async {
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signAndSendTransaction'},
    );
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));
    final service = controller();

    await service.prepareConnected(_solanaRequest(solanaFixture));
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signTransaction'},
    );

    await expectLater(
      service.confirmConnectedBridge(store.activeReceipt!.intentId),
      throwsA(_bridgeCode('prepared_wallet_context_changed')),
    );
    expect(store.activeReceipt!.state, BridgeFundingState.awaitingPlawieReview);
    expect(wallet.solanaSubmissions, isEmpty);
    expect(solanaRpc.broadcasts, isEmpty);
  });

  test('changed Solana account invalidates review without wallet action',
      () async {
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signTransaction'},
    );
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));
    final service = controller();

    await service.prepareConnected(_solanaRequest(solanaFixture));
    wallet.identity = _solanaIdentity(
      address: base58Encode(List<int>.filled(32, 9)),
      methods: const <String>{'solana_signTransaction'},
    );

    await expectLater(
      service.confirmConnectedBridge(store.activeReceipt!.intentId),
      throwsA(_bridgeCode('prepared_wallet_context_changed')),
    );
    expect(wallet.solanaSubmissions, isEmpty);
    expect(solanaRpc.broadcasts, isEmpty);
  });

  test('concurrent Solana confirmation invokes the wallet only once', () async {
    wallet.identity = _solanaIdentity(
      address: solanaFixture.signer,
      methods: const <String>{'solana_signAndSendTransaction'},
    );
    wallet.solanaCompleter = Completer<SolanaWalletSubmissionResult>();
    quotes.quotes.add(_solanaQuote(now: now, fixture: solanaFixture));
    solanaRpc.observations.add(
      SolanaSignatureObservation(
        signature: solanaFixture.signature,
        status: SolanaSignatureStatus.processed,
        slot: 14,
      ),
    );
    final service = controller();

    await service.prepareConnected(_solanaRequest(solanaFixture));
    final intentId = store.activeReceipt!.intentId;
    final first = service.confirmConnectedBridge(intentId);
    while (wallet.solanaSubmissions.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await expectLater(
      service.confirmConnectedBridge(intentId),
      throwsA(_bridgeCode('bridge_confirmation_in_progress')),
    );
    wallet.solanaCompleter!.complete(
      SubmittedSolanaTransaction(solanaFixture.signature),
    );
    await first;

    expect(wallet.solanaSubmissions, hasLength(1));
    expect(solanaRpc.broadcasts, isEmpty);
  });

  test('Solana resume with a persisted signature performs status read only',
      () async {
    await store.upsert(
      _solanaReceipt(
        now: now,
        fixture: solanaFixture,
        state: BridgeFundingState.submitted,
      ),
    );
    solanaRpc.observations.add(
      SolanaSignatureObservation(
        signature: solanaFixture.signature,
        status: SolanaSignatureStatus.processed,
        slot: 12,
      ),
    );
    final resumed = controller();

    await resumed.refreshStatus('solana-resume-intent');

    expect(wallet.solanaSubmissions, isEmpty);
    expect(solanaRpc.broadcasts, isEmpty);
    expect(solanaRpc.statusRequests, <String>[solanaFixture.signature]);
    expect(store.activeReceipt!.state, BridgeFundingState.sourcePending);
  });

  test('LI.FI observations persist destination settlement before Base refresh',
      () async {
    final receipt = _trackingReceipt(now: now);
    await store.upsert(receipt);
    lifiStatus.observations
      ..add(
        const LifiStatusObservation(
          state: BridgeFundingState.destinationPending,
          providerStatus: 'PENDING',
          providerSubstatus: 'WAIT_DESTINATION_TRANSACTION',
          destinationTransactionHash: null,
          actualOutputUnits: null,
          explorerLinks: <Uri>[],
        ),
      )
      ..add(
        const LifiStatusObservation(
          state: BridgeFundingState.completed,
          providerStatus: 'DONE',
          providerSubstatus: 'COMPLETED',
          destinationTransactionHash:
              '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          actualOutputUnits: '990000',
          explorerLinks: <Uri>[],
        ),
      );
    baseBalance
      ..succeeds = false
      ..onRefresh = () {
        final persisted = store.receiptForIntent(receipt.intentId)!;
        expect(persisted.state, BridgeFundingState.completed);
        expect(persisted.providerStatus, 'DONE');
        expect(persisted.destinationTransactionHash, isNotNull);
      };
    final service = controller();

    await service.refreshStatus(receipt.intentId);
    expect(store.activeReceipt!.state, BridgeFundingState.destinationPending);
    await service.refreshStatus(receipt.intentId);

    final completed = store.receiptForIntent(receipt.intentId)!;
    expect(completed.state, BridgeFundingState.completed);
    expect(completed.providerSubstatus, 'COMPLETED');
    expect(completed.actualOutputUnits, '990000');
    expect(completed.balanceRefreshPending, isTrue);
    expect(baseBalance.refreshCalls, 1);

    baseBalance.succeeds = true;
    await service.refreshBaseBalance(receipt.intentId);
    expect(
      store.receiptForIntent(receipt.intentId)!.balanceRefreshPending,
      isFalse,
    );
    expect(baseBalance.refreshCalls, 2);
  });

  test('LI.FI polling is bounded with exact backoff and no wallet replay',
      () async {
    final receipt = _trackingReceipt(now: now);
    await store.upsert(receipt);
    for (var index = 0; index < 7; index += 1) {
      lifiStatus.observations.add(
        const LifiStatusObservation(
          state: BridgeFundingState.sourcePending,
          providerStatus: 'PENDING',
          providerSubstatus: 'WAIT_SOURCE_CONFIRMATIONS',
          destinationTransactionHash: null,
          actualOutputUnits: null,
          explorerLinks: <Uri>[],
        ),
      );
    }
    final delays = <Duration>[];
    final service = controller(delay: (value) async => delays.add(value));

    await service.pollSettlement(receipt.intentId, maxObservations: 7);

    expect(delays, const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ]);
    expect(lifiStatus.requests, hasLength(7));
    expect(wallet.sentPayloads, isEmpty);
    expect(wallet.solanaSubmissions, isEmpty);
    expect(solanaRpc.broadcasts, isEmpty);
  });

  test('LI.FI polling pauses off-foreground and honors bounded Retry-After',
      () async {
    final receipt = _trackingReceipt(now: now);
    await store.upsert(receipt);
    final paused = controller(isForeground: () => false);
    await paused.pollSettlement(receipt.intentId);
    expect(lifiStatus.requests, isEmpty);

    lifiStatus.errors.add(
      const LifiStatusException(
        'rate_limited',
        retryAfter: Duration(seconds: 60),
      ),
    );
    lifiStatus.observations.add(
      const LifiStatusObservation(
        state: BridgeFundingState.destinationPending,
        providerStatus: 'PENDING',
        providerSubstatus: 'WAIT_DESTINATION_TRANSACTION',
        destinationTransactionHash: null,
        actualOutputUnits: null,
        explorerLinks: <Uri>[],
      ),
    );
    final delays = <Duration>[];
    final resumed = controller(delay: (value) async => delays.add(value));
    await resumed.pollSettlement(receipt.intentId, maxObservations: 2);

    expect(delays, const <Duration>[Duration(seconds: 60)]);
    expect(lifiStatus.requests, hasLength(2));
  });

  test('LI.FI polling stops immediately after a terminal observation',
      () async {
    final receipt = _trackingReceipt(now: now);
    await store.upsert(receipt);
    lifiStatus.observations.add(
      const LifiStatusObservation(
        state: BridgeFundingState.completed,
        providerStatus: 'DONE',
        providerSubstatus: 'COMPLETED',
        destinationTransactionHash:
            '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        actualOutputUnits: '990000',
        explorerLinks: <Uri>[],
      ),
    );
    final delays = <Duration>[];

    await controller(delay: (value) async => delays.add(value))
        .pollSettlement(receipt.intentId);

    expect(lifiStatus.requests, hasLength(1));
    expect(delays, isEmpty);
  });

  test('EVM unknown-return recovery attaches only the reviewed transaction',
      () async {
    const target = '0x6666666666666666666666666666666666666666';
    final reviewed = EvmBridgeExecutionPayload(
      chainId: BridgeConstants.ethereumChainId,
      from: connectedAddress,
      to: target,
      valueHex: '0x0',
      dataHex: '0x1234',
      gasLimitHex: '0x186a0',
      approvalAddress: null,
    );
    final receipt = _receipt(
      now: now,
      state: BridgeFundingState.awaitingExternalWallet,
      reviewedPayloadHash: _testPayloadFingerprint(reviewed),
      submissionOutcomeUnknown: true,
    );
    await store.upsert(receipt);
    rpc.transactions.add(
      const EvmTransactionObservation(
        chainId: BridgeConstants.ethereumChainId,
        transactionHash: sourceHash,
        from: connectedAddress,
        to: target,
        valueHex: '0x0',
        dataHex: '0x1234',
      ),
    );
    lifiStatus.observations.add(
      const LifiStatusObservation(
        state: BridgeFundingState.sourcePending,
        providerStatus: 'PENDING',
        providerSubstatus: 'WAIT_SOURCE_CONFIRMATIONS',
        destinationTransactionHash: null,
        actualOutputUnits: null,
        explorerLinks: <Uri>[],
      ),
    );
    final service = controller();

    await service.recoverEvmTransactionHash(receipt.intentId, sourceHash);

    final recovered = store.activeReceipt!;
    expect(recovered.state, BridgeFundingState.sourcePending);
    expect(recovered.sourceTransactionHash, sourceHash);
    expect(recovered.submissionOutcomeUnknown, isFalse);
    expect(lifiStatus.requests, hasLength(1));
    expect(wallet.sentPayloads, isEmpty);
  });

  test('EVM recovery mismatch remains outcome-unknown and never contacts LI.FI',
      () async {
    final receipt = _receipt(
      now: now,
      state: BridgeFundingState.awaitingExternalWallet,
      reviewedPayloadHash:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      submissionOutcomeUnknown: true,
    );
    await store.upsert(receipt);
    rpc.transactions.add(
      const EvmTransactionObservation(
        chainId: BridgeConstants.ethereumChainId,
        transactionHash: sourceHash,
        from: connectedAddress,
        to: '0x6666666666666666666666666666666666666666',
        valueHex: '0x0',
        dataHex: '0x1234',
      ),
    );

    await expectLater(
      controller().recoverEvmTransactionHash(receipt.intentId, sourceHash),
      throwsA(_bridgeCode('recovery_transaction_mismatch')),
    );

    expect(store.activeReceipt!.sourceTransactionHash, isNull);
    expect(store.activeReceipt!.submissionOutcomeUnknown, isTrue);
    expect(lifiStatus.requests, isEmpty);
    expect(wallet.sentPayloads, isEmpty);
  });

  test('direct Base recovery requires the exact reviewed USDC transfer',
      () async {
    final data = rpc.encodeExactTransfer(destination, BigInt.from(1000000));
    final payload = EvmBridgeExecutionPayload(
      chainId: BridgeConstants.baseChainId,
      from: connectedAddress,
      to: BridgeConstants.baseUsdc,
      valueHex: '0x0',
      dataHex: data,
      gasLimitHex: '0x186a0',
      approvalAddress: null,
    );
    final receipt = BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: 'direct-recovery-intent',
      method: BridgeFundingMethod.connectedWallet,
      provider: 'direct_base',
      state: BridgeFundingState.awaitingExternalWallet,
      sourceChainId: BridgeConstants.baseChainId,
      sourceTokenAddress: BridgeConstants.baseUsdc,
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1000000',
      baseDestinationAddress: destination,
      sourceAddress: connectedAddress,
      routeTool: 'direct_transfer',
      minimumOutputUnits: '1000000',
      reviewedPayloadHash: _testPayloadFingerprint(payload),
      submissionOutcomeUnknown: true,
      createdAt: now,
      updatedAt: now,
    );
    await store.upsert(receipt);
    rpc.transactions.add(
      EvmTransactionObservation(
        chainId: BridgeConstants.baseChainId,
        transactionHash: sourceHash,
        from: connectedAddress,
        to: BridgeConstants.baseUsdc,
        valueHex: '0x0',
        dataHex: data,
      ),
    );
    rpc.receipts.add(
      const EvmReceiptObservation(
        status: EvmReceiptStatus.succeeded,
        transactionHash: sourceHash,
      ),
    );

    await controller().recoverEvmTransactionHash(receipt.intentId, sourceHash);

    expect(store.receiptForIntent(receipt.intentId)!.state,
        BridgeFundingState.completed);
    expect(lifiStatus.requests, isEmpty);
    expect(wallet.sentPayloads, isEmpty);
  });

  test('Solana pasted-signature recovery verifies frozen bytes without resend',
      () async {
    final receipt = _solanaReceipt(
      now: now,
      fixture: solanaFixture,
      state: BridgeFundingState.awaitingExternalWallet,
      submissionOutcomeUnknown: true,
    );
    await store.upsert(receipt);
    solanaRpc.transactions.add(
      SolanaFetchedTransaction(
        signature: solanaFixture.signature,
        transactionBytes: solanaFixture.signedTransaction,
        slot: 50,
        failed: false,
      ),
    );
    lifiStatus.observations.add(
      const LifiStatusObservation(
        state: BridgeFundingState.sourcePending,
        providerStatus: 'PENDING',
        providerSubstatus: 'WAIT_SOURCE_CONFIRMATIONS',
        destinationTransactionHash: null,
        actualOutputUnits: null,
        explorerLinks: <Uri>[],
      ),
    );

    await controller().recoverSolanaSignature(
      receipt.intentId,
      solanaFixture.signature,
    );

    final recovered = store.activeReceipt!;
    expect(recovered.state, BridgeFundingState.sourcePending);
    expect(recovered.sourceTransactionHash, solanaFixture.signature);
    expect(recovered.submissionOutcomeUnknown, isFalse);
    expect(solanaRpc.broadcasts, isEmpty);
    expect(wallet.solanaSubmissions, isEmpty);
    expect(lifiStatus.requests, hasLength(1));
  });

  test('Solana bounded recovery scan attaches one exact reviewed transaction',
      () async {
    final receipt = _solanaReceipt(
      now: now,
      fixture: solanaFixture,
      state: BridgeFundingState.awaitingExternalWallet,
      submissionOutcomeUnknown: true,
    );
    await store.upsert(receipt);
    solanaRpc.histories.add(
      SolanaSignatureHistory(
        entries: <SolanaAddressSignature>[
          SolanaAddressSignature(
            signature: solanaFixture.signature,
            slot: 50,
            blockTime: now,
            failed: false,
          ),
        ],
        complete: true,
        truncated: false,
      ),
    );
    solanaRpc.transactions.add(
      SolanaFetchedTransaction(
        signature: solanaFixture.signature,
        transactionBytes: solanaFixture.signedTransaction,
        slot: 50,
        failed: false,
      ),
    );
    lifiStatus.observations.add(
      const LifiStatusObservation(
        state: BridgeFundingState.sourcePending,
        providerStatus: 'PENDING',
        providerSubstatus: 'WAIT_SOURCE_CONFIRMATIONS',
        destinationTransactionHash: null,
        actualOutputUnits: null,
        explorerLinks: <Uri>[],
      ),
    );

    final result = await controller().scanSolanaRecovery(receipt.intentId);

    expect(result, SolanaRecoveryScanResult.matched);
    expect(store.activeReceipt!.sourceTransactionHash, solanaFixture.signature);
    expect(solanaRpc.broadcasts, isEmpty);
  });

  test('Solana unknown outcome expires only with complete no-match evidence',
      () async {
    final receipt = _solanaReceipt(
      now: now,
      fixture: solanaFixture,
      state: BridgeFundingState.awaitingExternalWallet,
      submissionOutcomeUnknown: true,
    );
    await store.upsert(receipt);
    solanaRpc.histories.add(
      const SolanaSignatureHistory(
        entries: <SolanaAddressSignature>[],
        complete: true,
        truncated: false,
      ),
    );
    solanaRpc.blockhashValidity.add(false);

    final result = await controller().scanSolanaRecovery(receipt.intentId);

    expect(result, SolanaRecoveryScanResult.expired);
    final expired = store.receiptForIntent(receipt.intentId)!;
    expect(expired.state, BridgeFundingState.expired);
    expect(expired.submissionOutcomeUnknown, isFalse);
    expect(solanaRpc.blockhashRequests, <String>[solanaFixture.blockhash]);
  });

  test('Solana truncated no-match scan remains active and never checks expiry',
      () async {
    final receipt = _solanaReceipt(
      now: now,
      fixture: solanaFixture,
      state: BridgeFundingState.awaitingExternalWallet,
      submissionOutcomeUnknown: true,
    );
    await store.upsert(receipt);
    solanaRpc.histories.add(
      const SolanaSignatureHistory(
        entries: <SolanaAddressSignature>[],
        complete: false,
        truncated: true,
      ),
    );

    final result = await controller().scanSolanaRecovery(receipt.intentId);

    expect(result, SolanaRecoveryScanResult.inconclusive);
    expect(
        store.activeReceipt!.state, BridgeFundingState.awaitingExternalWallet);
    expect(store.activeReceipt!.submissionOutcomeUnknown, isTrue);
    expect(solanaRpc.blockhashRequests, isEmpty);
    expect(solanaRpc.broadcasts, isEmpty);
  });

  test('Relay instruction is persisted as awaiting deposit before reveal',
      () async {
    final request = _relayRequest();
    relay.instructions.add(_relayInstruction(now: now, request: request));
    persistence.onWrite = () {
      final current = store.receiptForIntent(
        '0123456789abcdef0123456789abcdef',
      );
      if (current?.depositAddressExposed == true) {
        expect(current!.state, BridgeFundingState.awaitingDeposit);
        expect(current.depositAddress, isNotNull);
      }
    };

    final instruction = await controller().prepareRelayDeposit(request);

    expect(instruction.depositAddress,
        '0x7777777777777777777777777777777777777777');
    final receipt = store.activeReceipt!;
    expect(receipt.state, BridgeFundingState.awaitingDeposit);
    expect(receipt.depositAddressExposed, isTrue);
    expect(receipt.provider, 'relay');
    expect(receipt.providerRequestId, instruction.requestId);
    expect(wallet.sentPayloads, isEmpty);
    expect(quotes.requests, isEmpty);
  });

  test('Relay persistence failure prevents instruction reveal', () async {
    final request = _relayRequest();
    relay.instructions.add(_relayInstruction(now: now, request: request));
    persistence.rejectExposedReceipt = true;

    await expectLater(
      controller().prepareRelayDeposit(request),
      throwsA(isA<BridgePersistenceException>()),
    );

    expect(relay.instructionsReturned, 1);
  });

  test('Relay status advances legally and persists completion before refresh',
      () async {
    final receipt = _relayReceipt(now: now);
    await store.upsert(receipt);
    relay.observations.add(
      BridgeFundingObservation(
        state: BridgeFundingState.completed,
        providerStatus: 'success',
        sourceTransactionHash: sourceHash,
        destinationTransactionHash:
            '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        actualOutputUnits: '990000',
        observedAt: now,
      ),
    );
    baseBalance.onRefresh = () {
      final completed = store.receiptForIntent(receipt.intentId)!;
      expect(completed.state, BridgeFundingState.completed);
      expect(completed.balanceRefreshPending, isTrue);
    };

    await controller().refreshStatus(receipt.intentId);

    final completed = store.receiptForIntent(receipt.intentId)!;
    expect(completed.state, BridgeFundingState.completed);
    expect(completed.sourceTransactionHash, sourceHash);
    expect(completed.actualOutputUnits, '990000');
    expect(completed.balanceRefreshPending, isFalse);
  });

  test('Relay partial fill persists before refreshing the Base balance',
      () async {
    final receipt = _relayReceipt(now: now);
    await store.upsert(receipt);
    relay.observations.add(
      BridgeFundingObservation(
        state: BridgeFundingState.partial,
        providerStatus: 'success_with_refund',
        sourceTransactionHash: sourceHash,
        destinationTransactionHash:
            '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        actualOutputUnits: '900000',
        observedAt: now,
      ),
    );
    baseBalance.onRefresh = () {
      final partial = store.receiptForIntent(receipt.intentId)!;
      expect(partial.state, BridgeFundingState.partial);
      expect(partial.balanceRefreshPending, isTrue);
    };

    await controller().refreshStatus(receipt.intentId);

    final partial = store.receiptForIntent(receipt.intentId)!;
    expect(baseBalance.refreshCalls, 1);
    expect(partial.state, BridgeFundingState.partial);
    expect(partial.actualOutputUnits, '900000');
    expect(partial.balanceRefreshPending, isFalse);
  });

  test('Relay partial Base balance reconciliation can be retried', () async {
    final receipt = _relayReceipt(now: now);
    await store.upsert(receipt);
    relay.observations.add(
      BridgeFundingObservation(
        state: BridgeFundingState.partial,
        providerStatus: 'success_with_refund',
        actualOutputUnits: '900000',
        observedAt: now,
      ),
    );
    baseBalance.succeeds = false;

    await controller().refreshStatus(receipt.intentId);
    expect(store.receiptForIntent(receipt.intentId)!.balanceRefreshPending,
        isTrue);

    baseBalance.succeeds = true;
    await controller().refreshBaseBalance(receipt.intentId);
    expect(baseBalance.refreshCalls, 2);
    expect(store.receiptForIntent(receipt.intentId)!.balanceRefreshPending,
        isFalse);
  });

  test('Relay waiting instruction expires locally only when still unsent',
      () async {
    final receipt = _relayReceipt(
      now: now.subtract(const Duration(minutes: 20)),
      expiresAt: now.subtract(const Duration(minutes: 10)),
    );
    await store.upsert(receipt);
    relay.observations.add(
      BridgeFundingObservation(
        state: BridgeFundingState.awaitingDeposit,
        providerStatus: 'waiting',
        observedAt: now,
      ),
    );

    await controller().refreshStatus(receipt.intentId);

    expect(store.receiptForIntent(receipt.intentId)!.state,
        BridgeFundingState.expired);
  });

  test('hiding Relay instructions archives without cancelling provider state',
      () async {
    final receipt = _relayReceipt(now: now);
    await store.upsert(receipt);

    await controller().archiveRelayInstructions(receipt.intentId);

    final archived = store.receiptForIntent(receipt.intentId)!;
    expect(archived.state, BridgeFundingState.awaitingDeposit);
    expect(archived.providerStatus, 'waiting');
    expect(archived.archivedAt, now);
    expect(archived.depositAddressExposed, isTrue);
  });

  test('replacement Relay instruction requires old-address acknowledgement',
      () async {
    final oldReceipt = _relayReceipt(now: now);
    await store.upsert(oldReceipt);
    await controller().archiveRelayInstructions(oldReceipt.intentId);
    final request = _relayRequest();
    relay.instructions.add(_relayInstruction(now: now, request: request));

    await expectLater(
      controller().prepareRelayDeposit(request),
      throwsA(_bridgeCode('old_relay_address_warning_required')),
    );
    expect(relay.instructionsReturned, 0);

    await controller().prepareRelayDeposit(
      request,
      oldAddressWarningAcknowledged: true,
    );
    expect(relay.instructionsReturned, 1);
  });

  test('locally expired Relay instruction still tracks a late deposit',
      () async {
    final receipt = _relayReceipt(
      now: now.subtract(const Duration(minutes: 20)),
      expiresAt: now.subtract(const Duration(minutes: 10)),
    );
    await store.upsert(receipt);
    relay.observations.add(
      BridgeFundingObservation(
        state: BridgeFundingState.awaitingDeposit,
        providerStatus: 'waiting',
        observedAt: now,
      ),
    );
    await controller().refreshStatus(receipt.intentId);
    expect(store.receiptForIntent(receipt.intentId)!.state,
        BridgeFundingState.expired);

    final replacementRequest = _relayRequest();
    relay.instructions.add(
      _relayInstruction(now: now, request: replacementRequest),
    );
    await controller().prepareRelayDeposit(
      replacementRequest,
      oldAddressWarningAcknowledged: true,
    );
    expect(store.receiptForIntent(receipt.intentId)!.archivedAt, isNotNull);

    relay.observations.add(
      BridgeFundingObservation(
        state: BridgeFundingState.depositDetected,
        providerStatus: 'depositing',
        sourceTransactionHash: sourceHash,
        observedAt: now.add(const Duration(seconds: 30)),
      ),
    );
    await controller().refreshStatus(receipt.intentId);

    expect(store.receiptForIntent(receipt.intentId)!.state,
        BridgeFundingState.depositDetected);
    expect(store.activeReceipt!.state, BridgeFundingState.awaitingDeposit);

    relay.observations.add(
      BridgeFundingObservation(
        state: BridgeFundingState.completed,
        providerStatus: 'success',
        sourceTransactionHash: sourceHash,
        destinationTransactionHash:
            '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        actualOutputUnits: '990000',
        observedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    await controller().refreshStatus(receipt.intentId);

    expect(store.receiptForIntent(receipt.intentId)!.state,
        BridgeFundingState.completed);
    expect(store.activeReceipt!.state, BridgeFundingState.awaitingDeposit);
    expect(baseBalance.refreshCalls, 1);
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

const _solanaChain = BridgeChain(
  id: BridgeConstants.solanaChainId,
  key: 'sol',
  name: 'Solana',
  type: BridgeChainType.svm,
  nativeTokenSymbol: 'SOL',
);

const _solanaToken = BridgeToken(
  chainId: BridgeConstants.solanaChainId,
  address: 'So11111111111111111111111111111111111111112',
  symbol: 'SOL',
  decimals: 9,
  solverDepositable: false,
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

BridgeFundingRequest _solanaRequest(SolanaTransactionFixture fixture) =>
    BridgeFundingRequest(
      method: BridgeFundingMethod.connectedWallet,
      sourceChain: _solanaChain,
      sourceToken: _solanaToken,
      amount: '0.01',
      amountUnits: '10000000',
      baseDestinationAddress: '0x3333333333333333333333333333333333333333',
      sourceAddress: fixture.signer,
      selfCustodyConfirmed: true,
    );

BridgeExecutableQuote _solanaQuote({
  required DateTime now,
  required SolanaTransactionFixture fixture,
}) {
  final request = _solanaRequest(fixture);
  final payload = SolanaBridgeExecutionPayload(
    from: fixture.signer,
    base64Transaction: fixture.unsignedBase64,
  );
  return BridgeExecutableQuote(
    estimate: BridgeEstimate(
      provider: 'lifi',
      quoteId: 'solana-quote-1',
      request: request,
      minimumOutputUnits: '990000',
      minimumOutputDisplay: '0.99',
      routeTool: 'mayan',
      quotedAt: now,
      expiresAt: now.add(const Duration(minutes: 1)),
    ),
    connectedSourceAddress: fixture.signer,
    destinationChainId: BridgeConstants.baseChainId,
    destinationToken: const BridgeToken(
      chainId: BridgeConstants.baseChainId,
      address: BridgeConstants.baseUsdc,
      symbol: 'USDC',
      decimals: 6,
      solverDepositable: false,
    ),
    payload: payload,
    fingerprint: sha256.convert(fixture.unsignedTransaction).toString(),
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

ExternalWalletIdentity _solanaIdentity({
  required String address,
  required Set<String> methods,
  ExternalWalletTransport transport = ExternalWalletTransport.solanaMwa,
}) =>
    ExternalWalletIdentity(
      transport: transport,
      walletLabel: 'Test Solana Wallet',
      publicAddress: address,
      chainId: BridgeConstants.solanaChainId,
      chainType: BridgeChainType.svm,
      approvedMethods: methods,
      approvedFeatures: const <String>{},
    );

BridgeFundingReceipt _receipt({
  required DateTime now,
  required BridgeFundingState state,
  required String reviewedPayloadHash,
  bool submissionOutcomeUnknown = false,
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
      submissionOutcomeUnknown: submissionOutcomeUnknown,
      createdAt: now,
      updatedAt: now,
    );

BridgeFundingReceipt _solanaReceipt({
  required DateTime now,
  required SolanaTransactionFixture fixture,
  required BridgeFundingState state,
  String? sourceTransactionHash,
  bool submissionOutcomeUnknown = false,
}) =>
    BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: 'solana-resume-intent',
      method: BridgeFundingMethod.connectedWallet,
      provider: 'lifi',
      state: state,
      sourceChainId: BridgeConstants.solanaChainId,
      sourceTokenAddress: _solanaToken.address,
      sourceTokenSymbol: _solanaToken.symbol,
      sourceAmountUnits: '10000000',
      baseDestinationAddress: '0x3333333333333333333333333333333333333333',
      sourceAddress: fixture.signer,
      providerQuoteId: 'solana-quote-1',
      routeTool: 'mayan',
      minimumOutputUnits: '990000',
      walletTransport: ExternalWalletTransport.solanaMwa,
      reviewedPayloadHash: sha256.convert(fixture.message).toString(),
      sourceBlockhash: fixture.blockhash,
      sourceTransactionHash: sourceTransactionHash ??
          (state == BridgeFundingState.awaitingExternalWallet
              ? null
              : fixture.signature),
      providerStatus: 'submitted',
      submissionOutcomeUnknown: submissionOutcomeUnknown,
      createdAt: now,
      updatedAt: now,
    );

BridgeFundingReceipt _trackingReceipt({required DateTime now}) =>
    BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: 'lifi-tracking-intent',
      method: BridgeFundingMethod.connectedWallet,
      provider: 'lifi',
      state: BridgeFundingState.sourcePending,
      sourceChainId: BridgeConstants.ethereumChainId,
      sourceTokenAddress: '0x4444444444444444444444444444444444444444',
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1000000',
      baseDestinationAddress: '0x3333333333333333333333333333333333333333',
      sourceAddress: '0x2222222222222222222222222222222222222222',
      providerQuoteId: 'quote-1',
      routeTool: 'across',
      minimumOutputUnits: '990000',
      sourceTransactionHash:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      providerStatus: 'PENDING',
      providerSubstatus: 'WAIT_SOURCE_CONFIRMATIONS',
      walletTransport: ExternalWalletTransport.reownEvm,
      reviewedPayloadHash:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      createdAt: now,
      updatedAt: now,
    );

BridgeFundingRequest _relayRequest() => BridgeFundingRequest(
      method: BridgeFundingMethod.relayDeposit,
      sourceChain: _ethereumChain,
      sourceToken: const BridgeToken(
        chainId: BridgeConstants.ethereumChainId,
        address: '0x4444444444444444444444444444444444444444',
        symbol: 'USDC',
        decimals: 6,
        solverDepositable: true,
      ),
      amount: '1',
      amountUnits: '1000000',
      baseDestinationAddress: '0x3333333333333333333333333333333333333333',
      refundAddress: '0x6666666666666666666666666666666666666666',
      selfCustodyConfirmed: true,
    );

RelayDepositInstruction _relayInstruction({
  required DateTime now,
  required BridgeFundingRequest request,
}) =>
    RelayDepositInstruction(
      requestId:
          '0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      depositAddress: '0x7777777777777777777777777777777777777777',
      request: request,
      minimumOutputUnits: '990000',
      minimumOutputDisplay: '0.99',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
    );

BridgeFundingReceipt _relayReceipt({
  required DateTime now,
  DateTime? expiresAt,
}) =>
    BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: 'relay-tracking-intent',
      method: BridgeFundingMethod.relayDeposit,
      provider: 'relay',
      state: BridgeFundingState.awaitingDeposit,
      sourceChainId: BridgeConstants.ethereumChainId,
      sourceTokenAddress: '0x4444444444444444444444444444444444444444',
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1000000',
      baseDestinationAddress: '0x3333333333333333333333333333333333333333',
      refundAddress: '0x6666666666666666666666666666666666666666',
      depositAddress: '0x7777777777777777777777777777777777777777',
      providerRequestId:
          '0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      minimumOutputUnits: '990000',
      providerStatus: 'waiting',
      createdAt: now,
      updatedAt: now,
      expiresAt: expiresAt ?? now.add(const Duration(minutes: 10)),
      depositAddressExposed: true,
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
  ExternalWalletIdentity? connectIdentity;
  int disconnectCalls = 0;
  final List<ExternalWalletTransport?> connectTransports =
      <ExternalWalletTransport?>[];
  final List<EvmBridgeExecutionPayload> sentPayloads =
      <EvmBridgeExecutionPayload>[];
  ExternalWalletException? sendError;
  void Function(EvmBridgeExecutionPayload payload)? onSend;
  final List<SolanaBridgeExecutionPayload> solanaSubmissions =
      <SolanaBridgeExecutionPayload>[];
  SolanaWalletSubmissionResult? solanaResult;
  Completer<SolanaWalletSubmissionResult>? solanaCompleter;
  ExternalWalletException? solanaError;
  void Function(SolanaBridgeExecutionPayload payload)? onSolanaSubmit;

  @override
  Future<ExternalWalletIdentity> connect(
    BridgeChain chain, {
    ExternalWalletTransport? transport,
  }) async {
    connectTransports.add(transport);
    identity = connectIdentity ?? identity;
    return identity!;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    identity = null;
  }

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
  ) async {
    solanaSubmissions.add(payload);
    onSolanaSubmit?.call(payload);
    final error = solanaError;
    if (error != null) throw error;
    final completer = solanaCompleter;
    if (completer != null) return completer.future;
    return solanaResult ??
        (throw StateError('No fake Solana wallet result was configured.'));
  }
}

final class _FakeRpc implements EvmBridgeRpc {
  final EvmBridgeRpcService _encoder = EvmBridgeRpcService(
    transport: _UnusedTransport(),
  );
  final List<BigInt> allowances = <BigInt>[];
  final List<Map<String, Object?>> allowanceRequests = <Map<String, Object?>>[];
  final List<EvmReceiptObservation> receipts = <EvmReceiptObservation>[];
  final List<String> receiptRequests = <String>[];
  final List<EvmTransactionObservation?> transactions =
      <EvmTransactionObservation?>[];
  final List<String> transactionRequests = <String>[];
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

  @override
  Future<EvmTransactionObservation?> transactionByHash({
    required int chainId,
    required String transactionHash,
  }) async {
    transactionRequests.add(transactionHash);
    return transactions.removeAt(0);
  }
}

final class _FakeBaseBalance implements BaseBalanceRefreshService {
  int refreshCalls = 0;
  bool succeeds = true;
  void Function()? onRefresh;

  @override
  Future<bool> refresh() async {
    refreshCalls += 1;
    onRefresh?.call();
    return succeeds;
  }
}

final class _FakeLifiStatus implements LifiSettlementStatusProvider {
  final List<LifiStatusObservation> observations = <LifiStatusObservation>[];
  final List<LifiStatusException> errors = <LifiStatusException>[];
  final List<Map<String, Object?>> requests = <Map<String, Object?>>[];

  @override
  Future<LifiStatusObservation> status({
    required String sourceTransactionHash,
    required int sourceChainId,
    required String routeTool,
  }) async {
    requests.add(<String, Object?>{
      'sourceTransactionHash': sourceTransactionHash,
      'sourceChainId': sourceChainId,
      'routeTool': routeTool,
    });
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return observations.removeAt(0);
  }
}

final class _FakeRelayDeposit implements RelayDepositProvider {
  final List<RelayDepositInstruction> instructions =
      <RelayDepositInstruction>[];
  final List<BridgeFundingObservation> observations =
      <BridgeFundingObservation>[];
  final List<BridgeFundingRequest> requests = <BridgeFundingRequest>[];
  int instructionsReturned = 0;

  @override
  Future<RelayDepositInstruction> createInstruction(
    BridgeFundingRequest request,
  ) async {
    requests.add(request);
    instructionsReturned += 1;
    return instructions.removeAt(0);
  }

  @override
  Future<BridgeFundingObservation> status(
    BridgeFundingReceipt receipt,
  ) async =>
      observations.removeAt(0);
}

final class _FakeSolanaRpc implements SolanaRpcBroadcaster {
  final List<Uint8List> broadcasts = <Uint8List>[];
  final List<String> statusRequests = <String>[];
  final List<SolanaSignatureObservation> observations =
      <SolanaSignatureObservation>[];
  String? broadcastResult;
  SolanaRpcException? broadcastError;
  SolanaRpcException? statusError;
  void Function(Uint8List transaction)? onBroadcast;
  void Function(String signature)? onStatus;
  final List<SolanaSignatureHistory> histories = <SolanaSignatureHistory>[];
  final List<SolanaFetchedTransaction?> transactions =
      <SolanaFetchedTransaction?>[];
  final List<String> transactionRequests = <String>[];
  final List<bool> blockhashValidity = <bool>[];
  final List<String> blockhashRequests = <String>[];

  @override
  Future<String> sendTransaction(Uint8List signedTransaction) async {
    broadcasts.add(Uint8List.fromList(signedTransaction));
    onBroadcast?.call(signedTransaction);
    final failure = broadcastError;
    if (failure != null) throw failure;
    return broadcastResult ??
        (throw StateError('No fake Solana broadcast result was configured.'));
  }

  @override
  Future<SolanaSignatureObservation> signatureStatus(String signature) async {
    statusRequests.add(signature);
    onStatus?.call(signature);
    final failure = statusError;
    if (failure != null) throw failure;
    return observations.removeAt(0);
  }

  @override
  Future<SolanaSignatureHistory> signaturesForAddress(
    String address, {
    required DateTime since,
    int limit = 200,
  }) async =>
      histories.removeAt(0);

  @override
  Future<SolanaFetchedTransaction?> transaction(String signature) async {
    transactionRequests.add(signature);
    return transactions.removeAt(0);
  }

  @override
  Future<bool> isBlockhashValid(String blockhash) async {
    blockhashRequests.add(blockhash);
    return blockhashValidity.removeAt(0);
  }
}

final class _MemoryReceiptPersistence implements BridgeReceiptPersistence {
  @override
  String? activeBridgeReceiptJson;

  @override
  List<String> bridgeReceipts = <String>[];
  bool rejectExposedReceipt = false;
  void Function()? onWrite;

  @override
  Future<bool> setActiveBridgeReceiptJson(String? value) async {
    if (rejectExposedReceipt &&
        value?.contains('"depositAddressExposed":true') == true) {
      return false;
    }
    activeBridgeReceiptJson = value;
    onWrite?.call();
    return true;
  }

  @override
  Future<bool> setBridgeReceipts(List<String> value) async {
    if (rejectExposedReceipt &&
        value.any((item) => item.contains('"depositAddressExposed":true'))) {
      return false;
    }
    bridgeReceipts = List<String>.from(value);
    onWrite?.call();
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
