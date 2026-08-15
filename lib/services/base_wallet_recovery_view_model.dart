import 'native_bridge.dart';

/// Pure product-action matrix for the native secure-wallet state contract.
class BaseWalletRecoveryViewModel {
  final SecureWalletState state;
  final String title;
  final String consequence;
  final String guidance;
  final bool actionsEnabled;
  final bool canCreate;
  final bool canImport;
  final bool canMigrate;
  final bool canBackup;
  final bool canRemove;
  final bool canRestoreBackup;
  final bool canRemoveDamaged;
  final bool canRemoveOrphanedAlias;

  const BaseWalletRecoveryViewModel._({
    required this.state,
    required this.title,
    required this.consequence,
    required this.guidance,
    required this.actionsEnabled,
    this.canCreate = false,
    this.canImport = false,
    this.canMigrate = false,
    this.canBackup = false,
    this.canRemove = false,
    this.canRestoreBackup = false,
    this.canRemoveDamaged = false,
    this.canRemoveOrphanedAlias = false,
  });

  factory BaseWalletRecoveryViewModel.fromStatus(SecureWalletStatus status) {
    switch (status.state) {
      case SecureWalletState.absent:
        return const BaseWalletRecoveryViewModel._(
          state: SecureWalletState.absent,
          title: 'No Plawie wallet on this device',
          consequence: 'Create a new wallet or restore an exported backup.',
          guidance: 'Back up the private key before funding the wallet.',
          actionsEnabled: true,
          canCreate: true,
          canImport: true,
        );
      case SecureWalletState.healthy:
        return BaseWalletRecoveryViewModel._(
          state: SecureWalletState.healthy,
          title: status.verificationPending
              ? 'Wallet created · verification pending'
              : 'Wallet protected by Android',
          consequence: status.verificationPending
              ? 'The encrypted wallet was saved, but the final unlock check was deferred.'
              : 'Every signing operation requires device authentication.',
          guidance: status.verificationPending
              ? 'Authenticate with Backup before funding. Signed updates preserve it; clearing app data or uninstalling removes it.'
              : 'Signed updates preserve it. Export a backup before clearing app data or uninstalling.',
          actionsEnabled: true,
          canBackup: true,
          canRemove: true,
        );
      case SecureWalletState.legacyMigrationRequired:
        return const BaseWalletRecoveryViewModel._(
          state: SecureWalletState.legacyMigrationRequired,
          title: 'Existing wallet needs stronger protection',
          consequence:
              'The historical key has not yet moved into Android Keystore.',
          guidance: 'Secure this wallet before transfers or AI payments.',
          actionsEnabled: true,
          canMigrate: true,
        );
      case SecureWalletState.authenticationUnavailable:
        return const BaseWalletRecoveryViewModel._(
          state: SecureWalletState.authenticationUnavailable,
          title: 'Secure device authentication unavailable',
          consequence: 'Wallet creation and signing are disabled.',
          guidance:
              'Set up a secure device lock or Class 3 biometric, then refresh.',
          actionsEnabled: false,
        );
      case SecureWalletState.envelopeCorrupt:
        return damaged(
          status.state,
          'Encrypted wallet record is damaged',
          'Plawie will not treat this record as an empty wallet.',
        );
      case SecureWalletState.keystoreKeyMissing:
        return damaged(
          status.state,
          'Wallet protection key is missing',
          'The public address is known, but this device cannot unlock the wallet.',
        );
      case SecureWalletState.keystoreKeyInvalidated:
        return damaged(
          status.state,
          'Wallet protection was invalidated',
          'A device-security change prevents this wallet from being unlocked.',
        );
      case SecureWalletState.orphanedKeystoreAlias:
        return const BaseWalletRecoveryViewModel._(
          state: SecureWalletState.orphanedKeystoreAlias,
          title: 'Orphaned wallet protection record',
          consequence:
              'No wallet envelope exists, but its Keystore alias remains.',
          guidance: 'Remove only the orphaned protection record, then refresh.',
          actionsEnabled: true,
          canRemoveOrphanedAlias: true,
        );
      case SecureWalletState.operationBusy:
        return const BaseWalletRecoveryViewModel._(
          state: SecureWalletState.operationBusy,
          title: 'Wallet authentication in progress',
          consequence: 'Another protected wallet operation is active.',
          guidance: 'Finish or cancel the Android prompt before continuing.',
          actionsEnabled: false,
        );
      case SecureWalletState.unavailable:
        return const BaseWalletRecoveryViewModel._(
          state: SecureWalletState.unavailable,
          title: 'Wallet status unavailable',
          consequence: 'Plawie could not safely classify the native wallet.',
          guidance:
              'Retry status. Do not create or import until it is classified.',
          actionsEnabled: false,
        );
    }
  }

  static BaseWalletRecoveryViewModel damaged(
    SecureWalletState state,
    String title,
    String consequence,
  ) =>
      BaseWalletRecoveryViewModel._(
        state: state,
        title: title,
        consequence: consequence,
        guidance:
            'Restore an exported backup or explicitly remove the damaged record.',
        actionsEnabled: true,
        canRestoreBackup: true,
        canRemoveDamaged: true,
      );

  bool get hasMutationAction =>
      canCreate ||
      canImport ||
      canMigrate ||
      canRemove ||
      canRestoreBackup ||
      canRemoveDamaged ||
      canRemoveOrphanedAlias;
}
