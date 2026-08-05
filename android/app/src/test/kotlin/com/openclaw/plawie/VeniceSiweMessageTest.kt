package com.openclaw.plawie

import org.junit.Assert.assertEquals
import org.junit.Test

class VeniceSiweMessageTest {
    @Test
    fun constructsTheBoundedEip4361MessageExactly() {
        assertEquals(
            """api.venice.ai wants you to sign in with your Ethereum account:
0x857b06519E91e3A54538791bDbb0E22373e36b66

Sign in to Venice AI

URI: https://api.venice.ai/api/v1/x402/balance/0x857b06519E91e3A54538791bDbb0E22373e36b66
Version: 1
Chain ID: 8453
Nonce: AbCdEf123456
Issued At: 2026-08-05T12:00:00Z
Expiration Time: 2026-08-05T12:05:00Z""",
            VeniceSiweMessage.build(
                address = "0x857b06519E91e3A54538791bDbb0E22373e36b66",
                uri = "https://api.venice.ai/api/v1/x402/balance/0x857b06519E91e3A54538791bDbb0E22373e36b66",
                nonce = "AbCdEf123456",
                issuedAt = "2026-08-05T12:00:00Z",
                expirationTime = "2026-08-05T12:05:00Z",
            ),
        )
    }
}
