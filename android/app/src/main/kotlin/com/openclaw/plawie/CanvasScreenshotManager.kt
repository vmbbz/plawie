package com.openclaw.plawie

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.PixelCopy
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

object CanvasScreenshotManager {
    const val CHANNEL = "com.openclaw.plawie/canvas_screenshot"

    private var activity: FlutterActivity? = null

    fun register(activity: FlutterActivity, messenger: io.flutter.plugin.common.BinaryMessenger) {
        this.activity = activity
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "captureScreenshot" -> {
                    val viewId = call.argument<Int>("viewId") ?: 0
                    Thread {
                        val bytes = captureScreenshot(viewId)
                        activity.runOnUiThread { result.success(bytes) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    fun unregister() {
        activity = null
    }

    private fun captureScreenshot(viewId: Int): ByteArray? {
        val activity = this.activity ?: return null
        var webView: WebView? = null
        activity.runOnUiThread {
            val root = activity.findViewById<View>(android.R.id.content) as? ViewGroup
            webView = root?.let { findWebView(it) }
        }
        // Small delay to ensure the synchronous UI lookup has run.
        Thread.sleep(50)

        val captured = webView ?: return null
        val width = captured.width.coerceAtLeast(1)
        val height = captured.height.coerceAtLeast(1)

        val location = IntArray(2)
        captured.getLocationOnScreen(location)
        val screenRect = Rect(location[0], location[1], location[0] + width, location[1] + height)

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)

        // Try PixelCopy first (API 24+), fall back to View.draw() for older devices or failures.
        val pixelCopyBytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val window = activity.window
            val latch = CountDownLatch(1)
            var success = false
            try {
                PixelCopy.request(window, screenRect, bitmap, { copyResult ->
                    success = copyResult == PixelCopy.SUCCESS
                    latch.countDown()
                }, Handler(Looper.getMainLooper()))
                latch.await(2, TimeUnit.SECONDS)
            } catch (e: Exception) {
                Log.w("CanvasScreenshot", "PixelCopy failed, falling back to View.draw", e)
                success = false
            }
            if (success) bitmapToPng(bitmap) else null
        } else null

        if (pixelCopyBytes != null) return pixelCopyBytes

        // Fallback: draw the WebView into a Canvas-backed Bitmap. This is less reliable for
        // hardware-accelerated platform views but works on most devices.
        return try {
            val drawBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(drawBitmap)
            activity.runOnUiThread { captured.draw(canvas) }
            Thread.sleep(100)
            bitmapToPng(drawBitmap)
        } catch (e: Exception) {
            Log.w("CanvasScreenshot", "View.draw fallback failed", e)
            null
        }
    }

    private fun findWebView(root: View): WebView? {
        if (root is WebView) return root
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                val found = findWebView(root.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    private fun bitmapToPng(bitmap: Bitmap): ByteArray {
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }
}
