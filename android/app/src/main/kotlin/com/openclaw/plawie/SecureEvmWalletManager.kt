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
 * Device-authenticated EVM signer for the app-owned Base wallet.
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
        private const val BASE_MAINNET_CHAIN_ID = 8453L
        private const val BASE_SEPOLIA_CHAIN_ID = 84532L
        private const val MAX_X402_USDC_UNITS = 5_000_000L
        private const val MAX_X402_WINDOW_SECONDS = 300L
        private const val USDC_MAINNET =
            "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"
        private const val USDC_SEPOLIA =
            "0x036cbd53842c5426634e7929541ec2318f3dcf7e"
        private const val ERC20_TRANSFER_SELECTOR = "a9059cbb"
        private val X402_HOSTS = setOf("api.venice.ai", "blockrun.ai")
        private val HEX_ADDRESS = Regex("^0x[0-9a-fA-F]{40}$")
        private val HEX_BYTES32 = Regex("^0x[0-9a-fA-F]{64}$")
        private val SIWE_NONCE = Regex("^[A-Za-z0-9]{8,64}$")
        private val operationActive = AtomicBoolean(false)
    }

    private val executor: Executor = activity.mainExecutor
    private val envelopeFile = AtomicFile(File(activity.noBackupFilesDir, ENVELOPE_FILE))
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    fun status(): Map<String, Any> {
        val envelope = readEnvelopeOrNull()
        val auth = authenticationStatus()
        val securityLevel = keySecurityLevel()
        val corrupt = envelope == null && envelopeFile.baseFile.exists()
        return mapOf(
            "exists" to (envelope != null),
            "address" to (envelope?.address ?: ""),
            "envelopeIntegrity" to if (corrupt) "corrupt" else if (envelope != null) "verified" else "absent",
            "securityLevel" to securityLevel,
            "hardwareBacked" to isHardwareSecurityLevel(securityLevel),
            "authenticationAvailable" to auth.first,
            "authenticationMode" to auth.second,
            "privateKeyLeavesAndroid" to false,
            "genericSigningAvailable" to false,
        )
    }

    fun createWallet(result: MethodChannel.Result) {
        if (envelopeFile.baseFile.exists()) {
            result.error("WALLET_EXISTS", "A secure wallet already exists.", null)
            return
        }
        val pair = Keys.createEcKeyPair()
        val privateKey = Numeric.toBytesPadded(pair.privateKey, 32)
        val address = Keys.toChecksumAddress("0x${Keys.getAddress(pair)}")
        encryptAndStore(privateKey, address, "Create wallet", result)
    }

    fun importWallet(privateKey: ByteArray?, result: MethodChannel.Result) {
        if (envelopeFile.baseFile.exists()) {
            privateKey?.let { Arrays.fill(it, 0) }
            result.error("WALLET_EXISTS", "Remove the existing wallet before importing another.", null)
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
            val request = parseTransaction(arguments)
            val summary = transactionSummary(request)
            withDecryptedKey(
                envelope = envelope,
                title = "Approve Base transaction",
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
     * Signs only the Venice balance endpoint's EIP-4361 identity message.
     * This is intentionally not a generic personal-message signer and cannot
     * authorize a transfer or an arbitrary provider resource.
     */
    fun signVeniceBalanceIdentity(arguments: Map<*, *>?, result: MethodChannel.Result) {
        val envelope = requireEnvelope(result) ?: return
        try {
            val request = parseVeniceBalanceIdentity(arguments, envelope.address)
            val message = VeniceSiweMessage.build(
                address = envelope.address,
                uri = request.uri,
                nonce = request.nonce,
                issuedAt = request.issuedAt,
                expirationTime = request.expirationTime,
            )
            withDecryptedKey(
                envelope = envelope,
                title = "Sign in to Venice",
                description = "Authenticate this wallet to read its Venice balance",
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
            title = "Remove Base wallet",
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
        try {
            ensureAuthenticationAvailable()
            val secretKey = getOrCreateEnvelopeKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            authenticateCipher(
                cipher = cipher,
                title = title,
                description = "Protect $address with your device lock",
                result = result,
                onSuccess = { authenticatedCipher ->
                    try {
                        val encrypted = authenticatedCipher.doFinal(privateKey)
                        writeEnvelope(
                            WalletEnvelope(
                                address = address,
                                iv = authenticatedCipher.iv,
                                ciphertext = encrypted,
                            ),
                        )
                        result.success(status())
                    } catch (error: Exception) {
                        result.error("WALLET_STORE_ERROR", safeMessage(error), null)
                    } finally {
                        Arrays.fill(privateKey, 0)
                        endOperation()
                    }
                },
                onFailure = {
                    Arrays.fill(privateKey, 0)
                    endOperation()
                },
            )
        } catch (error: Exception) {
            Arrays.fill(privateKey, 0)
            endOperation()
            result.error("WALLET_SECURITY_ERROR", safeMessage(error), null)
        }
    }

    private fun <T> withDecryptedKey(
        envelope: WalletEnvelope,
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
        val finished = AtomicBoolean(false)
        fun fail(code: String, message: String) {
            if (!finished.compareAndSet(false, true)) return
            onFailure()
            result.error(code, message, null)
        }

        val builder = BiometricPrompt.Builder(activity)
            .setTitle(title)
            .setSubtitle(description.take(120))
            .setConfirmationRequired(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setAllowedAuthenticators(
                KeyProperties.AUTH_BIOMETRIC_STRONG or
                    KeyProperties.AUTH_DEVICE_CREDENTIAL,
            )
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
                        onFailure()
                        result.error(
                            "WALLET_AUTH_ERROR",
                            "Android did not return the authenticated cryptographic operation.",
                            null,
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
                KeyProperties.AUTH_BIOMETRIC_STRONG or
                    KeyProperties.AUTH_DEVICE_CREDENTIAL,
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
            val allowed = KeyProperties.AUTH_BIOMETRIC_STRONG or
                KeyProperties.AUTH_DEVICE_CREDENTIAL
            Pair(
                manager.canAuthenticate(allowed) == BiometricManager.BIOMETRIC_SUCCESS,
                "strong biometric or device credential",
            )
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

    private fun writeEnvelope(envelope: WalletEnvelope) {
        val json = JSONObject()
            .put("version", ENVELOPE_VERSION)
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

    private fun readEnvelopeOrNull(): WalletEnvelope? {
        if (!envelopeFile.baseFile.exists()) return null
        return try {
            val json = JSONObject(
                envelopeFile.openRead().bufferedReader(StandardCharsets.UTF_8).use { it.readText() },
            )
            require(json.getInt("version") == ENVELOPE_VERSION)
            val address = json.getString("address")
            require(HEX_ADDRESS.matches(address))
            val iv = Base64.decode(json.getString("iv"), Base64.NO_WRAP)
            val ciphertext = Base64.decode(json.getString("ciphertext"), Base64.NO_WRAP)
            require(iv.size == 12 && ciphertext.size >= 48)
            WalletEnvelope(address, iv, ciphertext)
        } catch (_: Exception) {
            null
        }
    }

    private fun requireEnvelope(result: MethodChannel.Result): WalletEnvelope? {
        val envelope = readEnvelopeOrNull()
        if (envelope == null) {
            if (envelopeFile.baseFile.exists()) {
                result.error(
                    "WALLET_ENVELOPE_CORRUPT",
                    "The secure wallet envelope failed its integrity checks. Do not create another wallet; restore from backup after removing the damaged record.",
                    null,
                )
            } else {
                result.error("WALLET_NOT_FOUND", "No secure Base wallet is available.", null)
            }
        }
        return envelope
    }

    private fun isHardwareSecurityLevel(level: String): Boolean =
        level == "StrongBox" || level == "Trusted Environment" || level == "secure hardware"

    private fun deleteEnvelopeAndKey() {
        if (envelopeFile.baseFile.exists() && !envelopeFile.baseFile.delete()) {
            throw IllegalStateException("Could not remove the wallet envelope.")
        }
        if (keyStore.containsAlias(KEY_ALIAS)) keyStore.deleteEntry(KEY_ALIAS)
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
                clipboard.setPrimaryClip(ClipData.newPlainText("Base private key", privateKey))
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

    private fun parseTransaction(arguments: Map<*, *>?): TransactionRequest {
        require(arguments != null) { "Transaction arguments are missing." }
        val kind = arguments["kind"]?.toString()?.lowercase(Locale.US) ?: ""
        require(kind == "eth" || kind == "usdc") { "Only ETH and USDC transfers are allowed." }
        val chainId = arguments["chainId"]?.toString()?.toLongOrNull()
            ?: throw IllegalArgumentException("chainId is missing.")
        require(chainId == BASE_MAINNET_CHAIN_ID || chainId == BASE_SEPOLIA_CHAIN_ID) {
            "Only Base Mainnet and Base Sepolia transactions are allowed."
        }
        val nonce = positiveBigInt(arguments["nonce"], "nonce", allowZero = true)
        val gasPrice = positiveBigInt(arguments["gasPrice"], "gasPrice")
        val gasLimit = positiveBigInt(arguments["gasLimit"], "gasLimit")
        require(gasLimit <= BigInteger.valueOf(2_000_000L)) { "Gas limit exceeds wallet policy." }
        val to = arguments["to"]?.toString() ?: ""
        require(HEX_ADDRESS.matches(to)) { "Destination is not an EVM address." }
        val value = positiveBigInt(arguments["value"], "value", allowZero = kind == "usdc")
        var data = arguments["data"]?.toString()?.lowercase(Locale.US) ?: "0x"
        if (data.isEmpty()) data = "0x"
        require(data.startsWith("0x") && data.length % 2 == 0) { "Transaction data is invalid." }
        if (kind == "eth") {
            require(data == "0x" && value > BigInteger.ZERO) { "ETH transfer payload is invalid." }
        } else {
            val expectedContract = if (chainId == BASE_MAINNET_CHAIN_ID) USDC_MAINNET else USDC_SEPOLIA
            require(to.equals(expectedContract, ignoreCase = true)) { "USDC contract does not match the Base network." }
            parseUsdcTransfer(data)
            require(value == BigInteger.ZERO) { "USDC transaction must not send native ETH." }
        }
        return TransactionRequest(kind, chainId, nonce, gasPrice, gasLimit, to, value, data)
    }

    private fun transactionSummary(request: TransactionRequest): String {
        if (request.kind == "eth") {
            return "Send ${formatUnits(request.value, 18)} ETH to ${shortAddress(request.to)} on Base"
        }
        val transfer = parseUsdcTransfer(request.data)
        return "Send ${formatUnits(transfer.second, 6)} USDC to ${shortAddress(transfer.first)} on Base"
    }

    private fun parseUsdcTransfer(data: String): Pair<String, BigInteger> {
        val raw = data.removePrefix("0x")
        require(raw.length == 136 && raw.startsWith(ERC20_TRANSFER_SELECTOR)) {
            "Only ERC-20 transfer(address,uint256) is allowed for USDC."
        }
        val recipient = "0x${raw.substring(32, 72)}"
        require(HEX_ADDRESS.matches(recipient)) { "USDC recipient is invalid." }
        val amount = BigInteger(raw.substring(72, 136), 16)
        require(amount > BigInteger.ZERO) { "USDC amount must be positive." }
        return Pair(recipient, amount)
    }

    private fun parseX402Authorization(arguments: Map<*, *>?, walletAddress: String): X402Request {
        require(arguments != null) { "x402 authorization is missing." }
        val host = arguments["host"]?.toString()?.trim()?.lowercase(Locale.US) ?: ""
        require(X402_HOSTS.any { host == it || host.endsWith(".$it") }) {
            "x402 host is not allowlisted."
        }
        val chainId = arguments["chainId"]?.toString()?.toLongOrNull()
        require(chainId == BASE_MAINNET_CHAIN_ID) { "x402 payments require Base Mainnet." }
        val verifyingContract = arguments["verifyingContract"]?.toString()?.lowercase(Locale.US) ?: ""
        require(verifyingContract == USDC_MAINNET) { "x402 asset is not native Base USDC." }
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

    private fun parseVeniceBalanceIdentity(
        arguments: Map<*, *>?,
        walletAddress: String,
    ): VeniceBalanceIdentityRequest {
        require(arguments != null) { "Venice identity request is missing." }
        val uriText = arguments["uri"]?.toString()?.trim() ?: ""
        val uri = URI(uriText)
        require(
            uri.scheme.equals("https", ignoreCase = true) &&
                uri.host.equals("api.venice.ai", ignoreCase = true) &&
                (uri.port == -1 || uri.port == 443) &&
                uri.userInfo == null &&
                uri.query == null &&
                uri.fragment == null
        ) { "Venice identity URI is not allowlisted." }
        val expectedPath = "/api/v1/x402/balance/$walletAddress"
        require(uri.path.equals(expectedPath, ignoreCase = true)) {
            "Venice identity is limited to this wallet's balance endpoint."
        }
        val nonce = arguments["nonce"]?.toString()?.trim() ?: ""
        require(SIWE_NONCE.matches(nonce)) { "Venice identity nonce is invalid." }
        val issuedAt = Instant.parse(arguments["issuedAt"]?.toString() ?: "")
        val expirationTime = Instant.parse(arguments["expirationTime"]?.toString() ?: "")
        val now = Instant.now()
        require(Duration.between(issuedAt, now).abs() <= Duration.ofSeconds(60)) {
            "Venice identity issue time is stale."
        }
        require(expirationTime.isAfter(now)) { "Venice identity has expired." }
        require(
            expirationTime.isAfter(issuedAt) &&
                Duration.between(issuedAt, expirationTime) <= Duration.ofMinutes(5)
        ) { "Venice identity lifetime exceeds five minutes." }
        return VeniceBalanceIdentityRequest(
            uri = uri.toString(),
            nonce = nonce,
            issuedAt = issuedAt.toString(),
            expirationTime = expirationTime.toString(),
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

    private data class WalletEnvelope(
        val address: String,
        val iv: ByteArray,
        val ciphertext: ByteArray,
    )

    private data class TransactionRequest(
        val kind: String,
        val chainId: Long,
        val nonce: BigInteger,
        val gasPrice: BigInteger,
        val gasLimit: BigInteger,
        val to: String,
        val value: BigInteger,
        val data: String,
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

    private data class VeniceBalanceIdentityRequest(
        val uri: String,
        val nonce: String,
        val issuedAt: String,
        val expirationTime: String,
    )
}

internal object VeniceSiweMessage {
    fun build(
        address: String,
        uri: String,
        nonce: String,
        issuedAt: String,
        expirationTime: String,
    ): String = """api.venice.ai wants you to sign in with your Ethereum account:
$address

Sign in to Venice AI

URI: $uri
Version: 1
Chain ID: 8453
Nonce: $nonce
Issued At: $issuedAt
Expiration Time: $expirationTime"""
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
