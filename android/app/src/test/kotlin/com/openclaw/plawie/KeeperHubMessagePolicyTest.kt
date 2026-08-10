package com.openclaw.plawie

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
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

    @Test
    fun attestsOnlyTheZeroValueBaseSepoliaSelfTransfer() {
        val arguments = mapOf(
            "intentId" to "intent_12345678",
            "chainId" to "84532",
            "from" to "0x2222222222222222222222222222222222222222",
            "to" to "0x2222222222222222222222222222222222222222",
            "amount" to "0",
            "simulationFingerprint" to "a".repeat(64),
            "idempotencyKey" to "b".repeat(64),
            "expiresAt" to "2026-08-10T12:05:00Z",
        )
        val request = KeeperHubExecutionAttestationPolicy.parse(
            arguments,
            wallet,
            now,
        )
        assertEquals("intent_12345678", request.intentId)
        assertEquals("a".repeat(64), request.simulationFingerprint)
        assertEquals("b".repeat(64), request.idempotencyKey)
        assertTrue(request.message.contains("Amount: 0 ETH"))

        listOf(
            arguments + ("chainId" to "8453"),
            arguments + ("amount" to "0.000001"),
            arguments + ("to" to "0x3333333333333333333333333333333333333333"),
            arguments + ("contractAddress" to wallet),
        ).forEach { invalid ->
            assertThrows(IllegalArgumentException::class.java) {
                KeeperHubExecutionAttestationPolicy.parse(invalid, wallet, now)
            }
        }
    }
}
