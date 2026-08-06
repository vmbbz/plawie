package com.openclaw.plawie

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SecureEvmWalletRecoveryPolicyTest {
    @Test
    fun `orphan cleanup is limited to the exact orphan state`() {
        SecureEvmWalletState.entries.forEach { state ->
            val expected = state == SecureEvmWalletState.ORPHANED_ALIAS
            assertTrue(
                state.wireName,
                SecureEvmWalletRecoveryPolicy.canRemoveOrphanedAlias(state) == expected,
            )
        }
    }

    @Test
    fun `damaged removal accepts only bounded damaged states`() {
        val accepted = setOf(
            SecureEvmWalletState.ENVELOPE_CORRUPT,
            SecureEvmWalletState.KEY_MISSING,
            SecureEvmWalletState.KEY_INVALIDATED,
        )
        SecureEvmWalletState.entries.forEach { state ->
            assertTrue(
                state.wireName,
                SecureEvmWalletRecoveryPolicy.canRemoveDamagedWallet(state) ==
                    accepted.contains(state),
            )
        }
    }

    @Test
    fun `recovery authenticates only when a usable alias remains`() {
        assertTrue(
            SecureEvmWalletRecoveryPolicy.requiresAuthentication(
                aliasPresent = true,
                keyInvalidated = false,
            ),
        )
        assertFalse(
            SecureEvmWalletRecoveryPolicy.requiresAuthentication(
                aliasPresent = false,
                keyInvalidated = false,
            ),
        )
        assertFalse(
            SecureEvmWalletRecoveryPolicy.requiresAuthentication(
                aliasPresent = true,
                keyInvalidated = true,
            ),
        )
    }
}
