import 'dart:async';

import 'package:clawa/services/bridge/bridge_capability_service.dart';
import 'package:clawa/services/bridge/bridge_funding_controller.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/external_jumper_fallback.dart';
import 'package:clawa/services/bridge/external_wallet_session_service.dart';
import 'package:clawa/widgets/bridge_funding_panel.dart';
import 'package:clawa/widgets/relay_deposit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Jumper fallback preserves only honest prefill fields', () {
    final uri = const ExternalJumperFallback().build(_request());

    expect(uri.scheme, 'https');
    expect(uri.host, 'jumper.exchange');
    expect(uri.path, '/');
    expect(uri.queryParameters, <String, String>{
      'fromAmount': '1.25',
      'fromChain': '1',
      'fromToken': _ethUsdc.address,
      'toChain': '8453',
      'toToken': BridgeConstants.baseUsdc,
      'toAddress': _baseAddress,
    });
  });

  testWidgets(
      'blocks absent wallet and non-Base network before capability calls',
      (tester) async {
    final capabilities = _FakeCapabilities(_snapshot());

    await _pumpPanel(
      tester,
      controller: _FakeController(),
      capabilities: capabilities,
      baseAddress: null,
      baseWalletAvailable: false,
    );
    expect(find.text('Create or restore the internal Base wallet first.'),
        findsOneWidget);
    expect(capabilities.refreshCalls, 0);

    await _pumpPanel(
      tester,
      controller: _FakeController(),
      capabilities: capabilities,
      baseMainnetSelected: false,
    );
    expect(find.text('Switch to Base Mainnet to use external funding.'),
        findsOneWidget);
    expect(capabilities.refreshCalls, 0);
  });

  testWidgets('shows loading then uses a fresh capability snapshot',
      (tester) async {
    final completer = Completer<BridgeCapabilitySnapshot>();
    final capabilities = _FakeCapabilities.future(completer.future);

    await _pumpPanel(
      tester,
      controller: _FakeController(),
      capabilities: capabilities,
      settle: false,
    );
    expect(find.text('Checking funding routes…'), findsOneWidget);

    completer.complete(_snapshot());
    await tester.pumpAndSettle();
    expect(find.text('Connect wallet'), findsOneWidget);
    expect(find.text('One-time address'), findsOneWidget);
    expect(find.text('Ethereum'), findsOneWidget);
  });

  testWidgets('prefers live Robinhood USDG without hiding ETH', (tester) async {
    await _pumpPanel(
      tester,
      controller: _FakeController(),
      capabilities: _FakeCapabilities(_robinhoodSnapshot()),
      initialSourceChainId: BridgeConstants.robinhoodChainId,
      initialSourceTokenSymbol: 'USDG',
    );

    final chain = tester.widget<DropdownButtonFormField<BridgeChain>>(
      find.byKey(const Key('bridge-source-chain')),
    );
    final token = tester.widget<DropdownButtonFormField<BridgeToken>>(
      find.byKey(
        const ValueKey<String>('bridge-source-token-4663'),
      ),
    );
    expect(chain.initialValue?.id, BridgeConstants.robinhoodChainId);
    expect(token.initialValue?.symbol, 'USDG');
    expect(find.textContaining('Keep some ETH'), findsOneWidget);

    await tester.tap(find.byKey(
      const ValueKey<String>('bridge-source-token-4663'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('ETH ·'), findsWidgets);
    expect(find.textContaining('USDG ·'), findsWidgets);
  });

  testWidgets('uses cached routes read-only when live refresh fails',
      (tester) async {
    final capabilities = _FakeCapabilities.error(
      StateError('offline'),
      cachedSnapshot: _snapshot(),
    );

    await _pumpPanel(
      tester,
      controller: _FakeController(),
      capabilities: capabilities,
    );

    expect(
      find.text(
        'Using recently cached routes. A live refresh is required before transfer.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bridge-primary-action')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('bridge-primary-action')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('connected flow derives transport and opens exact review',
      (tester) async {
    final controller = _FakeController()
      ..walletOptions = const <ExternalWalletOption>[
        ExternalWalletOption(
          transport: ExternalWalletTransport.reownEvm,
          label: 'Search compatible EVM wallets',
          available: true,
        ),
        ExternalWalletOption(
          transport: ExternalWalletTransport.baseAccountMwp,
          label: 'Base Account',
          available: false,
          reason: 'Base Account support is not enabled in this release.',
        ),
      ];
    await _pumpPanel(
      tester,
      controller: controller,
      capabilities: _FakeCapabilities(_snapshot()),
    );
    expect(find.text('Base Account support is not enabled in this release.'),
        findsOneWidget);

    await tester.enterText(find.byKey(const Key('bridge-amount')), '1.25');
    await tester.ensureVisible(find.byKey(const Key('bridge-primary-action')));
    await tester.tap(find.byKey(const Key('bridge-primary-action')));
    await tester.pumpAndSettle();

    expect(controller.connectedRequests, hasLength(1));
    expect(controller.selectedTransport, ExternalWalletTransport.reownEvm);
    expect(controller.connectedRequests.single.sourceAddress, isNull);
    expect(find.text('Review Base funding'), findsOneWidget);
    expect(find.textContaining('at least 1.2 USDC'), findsOneWidget);
    expect(find.text('Approve in wallet'), findsOneWidget);
  });

  testWidgets('completion callback fires once for this session intent only',
      (tester) async {
    final completions = <BridgeFundingReceipt>[];
    final controller = _FakeController()
      ..completeOnConfirm = true
      ..walletOptions = const <ExternalWalletOption>[
        ExternalWalletOption(
          transport: ExternalWalletTransport.reownEvm,
          label: 'Compatible EVM wallet',
          available: true,
        ),
      ];
    await _pumpPanel(
      tester,
      controller: controller,
      capabilities: _FakeCapabilities(_snapshot()),
      onFundingCompleted: completions.add,
    );

    await tester.enterText(find.byKey(const Key('bridge-amount')), '1.25');
    await tester.ensureVisible(find.byKey(const Key('bridge-primary-action')));
    await tester.tap(find.byKey(const Key('bridge-primary-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve in wallet'));
    await tester.pumpAndSettle();

    expect(completions, hasLength(1));
    expect(completions.single.state, BridgeFundingState.completed);
    expect(completions.single.intentId, controller.currentReceipt?.intentId);
  });

  testWidgets('execution stops when mandatory capability refresh fails',
      (tester) async {
    final controller = _FakeController()
      ..walletOptions = const <ExternalWalletOption>[
        ExternalWalletOption(
          transport: ExternalWalletTransport.reownEvm,
          label: 'Compatible EVM wallet',
          available: true,
        ),
      ];
    final capabilities = _SequencedCapabilities(<Object>[
      _snapshot(),
      StateError('offline'),
    ]);
    await _pumpPanel(
      tester,
      controller: controller,
      capabilities: capabilities,
    );

    await tester.enterText(find.byKey(const Key('bridge-amount')), '1.25');
    await tester.ensureVisible(find.byKey(const Key('bridge-primary-action')));
    await tester.tap(find.byKey(const Key('bridge-primary-action')));
    await tester.pumpAndSettle();

    expect(capabilities.refreshCalls, 2);
    expect(controller.connectedRequests, isEmpty);
    expect(find.textContaining('live funding routes'), findsOneWidget);
  });

  testWidgets('display-only capability fallback cannot authorize execution',
      (tester) async {
    final controller = _FakeController()
      ..walletOptions = const <ExternalWalletOption>[
        ExternalWalletOption(
          transport: ExternalWalletTransport.reownEvm,
          label: 'Compatible EVM wallet',
          available: true,
        ),
      ];
    final capabilities = _SequencedCapabilities(<Object>[
      _snapshot(),
      _snapshot(displayOnly: true),
    ]);
    await _pumpPanel(
      tester,
      controller: controller,
      capabilities: capabilities,
    );

    await tester.enterText(find.byKey(const Key('bridge-amount')), '1.25');
    await tester.ensureVisible(find.byKey(const Key('bridge-primary-action')));
    await tester.tap(find.byKey(const Key('bridge-primary-action')));
    await tester.pumpAndSettle();

    expect(capabilities.refreshCalls, 2);
    expect(controller.connectedRequests, isEmpty);
    expect(find.textContaining('live funding routes'), findsOneWidget);
  });

  testWidgets('Relay reveals only persisted exact self-custody instructions',
      (tester) async {
    final controller = _FakeController();
    await _pumpPanel(
      tester,
      controller: controller,
      capabilities: _FakeCapabilities(_snapshot()),
    );

    await tester.tap(find.text('One-time address'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Exchange / CEX withdrawals are not supported'),
        findsOneWidget);
    await tester.enterText(find.byKey(const Key('bridge-amount')), '1.25');
    await tester.enterText(
      find.byKey(const Key('bridge-refund-address')),
      _refundAddress,
    );
    await tester.ensureVisible(find.byKey(const Key('bridge-self-custody')));
    await tester.tap(find.byKey(const Key('bridge-self-custody')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('bridge-primary-action')));
    await tester.tap(find.byKey(const Key('bridge-primary-action')));
    await tester.pumpAndSettle();

    expect(controller.relayPersistedBeforeReturn, isTrue);
    expect(find.text('Send exact amount'), findsOneWidget);
    expect(find.text('1.25 USDC on Ethereum'), findsOneWidget);
    expect(find.text(_depositAddress), findsOneWidget);
    expect(
        find.textContaining('Address only — send the exact token and amount'),
        findsOneWidget);
    expect(find.textContaining('I sent'), findsNothing);
  });

  testWidgets('outcome-unknown receipt exposes reconciliation, never resend',
      (tester) async {
    final controller = _FakeController()..currentReceipt = _unknownReceipt();
    await _pumpPanel(
      tester,
      controller: controller,
      capabilities: _FakeCapabilities(_snapshot()),
    );

    expect(find.text('Wallet result needs verification'), findsOneWidget);
    expect(find.byKey(const Key('bridge-recovery-id')), findsOneWidget);
    expect(find.text('Verify transaction hash'), findsOneWidget);
    expect(find.textContaining('Submit again'), findsNothing);
    expect(find.text('Cancel transfer'), findsNothing);
    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('resumes pending receipt with read-only polling once',
      (tester) async {
    final controller = _FakeController()..currentReceipt = _pendingReceipt();
    await _pumpPanel(
      tester,
      controller: controller,
      capabilities: _FakeCapabilities(_snapshot()),
    );

    expect(controller.pollCalls, 1);
    expect(find.text('Base delivery pending'), findsOneWidget);
  });

  testWidgets('hidden Relay instruction remains visible to status tracking',
      (tester) async {
    final controller = _FakeController()
      ..currentReceipt = _archivedRelayReceipt();
    await _pumpPanel(
      tester,
      controller: controller,
      capabilities: _FakeCapabilities(_snapshot()),
    );

    expect(controller.pollCalls, 1);
    await tester.ensureVisible(find.text('Latest funding receipt'));
    await tester.tap(find.text('Latest funding receipt'));
    await tester.pumpAndSettle();
    expect(find.text('Refresh status'), findsOneWidget);
    expect(find.text('View deposit instructions'), findsOneWidget);
  });

  testWidgets('expired Relay address cannot be copied or scanned',
      (tester) async {
    final instruction = RelayDepositInstruction(
      requestId:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      depositAddress: _depositAddress,
      request: _request(
        method: BridgeFundingMethod.relayDeposit,
        selfCustody: true,
        refundAddress: _refundAddress,
      ),
      minimumOutputUnits: '1200000',
      minimumOutputDisplay: '1.2',
      createdAt: DateTime.utc(2026, 8, 7, 10),
      expiresAt: DateTime.utc(2026, 8, 7, 10, 10),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: RelayDepositSheet(
            instruction: instruction,
            onCopy: (_) async {},
            clock: () => DateTime.utc(2026, 8, 7, 11),
          ),
        ),
      ),
    );

    expect(find.text('Deposit instruction expired'), findsOneWidget);
    expect(find.text(_depositAddress), findsNothing);
    expect(find.text('Copy address'), findsNothing);
    expect(find.textContaining('address hidden'), findsOneWidget);
  });

  testWidgets('layout survives 320px width and 200 percent text scaling',
      (tester) async {
    await _pumpPanel(
      tester,
      controller: _FakeController(),
      capabilities: _FakeCapabilities(_snapshot(longNames: true)),
      size: const Size(320, 900),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Extremely Long Ethereum'), findsOneWidget);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required BridgeFundingUiController controller,
  required BridgeCapabilitySource capabilities,
  String? baseAddress = _baseAddress,
  bool baseWalletAvailable = true,
  bool baseMainnetSelected = true,
  int? initialSourceChainId,
  String? initialSourceTokenSymbol,
  ValueChanged<BridgeFundingReceipt>? onFundingCompleted,
  bool settle = true,
  Size size = const Size(430, 900),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: textScaler),
        child: Scaffold(
          body: SingleChildScrollView(
            child: BridgeFundingPanel(
              controller: controller,
              capabilities: capabilities,
              baseDestinationAddress: baseAddress,
              baseWalletAvailable: baseWalletAvailable,
              baseMainnetSelected: baseMainnetSelected,
              initialSourceChainId: initialSourceChainId,
              initialSourceTokenSymbol: initialSourceTokenSymbol,
              onFundingCompleted: onFundingCompleted,
              launchExternal: (_) async => true,
              copyText: (_) async {},
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

final class _FakeCapabilities implements BridgeCapabilitySource {
  _FakeCapabilities(BridgeCapabilitySnapshot snapshot)
      : _future = Future<BridgeCapabilitySnapshot>.value(snapshot),
        _error = null,
        cachedSnapshot = null;

  _FakeCapabilities.future(this._future)
      : _error = null,
        cachedSnapshot = null;

  _FakeCapabilities.error(Object error, {this.cachedSnapshot})
      : _future = null,
        _error = error;

  final Future<BridgeCapabilitySnapshot>? _future;
  final Object? _error;
  int refreshCalls = 0;

  @override
  final BridgeCapabilitySnapshot? cachedSnapshot;

  @override
  Future<BridgeCapabilitySnapshot> refresh({
    required bool internalBaseWalletAvailable,
  }) {
    refreshCalls += 1;
    final error = _error;
    if (error != null) return Future<BridgeCapabilitySnapshot>.error(error);
    return _future!;
  }
}

final class _SequencedCapabilities implements BridgeCapabilitySource {
  _SequencedCapabilities(this.outcomes);

  final List<Object> outcomes;
  int refreshCalls = 0;

  @override
  BridgeCapabilitySnapshot? get cachedSnapshot => null;

  @override
  Future<BridgeCapabilitySnapshot> refresh({
    required bool internalBaseWalletAvailable,
  }) async {
    final outcome = outcomes[refreshCalls++];
    if (outcome is BridgeCapabilitySnapshot) return outcome;
    throw outcome;
  }
}

final class _FakeController implements BridgeFundingUiController {
  BridgeFundingReceipt? currentReceipt;
  List<ExternalWalletOption> walletOptions = const <ExternalWalletOption>[];
  final List<BridgeFundingRequest> connectedRequests = <BridgeFundingRequest>[];
  ExternalWalletTransport? selectedTransport;
  bool relayPersistedBeforeReturn = false;
  bool completeOnConfirm = false;
  int pollCalls = 0;

  @override
  BridgeFundingReceipt? get activeReceipt {
    final receipt = currentReceipt;
    if (receipt == null || receipt.archivedAt != null) return null;
    if (<BridgeFundingState>{
      BridgeFundingState.completed,
      BridgeFundingState.failed,
      BridgeFundingState.refunded,
      BridgeFundingState.partial,
      BridgeFundingState.expired,
      BridgeFundingState.cancelled,
    }.contains(receipt.state)) {
      return null;
    }
    return receipt;
  }

  @override
  List<BridgeFundingReceipt> get receipts => currentReceipt == null
      ? const <BridgeFundingReceipt>[]
      : <BridgeFundingReceipt>[currentReceipt!];

  @override
  BridgeReviewKind? pendingReviewKind(String intentId) =>
      currentReceipt?.state == BridgeFundingState.awaitingPlawieReview
          ? BridgeReviewKind.bridge
          : null;

  @override
  Future<List<ExternalWalletOption>> discoverWallets(BridgeChain chain) async =>
      walletOptions;

  @override
  Future<void> prepareConnected(
    BridgeFundingRequest request, {
    ExternalWalletTransport? transport,
  }) async {
    connectedRequests.add(request);
    selectedTransport = transport;
    currentReceipt = _reviewReceipt(request);
  }

  @override
  Future<RelayDepositInstruction> prepareRelayDeposit(
    BridgeFundingRequest request, {
    bool oldAddressWarningAcknowledged = false,
  }) async {
    currentReceipt = _relayReceipt(request);
    relayPersistedBeforeReturn = currentReceipt?.depositAddressExposed == true;
    return RelayDepositInstruction(
      requestId:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      depositAddress: _depositAddress,
      request: request,
      minimumOutputUnits: '1200000',
      minimumOutputDisplay: '1.20',
      createdAt: DateTime.utc(2026, 8, 7, 12),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<void> archiveRelayInstructions(String intentId) async {}

  @override
  Future<void> cancelBeforeSubmission(String intentId) async {}

  @override
  Future<void> confirmConnectedBridge(String intentId) async {
    if (!completeOnConfirm || currentReceipt?.intentId != intentId) return;
    currentReceipt = _completedReceipt(currentReceipt!);
  }

  @override
  Future<void> confirmEvmAllowance(String intentId) async {}

  @override
  Future<void> pollSettlement(String intentId,
      {int maxObservations = 7}) async {
    pollCalls += 1;
  }

  @override
  Future<void> recoverEvmTransactionHash(
      String intentId, String transactionHash) async {}

  @override
  Future<void> recoverSolanaSignature(
      String intentId, String signature) async {}

  @override
  Future<void> refreshBaseBalance(String intentId) async {}

  @override
  Future<void> refreshStatus(String intentId) async {}

  @override
  Future<SolanaRecoveryScanResult> scanSolanaRecovery(String intentId) async =>
      SolanaRecoveryScanResult.inconclusive;
}

BridgeCapabilitySnapshot _snapshot({
  bool longNames = false,
  bool displayOnly = false,
}) {
  final ethereum = BridgeChain(
    id: 1,
    key: 'eth',
    name: longNames
        ? 'Extremely Long Ethereum Compatible Source Network Name'
        : 'Ethereum',
    type: BridgeChainType.evm,
    nativeTokenSymbol: 'ETH',
  );
  return BridgeCapabilitySnapshot(
    schemaVersion: 1,
    refreshedAt: DateTime.now().toUtc(),
    connectedChains: <BridgeChain>[ethereum],
    relayChains: <BridgeChain>[ethereum],
    connectedTokensByChain: <int, List<BridgeToken>>{
      ethereum.id: <BridgeToken>[_ethUsdc],
    },
    relayTokensByChain: <int, List<BridgeToken>>{
      ethereum.id: <BridgeToken>[_ethUsdc],
    },
    availabilityReasons: <String, String>{
      'base_account': 'Base Account support is not enabled in this release.',
      'robinhood': 'Robinhood Chain has no verified route right now.',
      if (displayOnly)
        'execution':
            'Cached capabilities are display-only; a live quote is required before execution.',
    },
  );
}

BridgeCapabilitySnapshot _robinhoodSnapshot() {
  const robinhood = BridgeChain(
    id: BridgeConstants.robinhoodChainId,
    key: 'rhc',
    name: 'Robinhood Chain',
    type: BridgeChainType.evm,
    nativeTokenSymbol: 'ETH',
  );
  return BridgeCapabilitySnapshot(
    schemaVersion: 1,
    refreshedAt: DateTime.now().toUtc(),
    connectedChains: const <BridgeChain>[robinhood],
    relayChains: const <BridgeChain>[],
    connectedTokensByChain: const <int, List<BridgeToken>>{
      BridgeConstants.robinhoodChainId: <BridgeToken>[
        _robinhoodEth,
        _robinhoodUsdg,
      ],
    },
    relayTokensByChain: const <int, List<BridgeToken>>{},
    availabilityReasons: const <String, String>{},
  );
}

BridgeFundingRequest _request({
  BridgeFundingMethod method = BridgeFundingMethod.externalJumper,
  bool selfCustody = false,
  String? refundAddress,
}) =>
    BridgeFundingRequest(
      method: method,
      sourceChain: _ethereum,
      sourceToken: _ethUsdc,
      amount: '1.25',
      amountUnits: '1250000',
      baseDestinationAddress: _baseAddress,
      refundAddress: refundAddress,
      selfCustodyConfirmed: selfCustody,
    );

BridgeFundingReceipt _reviewReceipt(BridgeFundingRequest request) =>
    BridgeFundingReceipt(
      schemaVersion: 1,
      intentId: '11111111111111111111111111111111',
      method: BridgeFundingMethod.connectedWallet,
      provider: 'lifi',
      state: BridgeFundingState.awaitingPlawieReview,
      sourceChainId: request.sourceChain.id,
      sourceTokenAddress: request.sourceToken.address,
      sourceTokenSymbol: request.sourceToken.symbol,
      sourceAmountUnits: request.amountUnits,
      baseDestinationAddress: request.baseDestinationAddress,
      sourceAddress: _sourceAddress,
      providerQuoteId: 'quote-1',
      routeTool: 'across',
      minimumOutputUnits: '1200000',
      reviewedPayloadHash:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      createdAt: DateTime.utc(2026, 8, 7, 12),
      updatedAt: DateTime.utc(2026, 8, 7, 12),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );

BridgeFundingReceipt _completedReceipt(BridgeFundingReceipt receipt) =>
    BridgeFundingReceipt(
      schemaVersion: receipt.schemaVersion,
      intentId: receipt.intentId,
      method: receipt.method,
      provider: receipt.provider,
      state: BridgeFundingState.completed,
      sourceChainId: receipt.sourceChainId,
      sourceTokenAddress: receipt.sourceTokenAddress,
      sourceTokenSymbol: receipt.sourceTokenSymbol,
      sourceAmountUnits: receipt.sourceAmountUnits,
      baseDestinationAddress: receipt.baseDestinationAddress,
      sourceAddress: receipt.sourceAddress,
      providerQuoteId: receipt.providerQuoteId,
      routeTool: receipt.routeTool,
      minimumOutputUnits: receipt.minimumOutputUnits,
      actualOutputUnits: receipt.minimumOutputUnits,
      sourceTransactionHash:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      destinationTransactionHash:
          '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      createdAt: receipt.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

BridgeFundingReceipt _relayReceipt(BridgeFundingRequest request) =>
    BridgeFundingReceipt(
      schemaVersion: 1,
      intentId: '22222222222222222222222222222222',
      method: BridgeFundingMethod.relayDeposit,
      provider: 'relay',
      state: BridgeFundingState.awaitingDeposit,
      sourceChainId: request.sourceChain.id,
      sourceTokenAddress: request.sourceToken.address,
      sourceTokenSymbol: request.sourceToken.symbol,
      sourceAmountUnits: request.amountUnits,
      baseDestinationAddress: request.baseDestinationAddress,
      refundAddress: request.refundAddress,
      depositAddress: _depositAddress,
      providerRequestId:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      minimumOutputUnits: '1200000',
      depositAddressExposed: true,
      createdAt: DateTime.utc(2026, 8, 7, 12),
      updatedAt: DateTime.utc(2026, 8, 7, 12),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );

BridgeFundingReceipt _unknownReceipt() => BridgeFundingReceipt(
      schemaVersion: 1,
      intentId: '33333333333333333333333333333333',
      method: BridgeFundingMethod.connectedWallet,
      provider: 'lifi',
      state: BridgeFundingState.awaitingExternalWallet,
      sourceChainId: BridgeConstants.ethereumChainId,
      sourceTokenAddress: _ethUsdc.address,
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1250000',
      baseDestinationAddress: _baseAddress,
      sourceAddress: _sourceAddress,
      reviewedPayloadHash:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      submissionOutcomeUnknown: true,
      createdAt: DateTime.utc(2026, 8, 7, 12),
      updatedAt: DateTime.utc(2026, 8, 7, 12),
    );

BridgeFundingReceipt _pendingReceipt() => BridgeFundingReceipt(
      schemaVersion: 1,
      intentId: '44444444444444444444444444444444',
      method: BridgeFundingMethod.connectedWallet,
      provider: 'lifi',
      state: BridgeFundingState.destinationPending,
      sourceChainId: BridgeConstants.ethereumChainId,
      sourceTokenAddress: _ethUsdc.address,
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1250000',
      baseDestinationAddress: _baseAddress,
      sourceAddress: _sourceAddress,
      sourceTransactionHash:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      routeTool: 'across',
      createdAt: DateTime.utc(2026, 8, 7, 12),
      updatedAt: DateTime.utc(2026, 8, 7, 12),
    );

BridgeFundingReceipt _archivedRelayReceipt() => BridgeFundingReceipt(
      schemaVersion: 1,
      intentId: '55555555555555555555555555555555',
      method: BridgeFundingMethod.relayDeposit,
      provider: 'relay',
      state: BridgeFundingState.awaitingDeposit,
      sourceChainId: BridgeConstants.ethereumChainId,
      sourceTokenAddress: _ethUsdc.address,
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1250000',
      baseDestinationAddress: _baseAddress,
      refundAddress: _refundAddress,
      depositAddress: _depositAddress,
      providerRequestId:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      minimumOutputUnits: '1200000',
      depositAddressExposed: true,
      archivedAt: DateTime.utc(2026, 8, 7, 12, 1),
      createdAt: DateTime.utc(2026, 8, 7, 12),
      updatedAt: DateTime.utc(2026, 8, 7, 12, 1),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 8)),
    );

const _ethereum = BridgeChain(
  id: BridgeConstants.ethereumChainId,
  key: 'eth',
  name: 'Ethereum',
  type: BridgeChainType.evm,
  nativeTokenSymbol: 'ETH',
);

const _ethUsdc = BridgeToken(
  chainId: BridgeConstants.ethereumChainId,
  address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
  symbol: 'USDC',
  decimals: 6,
  solverDepositable: true,
);

const _robinhoodEth = BridgeToken(
  chainId: BridgeConstants.robinhoodChainId,
  address: '0x0000000000000000000000000000000000000000',
  symbol: 'ETH',
  decimals: 18,
  solverDepositable: true,
);

const _robinhoodUsdg = BridgeToken(
  chainId: BridgeConstants.robinhoodChainId,
  address: BridgeConstants.robinhoodUsdg,
  symbol: 'USDG',
  decimals: 6,
  solverDepositable: true,
);

const _baseAddress = '0x1111111111111111111111111111111111111111';
const _sourceAddress = '0x2222222222222222222222222222222222222222';
const _refundAddress = '0x3333333333333333333333333333333333333333';
const _depositAddress = '0x4444444444444444444444444444444444444444';
