package com.openclaw.plawie

import java.time.Duration
import java.time.Instant

internal data class KeeperHubSiweRequest(
    val nonce: String,
    val issuedAt: String,
    val message: String,
)

/**
 * Closed policy for KeeperHub's documented headless SIWE route.
 *
 * Dart supplies only the server nonce and current issue time. The trusted
 * domain, URI, statement, chain assertion, and wallet address are owned by
 * Android so this surface cannot become a generic personal-message signer.
 */
internal object KeeperHubSiwePolicy {
    const val BASE_URI = "https://app.keeperhub.com"
    const val DOMAIN = "app.keeperhub.com"
    const val CHAIN_ID = 1L
    private const val STATEMENT = "Sign in to KeeperHub"
    private val walletPattern = Regex("^0x[0-9a-fA-F]{40}$")
    private val noncePattern = Regex("^[A-Za-z0-9]{8,96}$")
    private val issuedAtPattern = Regex(
        "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d{1,9})?Z$",
    )

    fun parse(
        arguments: Map<*, *>?,
        walletAddress: String,
        now: Instant = Instant.now(),
    ): KeeperHubSiweRequest {
        require(arguments != null) { "KeeperHub sign-in request is missing." }
        require(arguments.keys.all { it == "nonce" || it == "issuedAt" }) {
            "KeeperHub sign-in request contains unsupported fields."
        }
        require(walletPattern.matches(walletAddress)) {
            "The secure KeeperHub identity wallet is invalid."
        }
        val nonce = arguments["nonce"]?.toString()?.trim() ?: ""
        require(noncePattern.matches(nonce)) { "KeeperHub sign-in nonce is invalid." }

        val issuedAtText = arguments["issuedAt"]?.toString()?.trim() ?: ""
        require(issuedAtPattern.matches(issuedAtText)) {
            "KeeperHub sign-in issue time is invalid."
        }
        val issuedAt = Instant.parse(issuedAtText)
        require(Duration.between(issuedAt, now).abs() <= Duration.ofMinutes(2)) {
            "KeeperHub sign-in issue time is stale."
        }

        val message = """$DOMAIN wants you to sign in with your Ethereum account:
$walletAddress

$STATEMENT

URI: $BASE_URI
Version: 1
Chain ID: $CHAIN_ID
Nonce: $nonce
Issued At: $issuedAtText"""
        return KeeperHubSiweRequest(
            nonce = nonce,
            issuedAt = issuedAtText,
            message = message,
        )
    }
}

internal data class KeeperHubKeyChallengeRequest(
    val challenge: String,
    val operation: String,
    val promptDescription: String,
)

/** Closed policy for KeeperHub's API-key create/revoke step-up action. */
internal object KeeperHubKeyChallengePolicy {
    private val challengePattern = Regex(
        "^KeeperHub action confirmation\\n\\n ?Action: org_api_key_manage" +
            "\\n ?Nonce: [0-9a-fA-F]{16,128}$",
    )

    fun parse(arguments: Map<*, *>?): KeeperHubKeyChallengeRequest {
        require(arguments != null) { "KeeperHub key challenge is missing." }
        require(arguments.keys.all { it == "challenge" || it == "operation" }) {
            "KeeperHub key challenge contains unsupported fields."
        }
        val challenge = arguments["challenge"]?.toString() ?: ""
        require(challenge.length <= 256 && challengePattern.matches(challenge)) {
            "KeeperHub key challenge is not the allowlisted action."
        }
        val operation = arguments["operation"]?.toString()?.lowercase() ?: ""
        val prompt = when (operation) {
            "create" -> "Authorize creation of one Plawie organization key"
            "revoke" -> "Authorize revocation of the Plawie organization key"
            else -> throw IllegalArgumentException(
                "KeeperHub key operation must be create or revoke.",
            )
        }
        return KeeperHubKeyChallengeRequest(
            challenge = challenge,
            operation = operation,
            promptDescription = prompt,
        )
    }
}
