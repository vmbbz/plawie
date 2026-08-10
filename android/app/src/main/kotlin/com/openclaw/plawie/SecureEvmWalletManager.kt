package com.openclaw.plawie

import android.app.Activity
import android.app.AlertDialog
import android.app.KeyguardManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import android.util.AtomicFile
import android.util.Base64
import android.util.Log
import android.widget.ScrollView
import android.widget.TextView
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.math.BigInteger
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.net.URI
import java.time.Duration
import java.time.Instant
import java.util.Arrays
import java.util.Locale
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import org.json.JSONObject
import org.web3j.crypto.Credentials
import org.web3j.crypto.ECKeyPair
import org.web3j.crypto.Hash
import org.web3j.crypto.Keys
import org.web3j.crypto.RawTransaction
import org.web3j.crypto.Sign
import org.web3j.crypto.TransactionEncoder
import org.web3j.utils.Numeric

/**
 * Device-authenticated EVM signer for the app-owned multi-network wallet.
 *
 * Android Keystore does not expose secp256k1 keys, so the EVM key is wrapped
 * with a non-exportable AES-256-GCM Keystore key. Every unwrap is tied to a
 * system biometric/device-credential prompt. Only bounded transaction and
 * EIP-3009 operations are exposed; there is deliberately no generic digest
 * signing MethodChannel.
 */
class SecureEvmWalletManager(private val activity: Activity) {
    companion object {
        private const val TAG = "SecureEvmWallet"
        private const val KEY_ALIAS = "plawie_base_evm_envelope_v1"
        private const val ENVELOPE_VERSION = 1
        private const val ENVELOPE_FILE = "base_evm_wallet_v1.json"
        private const val MAX_X402_USDC_UNITS = 5_000_000L
        private const val MAX_X402_WINDOW_SECONDS = 300L
        private val X402_HOSTS = setOf("api.venice.ai", "blockrun.ai")
        private val HEX_ADDRESS = Regex("^0x[0-9a-fA-F]{40}$")
        private val HEX_BYTES32 = Regex("^0x[0-9a-fA-F]{64}$")
        private val operationActive = AtomicBoolean(false)
    }

    private val executor: Executor = activity.mainExecutor
    private val envelopeFile = AtomicFile(File(activity.noBackupFilesDir, ENVELOPE_FILE))
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private val walletCommitStore = object : WalletCommitStore {
        override fun aliasExists(): Boolean = keyStore.containsAlias(KEY_ALIAS)

        override fun deleteAlias() {
            if (keyStore.containsAlias(KEY_ALIAS)) keyStore.deleteEntry(KEY_ALIAS)
        }

        override fun envelopeExists(): Boolean = envelopeFile.baseFile.exists()

        override fun writeEnvelope(envelope: WalletEnvelopeRecord) {
            this@SecureEvmWalletManager.writeEnvelope(envelope)
        }

        override fun readEnvelope(): WalletEnvelopeRecord =
            readEnvelopeOrNull() ?: throw IllegalStateException(
                "The committed wallet envelope could not be read back.",
            )

        override fun deletePartialEnvelope() {
            envelopeFile.delete()
        }
    }

    fun status(): Map<String, Any> {
        val snapshot = walletStateSnapshot()
        val envelopePresent = snapshot.envelopePresent
        val envelope = snapshot.envelope
        val auth = snapshot.authentication
        val keyProbe = snapshot.keyProbe
        val state = snapshot.state
        val securityLevel = snapshot.securityLevel
        Log.i(
            TAG,
            "status state=${state.wireName} envelopePresent=$envelopePresent " +
                "aliasPresent=${keyProbe.aliasPresent} securityLevel=$securityLevel " +
                "errorCode=${state.errorCode}",
        )
        return mapOf(
            "exists" to (envelope != null),
            "address" to (envelope?.address ?: ""),
            "envelopeIntegrity" to if (envelopePresent && envelope == null) {
                "corrupt"
            } else if (envelope != null) {
                "verified"
            } else {
                "absent"
            },
            "securityLevel" to securityLevel,
            "hardwareBacked" to isHardwareSecurityLevel(securityLevel),
            "authenticationAvailable" to auth.first,
            "authenticationMode" to auth.second,
            "privateKeyLeavesAndroid" to false,
            "genericSigningAvailable" to false,
            "state" to state.wireName,
            "errorCode" to state.errorCode,
            "canCreate" to state.canCreate,
            "canRestore" to state.canRestore,
            "requiresDestructiveRecovery" to state.requiresDestructiveRecovery,
        )
    }

    private fun walletStateSnapshot(
        operationInProgress: Boolean = operationActive.get(),
    ): WalletStateSnapshot {
        val envelopePresent = envelopeFile.baseFile.exists()
        val envelope = readEnvelopeOrNull()
        val auth = authenticationStatus()
        val keyProbe = probeEnvelopeKey(envelope, envelopePresent)
        val state = SecureEvmWalletStateClassifier.classify(
            WalletStorageFacts(
                envelopePresent = envelopePresent,
                envelopeParseable = envelope != null,
                keyAliasPresent = keyProbe.aliasPresent,
                keyInvalidated = keyProbe.invalidated,
                authenticationAvailable = auth.first,
                operationActive = operationInProgress,
            ),
        )
        val securityLevel = keySecurityLevel()
        return WalletStateSnapshot(
            envelopePresent = envelopePresent,
            envelope = envelope,
            authentication = auth,
            keyProbe = keyProbe,
            state = state,
            securityLevel = securityLevel,
        )
    }

    fun createWallet(result: MethodChannel.Result) {
        val state = walletStateSnapshot().state
        if (!state.canCreate) {
            result.error(state.createErrorCode, createBlockedMessage(state), null)
            return
        }
        val pair = Keys.createEcKeyPair()
        val privateKey = Numeric.toBytesPadded(pair.privateKey, 32)
        val address = Keys.toChecksumAddress("0x${Keys.getAddress(pair)}")
        encryptAndStore(privateKey, address, "Create wallet", result)
    }

    fun importWallet(privateKey: ByteArray?, result: MethodChannel.Result) {
        val state = walletStateSnapshot().state
        if (!state.canCreate) {
            privateKey?.let { Arrays.fill(it, 0) }
            result.error(state.createErrorCode, createBlockedMessage(state), null)
            return
        }
        if (privateKey == null || privateKey.size != 32) {
            privateKey?.let { Arrays.fill(it, 0) }
            result.error("INVALID_PRIVATE_KEY", "The private key must be exactly 32 bytes.", null)
            return
        }
        try {
            val value = BigInteger(1, privateKey)
            if (value == BigInteger.ZERO || value >= Sign.CURVE_PARAMS.n) {
                throw IllegalArgumentException("Private key is outside the secp256k1 range.")
            }
            val pair = ECKeyPair.create(value)
            val address = Keys.toChecksumAddress("0x${Keys.getAddress(pair)}")
            encryptAndStore(privateKey, address, "Secure imported wallet", result)
        } catch (error: Exception) {
            Arrays.fill(privateKey, 0)
            result.error("INVALID_PRIVATE_KEY", safeMessage(error), null)
        }
    }

    fun signTransaction(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val envelope = requireEnvelope(result) ?: return
        try {
            val request = OrdinaryEvmTransactionPolicy.parse(arguments)
            val summary = OrdinaryEvmTransactionPolicy.summary(request)
            withDecryptedKey(
                envelope = envelope,
                title = "Approve wallet transaction",
                description = summary,
                result = result,
            ) { privateKey ->
                val pair = ECKeyPair.create(BigInteger(1, privateKey))
                val credentials = Credentials.create(pair)
                require(credentials.address.equals(envelope.address, ignoreCase = true)) {
                    "Wallet address integrity check failed."
                }
                val raw = RawTransaction.createTransaction(
                    request.nonce,
                    request.gasPrice,
                    request.gasLimit,
                    request.to,
                    request.value,
                    request.data,
                )
                val signed = TransactionEncoder.signMessage(raw, request.chainId, credentials)
                Numeric.toHexString(signed)
            }
        } catch (error: Exception) {
            result.error("TRANSACTION_POLICY_ERROR", safeMessage(error), null)
        }
    }

    fun signX402Authorization(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val envelope = requireEnvelope(result) ?: return
        try {
            val securityLevel = keySecurityLevel()
            require(isHardwareSecurityLevel(securityLevel)) {
                "x402 signing requires a hardware-backed Android Keystore key; this device reports $securityLevel."
            }
            val request = parseX402Authorization(arguments, envelope.address)
            val amount = formatUnits(request.value, 6)
            val summary = "Pay $amount USDC to ${shortAddress(request.to)} via ${request.host}"
            withDecryptedKey(
                envelope = envelope,
                title = "Approve AI payment",
                description = summary,
                result = result,
            ) { privateKey ->
                val pair = ECKeyPair.create(BigInteger(1, privateKey))
                val digest = eip3009Digest(request)
                val signature = Sign.signMessage(digest, pair, false)
                val signatureBytes = ByteArray(65)
                System.arraycopy(signature.r, 0, signatureBytes, 0, 32)
                System.arraycopy(signature.s, 0, signatureBytes, 32, 32)
                signatureBytes[64] = signature.v[0]

                val recovered = Sign.signedMessageHashToKey(digest, signature)
                val recoveredAddress = Keys.toChecksumAddress(
                    "0x${Keys.getAddress(recovered)}",
                )
                require(recoveredAddress.equals(envelope.address, ignoreCase = true)) {
                    "x402 signature self-verification failed."
                }
                mapOf(
                    "signature" to Numeric.toHexString(signatureBytes),
                    "payer" to envelope.address,
                    "digest" to Numeric.toHexString(digest),
                )
            }
        } catch (error: Exception) {
            result.error("X402_POLICY_ERROR", safeMessage(error), null)
        }
    }

    /**
     * Signs only closed-table Venice provider identity routes. This is
     * intentionally not a generic personal-message signer and cannot authorize
     * a transfer, caller-provided statement, or arbitrary provider resource.
     */
    fun signVeniceProviderIdentity(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val envelope = requireEnvelope(result) ?: return
        try {
            val request = VeniceProviderIdentityPolicy.parse(arguments, envelope.address)
            val message = VeniceSiweMessage.build(
                address = envelope.address,
                statement = request.statement,
                uri = request.uri,
                nonce = request.nonce,
                issuedAt = request.issuedAt,
                expirationTime = request.expirationTime,
            )
            withDecryptedKey(
                envelope = envelope,
                title = "Sign in to Venice",
                description = request.promptDescription,
                result = result,
            ) { privateKey ->
                val pair = ECKeyPair.create(BigInteger(1, privateKey))
                val bytes = message.toByteArray(StandardCharsets.UTF_8)
                val signature = Sign.signPrefixedMessage(bytes, pair)
                val signatureBytes = ByteArray(65)
                System.arraycopy(signature.r, 0, signatureBytes, 0, 32)
                System.arraycopy(signature.s, 0, signatureBytes, 32, 32)
                signatureBytes[64] = signature.v[0]
                val recovered = Sign.signedPrefixedMessageToKey(bytes, signature)
                val recoveredAddress = Keys.toChecksumAddress("0x${Keys.getAddress(recovered)}")
                require(recoveredAddress.equals(envelope.address, ignoreCase = true)) {
                    "Venice identity signature self-verification failed."
                }
                mapOf(
                    "signature" to Numeric.toHexString(signatureBytes),
                    "payer" to envelope.address,
                    "message" to message,
                )
            }
        } catch (error: Exception) {
            result.error("VENICE_IDENTITY_POLICY_ERROR", safeMessage(error), null)
        }
    }

    /** Compatibility wrapper retained for the existing balance service. */
    fun signVeniceBalanceIdentity(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val compatible = arguments?.toMutableMap() ?: run {
            signVeniceProviderIdentity(null, result)
            return
        }
        compatible["method"] = "GET"
        signVeniceProviderIdentity(compatible, result)
    }

    /**
     * Signs only KeeperHub's fixed EIP-4361 login assertion. The caller cannot
     * choose the domain, URI, statement, chain assertion, or wallet address.
     */
    fun signKeeperHubSiwe(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val envelope = requireEnvelope(result) ?: return
        try {
            val request = KeeperHubSiwePolicy.parse(arguments, envelope.address)
            withDecryptedKey(
                envelope = envelope,
                title = "Connect Agent Wallet",
                description = "Sign in to KeeperHub with your Personal Wallet",
                result = result,
            ) { privateKey ->
                signAndVerifyPrefixedMessage(
                    message = request.message,
                    privateKey = privateKey,
                    expectedAddress = envelope.address,
                    purpose = "KeeperHub sign-in",
                )
            }
        } catch (error: Exception) {
            result.error("KEEPERHUB_SIWE_POLICY_ERROR", safeMessage(error), null)
        }
    }

    /** Signs only the documented org_api_key_manage step-up challenge. */
    fun signKeeperHubKeyChallenge(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val envelope = requireEnvelope(result) ?: return
        try {
            val request = KeeperHubKeyChallengePolicy.parse(arguments)
            withDecryptedKey(
                envelope = envelope,
                title = if (request.operation == "create") {
                    "Create Agent Wallet access"
                } else {
                    "Revoke Agent Wallet access"
                },
                description = request.promptDescription,
                result = result,
            ) { privateKey ->
                signAndVerifyPrefixedMessage(
                    message = request.challenge,
                    privateKey = privateKey,
                    expectedAddress = envelope.address,
                    purpose = "KeeperHub key authorization",
                )
            }
        } catch (error: Exception) {
            result.error("KEEPERHUB_KEY_POLICY_ERROR", safeMessage(error), null)
        }
    }

    /** Device-authenticated local approval proof for one zero-value testnet run. */
    fun attestKeeperHubExecution(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val envelope = requireEnvelope(result) ?: return
        try {
            val request = KeeperHubExecutionAttestationPolicy.parse(
                arguments,
                envelope.address,
            )
            withDecryptedKey(
                envelope = envelope,
                title = "Authorize Agent Wallet proof",
                description = "Approve 0 ETH self-transfer on Base Sepolia",
                result = result,
            ) { privateKey ->
                val signed = signAndVerifyPrefixedMessage(
                    message = request.message,
                    privateKey = privateKey,
                    expectedAddress = envelope.address,
                    purpose = "KeeperHub execution approval",
                ).toMutableMap()
                signed["attestationDigest"] = Numeric.toHexString(
                    Hash.sha3(request.message.toByteArray(StandardCharsets.UTF_8)),
                )
                signed["intentId"] = request.intentId
                signed["simulationFingerprint"] = request.simulationFingerprint
                signed["idempotencyKey"] = request.idempotencyKey
                signed
            }
        } catch (error: Exception) {
            result.error("KEEPERHUB_EXECUTION_POLICY_ERROR", safeMessage(error), null)
        }
    }

    private fun signAndVerifyPrefixedMessage(
        message: String,
        privateKey: ByteArray,
        expectedAddress: String,
        purpose: String,
    ): Map<String, String> {
        val pair = ECKeyPair.create(BigInteger(1, privateKey))
        val bytes = message.toByteArray(StandardCharsets.UTF_8)
        val signature = Sign.signPrefixedMessage(bytes, pair)
        val signatureBytes = ByteArray(65)
        System.arraycopy(signature.r, 0, signatureBytes, 0, 32)
        System.arraycopy(signature.s, 0, signatureBytes, 32, 32)
        signatureBytes[64] = signature.v[0]
        val recovered = Sign.signedPrefixedMessageToKey(bytes, signature)
        val recoveredAddress = Keys.toChecksumAddress("0x${Keys.getAddress(recovered)}")
        require(recoveredAddress.equals(expectedAddress, ignoreCase = true)) {
            "$purpose signature self-verification failed."
        }
        return mapOf(
            "signature" to Numeric.toHexString(signatureBytes),
            "walletAddress" to expectedAddress,
            "message" to message,
        )
    }

    fun showPrivateKeyBackup(result: MethodChannel.Result) {
        val envelope = requireEnvelope(result) ?: return
        withDecryptedKey(
            envelope = envelope,
            title = "Unlock private-key backup",
            description = "Only reveal this key in a private place",
            result = result,
            completeResult = false,
        ) { privateKey ->
            val hex = Numeric.toHexStringNoPrefix(privateKey)
            showBackupDialog(hex, result)
            Unit
        }
    }

    fun deleteWallet(result: MethodChannel.Result) {
        val envelope = requireEnvelope(result) ?: return
        withDecryptedKey(
            envelope = envelope,
            title = "Remove Plawie wallet",
            description = "Authenticate to permanently remove this wallet from the device",
            result = result,
        ) {
            deleteEnvelopeAndKey()
            true
        }
    }

    private fun encryptAndStore(
        privateKey: ByteArray,
        address: String,
        title: String,
        result: MethodChannel.Result,
    ) {
        if (!beginOperation(result)) {
            Arrays.fill(privateKey, 0)
            return
        }
        val transaction = try {
            SecureEvmWalletTransaction(walletCommitStore)
        } catch (error: Exception) {
            Arrays.fill(privateKey, 0)
            endOperation()
            result.error("WALLET_STATE_CHANGED", safeMessage(error), null)
            return
        }
        val completed = AtomicBoolean(false)

        fun finishError(
            code: String,
            message: String,
            abortCommittedAttempt: Boolean = false,
        ) {
            if (!completed.compareAndSet(false, true)) return
            if (abortCommittedAttempt) {
                try {
                    transaction.abortCommittedAttempt()
                } catch (_: Throwable) {
                    Log.e(TAG, "Secure wallet verification cleanup failed; recovery remains explicit")
                }
            } else {
                rollbackWalletTransaction(transaction)
            }
            Arrays.fill(privateKey, 0)
            endOperation()
            result.error(code, message.take(240), null)
        }

        fun finishSuccess(verificationPending: Boolean) {
            if (!completed.compareAndSet(false, true)) return
            Arrays.fill(privateKey, 0)
            endOperation()
            try {
                val response = status().toMutableMap()
                response["verificationPending"] = verificationPending
                response["verificationCode"] = if (verificationPending) {
                    "WALLET_CREATED_VERIFICATION_PENDING"
                } else {
                    ""
                }
                result.success(response)
            } catch (error: Exception) {
                result.error("WALLET_STATUS_ERROR", safeMessage(error), null)
            }
        }

        try {
            ensureAuthenticationAvailable()
            val secretKey = getOrCreateEnvelopeKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            requestAuthenticatedCipher(
                cipher = cipher,
                title = title,
                description = "Protect $address with your device lock",
                onSuccess = { authenticatedCipher ->
                    try {
                        val encrypted = authenticatedCipher.doFinal(privateKey)
                        val envelope = WalletEnvelopeRecord(
                            version = ENVELOPE_VERSION,
                            address = address,
                            iv = authenticatedCipher.iv,
                            ciphertext = encrypted,
                        )
                        transaction.commit(envelope)

                        val pair = ECKeyPair.create(BigInteger(1, privateKey))
                        val derivedAddress = Keys.toChecksumAddress("0x${Keys.getAddress(pair)}")
                        require(derivedAddress == address) {
                            "The in-memory wallet identity changed before commit."
                        }
                        Arrays.fill(privateKey, 0)

                        val committedKey = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
                            ?: throw IllegalStateException(
                                "The committed wallet protection key is missing.",
                            )
                        val verificationCipher = Cipher.getInstance("AES/GCM/NoPadding")
                        verificationCipher.init(
                            Cipher.DECRYPT_MODE,
                            committedKey,
                            GCMParameterSpec(128, envelope.iv),
                        )
                        try {
                            requestAuthenticatedCipher(
                                cipher = verificationCipher,
                                title = "Verify protected wallet",
                                description = "Confirm $address can be unlocked on this device",
                                onSuccess = { authenticatedVerificationCipher ->
                                    var decryptedKey: ByteArray? = null
                                    try {
                                        decryptedKey = authenticatedVerificationCipher.doFinal(
                                            envelope.ciphertext,
                                        )
                                        require(decryptedKey.size == 32) {
                                            "The committed wallet envelope is invalid."
                                        }
                                        val verifiedPair = ECKeyPair.create(BigInteger(1, decryptedKey))
                                        val verifiedAddress = Keys.toChecksumAddress(
                                            "0x${Keys.getAddress(verifiedPair)}",
                                        )
                                        require(verifiedAddress == address) {
                                            "The committed wallet identity could not be verified."
                                        }
                                        finishSuccess(verificationPending = false)
                                    } catch (error: Exception) {
                                        finishError(
                                            code = "WALLET_STORE_VERIFICATION_ERROR",
                                            message = safeMessage(error),
                                            abortCommittedAttempt = true,
                                        )
                                    } finally {
                                        decryptedKey?.let { Arrays.fill(it, 0) }
                                    }
                                },
                                onError = { _, _ ->
                                    // The envelope already passed atomic read-back. A cancelled
                                    // second prompt defers, rather than destroys, verification.
                                    finishSuccess(verificationPending = true)
                                },
                            )
                        } catch (_: Exception) {
                            // Prompt presentation itself can fail during an Activity transition.
                            // Keep the verified atomic envelope and retry verification later.
                            finishSuccess(verificationPending = true)
                        }
                    } catch (error: Exception) {
                        finishError(
                            code = if (transaction.isCommitted) {
                                "WALLET_STORE_VERIFICATION_ERROR"
                            } else {
                                "WALLET_STORE_ERROR"
                            },
                            message = safeMessage(error),
                            abortCommittedAttempt = transaction.isCommitted,
                        )
                    }
                },
                onError = { code, message ->
                    finishError(code, message)
                },
            )
        } catch (error: Exception) {
            finishError("WALLET_SECURITY_ERROR", safeMessage(error))
        }
    }

    private fun <T> withDecryptedKey(
        envelope: WalletEnvelopeRecord,
        title: String,
        description: String,
        result: MethodChannel.Result,
        completeResult: Boolean = true,
        operation: (ByteArray) -> T,
    ) {
        if (!beginOperation(result)) return
        try {
            ensureAuthenticationAvailable()
            val key = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
                ?: throw IllegalStateException("The wallet protection key is missing.")
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, envelope.iv))
            authenticateCipher(
                cipher = cipher,
                title = title,
                description = description,
                result = result,
                onSuccess = { authenticatedCipher ->
                    var privateKey: ByteArray? = null
                    try {
                        privateKey = authenticatedCipher.doFinal(envelope.ciphertext)
                        require(privateKey.size == 32) { "Wallet envelope is invalid." }
                        val output = operation(privateKey)
                        if (completeResult) result.success(output)
                    } catch (error: Exception) {
                        result.error("WALLET_OPERATION_ERROR", safeMessage(error), null)
                    } finally {
                        privateKey?.let { Arrays.fill(it, 0) }
                        endOperation()
                    }
                },
                onFailure = { endOperation() },
            )
        } catch (error: KeyPermanentlyInvalidatedException) {
            endOperation()
            result.error(
                "WALLET_KEY_INVALIDATED",
                "Device security changed and invalidated the wallet key. Restore the wallet from your backup.",
                null,
            )
        } catch (error: Exception) {
            endOperation()
            result.error("WALLET_SECURITY_ERROR", safeMessage(error), null)
        }
    }

    private fun authenticateCipher(
        cipher: Cipher,
        title: String,
        description: String,
        result: MethodChannel.Result,
        onSuccess: (Cipher) -> Unit,
        onFailure: () -> Unit,
    ) {
        requestAuthenticatedCipher(
            cipher = cipher,
            title = title,
            description = description,
            onSuccess = onSuccess,
            onError = { code, message ->
                onFailure()
                result.error(code, message, null)
            },
        )
    }

    private fun requestAuthenticatedCipher(
        cipher: Cipher,
        title: String,
        description: String,
        onSuccess: (Cipher) -> Unit,
        onError: (String, String) -> Unit,
    ) {
        val finished = AtomicBoolean(false)
        fun fail(code: String, message: String) {
            if (!finished.compareAndSet(false, true)) return
            onError(code, message)
        }

        val builder = BiometricPrompt.Builder(activity)
            .setTitle(title)
            .setSubtitle(description.take(120))
            .setConfirmationRequired(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setAllowedAuthenticators(WalletAuthenticatorPolicy.biometricApiMask)
        } else {
            builder.setNegativeButton("Cancel", executor) { _, _ ->
                fail("WALLET_AUTH_CANCELLED", "Wallet authentication was cancelled.")
            }
        }

        val cancellation = CancellationSignal()
        val prompt = builder.build()
        prompt.authenticate(
            BiometricPrompt.CryptoObject(cipher),
            cancellation,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(
                    authenticationResult: BiometricPrompt.AuthenticationResult,
                ) {
                    if (!finished.compareAndSet(false, true)) return
                    val authenticated = authenticationResult.cryptoObject?.cipher
                    if (authenticated == null) {
                        onError(
                            "WALLET_AUTH_ERROR",
                            "Android did not return the authenticated cryptographic operation.",
                        )
                        return
                    }
                    onSuccess(authenticated)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    val code = when (errorCode) {
                        BiometricPrompt.BIOMETRIC_ERROR_CANCELED,
                        BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
                        -> "WALLET_AUTH_CANCELLED"
                        else -> "WALLET_AUTH_ERROR"
                    }
                    fail(code, errString.toString())
                }
            },
        )
    }

    private fun getOrCreateEnvelopeKey(): SecretKey {
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val strongBoxAvailable = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_STRONGBOX_KEYSTORE)
        if (strongBoxAvailable) {
            try {
                return generateEnvelopeKey(strongBox = true)
            } catch (_: StrongBoxUnavailableException) {
                keyStore.deleteEntry(KEY_ALIAS)
            }
        }
        return generateEnvelopeKey(strongBox = false)
    }

    private fun generateEnvelopeKey(strongBox: Boolean): SecretKey {
        val builder = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setKeySize(256)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .setUserAuthenticationRequired(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                0,
                WalletAuthenticatorPolicy.keyStoreMask,
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(-1)
            builder.setInvalidatedByBiometricEnrollment(true)
        }
        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setIsStrongBoxBacked(true)
        }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(builder.build())
        return generator.generateKey()
    }

    private fun ensureAuthenticationAvailable() {
        val status = authenticationStatus()
        require(status.first) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                "Set up a secure screen lock or Class 3 biometric before using the wallet."
            } else {
                "Android 10 requires an enrolled Class 3 biometric for payment signing."
            }
        }
    }

    private fun authenticationStatus(): Pair<Boolean, String> {
        val manager = activity.getSystemService(BiometricManager::class.java)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val mode = "strong biometric or device credential"
            try {
                Pair(
                    manager.canAuthenticate(WalletAuthenticatorPolicy.biometricApiMask) ==
                        BiometricManager.BIOMETRIC_SUCCESS,
                    mode,
                )
            } catch (error: SecurityException) {
                Log.e(TAG, "Android rejected the wallet authenticator policy", error)
                Pair(false, "$mode unavailable")
            }
        } else {
            @Suppress("DEPRECATION")
            val biometricReady = manager.canAuthenticate() == BiometricManager.BIOMETRIC_SUCCESS
            val secure = (activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager)
                .isDeviceSecure
            Pair(biometricReady && secure, "Class 3 biometric")
        }
    }

    private fun keySecurityLevel(): String {
        val key = try {
            keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        } catch (_: Exception) {
            null
        } ?: return "not-created"
        return try {
            val factory = SecretKeyFactory.getInstance(key.algorithm, "AndroidKeyStore")
            val info = factory.getKeySpec(key, KeyInfo::class.java) as KeyInfo
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                when (info.securityLevel) {
                    KeyProperties.SECURITY_LEVEL_STRONGBOX -> "StrongBox"
                    KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> "Trusted Environment"
                    KeyProperties.SECURITY_LEVEL_SOFTWARE -> "software"
                    else -> "unknown"
                }
            } else if (info.isInsideSecureHardware) {
                "secure hardware"
            } else {
                "software"
            }
        } catch (_: Exception) {
            "unknown"
        }
    }

    /**
     * Removes only the known Keystore alias when no wallet envelope exists.
     * This is deliberately separate from create/import and healthy deletion.
     */
    fun recoverOrphanedAlias(result: MethodChannel.Result) {
        val initial = walletStateSnapshot()
        if (!SecureEvmWalletRecoveryPolicy.canRemoveOrphanedAlias(initial.state)) {
            result.error(
                "WALLET_RECOVERY_NOT_ALLOWED",
                "Orphan cleanup is available only for an orphaned wallet protection record.",
                null,
            )
            return
        }
        if (!beginOperation(result)) return

        val completed = AtomicBoolean(false)
        fun finishError(code: String, message: String) {
            if (!completed.compareAndSet(false, true)) return
            endOperation()
            result.error(code, message.take(240), null)
        }
        fun finishSuccess() {
            if (!completed.compareAndSet(false, true)) return
            endOperation()
            try {
                result.success(status())
            } catch (error: Exception) {
                result.error("WALLET_STATUS_ERROR", safeMessage(error), null)
            }
        }

        try {
            AlertDialog.Builder(activity)
                .setTitle("Remove orphaned wallet protection?")
                .setMessage(
                    "Plawie found an Android Keystore protection record without a wallet. " +
                        "Removing this record cannot restore a wallet, but it allows a new " +
                        "wallet or backup to be secured on this device.",
                )
                .setNegativeButton("Cancel") { _, _ ->
                    finishError("WALLET_RECOVERY_CANCELLED", "Wallet recovery was cancelled.")
                }
                .setPositiveButton("Remove record") { _, _ ->
                    try {
                        val current = walletStateSnapshot(operationInProgress = false)
                        require(
                            SecureEvmWalletRecoveryPolicy.canRemoveOrphanedAlias(current.state),
                        ) { "Wallet storage changed; no recovery data was removed." }
                        require(!current.envelopePresent) {
                            "A wallet envelope appeared; no protection record was removed."
                        }
                        deleteKnownAlias()
                        finishSuccess()
                    } catch (error: Exception) {
                        finishError("WALLET_RECOVERY_ERROR", safeMessage(error))
                    }
                }
                .setOnCancelListener {
                    finishError("WALLET_RECOVERY_CANCELLED", "Wallet recovery was cancelled.")
                }
                .show()
        } catch (error: Exception) {
            finishError("WALLET_RECOVERY_ERROR", safeMessage(error))
        }
    }

    /**
     * Removes only an explicitly classified damaged wallet. When its Keystore
     * key can still be used, Android authentication is mandatory after the
     * destructive warning. Missing/invalidated keys cannot be authenticated.
     */
    fun removeDamagedWallet(result: MethodChannel.Result) {
        val initial = walletStateSnapshot()
        if (!SecureEvmWalletRecoveryPolicy.canRemoveDamagedWallet(initial.state)) {
            result.error(
                "WALLET_RECOVERY_NOT_ALLOWED",
                "Damaged-wallet removal is available only for a classified recovery state.",
                null,
            )
            return
        }
        if (!beginOperation(result)) return

        val completed = AtomicBoolean(false)
        fun finishError(code: String, message: String) {
            if (!completed.compareAndSet(false, true)) return
            endOperation()
            result.error(code, message.take(240), null)
        }
        fun finishSuccess() {
            if (!completed.compareAndSet(false, true)) return
            endOperation()
            try {
                result.success(status())
            } catch (error: Exception) {
                result.error("WALLET_STATUS_ERROR", safeMessage(error), null)
            }
        }
        fun removeConfirmedArtifacts() {
            try {
                deleteEnvelopeAndKey()
                finishSuccess()
            } catch (error: Exception) {
                finishError("WALLET_RECOVERY_ERROR", safeMessage(error))
            }
        }
        fun authenticateThenRemove(snapshot: WalletStateSnapshot) {
            if (!SecureEvmWalletRecoveryPolicy.requiresAuthentication(
                    aliasPresent = snapshot.keyProbe.aliasPresent,
                    keyInvalidated = snapshot.keyProbe.invalidated,
                )
            ) {
                removeConfirmedArtifacts()
                return
            }
            try {
                ensureAuthenticationAvailable()
                val key = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
                if (key == null) {
                    // The alias became unusable after the warning. It cannot be
                    // authenticated, and the bounded recovery state remains valid.
                    removeConfirmedArtifacts()
                    return
                }
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.ENCRYPT_MODE, key)
                requestAuthenticatedCipher(
                    cipher = cipher,
                    title = "Remove damaged Plawie wallet",
                    description = "Authenticate to permanently remove the unusable wallet record",
                    onSuccess = { authenticatedCipher ->
                        try {
                            authenticatedCipher.doFinal(ByteArray(0))
                            removeConfirmedArtifacts()
                        } catch (error: Exception) {
                            finishError("WALLET_RECOVERY_ERROR", safeMessage(error))
                        }
                    },
                    onError = { code, message -> finishError(code, message) },
                )
            } catch (_: KeyPermanentlyInvalidatedException) {
                // Android cannot authenticate an invalidated key. The explicit
                // destructive warning is the final available approval boundary.
                removeConfirmedArtifacts()
            } catch (error: Exception) {
                finishError("WALLET_RECOVERY_ERROR", safeMessage(error))
            }
        }

        try {
            AlertDialog.Builder(activity)
                .setTitle("Remove damaged Plawie wallet?")
                .setMessage(
                    "This permanently removes the unusable encrypted wallet record from this " +
                        "device. It does not recover funds. Continue only if you have the private " +
                        "key backup needed to restore this wallet.",
                )
                .setNegativeButton("Cancel") { _, _ ->
                    finishError("WALLET_RECOVERY_CANCELLED", "Wallet recovery was cancelled.")
                }
                .setPositiveButton("Remove damaged wallet") { _, _ ->
                    try {
                        val current = walletStateSnapshot(operationInProgress = false)
                        require(
                            SecureEvmWalletRecoveryPolicy.canRemoveDamagedWallet(current.state),
                        ) { "Wallet storage changed; no recovery data was removed." }
                        authenticateThenRemove(current)
                    } catch (error: Exception) {
                        finishError("WALLET_RECOVERY_ERROR", safeMessage(error))
                    }
                }
                .setOnCancelListener {
                    finishError("WALLET_RECOVERY_CANCELLED", "Wallet recovery was cancelled.")
                }
                .show()
        } catch (error: Exception) {
            finishError("WALLET_RECOVERY_ERROR", safeMessage(error))
        }
    }

    private fun createBlockedMessage(state: SecureEvmWalletState): String = when (state) {
        SecureEvmWalletState.HEALTHY ->
            "A secure wallet already exists. Remove it before importing another wallet."
        SecureEvmWalletState.AUTHENTICATION_UNAVAILABLE ->
            "Set up a supported device lock before creating or importing a wallet."
        SecureEvmWalletState.ENVELOPE_CORRUPT ->
            "The wallet envelope is damaged. Restore or remove it through explicit recovery."
        SecureEvmWalletState.KEY_MISSING ->
            "The wallet protection key is missing. Restore or remove the damaged wallet explicitly."
        SecureEvmWalletState.KEY_INVALIDATED ->
            "Device security invalidated the wallet key. Restore the wallet from backup."
        SecureEvmWalletState.ORPHANED_ALIAS ->
            "An orphaned wallet protection record must be removed through explicit recovery first."
        SecureEvmWalletState.OPERATION_BUSY ->
            "Another wallet authentication is already active."
        SecureEvmWalletState.ABSENT ->
            "Wallet creation is available."
    }

    /**
     * Checks whether the known envelope key can be initialized without
     * decrypting wallet material or displaying an authentication prompt.
     * Unknown Keystore failures are classified as unusable so status never
     * turns a potentially protected wallet into an ordinary create flow.
     */
    private fun probeEnvelopeKey(
        envelope: WalletEnvelopeRecord?,
        envelopePresent: Boolean,
    ): EnvelopeKeyProbe {
        val aliasPresent = try {
            keyStore.containsAlias(KEY_ALIAS)
        } catch (_: Exception) {
            Log.w(TAG, "Wallet key alias probe failed; preserving a fail-closed state")
            return EnvelopeKeyProbe(aliasPresent = true, invalidated = envelopePresent)
        }
        if (!aliasPresent) return EnvelopeKeyProbe(aliasPresent = false, invalidated = false)
        if (envelope == null) return EnvelopeKeyProbe(aliasPresent = true, invalidated = false)

        return try {
            val key = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
                ?: return EnvelopeKeyProbe(aliasPresent = true, invalidated = true)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, envelope.iv))
            EnvelopeKeyProbe(aliasPresent = true, invalidated = false)
        } catch (_: KeyPermanentlyInvalidatedException) {
            EnvelopeKeyProbe(aliasPresent = true, invalidated = true)
        } catch (_: Exception) {
            Log.w(TAG, "Wallet key usability probe failed; preserving a fail-closed state")
            EnvelopeKeyProbe(aliasPresent = true, invalidated = true)
        }
    }

    private fun writeEnvelope(envelope: WalletEnvelopeRecord) {
        val json = JSONObject()
            .put("version", envelope.version)
            .put("address", envelope.address)
            .put("iv", Base64.encodeToString(envelope.iv, Base64.NO_WRAP))
            .put(
                "ciphertext",
                Base64.encodeToString(envelope.ciphertext, Base64.NO_WRAP),
            )
        val output = envelopeFile.startWrite()
        try {
            output.write(json.toString().toByteArray(StandardCharsets.UTF_8))
            output.fd.sync()
            envelopeFile.finishWrite(output)
        } catch (error: Exception) {
            envelopeFile.failWrite(output)
            throw error
        }
    }

    private fun readEnvelopeOrNull(): WalletEnvelopeRecord? {
        if (!envelopeFile.baseFile.exists()) return null
        return try {
            val json = JSONObject(
                envelopeFile.openRead().bufferedReader(StandardCharsets.UTF_8).use { it.readText() },
            )
            val version = json.getInt("version")
            require(version == ENVELOPE_VERSION)
            val address = json.getString("address")
            require(HEX_ADDRESS.matches(address))
            val iv = Base64.decode(json.getString("iv"), Base64.NO_WRAP)
            val ciphertext = Base64.decode(json.getString("ciphertext"), Base64.NO_WRAP)
            require(iv.size == 12 && ciphertext.size >= 48)
            WalletEnvelopeRecord(version, address, iv, ciphertext)
        } catch (_: Exception) {
            null
        }
    }

    private fun requireEnvelope(result: MethodChannel.Result): WalletEnvelopeRecord? {
        val envelope = readEnvelopeOrNull()
        if (envelope == null) {
            if (envelopeFile.baseFile.exists()) {
                result.error(
                    "WALLET_ENVELOPE_CORRUPT",
                    "The secure wallet envelope failed its integrity checks. Do not create another wallet; restore from backup after removing the damaged record.",
                    null,
                )
            } else {
                result.error("WALLET_NOT_FOUND", "No secure Plawie wallet is available.", null)
            }
        }
        return envelope
    }

    private fun isHardwareSecurityLevel(level: String): Boolean =
        level == "StrongBox" || level == "Trusted Environment" || level == "secure hardware"

    private fun deleteEnvelopeAndKey() {
        envelopeFile.delete()
        if (envelopeFile.baseFile.exists()) {
            throw IllegalStateException("Could not remove the wallet envelope.")
        }
        deleteKnownAlias()
    }

    private fun deleteKnownAlias() {
        if (keyStore.containsAlias(KEY_ALIAS)) keyStore.deleteEntry(KEY_ALIAS)
    }

    private fun rollbackWalletTransaction(
        transaction: SecureEvmWalletTransaction,
        originalError: Throwable? = null,
    ) {
        try {
            transaction.rollback()
        } catch (rollbackError: Throwable) {
            if (originalError != null) {
                originalError.addSuppressed(rollbackError)
            } else {
                Log.e(TAG, "Secure wallet rollback failed; recovery state will remain explicit")
            }
        }
    }

    private fun showBackupDialog(privateKey: String, result: MethodChannel.Result) {
        val completed = AtomicBoolean(false)
        val text = TextView(activity).apply {
            setPadding(48, 24, 48, 24)
            setTextIsSelectable(true)
            textSize = 13f
            typeface = android.graphics.Typeface.MONOSPACE
            this.text = privateKey
        }
        val scroll = ScrollView(activity).apply { addView(text) }
        val dialog = AlertDialog.Builder(activity)
            .setTitle("Private key backup")
            .setMessage("Never share this key. Anyone with it controls the wallet.")
            .setView(scroll)
            .setNegativeButton("Close", null)
            .setPositiveButton("Copy and close") { _, _ ->
                val clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("Plawie wallet private key", privateKey))
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        val current = clipboard.primaryClip?.getItemAt(0)?.coerceToText(activity)?.toString()
                        if (current == privateKey) clipboard.clearPrimaryClip()
                    } catch (_: Exception) {
                    }
                }, 60_000L)
            }
            .create()
        dialog.setOnDismissListener {
            if (completed.compareAndSet(false, true)) result.success(true)
        }
        dialog.setOnCancelListener {
            if (completed.compareAndSet(false, true)) result.success(false)
        }
        dialog.show()
    }

    private fun parseX402Authorization(arguments: Map<*, *>?, walletAddress: String): X402Request {
        require(arguments != null) { "x402 authorization is missing." }
        val host = arguments["host"]?.toString()?.trim()?.lowercase(Locale.US) ?: ""
        require(X402_HOSTS.any { host == it || host.endsWith(".$it") }) {
            "x402 host is not allowlisted."
        }
        val chainId = arguments["chainId"]?.toString()?.toLongOrNull()
        require(chainId == OrdinaryEvmTransactionPolicy.BASE_MAINNET_CHAIN_ID) {
            "x402 payments require Base Mainnet."
        }
        val verifyingContract = arguments["verifyingContract"]?.toString()?.lowercase(Locale.US) ?: ""
        require(verifyingContract == OrdinaryEvmTransactionPolicy.USDC_MAINNET) {
            "x402 asset is not native Base USDC."
        }
        val from = arguments["from"]?.toString() ?: ""
        require(from.equals(walletAddress, ignoreCase = true)) { "x402 payer does not match the secure wallet." }
        val to = arguments["to"]?.toString() ?: ""
        require(HEX_ADDRESS.matches(to)) { "x402 payee is invalid." }
        val value = positiveBigInt(arguments["value"], "value")
        require(value <= BigInteger.valueOf(MAX_X402_USDC_UNITS)) { "x402 amount exceeds the 5 USDC policy cap." }
        val validAfter = positiveBigInt(arguments["validAfter"], "validAfter", allowZero = true)
        val validBefore = positiveBigInt(arguments["validBefore"], "validBefore")
        val now = System.currentTimeMillis() / 1000L
        require(validAfter <= BigInteger.valueOf(now + 30L)) { "x402 authorization starts too far in the future." }
        require(validAfter >= BigInteger.valueOf(now - MAX_X402_WINDOW_SECONDS)) { "x402 authorization is stale." }
        require(validBefore > BigInteger.valueOf(now)) { "x402 authorization has expired." }
        require(validBefore <= BigInteger.valueOf(now + MAX_X402_WINDOW_SECONDS + 30L)) {
            "x402 authorization window exceeds policy."
        }
        val nonce = arguments["nonce"]?.toString()?.lowercase(Locale.US) ?: ""
        require(HEX_BYTES32.matches(nonce)) { "x402 nonce must be bytes32." }
        val name = arguments["name"]?.toString()?.trim() ?: ""
        val version = arguments["version"]?.toString()?.trim() ?: ""
        require(name.isNotEmpty() && name.length <= 64 && version.isNotEmpty() && version.length <= 16) {
            "x402 token domain is invalid."
        }
        return X402Request(
            host,
            name,
            version,
            chainId,
            verifyingContract,
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
        )
    }

    private fun eip3009Digest(request: X402Request): ByteArray {
        return Eip3009Digest.compute(
            name = request.name,
            version = request.version,
            chainId = request.chainId,
            verifyingContract = request.verifyingContract,
            from = request.from,
            to = request.to,
            value = request.value,
            validAfter = request.validAfter,
            validBefore = request.validBefore,
            nonce = request.nonce,
        )
    }

    private fun positiveBigInt(raw: Any?, name: String, allowZero: Boolean = false): BigInteger {
        val value = raw?.toString()?.let {
            try {
                BigInteger(it)
            } catch (_: NumberFormatException) {
                null
            }
        } ?: throw IllegalArgumentException("$name is missing or invalid.")
        require(if (allowZero) value >= BigInteger.ZERO else value > BigInteger.ZERO) {
            "$name is outside the allowed range."
        }
        return value
    }

    private fun formatUnits(value: BigInteger, decimals: Int): String {
        val divisor = BigInteger.TEN.pow(decimals)
        val whole = value.divide(divisor)
        val fraction = value.mod(divisor).toString().padStart(decimals, '0').trimEnd('0')
        return if (fraction.isEmpty()) whole.toString() else "$whole.$fraction"
    }

    private fun shortAddress(value: String): String =
        if (value.length > 12) "${value.take(6)}…${value.takeLast(4)}" else value

    private fun beginOperation(result: MethodChannel.Result): Boolean {
        if (operationActive.compareAndSet(false, true)) return true
        result.error("WALLET_OPERATION_BUSY", "Another wallet authentication is already active.", null)
        return false
    }

    private fun endOperation() {
        operationActive.set(false)
    }

    private fun safeMessage(error: Exception): String =
        error.message?.take(240) ?: error.javaClass.simpleName

    private data class EnvelopeKeyProbe(
        val aliasPresent: Boolean,
        val invalidated: Boolean,
    )

    private data class WalletStateSnapshot(
        val envelopePresent: Boolean,
        val envelope: WalletEnvelopeRecord?,
        val authentication: Pair<Boolean, String>,
        val keyProbe: EnvelopeKeyProbe,
        val state: SecureEvmWalletState,
        val securityLevel: String,
    )

    private data class X402Request(
        val host: String,
        val name: String,
        val version: String,
        val chainId: Long,
        val verifyingContract: String,
        val from: String,
        val to: String,
        val value: BigInteger,
        val validAfter: BigInteger,
        val validBefore: BigInteger,
        val nonce: String,
    )

}

internal data class OrdinaryEvmTransactionRequest(
    val kind: String,
    val chainId: Long,
    val nonce: BigInteger,
    val gasPrice: BigInteger,
    val gasLimit: BigInteger,
    val to: String,
    val value: BigInteger,
    val data: String,
)

/**
 * Pure allowlist used by the Android-owned signer and its JVM tests. A Dart
 * payload cannot widen this policy into generic contract or cross-chain
 * signing.
 */
internal object OrdinaryEvmTransactionPolicy {
    const val BASE_MAINNET_CHAIN_ID = 8453L
    const val ROBINHOOD_MAINNET_CHAIN_ID = 4663L
    const val BASE_SEPOLIA_CHAIN_ID = 84532L
    const val USDC_MAINNET = "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"
    const val USDC_SEPOLIA = "0x036cbd53842c5426634e7929541ec2318f3dcf7e"
    const val USDG_ROBINHOOD = "0x5fc5360d0400a0fd4f2af552add042d716f1d168"
    private const val ERC20_TRANSFER_SELECTOR = "a9059cbb"
    private val HEX_ADDRESS = Regex("^0x[0-9a-fA-F]{40}$")

    fun parse(arguments: Map<*, *>?): OrdinaryEvmTransactionRequest {
        require(arguments != null) { "Transaction arguments are missing." }
        val kind = arguments["kind"]?.toString()?.lowercase(Locale.US) ?: ""
        require(kind == "eth" || kind == "usdc" || kind == "usdg") {
            "Only ETH, Base USDC, and Robinhood USDG transfers are allowed."
        }
        val chainId = arguments["chainId"]?.toString()?.toLongOrNull()
            ?: throw IllegalArgumentException("chainId is missing.")
        require(
            chainId == BASE_MAINNET_CHAIN_ID ||
                chainId == ROBINHOOD_MAINNET_CHAIN_ID ||
                chainId == BASE_SEPOLIA_CHAIN_ID,
        ) { "The wallet network is not allowlisted." }

        val nonce = positiveBigInt(arguments["nonce"], "nonce", allowZero = true)
        val gasPrice = positiveBigInt(arguments["gasPrice"], "gasPrice")
        val gasLimit = positiveBigInt(arguments["gasLimit"], "gasLimit")
        require(gasLimit <= BigInteger.valueOf(2_000_000L)) {
            "Gas limit exceeds wallet policy."
        }
        val to = arguments["to"]?.toString() ?: ""
        require(HEX_ADDRESS.matches(to)) { "Destination is not an EVM address." }
        val isToken = kind != "eth"
        val value = positiveBigInt(arguments["value"], "value", allowZero = isToken)
        var data = arguments["data"]?.toString()?.lowercase(Locale.US) ?: "0x"
        if (data.isEmpty()) data = "0x"
        require(data.startsWith("0x") && data.length % 2 == 0) {
            "Transaction data is invalid."
        }

        when (kind) {
            "eth" -> require(data == "0x" && value > BigInteger.ZERO) {
                "ETH transfer payload is invalid."
            }
            "usdc" -> {
                require(chainId != ROBINHOOD_MAINNET_CHAIN_ID) {
                    "USDC transfers are not authorized on Robinhood Chain."
                }
                val expected = if (chainId == BASE_MAINNET_CHAIN_ID) {
                    USDC_MAINNET
                } else {
                    USDC_SEPOLIA
                }
                require(to.equals(expected, ignoreCase = true)) {
                    "USDC contract does not match the Base network."
                }
                parseTokenTransfer(data, "USDC")
                require(value == BigInteger.ZERO) {
                    "USDC transaction must not send native ETH."
                }
            }
            "usdg" -> {
                require(chainId == ROBINHOOD_MAINNET_CHAIN_ID) {
                    "USDG transfers require Robinhood Chain."
                }
                require(to.equals(USDG_ROBINHOOD, ignoreCase = true)) {
                    "USDG contract does not match Robinhood Chain."
                }
                parseTokenTransfer(data, "USDG")
                require(value == BigInteger.ZERO) {
                    "USDG transaction must not send native ETH."
                }
            }
        }
        return OrdinaryEvmTransactionRequest(
            kind,
            chainId,
            nonce,
            gasPrice,
            gasLimit,
            to,
            value,
            data,
        )
    }

    fun summary(request: OrdinaryEvmTransactionRequest): String {
        val network = when (request.chainId) {
            BASE_MAINNET_CHAIN_ID -> "Base Mainnet"
            BASE_SEPOLIA_CHAIN_ID -> "Base Sepolia"
            ROBINHOOD_MAINNET_CHAIN_ID -> "Robinhood Chain"
            else -> error("Unexpected allowlisted chain")
        }
        if (request.kind == "eth") {
            return "Send ${formatUnits(request.value, 18)} ETH to " +
                "${shortAddress(request.to)} on $network"
        }
        val symbol = if (request.kind == "usdg") "USDG" else "USDC"
        val transfer = parseTokenTransfer(request.data, symbol)
        return "Send ${formatUnits(transfer.second, 6)} $symbol to " +
            "${shortAddress(transfer.first)} on $network"
    }

    private fun parseTokenTransfer(data: String, symbol: String): Pair<String, BigInteger> {
        val raw = data.removePrefix("0x")
        require(raw.length == 136 && raw.startsWith(ERC20_TRANSFER_SELECTOR)) {
            "Only ERC-20 transfer(address,uint256) is allowed for $symbol."
        }
        val recipient = "0x${raw.substring(32, 72)}"
        require(HEX_ADDRESS.matches(recipient)) { "$symbol recipient is invalid." }
        val amount = BigInteger(raw.substring(72, 136), 16)
        require(amount > BigInteger.ZERO) { "$symbol amount must be positive." }
        return Pair(recipient, amount)
    }

    private fun positiveBigInt(raw: Any?, name: String, allowZero: Boolean = false): BigInteger {
        val value = raw?.toString()?.let {
            try {
                BigInteger(it)
            } catch (_: NumberFormatException) {
                null
            }
        } ?: throw IllegalArgumentException("$name is missing or invalid.")
        require(if (allowZero) value >= BigInteger.ZERO else value > BigInteger.ZERO) {
            "$name is outside the allowed range."
        }
        return value
    }

    private fun formatUnits(value: BigInteger, decimals: Int): String {
        val divisor = BigInteger.TEN.pow(decimals)
        val whole = value.divide(divisor)
        val fraction = value.mod(divisor).toString().padStart(decimals, '0').trimEnd('0')
        return if (fraction.isEmpty()) whole.toString() else "$whole.$fraction"
    }

    private fun shortAddress(value: String): String =
        if (value.length > 12) "${value.take(6)}…${value.takeLast(4)}" else value
}

/**
 * Android's biometric APIs and Android Keystore intentionally define separate
 * authenticator constant families. Their numeric values are not interchangeable.
 */
internal object WalletAuthenticatorPolicy {
    val biometricApiMask: Int =
        BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL

    val keyStoreMask: Int =
        KeyProperties.AUTH_BIOMETRIC_STRONG or
            KeyProperties.AUTH_DEVICE_CREDENTIAL
}

internal object VeniceSiweMessage {
    fun build(
        address: String,
        statement: String,
        uri: String,
        nonce: String,
        issuedAt: String,
        expirationTime: String,
    ): String = """api.venice.ai wants you to sign in with your Ethereum account:
$address

$statement

URI: $uri
Version: 1
Chain ID: 8453
Nonce: $nonce
Issued At: $issuedAt
Expiration Time: $expirationTime"""
}

internal data class VeniceProviderIdentityRequest(
    val method: String,
    val uri: String,
    val statement: String,
    val promptDescription: String,
    val nonce: String,
    val issuedAt: String,
    val expirationTime: String,
)

/** Pure closed-route parser kept outside Android APIs for JVM security tests. */
internal object VeniceProviderIdentityPolicy {
    private val noncePattern = Regex("^[A-Za-z0-9]{8,64}$")
    private val walletPattern = Regex("^0x[0-9a-fA-F]{40}$")
    private const val statement = "Sign in to Venice AI"

    fun parse(
        arguments: Map<*, *>?,
        walletAddress: String,
        now: Instant = Instant.now(),
        responsesEnabled: Boolean = false,
    ): VeniceProviderIdentityRequest {
        require(arguments != null) { "Venice identity request is missing." }
        require(walletPattern.matches(walletAddress)) {
            "The secure Venice identity wallet is invalid."
        }
        val method = arguments["method"]?.toString()?.trim() ?: ""
        val uriText = arguments["uri"]?.toString()?.trim() ?: ""
        val uri = URI(uriText)
        require(
            !uri.isOpaque &&
                uri.scheme.equals("https", ignoreCase = true) &&
                uri.host.equals("api.venice.ai", ignoreCase = true) &&
                (uri.port == -1 || uri.port == 443) &&
                uri.userInfo == null &&
                uri.rawQuery == null &&
                uri.rawFragment == null
        ) { "Venice identity URI is not allowlisted." }

        val rawPath = uri.rawPath ?: ""
        val balancePrefix = "/api/v1/x402/balance/"
        val promptDescription = when {
            method == "GET" && rawPath == "/api/v1/models" ->
                "Authenticate this wallet to load Venice models"
            method == "POST" && rawPath == "/api/v1/chat/completions" ->
                "Authenticate this wallet for this Venice model request"
            responsesEnabled && method == "POST" && rawPath == "/api/v1/responses" ->
                "Authenticate this wallet for this Venice response request"
            method == "GET" &&
                rawPath.startsWith(balancePrefix) &&
                rawPath.removePrefix(balancePrefix).equals(walletAddress, ignoreCase = true) ->
                "Authenticate this wallet to read its Venice balance"
            else -> throw IllegalArgumentException(
                "Venice identity method and route are not allowlisted.",
            )
        }

        val nonce = arguments["nonce"]?.toString()?.trim() ?: ""
        require(noncePattern.matches(nonce)) { "Venice identity nonce is invalid." }
        val issuedAt = Instant.parse(arguments["issuedAt"]?.toString() ?: "")
        val expirationTime = Instant.parse(arguments["expirationTime"]?.toString() ?: "")
        require(Duration.between(issuedAt, now).abs() <= Duration.ofSeconds(60)) {
            "Venice identity issue time is stale."
        }
        require(expirationTime.isAfter(now)) { "Venice identity has expired." }
        require(
            expirationTime.isAfter(issuedAt) &&
                Duration.between(issuedAt, expirationTime) <= Duration.ofMinutes(5)
        ) { "Venice identity lifetime exceeds five minutes." }

        return VeniceProviderIdentityRequest(
            method = method,
            uri = uri.toString(),
            statement = statement,
            promptDescription = promptDescription,
            nonce = nonce,
            issuedAt = issuedAt.toString(),
            expirationTime = expirationTime.toString(),
        )
    }
}

/** Pure EIP-712 encoder kept separately so JVM tests can verify it against an
 * independent reference implementation without touching Android Keystore. */
internal object Eip3009Digest {
    fun compute(
        name: String,
        version: String,
        chainId: Long,
        verifyingContract: String,
        from: String,
        to: String,
        value: BigInteger,
        validAfter: BigInteger,
        validBefore: BigInteger,
        nonce: String,
    ): ByteArray {
        val domainType = Hash.sha3(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                .toByteArray(StandardCharsets.UTF_8),
        )
        val authorizationType = Hash.sha3(
            "TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
                .toByteArray(StandardCharsets.UTF_8),
        )
        val domain = Hash.sha3(
            concat(
                domainType,
                Hash.sha3(name.toByteArray(StandardCharsets.UTF_8)),
                Hash.sha3(version.toByteArray(StandardCharsets.UTF_8)),
                uint256(BigInteger.valueOf(chainId)),
                addressWord(verifyingContract),
            ),
        )
        val authorization = Hash.sha3(
            concat(
                authorizationType,
                addressWord(from),
                addressWord(to),
                uint256(value),
                uint256(validAfter),
                uint256(validBefore),
                Numeric.hexStringToByteArray(nonce),
            ),
        )
        return Hash.sha3(concat(byteArrayOf(0x19, 0x01), domain, authorization))
    }

    private fun addressWord(address: String): ByteArray {
        val bytes = Numeric.hexStringToByteArray(address)
        require(bytes.size == 20)
        return ByteArray(32).also { System.arraycopy(bytes, 0, it, 12, 20) }
    }

    private fun uint256(value: BigInteger): ByteArray {
        require(value >= BigInteger.ZERO && value.bitLength() <= 256)
        return Numeric.toBytesPadded(value, 32)
    }

    private fun concat(vararg values: ByteArray): ByteArray {
        val output = ByteBuffer.allocate(values.sumOf { it.size })
        values.forEach { output.put(it) }
        return output.array()
    }
}
