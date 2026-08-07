package com.openclaw.plawie

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class OrdinaryEvmTransactionPolicyTest {
    @Test
    fun `Robinhood native ETH transfer is bounded and names the network`() {
        val request = OrdinaryEvmTransactionPolicy.parse(
            request(kind = "eth", chainId = 4663, value = "1000000000000000"),
        )

        assertEquals(4663L, request.chainId)
        assertEquals("eth", request.kind)
        assertTrue(OrdinaryEvmTransactionPolicy.summary(request).contains("Robinhood Chain"))
    }

    @Test
    fun `official Robinhood USDG transfer is allowed`() {
        val request = OrdinaryEvmTransactionPolicy.parse(
            request(
                kind = "usdg",
                chainId = 4663,
                to = OrdinaryEvmTransactionPolicy.USDG_ROBINHOOD,
                value = "0",
                data = transferData("0x2222222222222222222222222222222222222222", 2_500_000),
            ),
        )

        assertEquals("usdg", request.kind)
        assertTrue(OrdinaryEvmTransactionPolicy.summary(request).contains("2.5 USDG"))
    }

    @Test
    fun `Base USDC cannot be relabelled for Robinhood`() {
        assertThrows(IllegalArgumentException::class.java) {
            OrdinaryEvmTransactionPolicy.parse(
                request(
                    kind = "usdc",
                    chainId = 4663,
                    to = OrdinaryEvmTransactionPolicy.USDC_MAINNET,
                    value = "0",
                    data = transferData("0x2222222222222222222222222222222222222222", 1),
                ),
            )
        }
    }

    @Test
    fun `Robinhood USDG requires the exact contract and transfer selector`() {
        assertThrows(IllegalArgumentException::class.java) {
            OrdinaryEvmTransactionPolicy.parse(
                request(
                    kind = "usdg",
                    chainId = 4663,
                    to = "0x3333333333333333333333333333333333333333",
                    value = "0",
                    data = transferData("0x2222222222222222222222222222222222222222", 1),
                ),
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            OrdinaryEvmTransactionPolicy.parse(
                request(
                    kind = "usdg",
                    chainId = 4663,
                    to = OrdinaryEvmTransactionPolicy.USDG_ROBINHOOD,
                    value = "0",
                    data = "0xdeadbeef",
                ),
            )
        }
    }

    private fun request(
        kind: String,
        chainId: Long,
        to: String = "0x1111111111111111111111111111111111111111",
        value: String,
        data: String = "0x",
    ): Map<String, String> = mapOf(
        "kind" to kind,
        "chainId" to chainId.toString(),
        "nonce" to "0",
        "gasPrice" to "1000000000",
        "gasLimit" to "80000",
        "to" to to,
        "value" to value,
        "data" to data,
    )

    private fun transferData(recipient: String, amount: Long): String {
        val addressWord = recipient.removePrefix("0x").padStart(64, '0')
        val amountWord = amount.toString(16).padStart(64, '0')
        return "0xa9059cbb$addressWord$amountWord"
    }
}
