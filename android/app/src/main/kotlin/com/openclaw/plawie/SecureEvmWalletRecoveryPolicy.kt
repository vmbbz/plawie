package com.openclaw.plawie

/**
 * Keeps destructive wallet recovery bounded to explicit, fail-closed states.
 *
 * Ordinary create/import and healthy-wallet deletion deliberately do not use
 * this policy. Recovery may only remove the app's known envelope and Keystore
 * alias after the native confirmation/authentication flow has approved it.
 */
internal object SecureEvmWalletRecoveryPolicy {
    fun canRemoveOrphanedAlias(state: SecureEvmWalletState): Boolean =
        state == SecureEvmWalletState.ORPHANED_ALIAS

    fun canRemoveDamagedWallet(state: SecureEvmWalletState): Boolean =
        state == SecureEvmWalletState.ENVELOPE_CORRUPT ||
            state == SecureEvmWalletState.KEY_MISSING ||
            state == SecureEvmWalletState.KEY_INVALIDATED

    fun requiresAuthentication(aliasPresent: Boolean, keyInvalidated: Boolean): Boolean =
        aliasPresent && !keyInvalidated
}
