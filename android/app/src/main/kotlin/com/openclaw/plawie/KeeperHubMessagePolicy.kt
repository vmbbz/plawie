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

internal data class KeeperHubExecutionAttestationRequest(
    val intentId: String,
    val agentWalletAddress: String,
    val simulationFingerprint: String,
    val idempotencyKey: String,
    val expiresAt: String,
    val message: String,
)

/**
 * Closed local attestation for the hackathon proof transaction. It cannot
 * authorize a Mainnet transfer: only a zero-value Base Sepolia self-transfer
 * from the separately labelled KeeperHub Agent Wallet is accepted.
 */
internal object KeeperHubExecutionAttestationPolicy {
    const val BASE_SEPOLIA_CHAIN_ID = 84532L
    private val addressPattern = Regex("^0x[0-9a-fA-F]{40}$")
    private val digestPattern = Regex("^[0-9a-f]{64}$")
    private val intentPattern = Regex("^[A-Za-z0-9_-]{8,128}$")
    private val allowedKeys = setOf(
        "intentId",
        "chainId",
        "from",
        "to",
        "amount",
        "simulationFingerprint",
        "idempotencyKey",
        "expiresAt",
    )

    fun parse(
        arguments: Map<*, *>?,
        personalWalletAddress: String,
        now: Instant = Instant.now(),
    ): KeeperHubExecutionAttestationRequest {
        require(arguments != null) { "KeeperHub execution attestation is missing." }
        require(arguments.keys.all { it in allowedKeys }) {
            "KeeperHub execution attestation contains unsupported fields."
        }
        require(addressPattern.matches(personalWalletAddress)) {
            "The Personal Wallet address is invalid."
        }
        val intentId = arguments["intentId"]?.toString()?.trim() ?: ""
        require(intentPattern.matches(intentId)) { "KeeperHub intent ID is invalid." }
        val chainId = arguments["chainId"]?.toString()?.toLongOrNull()
        require(chainId == BASE_SEPOLIA_CHAIN_ID) {
            "Only the Base Sepolia proof transaction can be attested."
        }
        val from = arguments["from"]?.toString()?.trim() ?: ""
        val to = arguments["to"]?.toString()?.trim() ?: ""
        require(addressPattern.matches(from) && addressPattern.matches(to)) {
            "KeeperHub proof addresses are invalid."
        }
        require(from.equals(to, ignoreCase = true)) {
            "KeeperHub proof must be an Agent Wallet self-transfer."
        }
        val amount = arguments["amount"]?.toString()?.trim() ?: ""
        require(amount == "0") { "KeeperHub proof amount must be exactly zero." }
        val fingerprint =
            arguments["simulationFingerprint"]?.toString()?.trim() ?: ""
        val idempotencyKey = arguments["idempotencyKey"]?.toString()?.trim() ?: ""
        require(digestPattern.matches(fingerprint)) {
            "KeeperHub simulation fingerprint is invalid."
        }
        require(digestPattern.matches(idempotencyKey)) {
            "KeeperHub idempotency key is invalid."
        }
        val expiresAtText = arguments["expiresAt"]?.toString()?.trim() ?: ""
        val expiresAt = Instant.parse(expiresAtText)
        require(expiresAt.isAfter(now)) { "KeeperHub execution approval has expired." }
        require(Duration.between(now, expiresAt) <= Duration.ofMinutes(5)) {
            "KeeperHub execution approval exceeds five minutes."
        }

        val message = """Plawie KeeperHub execution approval
Version: 1
Personal Wallet: $personalWalletAddress
Agent Wallet: $from
Chain ID: $BASE_SEPOLIA_CHAIN_ID
Recipient: $to
Amount: 0 ETH
Intent ID: $intentId
Simulation SHA-256: $fingerprint
Idempotency Key: $idempotencyKey
Expires At: $expiresAtText"""
        return KeeperHubExecutionAttestationRequest(
            intentId = intentId,
            agentWalletAddress = from,
            simulationFingerprint = fingerprint,
            idempotencyKey = idempotencyKey,
            expiresAt = expiresAtText,
            message = message,
        )
    }
}

internal data class KeeperHubRevocationAuthorizationRequest(
    val keyId: String,
    val keyPrefix: String,
    val message: String,
)

/** Closed local authorization for revoking Plawie's organization credential. */
internal object KeeperHubRevocationAuthorizationPolicy {
    private val keyIdPattern = Regex("^[A-Za-z0-9_-]{4,160}$")
    private val keyPrefixPattern = Regex("^kh_[A-Za-z0-9_-]{5,29}$")

    fun parse(
        arguments: Map<*, *>?,
        personalWalletAddress: String,
    ): KeeperHubRevocationAuthorizationRequest {
        require(arguments != null) { "KeeperHub revocation request is missing." }
        require(arguments.keys.all { it == "keyId" || it == "keyPrefix" }) {
            "KeeperHub revocation request contains unsupported fields."
        }
        require(Regex("^0x[0-9a-fA-F]{40}$").matches(personalWalletAddress)) {
            "The Personal Wallet address is invalid."
        }
        val keyId = arguments["keyId"]?.toString()?.trim() ?: ""
        val keyPrefix = arguments["keyPrefix"]?.toString()?.trim() ?: ""
        require(keyIdPattern.matches(keyId)) { "KeeperHub key ID is invalid." }
        require(keyPrefixPattern.matches(keyPrefix)) {
            "KeeperHub key prefix is invalid."
        }
        val message = """Plawie KeeperHub credential revocation
Version: 1
Personal Wallet: $personalWalletAddress
Organization Key ID: $keyId
Organization Key Prefix: $keyPrefix
Action: Permanently revoke remote API access"""
        return KeeperHubRevocationAuthorizationRequest(
            keyId = keyId,
            keyPrefix = keyPrefix,
            message = message,
        )
    }
}
