package com.openclaw.plawie

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class KeeperHubMessagePolicyTest {
    private val wallet = "0x857b06519E91e3A54538791bDbb0E22373e36b66"
    private val now = Instant.parse("2026-08-10T12:00:00Z")

    @Test
    fun constructsTheDocumentedKeeperHubSiweMessageExactly() {
        val request = KeeperHubSiwePolicy.parse(
            mapOf(
                "nonce" to "AbCdEf123456",
                "issuedAt" to "2026-08-10T12:00:00.000Z",
            ),
            wallet,
            now,
        )

        assertEquals(
            """app.keeperhub.com wants you to sign in with your Ethereum account:
$wallet

Sign in to KeeperHub

URI: https://app.keeperhub.com
Version: 1
Chain ID: 1
Nonce: AbCdEf123456
Issued At: 2026-08-10T12:00:00.000Z""",
            request.message,
        )
    }

    @Test
    fun rejectsCallerControlledSiweFieldsAndStaleAssertions() {
        assertThrows(IllegalArgumentException::class.java) {
            KeeperHubSiwePolicy.parse(
                mapOf(
                    "nonce" to "AbCdEf123456",
                    "issuedAt" to "2026-08-10T12:00:00Z",
                    "domain" to "evil.example",
                ),
                wallet,
                now,
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            KeeperHubSiwePolicy.parse(
                mapOf(
                    "nonce" to "AbCdEf123456",
                    "issuedAt" to "2026-08-10T11:57:59Z",
                ),
                wallet,
                now,
            )
        }
    }

    @Test
    fun acceptsOnlyTheExactKeeperHubKeyManagementChallenge() {
        val challenge = "KeeperHub action confirmation\n\n" +
            "Action: org_api_key_manage\n" +
            "Nonce: 1a45b746114d0bdf9a5bec04335fd78b"
        val create = KeeperHubKeyChallengePolicy.parse(
            mapOf("challenge" to challenge, "operation" to "create"),
        )
        assertEquals(challenge, create.challenge)

        listOf(
            challenge.replace("org_api_key_manage", "wallet_withdraw"),
            "$challenge\nRecipient: 0x1111111111111111111111111111111111111111",
            challenge.replace("action confirmation", "payment confirmation"),
        ).forEach { invalid ->
            assertThrows(IllegalArgumentException::class.java) {
                KeeperHubKeyChallengePolicy.parse(
                    mapOf("challenge" to invalid, "operation" to "create"),
                )
            }
        }
        assertThrows(IllegalArgumentException::class.java) {
            KeeperHubKeyChallengePolicy.parse(
                mapOf("challenge" to challenge, "operation" to "execute"),
            )
        }
    }
}
