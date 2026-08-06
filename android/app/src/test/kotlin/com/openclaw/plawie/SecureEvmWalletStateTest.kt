package com.openclaw.plawie

import org.junit.Assert.assertEquals
import org.junit.Test

class SecureEvmWalletStateTest {
    @Test
    fun `classifies every supported wallet state`() {
        val cases = listOf(
            case("absent", facts(), SecureEvmWalletState.ABSENT),
            case(
                "healthy",
                facts(envelopePresent = true, envelopeParseable = true, keyAliasPresent = true),
                SecureEvmWalletState.HEALTHY,
            ),
            case(
                "authentication unavailable",
                facts(
                    envelopePresent = true,
                    envelopeParseable = true,
                    keyAliasPresent = true,
                    authenticationAvailable = false,
                ),
                SecureEvmWalletState.AUTHENTICATION_UNAVAILABLE,
            ),
            case(
                "corrupt envelope",
                facts(envelopePresent = true, keyAliasPresent = true),
                SecureEvmWalletState.ENVELOPE_CORRUPT,
            ),
            case(
                "missing key",
                facts(envelopePresent = true, envelopeParseable = true),
                SecureEvmWalletState.KEY_MISSING,
            ),
            case(
                "invalidated key",
                facts(
                    envelopePresent = true,
                    envelopeParseable = true,
                    keyAliasPresent = true,
                    keyInvalidated = true,
                ),
                SecureEvmWalletState.KEY_INVALIDATED,
            ),
            case(
                "orphaned alias",
                facts(keyAliasPresent = true),
                SecureEvmWalletState.ORPHANED_ALIAS,
            ),
            case(
                "operation busy",
                facts(operationActive = true),
                SecureEvmWalletState.OPERATION_BUSY,
            ),
        )

        cases.forEach { (name, input, expected) ->
            assertEquals(name, expected, SecureEvmWalletStateClassifier.classify(input))
        }
    }

    @Test
    fun `classification precedence fails closed`() {
        assertEquals(
            SecureEvmWalletState.OPERATION_BUSY,
            SecureEvmWalletStateClassifier.classify(
                facts(
                    envelopePresent = true,
                    keyAliasPresent = true,
                    keyInvalidated = true,
                    authenticationAvailable = false,
                    operationActive = true,
                ),
            ),
        )
        assertEquals(
            SecureEvmWalletState.ENVELOPE_CORRUPT,
            SecureEvmWalletStateClassifier.classify(
                facts(
                    envelopePresent = true,
                    keyAliasPresent = false,
                    keyInvalidated = true,
                    authenticationAvailable = false,
                ),
            ),
        )
        assertEquals(
            SecureEvmWalletState.KEY_MISSING,
            SecureEvmWalletStateClassifier.classify(
                facts(
                    envelopePresent = true,
                    envelopeParseable = true,
                    authenticationAvailable = false,
                ),
            ),
        )
        assertEquals(
            SecureEvmWalletState.KEY_INVALIDATED,
            SecureEvmWalletStateClassifier.classify(
                facts(
                    envelopePresent = true,
                    envelopeParseable = true,
                    keyAliasPresent = true,
                    keyInvalidated = true,
                    authenticationAvailable = false,
                ),
            ),
        )
        assertEquals(
            SecureEvmWalletState.ORPHANED_ALIAS,
            SecureEvmWalletStateClassifier.classify(
                facts(keyAliasPresent = true, authenticationAvailable = false),
            ),
        )
    }

    @Test
    fun `wire contract exposes stable codes and conservative actions`() {
        assertEquals("absent", SecureEvmWalletState.ABSENT.wireName)
        assertEquals("healthy", SecureEvmWalletState.HEALTHY.wireName)
        assertEquals("authenticationUnavailable", SecureEvmWalletState.AUTHENTICATION_UNAVAILABLE.wireName)
        assertEquals("envelopeCorrupt", SecureEvmWalletState.ENVELOPE_CORRUPT.wireName)
        assertEquals("keystoreKeyMissing", SecureEvmWalletState.KEY_MISSING.wireName)
        assertEquals("keystoreKeyInvalidated", SecureEvmWalletState.KEY_INVALIDATED.wireName)
        assertEquals("orphanedKeystoreAlias", SecureEvmWalletState.ORPHANED_ALIAS.wireName)
        assertEquals("operationBusy", SecureEvmWalletState.OPERATION_BUSY.wireName)

        assertEquals("", SecureEvmWalletState.HEALTHY.errorCode)
        assertEquals("", SecureEvmWalletState.ABSENT.errorCode)
        assertEquals("WALLET_AUTH_UNAVAILABLE", SecureEvmWalletState.AUTHENTICATION_UNAVAILABLE.errorCode)
        assertEquals("WALLET_ENVELOPE_CORRUPT", SecureEvmWalletState.ENVELOPE_CORRUPT.errorCode)
        assertEquals("WALLET_KEY_MISSING", SecureEvmWalletState.KEY_MISSING.errorCode)
        assertEquals("WALLET_KEY_INVALIDATED", SecureEvmWalletState.KEY_INVALIDATED.errorCode)
        assertEquals("WALLET_ORPHANED_KEY_ALIAS", SecureEvmWalletState.ORPHANED_ALIAS.errorCode)
        assertEquals("WALLET_OPERATION_BUSY", SecureEvmWalletState.OPERATION_BUSY.errorCode)

        assertEquals(true, SecureEvmWalletState.ABSENT.canCreate)
        assertEquals(false, SecureEvmWalletState.ORPHANED_ALIAS.canCreate)
        assertEquals(false, SecureEvmWalletState.ENVELOPE_CORRUPT.canCreate)
        assertEquals(false, SecureEvmWalletState.OPERATION_BUSY.canRestore)
        assertEquals(true, SecureEvmWalletState.KEY_MISSING.canRestore)
        assertEquals(true, SecureEvmWalletState.ENVELOPE_CORRUPT.requiresDestructiveRecovery)
        assertEquals(true, SecureEvmWalletState.KEY_MISSING.requiresDestructiveRecovery)
        assertEquals(true, SecureEvmWalletState.KEY_INVALIDATED.requiresDestructiveRecovery)
        assertEquals(false, SecureEvmWalletState.ORPHANED_ALIAS.requiresDestructiveRecovery)
    }

    private fun facts(
        envelopePresent: Boolean = false,
        envelopeParseable: Boolean = false,
        keyAliasPresent: Boolean = false,
        keyInvalidated: Boolean = false,
        authenticationAvailable: Boolean = true,
        operationActive: Boolean = false,
    ) = WalletStorageFacts(
        envelopePresent = envelopePresent,
        envelopeParseable = envelopeParseable,
        keyAliasPresent = keyAliasPresent,
        keyInvalidated = keyInvalidated,
        authenticationAvailable = authenticationAvailable,
        operationActive = operationActive,
    )

    private fun case(
        name: String,
        facts: WalletStorageFacts,
        expected: SecureEvmWalletState,
    ) = Triple(name, facts, expected)
}
