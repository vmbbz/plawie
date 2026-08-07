package com.openclaw.plawie

import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

internal class WalletLinkBridge(messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private companion object {
        const val EVENTS = "com.openclaw.plawie/wallet_links"
        const val METHODS = "com.openclaw.plawie/wallet_links_control"
    }

    private val eventChannel = EventChannel(messenger, EVENTS)
    private val methodChannel = MethodChannel(messenger, METHODS)
    private var eventSink: EventChannel.EventSink? = null
    private var pendingInitialLink: String? = null

    init {
        eventChannel.setStreamHandler(this)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialLink" -> {
                    val link = pendingInitialLink
                    pendingInitialLink = null
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun captureInitialIntent(intent: Intent?) {
        val link = acceptedLink(intent) ?: return
        if (pendingInitialLink == null) pendingInitialLink = link
    }

    fun onNewIntent(intent: Intent?) {
        val link = acceptedLink(intent) ?: return
        val sink = eventSink
        if (sink == null) {
            if (pendingInitialLink == null) pendingInitialLink = link
        } else {
            sink.success(link)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun dispose() {
        eventSink = null
        pendingInitialLink = null
        eventChannel.setStreamHandler(null)
        methodChannel.setMethodCallHandler(null)
    }

    private fun acceptedLink(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri = intent.data ?: return null
        if (uri.scheme != "plawie" || uri.host != "wallet-callback") return null
        return uri.toString()
    }
}
