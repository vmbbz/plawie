package com.openclaw.plawie

import java.math.BigInteger
import org.junit.Assert.assertEquals
import org.junit.Test
import org.web3j.utils.Numeric

class Eip3009DigestTest {
    @Test
    fun matchesIndependentEthersAndEthAccountVector() {
        val digest = Eip3009Digest.compute(
            name = "USDC",
            version = "2",
            chainId = 8453L,
            verifyingContract = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
            from = "0x857b06519E91e3A54538791bDbb0E22373e36b66",
            to = "0x209693Bc6afc0C5328bA36FaF03C514EF312287C",
            value = BigInteger("10000"),
            validAfter = BigInteger("1740672089"),
            validBefore = BigInteger("1740672154"),
            nonce = "0xf3746613c2d920b5fdabc0856f2aeb2d4f88ee6037b8cc5d04a71a4462f13480",
        )

        assertEquals(
            "0xcb6fddf88e01fd79bccb714a6cd964622528f5b47f8762d6b7aeda2148526b83",
            Numeric.toHexString(digest),
        )
    }
}
