package com.openclaw.plawie

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class VeniceSiweMessageTest {
    private val wallet = "0x857b06519E91e3A54538791bDbb0E22373e36b66"
    private val now = Instant.parse("2026-08-06T12:00:00Z")

    @Test
    fun acceptsOnlyTheClosedVeniceProviderRouteTable() {
        val cases = listOf(
            "GET" to "https://api.venice.ai/api/v1/models",
            "POST" to "https://api.venice.ai/api/v1/chat/completions",
            "GET" to "https://api.venice.ai/api/v1/x402/balance/$wallet",
        )

        cases.forEach { (method, uri) ->
            val request = VeniceProviderIdentityPolicy.parse(
                arguments = arguments(method, uri),
                walletAddress = wallet,
                now = now,
            )
            assertEquals(method, request.method)
            assertEquals(uri, request.uri)
            assertEquals("Sign in to Venice AI", request.statement)
        }

        assertThrows(IllegalArgumentException::class.java) {
            VeniceProviderIdentityPolicy.parse(
                arguments("POST", "https://api.venice.ai/api/v1/responses"),
                wallet,
                now,
            )
        }
        val responses = VeniceProviderIdentityPolicy.parse(
            arguments("POST", "https://api.venice.ai/api/v1/responses"),
            wallet,
            now,
            responsesEnabled = true,
        )
        assertEquals("POST", responses.method)
    }

    @Test
    fun constructsTheBoundedEip4361MessageExactly() {
        assertEquals(
            """api.venice.ai wants you to sign in with your Ethereum account:
$wallet

Sign in to Venice AI

URI: https://api.venice.ai/api/v1/chat/completions
Version: 1
Chain ID: 8453
Nonce: AbCdEf123456
Issued At: 2026-08-06T12:00:00Z
Expiration Time: 2026-08-06T12:05:00Z""",
            VeniceSiweMessage.build(
                address = wallet,
                statement = "Sign in to Venice AI",
                uri = "https://api.venice.ai/api/v1/chat/completions",
                nonce = "AbCdEf123456",
                issuedAt = "2026-08-06T12:00:00Z",
                expirationTime = "2026-08-06T12:05:00Z",
            ),
        )
    }

    @Test
    fun rejectsUntrustedOriginsMethodsAndPaths() {
        val invalid = listOf(
            "GET" to "http://api.venice.ai/api/v1/models",
            "GET" to "https://evil.api.venice.ai/api/v1/models",
            "GET" to "https://api.venice.ai.evil.example/api/v1/models",
            "GET" to "https://user@api.venice.ai/api/v1/models",
            "GET" to "https://api.venice.ai:444/api/v1/models",
            "GET" to "https://api.venice.ai/api/v1/models?type=text",
            "GET" to "https://api.venice.ai/api/v1/models#fragment",
            "GET" to "https://api.venice.ai/api/v1/models/extra",
            "POST" to "https://api.venice.ai/api/v1/models",
            "GET" to "https://api.venice.ai/api/v1/chat/completions",
            "PUT" to "https://api.venice.ai/api/v1/chat/completions",
            "GET" to
                "https://api.venice.ai/api/v1/x402/balance/0x1111111111111111111111111111111111111111",
        )

        invalid.forEach { (method, uri) ->
            assertThrows("$method $uri", IllegalArgumentException::class.java) {
                VeniceProviderIdentityPolicy.parse(
                    arguments(method, uri),
                    wallet,
                    now,
                )
            }
        }
    }

    @Test
    fun rejectsInvalidNonceAndTimeWindows() {
        listOf("short", "bad-nonce!", "a".repeat(65)).forEach { nonce ->
            assertThrows(IllegalArgumentException::class.java) {
                VeniceProviderIdentityPolicy.parse(
                    arguments(
                        "GET",
                        "https://api.venice.ai/api/v1/models",
                        nonce = nonce,
                    ),
                    wallet,
                    now,
                )
            }
        }

        val invalidTimes = listOf(
            "2026-08-06T11:58:59Z" to "2026-08-06T12:03:59Z",
            "2026-08-06T12:01:01Z" to "2026-08-06T12:05:00Z",
            "2026-08-06T12:00:00Z" to "2026-08-06T12:05:01Z",
            "2026-08-06T12:00:00Z" to "2026-08-06T12:00:00Z",
        )
        invalidTimes.forEach { (issuedAt, expirationTime) ->
            assertThrows(IllegalArgumentException::class.java) {
                VeniceProviderIdentityPolicy.parse(
                    arguments(
                        "GET",
                        "https://api.venice.ai/api/v1/models",
                        issuedAt = issuedAt,
                        expirationTime = expirationTime,
                    ),
                    wallet,
                    now,
                )
            }
        }
    }

    private fun arguments(
        method: String,
        uri: String,
        nonce: String = "AbCdEf123456",
        issuedAt: String = "2026-08-06T12:00:00Z",
        expirationTime: String = "2026-08-06T12:05:00Z",
    ): Map<String, String> = mapOf(
        "method" to method,
        "uri" to uri,
        "nonce" to nonce,
        "issuedAt" to issuedAt,
        "expirationTime" to expirationTime,
    )
}
