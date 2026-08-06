package com.openclaw.plawie

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class SecureEvmWalletTransactionTest {
    @Test
    fun `authentication cancellation removes artifacts created by the attempt`() {
        val store = FakeWalletCommitStore()
        val transaction = SecureEvmWalletTransaction(store)

        store.aliasPresent = true
        transaction.rollback()

        assertFalse(store.aliasPresent)
        assertFalse(store.envelopePresent)
        assertEquals(1, store.aliasDeleteCount)
        assertEquals(1, store.partialEnvelopeDeleteCount)
    }

    @Test
    fun `write failure removes a newly created alias and partial envelope`() {
        val store = FakeWalletCommitStore().apply { writeFailure = IllegalStateException("disk full") }
        val transaction = SecureEvmWalletTransaction(store)
        store.aliasPresent = true

        assertThrows(IllegalStateException::class.java) {
            transaction.commit(record())
        }

        assertFalse(store.aliasPresent)
        assertFalse(store.envelopePresent)
        assertEquals(1, store.aliasDeleteCount)
        assertEquals(1, store.partialEnvelopeDeleteCount)
    }

    @Test
    fun `rollback never deletes a pre-existing alias`() {
        val store = FakeWalletCommitStore(aliasPresent = true)
        val transaction = SecureEvmWalletTransaction(store)

        transaction.rollback()

        assertTrue(store.aliasPresent)
        assertEquals(0, store.aliasDeleteCount)
        assertEquals(1, store.partialEnvelopeDeleteCount)
    }

    @Test
    fun `read-back mismatch fails closed and rolls back`() {
        val store = FakeWalletCommitStore().apply {
            readOverride = record(address = "0x2222222222222222222222222222222222222222")
        }
        val transaction = SecureEvmWalletTransaction(store)
        store.aliasPresent = true

        val error = assertThrows(IllegalStateException::class.java) {
            transaction.commit(record())
        }

        assertTrue(error.message!!.contains("verification", ignoreCase = true))
        assertFalse(store.aliasPresent)
        assertFalse(store.envelopePresent)
    }

    @Test
    fun `verified commit is preserved if later cleanup is requested`() {
        val store = FakeWalletCommitStore()
        val transaction = SecureEvmWalletTransaction(store)
        store.aliasPresent = true
        val expected = record()

        transaction.commit(expected)
        transaction.rollback()

        assertTrue(store.aliasPresent)
        assertTrue(store.envelopePresent)
        assertEquals(0, store.aliasDeleteCount)
        assertEquals(0, store.partialEnvelopeDeleteCount)
        assertArrayEquals(expected.ciphertext, store.record!!.ciphertext)
    }

    @Test
    fun `failed cryptographic verification can abort only this committed attempt`() {
        val store = FakeWalletCommitStore()
        val transaction = SecureEvmWalletTransaction(store)
        store.aliasPresent = true
        transaction.commit(record())

        transaction.abortCommittedAttempt()

        assertFalse(store.aliasPresent)
        assertFalse(store.envelopePresent)
        assertEquals(1, store.aliasDeleteCount)
        assertEquals(1, store.partialEnvelopeDeleteCount)
    }

    @Test
    fun `damaged and orphaned states never permit ordinary creation`() {
        val rejected = listOf(
            SecureEvmWalletState.ENVELOPE_CORRUPT,
            SecureEvmWalletState.KEY_MISSING,
            SecureEvmWalletState.KEY_INVALIDATED,
            SecureEvmWalletState.ORPHANED_ALIAS,
            SecureEvmWalletState.AUTHENTICATION_UNAVAILABLE,
            SecureEvmWalletState.OPERATION_BUSY,
            SecureEvmWalletState.HEALTHY,
        )

        rejected.forEach { state ->
            assertFalse(state.wireName, state.canCreate)
            assertTrue(state.wireName, state.createErrorCode.isNotBlank())
        }
        assertTrue(SecureEvmWalletState.ABSENT.canCreate)
    }

    private fun record(
        address: String = "0x1111111111111111111111111111111111111111",
    ) = WalletEnvelopeRecord(
        version = 1,
        address = address,
        iv = ByteArray(12) { it.toByte() },
        ciphertext = ByteArray(48) { (it + 1).toByte() },
    )

    private class FakeWalletCommitStore(
        var aliasPresent: Boolean = false,
        var envelopePresent: Boolean = false,
    ) : WalletCommitStore {
        var record: WalletEnvelopeRecord? = null
        var readOverride: WalletEnvelopeRecord? = null
        var writeFailure: RuntimeException? = null
        var aliasDeleteCount = 0
        var partialEnvelopeDeleteCount = 0

        override fun aliasExists(): Boolean = aliasPresent

        override fun deleteAlias() {
            aliasDeleteCount += 1
            aliasPresent = false
        }

        override fun envelopeExists(): Boolean = envelopePresent

        override fun writeEnvelope(envelope: WalletEnvelopeRecord) {
            envelopePresent = true
            record = envelope
            writeFailure?.let { throw it }
        }

        override fun readEnvelope(): WalletEnvelopeRecord =
            readOverride ?: record ?: error("No envelope")

        override fun deletePartialEnvelope() {
            partialEnvelopeDeleteCount += 1
            envelopePresent = false
            record = null
        }
    }
}
