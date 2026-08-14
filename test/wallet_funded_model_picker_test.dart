import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/dynamic_model_catalog.dart';
import 'package:clawa/services/model_provider_catalog.dart';
import 'package:clawa/services/wallet_funded_provider_readiness.dart';
import 'package:clawa/widgets/dynamic_model_picker_panel.dart';

void main() {
  testWidgets('missing wallet is visible and blocks wallet-funded selection',
      (tester) async {
    String? selected;
    WalletFundedProviderAction? action;
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[_provider('venice')]),
      readiness: <String, WalletFundedProviderReadiness>{
        'venice': _readiness(
          providerId: 'venice',
          state: WalletFundedProviderState.walletRequired,
          canSelect: false,
          title: 'Base wallet required',
          action: WalletFundedProviderAction.openBase,
          actionLabel: 'Create or import wallet',
        ),
      },
      onSelected: (value) => selected = value.id,
      onAction: (_, value) => action = value,
    ));

    expect(find.text('WALLET FUNDED'), findsOneWidget);
    expect(find.text('Base wallet required'), findsOneWidget);
    expect(find.text('Live catalog'), findsOneWidget);
    expect(find.text('Transport starts on selection'), findsOneWidget);

    await tester.tap(find.byKey(const Key('model-option-venice/model-1')));
    await tester.pump();
    expect(selected, isNull);
    expect(action, WalletFundedProviderAction.openBase);

    action = null;
    await tester.tap(find.byKey(const Key('provider-action-venice')));
    await tester.pump();
    expect(action, WalletFundedProviderAction.openBase);
  });

  testWidgets(
      'unknown Venice balance refreshes automatically and enables selection',
      (tester) async {
    String? selected;
    var refreshCount = 0;
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[_provider('venice')]),
      readiness: <String, WalletFundedProviderReadiness>{
        'venice': _readiness(
          providerId: 'venice',
          state: WalletFundedProviderState.balanceUnknown,
          canSelect: false,
          title: 'Venice balance needs checking',
          detail: 'Check the wallet-linked Venice balance.',
          action: WalletFundedProviderAction.refreshBalance,
          actionLabel: 'Check Venice balance',
        ),
      },
      autoRefreshWalletBalances: true,
      onRefreshBalance: (providerId) async {
        refreshCount += 1;
        expect(providerId, 'venice');
        return <String, WalletFundedProviderReadiness>{
          'venice': _readiness(
            providerId: 'venice',
            state: WalletFundedProviderState.ready,
            canSelect: true,
            title: 'Prepaid balance ready',
            detail: r'$4.75 spendable',
            action: WalletFundedProviderAction.openBase,
            actionLabel: 'Manage',
          ),
        };
      },
      onSelected: (value) => selected = value.id,
    ));

    await tester.pumpAndSettle();
    expect(refreshCount, 1);
    expect(
        find.text(
            'Venice balance refreshed. Available models are ready to select.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('model-option-venice/model-1')));
    await tester.pump();
    expect(selected, 'venice/model-1');
  });

  testWidgets('blocked Venice model explains the balance gate and retries it',
      (tester) async {
    WalletFundedProviderAction? action;
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[_provider('venice')]),
      readiness: <String, WalletFundedProviderReadiness>{
        'venice': _readiness(
          providerId: 'venice',
          state: WalletFundedProviderState.balanceUnknown,
          canSelect: false,
          title: 'Venice balance needs checking',
          detail: 'Check the wallet-linked Venice balance.',
          action: WalletFundedProviderAction.refreshBalance,
          actionLabel: 'Check Venice balance',
        ),
      },
      onAction: (_, value) => action = value,
    ));

    expect(find.textContaining('Venice balance needs checking'), findsWidgets);
    expect(find.byIcon(Icons.lock_clock_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('model-option-venice/model-1')));
    await tester.pump();
    expect(action, WalletFundedProviderAction.refreshBalance);
  });

  testWidgets('BlockRun is selectable but never described as funded',
      (tester) async {
    String? selected;
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[_provider('blockrun')]),
      readiness: <String, WalletFundedProviderReadiness>{
        'blockrun': _readiness(
          providerId: 'blockrun',
          state: WalletFundedProviderState.paymentPerRequest,
          canSelect: true,
          title: 'Payment per request',
          detail: 'Every paid request has a separate exact approval.',
          action: WalletFundedProviderAction.fundWallet,
          actionLabel: 'Fund wallet',
        ),
      },
      onSelected: (value) => selected = value.id,
    ));

    expect(find.text('Payment per request'), findsOneWidget);
    expect(find.textContaining('funded', findRichText: true), findsNothing);
    await tester.tap(find.byKey(const Key('model-option-blockrun/model-1')));
    await tester.pump();
    expect(selected, 'blockrun/model-1');
  });

  testWidgets('advertised tools are not presented as Agent-ready',
      (tester) async {
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[_provider('openrouter')]),
      readiness: const <String, WalletFundedProviderReadiness>{},
    ));

    expect(
        find.textContaining('Provider says tools supported'), findsOneWidget);
    expect(find.textContaining('Agent-ready'), findsNothing);
  });

  testWidgets('unverified model exposes an explicit tool test action',
      (tester) async {
    String? tested;
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[_provider('openrouter')]),
      readiness: const <String, WalletFundedProviderReadiness>{},
      onTestTools: (model) => tested = model.id,
    ));

    await tester
        .tap(find.byKey(const Key('model-tool-test-openrouter/model-1')));
    await tester.pump();
    expect(tested, 'openrouter/model-1');
  });

  testWidgets('agent filter hides chat-only models until all chat is selected',
      (tester) async {
    final provider = DynamicProviderRecord(
      id: 'openrouter',
      label: 'OpenRouter',
      authenticationMode: ProviderAuthenticationMode.apiKey,
      connectionState: DynamicProviderConnectionState.connected,
      models: <DynamicModelRecord>[
        const DynamicModelRecord(
          id: 'openrouter/tool-model',
          providerId: 'openrouter',
          label: 'Tool Model',
          route: ModelRouteKind.cloud,
          supportsToolCalls: true,
          toolReadiness: ModelToolReadiness.providerAdvertised,
        ),
        const DynamicModelRecord(
          id: 'openrouter/chat-model',
          providerId: 'openrouter',
          label: 'Chat Model',
          route: ModelRouteKind.cloud,
          supportsToolCalls: false,
          toolReadiness: ModelToolReadiness.incompatible,
        ),
      ],
    );
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[provider]),
      readiness: const <String, WalletFundedProviderReadiness>{},
    ));

    expect(find.byKey(const Key('model-option-openrouter/tool-model')),
        findsOneWidget);
    expect(find.byKey(const Key('model-option-openrouter/chat-model')),
        findsNothing);
    await tester.tap(find.byKey(const Key('model-filter-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('model-option-openrouter/chat-model')),
        findsOneWidget);
    expect(find.textContaining('Chat only on this route'), findsOneWidget);
  });

  testWidgets('provider refresh replaces the displayed catalog',
      (tester) async {
    var refreshCount = 0;
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[_provider('openrouter')]),
      readiness: const <String, WalletFundedProviderReadiness>{},
      onRefreshModels: (providerId) async {
        refreshCount += 1;
        expect(providerId, 'openrouter');
        return _snapshot(<DynamicProviderRecord>[
          DynamicProviderRecord(
            id: 'openrouter',
            label: 'OpenRouter',
            authenticationMode: ProviderAuthenticationMode.apiKey,
            connectionState: DynamicProviderConnectionState.connected,
            catalogState: DynamicProviderCatalogState.fresh,
            lastRefreshedAt: DateTime.utc(2026, 8, 14),
            models: const <DynamicModelRecord>[
              DynamicModelRecord(
                id: 'openrouter/model-2',
                providerId: 'openrouter',
                label: 'Model Two',
                route: ModelRouteKind.cloud,
                supportsToolCalls: true,
                toolReadiness: ModelToolReadiness.providerAdvertised,
              ),
            ],
          ),
        ]);
      },
    ));

    await tester
        .tap(find.byKey(const Key('provider-refresh-models-openrouter')));
    await tester.pumpAndSettle();
    expect(refreshCount, 1);
    expect(find.byKey(const Key('model-option-openrouter/model-2')),
        findsOneWidget);
    expect(find.textContaining('catalog refreshed'), findsOneWidget);
  });

  testWidgets('search filters grouped providers and preserves stale warning',
      (tester) async {
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[
        _provider('venice', catalogState: DynamicProviderCatalogState.stale),
        _provider('openrouter', walletFunded: false),
      ], state: DynamicCatalogSnapshotState.stale),
      readiness: <String, WalletFundedProviderReadiness>{
        'venice': _readiness(
          providerId: 'venice',
          state: WalletFundedProviderState.balanceLow,
          canSelect: true,
          title: 'Low prepaid balance',
          action: WalletFundedProviderAction.topUpVenice,
          actionLabel: 'Top up Venice',
          catalogLabel: 'Cached catalog',
        ),
      },
    ));

    expect(find.text('Showing cached provider metadata'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('model-picker-search')), 'openrouter');
    await tester.pump();

    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.text('Venice'), findsNothing);
  });

  testWidgets('informational fallback model is disabled with its real reason',
      (tester) async {
    String? selected;
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[
        _provider('venice', live: false),
      ]),
      readiness: <String, WalletFundedProviderReadiness>{
        'venice': _readiness(
          providerId: 'venice',
          state: WalletFundedProviderState.catalogUnavailable,
          canSelect: false,
          title: 'Live models unavailable',
          action: WalletFundedProviderAction.refreshModels,
          actionLabel: 'Refresh models',
        ),
      },
      onSelected: (value) => selected = value.id,
    ));

    await tester.tap(find.byKey(const Key('model-filter-all')));
    await tester.pump();
    expect(find.text('Current models have not been loaded.'), findsOneWidget);
    await tester
        .tap(find.byKey(const Key('model-option-venice/catalog-unavailable')));
    await tester.pump();
    expect(selected, isNull);
  });

  testWidgets('BYOK model remains selectable beside wallet-funded groups',
      (tester) async {
    String? selected;
    await tester.pumpWidget(_host(
      snapshot: _snapshot(<DynamicProviderRecord>[
        _provider('blockrun'),
        _provider('openrouter', walletFunded: false),
      ]),
      readiness: <String, WalletFundedProviderReadiness>{
        'blockrun': _readiness(
          providerId: 'blockrun',
          state: WalletFundedProviderState.paymentPerRequest,
          canSelect: true,
          title: 'Payment per request',
          action: WalletFundedProviderAction.fundWallet,
          actionLabel: 'Fund wallet',
        ),
      },
      onSelected: (value) => selected = value.id,
    ));

    await tester.tap(find.byKey(const Key('model-option-openrouter/model-1')));
    await tester.pump();
    expect(selected, 'openrouter/model-1');
  });
}

Widget _host({
  required DynamicCatalogSnapshot snapshot,
  required Map<String, WalletFundedProviderReadiness> readiness,
  ValueChanged<DynamicModelRecord>? onSelected,
  void Function(String, WalletFundedProviderAction)? onAction,
  bool autoRefreshWalletBalances = false,
  WalletProviderBalanceRefresh? onRefreshBalance,
  DynamicModelCatalogRefresh? onRefreshModels,
  ValueChanged<DynamicModelRecord>? onTestTools,
}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SizedBox(
        height: 700,
        child: DynamicModelPickerPanel(
          snapshot: snapshot,
          currentModelId: '',
          walletReadiness: readiness,
          initiallyExpandedProviderIds:
              snapshot.providers.map((provider) => provider.id).toSet(),
          onSelected: onSelected ?? (_) {},
          onProviderAction: onAction ?? (_, __) {},
          autoRefreshWalletBalances: autoRefreshWalletBalances,
          onRefreshProviderBalance: onRefreshBalance,
          onRefreshModels: onRefreshModels,
          onTestTools: onTestTools,
        ),
      ),
    ),
  );
}

DynamicCatalogSnapshot _snapshot(
  List<DynamicProviderRecord> providers, {
  DynamicCatalogSnapshotState state = DynamicCatalogSnapshotState.fresh,
}) {
  return DynamicCatalogSnapshot(
    schemaVersion: DynamicCatalogSnapshot.currentSchemaVersion,
    snapshotId: 'picker-test',
    state: state,
    updatedAt: DateTime.utc(2026, 8, 6, 11),
    expiresAt: DateTime.utc(2026, 8, 6, 13),
    providers: providers,
  );
}

DynamicProviderRecord _provider(
  String id, {
  bool walletFunded = true,
  bool live = true,
  DynamicProviderCatalogState catalogState = DynamicProviderCatalogState.fresh,
}) {
  final label = switch (id) {
    'venice' => 'Venice',
    'blockrun' => 'BlockRun',
    _ => 'OpenRouter',
  };
  return DynamicProviderRecord(
    id: id,
    label: label,
    authenticationMode: walletFunded
        ? ProviderAuthenticationMode.walletIdentity
        : ProviderAuthenticationMode.apiKey,
    connectionState: DynamicProviderConnectionState.connected,
    catalogState:
        live ? catalogState : DynamicProviderCatalogState.offlineFallback,
    source: live ? 'live' : 'bundled-static',
    lastRefreshedAt: DateTime.utc(2026, 8, 6, 11),
    models: <DynamicModelRecord>[
      DynamicModelRecord(
        id: '$id/${live ? 'model-1' : 'catalog-unavailable'}',
        providerId: id,
        label: live ? 'Model One' : 'Refresh $label models',
        route: ModelRouteKind.cloud,
        supportsToolCalls: live,
        chatReadiness: live
            ? ModelChatReadiness.providerAdvertised
            : ModelChatReadiness.unknown,
        toolReadiness: live
            ? ModelToolReadiness.providerAdvertised
            : ModelToolReadiness.incompatible,
        liveAvailable: live,
        unavailableReason: live ? null : 'Current models have not been loaded.',
      ),
    ],
  );
}

WalletFundedProviderReadiness _readiness({
  required String providerId,
  required WalletFundedProviderState state,
  required bool canSelect,
  required String title,
  required WalletFundedProviderAction action,
  required String actionLabel,
  String detail = 'Readiness detail.',
  String catalogLabel = 'Live catalog',
}) {
  return WalletFundedProviderReadiness(
    providerId: providerId,
    state: state,
    canSelectModels: canSelect,
    title: title,
    detail: detail,
    catalogLabel: catalogLabel,
    transportLabel: 'Transport starts on selection',
    primaryAction: action,
    primaryActionLabel: actionLabel,
  );
}
