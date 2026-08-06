package com.openclaw.plawie

/** Serialized envelope representation used by the transactional commit seam. */
internal data class WalletEnvelopeRecord(
    val version: Int,
    val address: String,
    val iv: ByteArray,
    val ciphertext: ByteArray,
) {
    fun hasSameContents(other: WalletEnvelopeRecord): Boolean =
        version == other.version &&
            address == other.address &&
            iv.contentEquals(other.iv) &&
            ciphertext.contentEquals(other.ciphertext)
}

/** Minimal storage boundary needed to prove commit and rollback behavior on the JVM. */
internal interface WalletCommitStore {
    fun aliasExists(): Boolean
    fun deleteAlias()
    fun envelopeExists(): Boolean
    fun writeEnvelope(envelope: WalletEnvelopeRecord)
    fun readEnvelope(): WalletEnvelopeRecord
    fun deletePartialEnvelope()
}

/**
 * Tracks only artifacts created by one create/import attempt.
 *
 * A rollback never removes an alias or envelope that existed when this object
 * was created. A commit is complete only after a byte-for-byte read-back.
 */
internal class SecureEvmWalletTransaction(
    private val store: WalletCommitStore,
) {
    private val aliasPresentAtStart = store.aliasExists()
    private val envelopePresentAtStart = store.envelopeExists()
    private var committed = false
    private var rollbackComplete = false

    val isCommitted: Boolean
        get() = committed

    fun commit(envelope: WalletEnvelopeRecord) {
        check(!envelopePresentAtStart) { "A wallet envelope already exists." }
        check(!aliasPresentAtStart) { "A wallet protection alias already exists." }
        check(!committed) { "The wallet transaction is already committed." }
        check(!rollbackComplete) { "The wallet transaction was already rolled back." }

        try {
            store.writeEnvelope(envelope)
            val stored = store.readEnvelope()
            check(envelope.hasSameContents(stored)) {
                "Wallet envelope read-back verification failed."
            }
            committed = true
        } catch (error: Throwable) {
            try {
                rollback()
            } catch (rollbackError: Throwable) {
                error.addSuppressed(rollbackError)
            }
            throw error
        }
    }

    fun rollback() {
        if (committed || rollbackComplete) return
        cleanupAttemptArtifacts()
    }

    /** Removes a committed record only when cryptographic verification fails. */
    fun abortCommittedAttempt() {
        if (rollbackComplete) return
        committed = false
        cleanupAttemptArtifacts()
    }

    private fun cleanupAttemptArtifacts() {
        rollbackComplete = true
        var cleanupFailure: Throwable? = null

        if (!envelopePresentAtStart) {
            try {
                store.deletePartialEnvelope()
            } catch (error: Throwable) {
                cleanupFailure = error
            }
        }
        if (!aliasPresentAtStart) {
            try {
                if (store.aliasExists()) store.deleteAlias()
            } catch (error: Throwable) {
                if (cleanupFailure == null) {
                    cleanupFailure = error
                } else {
                    cleanupFailure.addSuppressed(error)
                }
            }
        }

        cleanupFailure?.let {
            throw IllegalStateException("Secure wallet rollback did not complete.", it)
        }
    }
}
