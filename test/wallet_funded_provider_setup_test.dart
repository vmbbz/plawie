import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clawa/screens/setup_flow_screen.dart';
import 'package:clawa/services/preferences_service.dart';
import 'package:clawa/services/provider_setup_service.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('wallet-funded setup clears pending BYOK data and records no model',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = PreferencesService();
    await preferences.init();
    final secrets = InMemoryProviderSecretBackend();
    final service = ProviderSetupService(
      preferences: preferences,
      secrets: secrets,
    );
    await service.stage(
      providerId: 'openrouter',
      modelId: 'openrouter/auto',
      apiKey: 'temporary-key',
    );

    await service.selectWalletFundedProvider('venice');

    expect(await service.readPending(), isNull);
    expect(secrets.values, isEmpty);
    expect(preferences.apiProvider, isNull);
    expect(preferences.configuredModel, isNull);
    expect(preferences.aiPaymentProvider, 'venice');
  });

  testWidgets('Venice setup explains prepaid funding without an API key',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const SetupFlowScreen()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(
      find.text('Venice'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    tester
        .widget<GestureDetector>(find.byKey(const Key('setup-provider-venice')))
        .onTap!();
    await tester.pump(const Duration(milliseconds: 100));
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Connect your provider'), findsOneWidget);
    expect(find.text('Wallet-funded provider'), findsOneWidget);
    expect(find.textContaining('prepaid Venice balance'), findsOneWidget);
    expect(find.textContaining('back up or export the wallet'), findsOneWidget);
    expect(find.textContaining('Setup performs no blockchain action'),
        findsOneWidget);
    expect(find.textContaining('Enter your Venice API key'), findsNothing);
  });

  testWidgets('BYOK setup keeps the existing API-key input', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const SetupFlowScreen()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Connect your provider'), findsOneWidget);
    expect(find.text('Enter your OpenRouter API key'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('BlockRun setup states per-request approval instead of top-up',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const SetupFlowScreen()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(
      find.text('BlockRun'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    tester
        .widget<GestureDetector>(
            find.byKey(const Key('setup-provider-blockrun')))
        .onTap!();
    await tester.pump(const Duration(milliseconds: 100));
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Connect your provider'), findsOneWidget);
    expect(find.textContaining('no prepaid provider balance'), findsOneWidget);
    expect(find.textContaining('exact Base USDC amount'), findsOneWidget);
    expect(find.textContaining('Setup performs no blockchain action'),
        findsOneWidget);
    expect(find.textContaining('Enter your BlockRun API key'), findsNothing);
  });

  testWidgets('final setup presents explicit unselected analytics choices',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const SetupFlowScreen()),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.scrollUntilVisible(
      find.text('Venice'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    tester
        .widget<GestureDetector>(find.byKey(const Key('setup-provider-venice')))
        .onTap!();
    await tester.pump(const Duration(milliseconds: 100));

    for (var step = 0; step < 3; step++) {
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Continue'),
          )
          .onPressed!();
      await tester.pumpAndSettle();
    }

    expect(find.text('Help improve Plawie'), findsOneWidget);
    expect(find.text('Share anonymous analytics'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Privacy details'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('analytics-choice-share')))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const Key('analytics-choice-not-now')),
          )
          .selected,
      isFalse,
    );
  });
}
