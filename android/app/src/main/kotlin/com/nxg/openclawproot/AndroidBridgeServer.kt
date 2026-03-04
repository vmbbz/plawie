package com.nxg.openclawproot

import android.content.Context
import android.os.BatteryManager
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import fi.iki.elonen.NanoHTTPD
import org.json.JSONObject
import android.util.Log

/**
 * Local HTTP Server running on port 8765 to bridge Node.js and Android APIs.
 * This matches comp's high-efficiency IPC architecture.
 *
 * Current endpoints:
 * - GET /battery
 * - POST /vibrate  { "durationMs": 200 }
 * - GET /sensor    ?type=accelerometer
 */
class AndroidBridgeServer(private val context: Context) : NanoHTTPD(8765) {

    companion object {
        private const val TAG = "AndroidBridgeServer"
        private var instance: AndroidBridgeServer? = null

        fun startServer(context: Context) {
            if (instance == null) {
                try {
                    instance = AndroidBridgeServer(context)
                    instance?.start(SOCKET_READ_TIMEOUT, false)
                    Log.i(TAG, "Server started on port 8765")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start server", e)
                }
            }
        }

        fun stopServer() {
            instance?.stop()
            instance = null
            Log.i(TAG, "Server stopped")
        }
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val method = session.method

        return try {
            when (uri) {
                "/battery" -> handleBattery()
                "/vibrate" -> handleVibrate(session)
                "/sensor"  -> handleSensor(session)
                "/ping"    -> newFixedLengthResponse("pong\\n")
                else       -> newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Not Found")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling request to $uri", e)
            val err = JSONObject().apply { put("error", e.message) }
            newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "application/json", err.toString())
        }
    }

    // ================================================================
    // Handlers
    // ================================================================

    private fun handleBattery(): Response {
        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                         status == BatteryManager.BATTERY_STATUS_FULL
                         
        val batteryPct = if (level >= 0 && scale > 0) (level * 100f / scale).toInt() else -1

        val json = JSONObject().apply {
            put("level", batteryPct)
            put("isCharging", isCharging)
        }
        return newFixedLengthResponse(Response.Status.OK, "application/json", json.toString())
    }

    private fun handleVibrate(session: IHTTPSession): Response {
        if (session.method != Method.POST) {
            return newFixedLengthResponse(Response.Status.METHOD_NOT_ALLOWED, MIME_PLAINTEXT, "POST required")
        }
        
        val map = HashMap<String, String>()
        session.parseBody(map)
        val bodyStr = map["postData"] ?: "{}"
        
        var durationMs = 200L
        try {
            val bodyJson = JSONObject(bodyStr)
            if (bodyJson.has("durationMs")) {
                durationMs = bodyJson.getLong("durationMs")
            }
        } catch (e: Exception) {
            // Ignore parse errors, use default
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                val vibrator = vibratorManager.defaultVibrator
                vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(durationMs)
                }
            }
            return newFixedLengthResponse(Response.Status.OK, "application/json", JSONObject().put("success", true).toString())
        } catch (e: Exception) {
            return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "application/json", JSONObject().put("error", e.message).toString())
        }
    }

    private fun handleSensor(session: IHTTPSession): Response {
        val typeParam = session.parameters["type"]?.firstOrNull() ?: "accelerometer"
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        
        val type = when (typeParam) {
            "accelerometer" -> Sensor.TYPE_ACCELEROMETER
            "gyroscope" -> Sensor.TYPE_GYROSCOPE
            "magnetometer" -> Sensor.TYPE_MAGNETIC_FIELD
            "barometer" -> Sensor.TYPE_PRESSURE
            else -> Sensor.TYPE_ACCELEROMETER
        }
        
        val sensor = sensorManager.getDefaultSensor(type)
            ?: return newFixedLengthResponse(
                Response.Status.BAD_REQUEST, "application/json",
                JSONObject().put("error", "Sensor $typeParam not available").toString()
            )

        // Sensors require asynchronous listeners, but NanoHTTPD expects synchronous returns.
        // We'll block up to 2 seconds waiting for the first reading.
        var resultJson: JSONObject? = null
        val lock = Object()
        
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent?) {
                if (event != null && resultJson == null) {
                    val data = JSONObject().apply {
                        put("sensor", typeParam)
                        put("timestamp", event.timestamp)
                        put("accuracy", event.accuracy)
                        
                        when (typeParam) {
                            "accelerometer", "gyroscope", "magnetometer" -> {
                                put("x", event.values[0].toDouble())
                                put("y", event.values[1].toDouble())
                                put("z", event.values[2].toDouble())
                            }
                            "barometer" -> {
                                put("pressure", event.values[0].toDouble())
                            }
                        }
                    }
                    resultJson = data
                    synchronized(lock) { lock.notify() }
                }
            }
            override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
        }

        sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        
        synchronized(lock) {
            if (resultJson == null) {
                try { lock.wait(2000) } catch (e: InterruptedException) {}
            }
        }
        
        sensorManager.unregisterListener(listener)

        return if (resultJson != null) {
            newFixedLengthResponse(Response.Status.OK, "application/json", resultJson.toString())
        } else {
            newFixedLengthResponse(Response.Status.REQUEST_TIMEOUT, "application/json", 
                JSONObject().put("error", "Sensor read timed out").toString())
        }
    }
}
