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

    await tester.tap(find.byKey(const Key('provider-action-venice')));
    await tester.pump();
    expect(action, WalletFundedProviderAction.openBase);
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
