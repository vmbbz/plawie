import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gateway_provider.dart';
import '../screens/base_screen.dart';
import '../services/preferences_service.dart';
import '../services/gateway_service.dart';
import '../services/wallet_funded_provider_readiness.dart';

/// Executes only an action the user explicitly tapped in a wallet-funded
/// provider status card. Payment, signing, and authentication remain owned by
/// their canonical Base/payment surfaces.
Future<void> runWalletFundedProviderAction(
  BuildContext context, {
  required String providerId,
  required WalletFundedProviderAction action,
}) async {
  if (action == WalletFundedProviderAction.none) return;

  if (action == WalletFundedProviderAction.refreshModels) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refreshing provider models…')),
    );
    try {
      await GatewayService().refreshProviderModelCatalog(providerId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Models refreshed. Reopen the model list.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model refresh failed: $error')),
      );
    }
    return;
  }

  if (action == WalletFundedProviderAction.restartGateway) {
    final gateway = Provider.of<GatewayProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restarting the Gateway transport…')),
    );
    try {
      await gateway.stop();
      await gateway.start();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gateway restarted. Reopen models.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gateway restart failed: $error')),
      );
    }
    return;
  }

  final preferences = PreferencesService();
  await preferences.init();
  preferences.aiPaymentProvider = providerId;
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BaseScreen(
        initialPaymentProviderId: providerId,
        initialAction: action,
      ),
    ),
  );
}
