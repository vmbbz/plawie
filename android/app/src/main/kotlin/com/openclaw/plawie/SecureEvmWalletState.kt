package com.openclaw.plawie

/** Facts gathered without decrypting the wallet or showing an auth prompt. */
internal data class WalletStorageFacts(
    val envelopePresent: Boolean,
    val envelopeParseable: Boolean,
    val keyAliasPresent: Boolean,
    val keyInvalidated: Boolean,
    val authenticationAvailable: Boolean,
    val operationActive: Boolean,
)

/** Stable Android-to-Dart wallet lifecycle contract. */
internal enum class SecureEvmWalletState(
    val wireName: String,
    val errorCode: String,
) {
    ABSENT("absent", ""),
    HEALTHY("healthy", ""),
    AUTHENTICATION_UNAVAILABLE(
        "authenticationUnavailable",
        "WALLET_AUTH_UNAVAILABLE",
    ),
    ENVELOPE_CORRUPT("envelopeCorrupt", "WALLET_ENVELOPE_CORRUPT"),
    KEY_MISSING("keystoreKeyMissing", "WALLET_KEY_MISSING"),
    KEY_INVALIDATED("keystoreKeyInvalidated", "WALLET_KEY_INVALIDATED"),
    ORPHANED_ALIAS("orphanedKeystoreAlias", "WALLET_ORPHANED_KEY_ALIAS"),
    OPERATION_BUSY("operationBusy", "WALLET_OPERATION_BUSY"),
    ;

    val canCreate: Boolean
        get() = this == ABSENT

    val createErrorCode: String
        get() = when (this) {
            ABSENT -> ""
            HEALTHY -> "WALLET_EXISTS"
            else -> errorCode
        }

    val canRestore: Boolean
        get() = this != OPERATION_BUSY

    val requiresDestructiveRecovery: Boolean
        get() = this == ENVELOPE_CORRUPT || this == KEY_MISSING || this == KEY_INVALIDATED
}

internal object SecureEvmWalletStateClassifier {
    fun classify(facts: WalletStorageFacts): SecureEvmWalletState = when {
        facts.operationActive -> SecureEvmWalletState.OPERATION_BUSY
        facts.envelopePresent && !facts.envelopeParseable ->
            SecureEvmWalletState.ENVELOPE_CORRUPT
        facts.envelopePresent && !facts.keyAliasPresent ->
            SecureEvmWalletState.KEY_MISSING
        facts.envelopePresent && facts.keyInvalidated ->
            SecureEvmWalletState.KEY_INVALIDATED
        !facts.envelopePresent && facts.keyAliasPresent ->
            SecureEvmWalletState.ORPHANED_ALIAS
        !facts.authenticationAvailable ->
            SecureEvmWalletState.AUTHENTICATION_UNAVAILABLE
        facts.envelopePresent -> SecureEvmWalletState.HEALTHY
        else -> SecureEvmWalletState.ABSENT
    }
}
