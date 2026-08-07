package com.openclaw.plawie

import android.net.Uri
import android.util.Base64
import androidx.activity.ComponentActivity
import com.solana.mobilewalletadapter.clientlib.ActivityResultSender
import com.solana.mobilewalletadapter.clientlib.ConnectionIdentity
import com.solana.mobilewalletadapter.clientlib.MobileWalletAdapter
import com.solana.mobilewalletadapter.clientlib.Solana
import com.solana.mobilewalletadapter.clientlib.TransactionResult
import com.solana.mobilewalletadapter.common.ProtocolContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.math.BigInteger
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

internal class SolanaMwaBridge(private val activity: ComponentActivity) {
    private companion object {
        const val CHANNEL = "com.openclaw.plawie/solana_mwa"
        const val SOLANA_MAINNET_CHAIN_ID = 1151111081099710L
        const val MAX_TRANSACTION_BYTES = 1232
        val BASE_58 =
            "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".toCharArray()
    }

    private class InvalidWalletPayloadException : IllegalArgumentException()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val operationInFlight = AtomicBoolean(false)
    private val sender = ActivityResultSender(activity)
    private val walletAdapter = MobileWalletAdapter(
        ConnectionIdentity(
            identityUri = Uri.parse("https://github.com/vmbbz/plawie"),
            iconUri = Uri.parse("favicon.ico"),
            identityName = "Plawie",
        )
    ).apply {
        blockchain = Solana.Mainnet
    }
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        if (channel != null) return
        channel = MethodChannel(messenger, CHANNEL).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "authorize" -> runExclusive(result) { authorize(result) }
                    "submitTransaction" -> runExclusive(result) {
                        submitTransaction(call.argument<String>("transaction"), result)
                    }
                    "deauthorize" -> runExclusive(result) { deauthorize(result) }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun runExclusive(
        result: MethodChannel.Result,
        operation: suspend () -> Unit,
    ) {
        if (!operationInFlight.compareAndSet(false, true)) {
            result.error("MWA_BUSY", "Another wallet request is active.", null)
            return
        }
        scope.launch {
            try {
                operation()
            } catch (_: InvalidWalletPayloadException) {
                result.error("MWA_INVALID_PAYLOAD", "Wallet payload is invalid.", null)
            } catch (_: Exception) {
                result.error("MWA_FAILURE", "Wallet request failed.", null)
            } finally {
                operationInFlight.set(false)
            }
        }
    }

    private suspend fun authorize(result: MethodChannel.Result) {
        val outcome = walletAdapter.transact(sender) { authorization ->
            val capabilities = getCapabilities()
            val account = authorization.accounts.firstOrNull()
                ?: throw IllegalStateException("missing account")
            validateMainnetAccount(account.publicKey, account.chains)
            val features = linkedSetOf<String>().apply {
                account.features?.let(::addAll)
                addAll(capabilities.supportedOptionalFeatures)
            }
            val methods = linkedSetOf(
                "authorize",
                "deauthorize",
                "signAndSendTransactions",
            )
            if (features.contains(ProtocolContract.FEATURE_ID_SIGN_TRANSACTIONS)) {
                methods.add("signTransactions")
            }
            mapOf(
                "walletLabel" to account.accountLabel.orEmpty().ifBlank { "Solana wallet" },
                "address" to encodeBase58(account.publicKey),
                "chainId" to SOLANA_MAINNET_CHAIN_ID,
                "chainType" to "svm",
                "features" to features.toList(),
                "methods" to methods.toList(),
            )
        }
        complete(outcome, result, "MWA_AUTH_FAILED")
    }

    @Suppress("DEPRECATION")
    private suspend fun submitTransaction(
        encodedTransaction: String?,
        result: MethodChannel.Result,
    ) {
        val encoded = encodedTransaction?.trim().orEmpty()
        val transaction = runCatching {
            Base64.decode(encoded, Base64.NO_WRAP)
        }.getOrElse {
            throw InvalidWalletPayloadException()
        }
        if (
            transaction.isEmpty() ||
            transaction.size > MAX_TRANSACTION_BYTES ||
            Base64.encodeToString(transaction, Base64.NO_WRAP) != encoded
        ) {
            throw InvalidWalletPayloadException()
        }

        val outcome = walletAdapter.transact(sender) { authorization ->
            val account = authorization.accounts.firstOrNull()
                ?: throw IllegalStateException("missing account")
            validateMainnetAccount(account.publicKey, account.chains)
            val capabilities = getCapabilities()
            val features = linkedSetOf<String>().apply {
                account.features?.let(::addAll)
                addAll(capabilities.supportedOptionalFeatures)
            }
            if (features.contains(ProtocolContract.FEATURE_ID_SIGN_TRANSACTIONS)) {
                val signed = signTransactions(arrayOf(transaction)).signedPayloads
                if (signed.size != 1) throw IllegalStateException("ambiguous result")
                mapOf(
                    "mode" to "signOnly",
                    "signedTransactionBytes" to signed.single(),
                )
            } else {
                val signatures = signAndSendTransactions(arrayOf(transaction)).signatures
                if (signatures.size != 1 || signatures.single().size != 64) {
                    throw IllegalStateException("ambiguous result")
                }
                mapOf(
                    "mode" to "signAndSend",
                    "signatureBase58" to encodeBase58(signatures.single()),
                )
            }
        }
        complete(outcome, result, "MWA_SUBMIT_FAILED")
    }

    private suspend fun deauthorize(result: MethodChannel.Result) {
        when (val outcome = walletAdapter.disconnect(sender)) {
            is TransactionResult.Success -> result.success(null)
            else -> complete(outcome, result, "MWA_DEAUTHORIZE_FAILED")
        }
    }

    private fun <T> complete(
        outcome: TransactionResult<T>,
        result: MethodChannel.Result,
        failureCode: String,
    ) {
        when (outcome) {
            is TransactionResult.Success -> result.success(outcome.payload)
            is TransactionResult.NoWalletFound -> result.error(
                "MWA_NO_WALLET",
                "No compatible Solana wallet is available.",
                null,
            )
            is TransactionResult.Failure -> {
                val cancelled = outcome.message.contains("cancel", ignoreCase = true) ||
                    outcome.message.contains("interrupt", ignoreCase = true)
                result.error(
                    if (cancelled) "MWA_CANCELLED" else failureCode,
                    if (cancelled) "Wallet request was cancelled." else "Wallet request failed.",
                    null,
                )
            }
        }
    }

    private fun validateMainnetAccount(publicKey: ByteArray, chains: Array<String>?) {
        if (publicKey.size != 32) throw IllegalStateException("invalid account")
        if (chains != null && !chains.contains(Solana.Mainnet.fullName)) {
            throw IllegalStateException("wrong chain")
        }
    }

    private fun encodeBase58(bytes: ByteArray): String {
        if (bytes.isEmpty()) return ""
        var leadingZeros = 0
        while (leadingZeros < bytes.size && bytes[leadingZeros].toInt() == 0) {
            leadingZeros += 1
        }
        var value = BigInteger(1, bytes)
        val encoded = StringBuilder()
        val radix = BigInteger.valueOf(58)
        while (value > BigInteger.ZERO) {
            val parts = value.divideAndRemainder(radix)
            encoded.append(BASE_58[parts[1].toInt()])
            value = parts[0]
        }
        repeat(leadingZeros) { encoded.append('1') }
        return encoded.reverse().toString()
    }

    fun dispose() {
        channel?.setMethodCallHandler(null)
        channel = null
        scope.cancel()
    }
}
