package com.openclaw.plawie

import android.util.Log
import java.io.File
import java.io.FileOutputStream
import android.os.Environment

import android.app.Notification
import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.content.IntentFilter
import android.graphics.drawable.Icon
import android.net.Uri
import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Geocoder
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest
import android.app.AlarmManager
import android.os.BatteryManager
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import java.util.Locale
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.openclaw.plawie/native"
    private val EVENT_CHANNEL = "com.openclaw.plawie/gateway_logs"
    companion object {
        const val ACTION_PIP_MIC = "com.openclaw.plawie.ACTION_PIP_MIC"
        const val ACTION_DEBUG_NATIVE_FULL_GATEWAY_BOOTSTRAP =
            "com.openclaw.plawie.DEBUG_NATIVE_FULL_GATEWAY_BOOTSTRAP"
        const val ACTION_DEBUG_NATIVE_FULL_GATEWAY_PRODUCTION =
            "com.openclaw.plawie.DEBUG_NATIVE_FULL_GATEWAY_PRODUCTION"
        const val URL_CHANNEL_ID = "openclaw_urls"
        const val NOTIFICATION_PERMISSION_REQUEST = 1001
        const val SCREEN_CAPTURE_REQUEST = 1002
        const val GIF_IMPORT_REQUEST = 1003
    }

    private lateinit var bootstrapManager: BootstrapManager
    private lateinit var processManager: ProcessManager
    private lateinit var nativeNodeSmokeProcess: NativeNodeSmokeProcess
    private lateinit var secureEvmWalletManager: SecureEvmWalletManager
    private var screenCaptureResult: MethodChannel.Result? = null
    private var gifImportResult: MethodChannel.Result? = null
    private var screenCaptureDurationMs: Long = 5000L
    private var wakeLock: PowerManager.WakeLock? = null
    private var pipMethodChannel: MethodChannel? = null
    private var nativeTts: TextToSpeech? = null
    private var nativeTtsReady: Boolean = false
    private var debugNativeFullGatewayBootstrapStarted: Boolean = false
    private var debugNativeFullGatewayProductionStarted: Boolean = false
    private val managedCliAllowlist = setOf(
        "eightctl",
        "blu",
        "himalaya",
        "openhue",
        "sonos",
        "wacli",
        "songsee",
        "gifgrep",
        "ffmpeg",
        "whisper",
        "sherpa-onnx",
        "tmux",
        "coding-agent",
        "opencode"
    )

    // Wake word EventChannel sink — receives "wake_word_detected" events from HotwordService
    private var hotwordEventSink: EventChannel.EventSink? = null
    private var methodChannel: MethodChannel? = null

    // Network Callback to notify Flutter of connectivity changes
    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            runOnUiThread {
                methodChannel?.invokeMethod("onNetworkChanged", true)
            }
        }
        override fun onLost(network: Network) {
            runOnUiThread {
                methodChannel?.invokeMethod("onNetworkChanged", false)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        handleDebugNativeFullGatewayBootstrapIntent(intent)
        super.onCreate(savedInstanceState)
    }

    // BroadcastReceiver that relays HotwordService detections to Flutter via EventChannel
    private val wakeWordReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == HotwordService.ACTION_WAKE_WORD_DETECTED) {
                Log.i("MainActivity", "Wake word detected — notifying Flutter")
                hotwordEventSink?.success("wake_word_detected")
            }
        }
    }

    // BroadcastReceiver that captures the PIP mic button tap
    private val pipMicReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_PIP_MIC) {
                Log.i("MainActivity", "PIP Mic button tapped — forwarding to Flutter")
                pipMethodChannel?.invokeMethod("toggleMicFromPip", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val filesDir = applicationContext.filesDir.absolutePath
        val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir

        processManager = ProcessManager(applicationContext, filesDir, nativeLibDir)
        bootstrapManager = BootstrapManager(applicationContext, filesDir, nativeLibDir, processManager)
        nativeNodeSmokeProcess = NativeNodeSmokeProcess(applicationContext, nativeLibDir)
        secureEvmWalletManager = SecureEvmWalletManager(this)
        handleDebugNativeFullGatewayBootstrapIntent(intent)

        pipMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vrm/pip_mode")
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "plawie/native_tts"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val speed = (call.argument<Double>("speed") ?: 1.0).toFloat()
                    speakNativeTts(text, speed, result)
                }
                "stop" -> {
                    nativeTts?.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Register the PIP mic broadcast receiver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pipMicReceiver, IntentFilter(ACTION_PIP_MIC), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(pipMicReceiver, IntentFilter(ACTION_PIP_MIC))
        }

        pipMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPictureInPictureMode" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val params = android.app.PictureInPictureParams.Builder()
                                .setAspectRatio(android.util.Rational(3, 4))
                                .setActions(buildPipActions(false))
                                .build()
                            val success = enterPictureInPictureMode(params)
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("PIP_ERROR", e.message, null)
                        }
                    } else {
                        result.error("UNSUPPORTED", "PiP requires Android O+", null)
                    }
                }
                "updatePipMicState" -> {
                    val isListening = call.arguments as? Boolean ?: false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val params = android.app.PictureInPictureParams.Builder()
                                .setAspectRatio(android.util.Rational(3, 4))
                                .setActions(buildPipActions(isListening))
                                .build()
                            setPictureInPictureParams(params)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).let { channel ->
            methodChannel = channel
            channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSecureEvmWalletStatus" -> {
                    result.success(secureEvmWalletManager.status())
                }
                "createSecureEvmWallet" -> {
                    secureEvmWalletManager.createWallet(result)
                }
                "importSecureEvmWallet" -> {
                    secureEvmWalletManager.importWallet(
                        call.argument<ByteArray>("privateKey"),
                        result,
                    )
                }
                "signSecureEvmTransaction" -> {
                    secureEvmWalletManager.signTransaction(
                        call.arguments as? Map<*, *>,
                        result,
                    )
                }
                "signSecureX402Authorization" -> {
                    secureEvmWalletManager.signX402Authorization(
                        call.arguments as? Map<*, *>,
                        result,
                    )
                }
                "showSecureEvmWalletBackup" -> {
                    secureEvmWalletManager.showPrivateKeyBackup(result)
                }
                "deleteSecureEvmWallet" -> {
                    secureEvmWalletManager.deleteWallet(result)
                }
                "getProotPath" -> {
                    result.success(processManager.getProotPath())
                }
                "getArch" -> {
                    result.success(ArchUtils.getArch())
                }
                "getFilesDir" -> {
                    result.success(filesDir)
                }
                "pickGif" -> {
                    if (gifImportResult != null) {
                        result.error("GIF_PICKER_BUSY", "A GIF picker request is already active.", null)
                    } else {
                        gifImportResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/gif"
                        }
                        startActivityForResult(intent, GIF_IMPORT_REQUEST)
                    }
                }
                "getNativeLibDir" -> {
                    result.success(nativeLibDir)
                }
                "getDeviceId" -> {
                    val androidId = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID
                    )
                    result.success(androidId ?: "unknown")
                }
                "getDeviceBrand" -> {
                    result.success(Build.BRAND ?: Build.MANUFACTURER ?: "unknown")
                }
                "getDeviceModel" -> {
                    result.success(Build.MODEL ?: "unknown")
                }
                "getAppVersion" -> {
                    try {
                        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(
                                packageName,
                                PackageManager.PackageInfoFlags.of(0)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        result.success(info.versionName ?: "unknown")
                    } catch (e: Exception) {
                        result.success("unknown")
                    }
                }
                "isBootstrapComplete" -> {
                    result.success(bootstrapManager.isBootstrapComplete())
                }
                "markBootstrapComplete" -> {
                    try {
                        val marker = java.io.File(filesDir, "setup/.bootstrap_complete")
                        marker.parentFile?.mkdirs()
                        marker.writeText("completed_${System.currentTimeMillis()}")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MARKER_ERROR", e.message, null)
                    }
                }
                "getBootstrapStatus" -> {
                    result.success(bootstrapManager.getBootstrapStatus())
                }
                "ensureOpenClawReady" -> {
                    result.success(bootstrapManager.ensureOpenClawReady())
                }
                "provisionOfficialOpenClaw" -> {
                    Thread {
                        try {
                            val requestId = OfficialOpenClawProvisioner
                                .createIsolatedProvisionRequest(this)
                            OfficialOpenClawInstallService.start(this, requestId)
                            val provisioned = OfficialOpenClawProvisioner
                                .awaitIsolatedProvisionResult(this, requestId)
                            runOnUiThread { result.success(provisioned) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error(
                                    "OFFICIAL_OPENCLAW_INSTALL_ERROR",
                                    e.message,
                                    null
                                )
                            }
                        }
                    }.start()
                }
                "getNativeOpenClawStatus" -> {
                    val status = OfficialOpenClawProvisioner.nativePackageStatus(this)
                    result.success(
                        mapOf(
                            "ready" to status.ready,
                            "version" to (status.version ?: ""),
                            "receiptVersion" to (status.receiptVersion ?: ""),
                            "receiptIntegrity" to (status.receiptIntegrity ?: "")
                        )
                    )
                }
                "getOfficialOpenClawProvisionStatus" -> {
                    result.success(
                        OfficialOpenClawProvisioner
                            .isolatedProvisionStatusForChannel(this)
                    )
                }
                "ensureAgentSkillsAwareness" -> {
                    Thread {
                        try {
                            bootstrapManager.ensureAgentSkillsAwareness()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("SKILLS_AWARENESS_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "extractRootfs" -> {
                    val tarPath = call.argument<String>("tarPath")
                    if (tarPath != null) {
                        Thread {
                            try {
                                bootstrapManager.extractRootfs(tarPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("EXTRACT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "tarPath required", null)
                    }
                }
                "runInProot" -> {
                    val command = call.argument<String>("command")
                    val timeout = call.argument<Int>("timeout")?.toLong() ?: 900L
                    if (command != null) {
                        Thread {
                            try {
                                val output = processManager.runInProotSync(command, timeout)
                                runOnUiThread { result.success(output) }
                            } catch (e: Exception) {
                                Log.e("MainActivity", "runInProot failed: command=$command", e)
                                runOnUiThread { result.error("PROOT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "command required", null)
                    }
                }
                "executeInShell" -> {
                    val command = call.argument<String>("command")
                    val timeoutMs = call.argument<Int>("timeoutMs")?.toLong() ?: 30000L
                    if (command != null) {
                        Thread {
                            try {
                                val output = processManager.executeInShell(command, timeoutMs)
                                runOnUiThread { result.success(output) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("SHELL_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "command required", null)
                    }
                }
                "runNativePython" -> {
                    val payloadJson = call.argument<String>("payloadJson") ?: "{}"
                    Thread {
                        try {
                            val output = runOpenClawNativePython(payloadJson)
                            runOnUiThread { result.success(output) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("NATIVE_PYTHON_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "runManagedFfmpeg" -> {
                    val rawArgs = call.argument<List<*>>("args") ?: emptyList<Any>()
                    val timeoutSeconds = call.argument<Int>("timeoutSeconds")?.toLong() ?: 30L
                    Thread {
                        try {
                            val output = runManagedFfmpeg(
                                rawArgs.map { it?.toString() ?: "" },
                                timeoutSeconds
                            )
                            runOnUiThread { result.success(output) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("MANAGED_FFMPEG_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "runManagedCli" -> {
                    val binName = call.argument<String>("binName") ?: ""
                    val rawArgs = call.argument<List<*>>("args") ?: emptyList<Any>()
                    val rawEnv = call.argument<Map<*, *>>("env") ?: emptyMap<Any, Any>()
                    val timeoutSeconds = call.argument<Int>("timeoutSeconds")?.toLong() ?: 20L
                    Thread {
                        try {
                            val output = runManagedCli(
                                binName,
                                rawArgs.map { it?.toString() ?: "" },
                                rawEnv.mapKeys { it.key?.toString() ?: "" }
                                    .mapValues { it.value?.toString() ?: "" },
                                timeoutSeconds
                            )
                            runOnUiThread { result.success(output) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("MANAGED_CLI_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                "destroyShell" -> {
                    processManager.destroyShell()
                    result.success(true)
                }
                "startGateway" -> {
                    try {
                        if (debugNativeFullGatewayProductionStarted) {
                            Log.i(
                                "MainActivity",
                                "startGateway ignored while native full Gateway production debug run is active"
                            )
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val allowDuringSetup = call.argument<Boolean>("allowDuringSetup") ?: false
                        if (!allowDuringSetup && !SetupGuards.canAutomateGateway(this)) {
                            Log.i("MainActivity", "startGateway ignored until setup completes")
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        if (!SetupGuards.isProotGatewayOwner(this)) {
                            Log.i(
                                "MainActivity",
                                "startGateway ignored because native Gateway owns production by default; " +
                                    "PRoot foreground service was not started"
                            )
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        PlawieForegroundService.start(this)
                        val success = processManager.startGateway()
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopGateway" -> {
                    try {
                        val success = processManager.stopGateway()
                        PlawieForegroundService.stop(this)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isGatewayRunning" -> {
                    // Native health probes open a loopback HTTP connection and
                    // inspect process state. Keep that work off Android's UI
                    // thread so node readiness polling cannot stall Flutter.
                    Thread {
                        val running = if (SetupGuards.isNativeGatewayOwner(this)) {
                            nativeNodeSmokeProcess.isFullGatewayProductionRunning()
                        } else {
                            processManager.isGatewayRunning()
                        }
                        runOnUiThread { result.success(running) }
                    }.start()
                }
                "getGatewayLogs" -> {
                    result.success(processManager.getRecentLogs())
                }
                "startNativeGatewaySmokeRuntime" -> {
                    result.success(NativeGatewaySmokeServer.startServer(applicationContext))
                }
                "stopNativeGatewaySmokeRuntime" -> {
                    result.success(NativeGatewaySmokeServer.stopServer())
                }
                "isNativeGatewaySmokeRuntimeRunning" -> {
                    result.success(NativeGatewaySmokeServer.isRunning())
                }
                "getNativeGatewaySmokeRuntimeLogs" -> {
                    result.success(NativeGatewaySmokeServer.getRecentLogs())
                }
                "startNativeNodeSmokeRuntime" -> {
                    if (debugNativeFullGatewayBootstrapStarted) {
                        result.success(nativeNodeSmokeProcess.startFullGatewayBootstrap())
                    } else {
                        result.success(nativeNodeSmokeProcess.start())
                    }
                }
                "startNativeNodeProductionPortCanaryRuntime" -> {
                    result.success(nativeNodeSmokeProcess.startProductionPortCanary())
                }
                "startNativeNodeFullGatewayBootstrapRuntime" -> {
                    result.success(nativeNodeSmokeProcess.startFullGatewayBootstrap())
                }
                "startNativeNodeFullGatewayProductionRuntime" -> {
                    debugNativeFullGatewayProductionStarted = true
                    result.success(nativeNodeSmokeProcess.startFullGatewayProduction())
                }
                "stopNativeNodeSmokeRuntime" -> {
                    val stopped = nativeNodeSmokeProcess.stop()
                    if (debugNativeFullGatewayBootstrapStarted ||
                        debugNativeFullGatewayProductionStarted
                    ) {
                        Log.i(
                            "MainActivity",
                            "Clearing native full Gateway debug ownership after stop request " +
                                "stopped=$stopped"
                        )
                    }
                    debugNativeFullGatewayBootstrapStarted = false
                    debugNativeFullGatewayProductionStarted = false
                    result.success(stopped)
                }
                "promoteNativeGatewayNotification" -> {
                    NativeNodeEmbeddedService.promoteGatewayNotification(applicationContext)
                    result.success(true)
                }
                "isNativeNodeSmokeRuntimeRunning" -> {
                    result.success(nativeNodeSmokeProcess.isRunning())
                }
                "isNativeNodeProductionPortCanaryRuntimeRunning" -> {
                    result.success(nativeNodeSmokeProcess.isProductionPortCanaryRunning())
                }
                "isNativeNodeFullGatewayBootstrapRuntimeRunning" -> {
                    result.success(nativeNodeSmokeProcess.isFullGatewayBootstrapRunning())
                }
                "isNativeNodeFullGatewayProductionRuntimeRunning" -> {
                    result.success(nativeNodeSmokeProcess.isFullGatewayProductionRunning())
                }
                "isNativeNodeIsolatedProcessAlive" -> {
                    result.success(nativeNodeSmokeProcess.isIsolatedProcessAlive())
                }
                "getNativeNodeSmokeRuntimeLogs" -> {
                    result.success(nativeNodeSmokeProcess.getRecentLogs())
                }
                "startNativeNodeSkillRunnerRuntime" -> {
                    result.success(NativeNodeSkillRunnerService.start(applicationContext))
                }
                "stopNativeNodeSkillRunnerRuntime" -> {
                    result.success(NativeNodeSkillRunnerService.stop(applicationContext))
                }
                "getNativeNodeSkillRunnerRuntimeLogs" -> {
                    result.success(
                        NativeNodeSkillRunnerService.getRecentLogs(applicationContext)
                    )
                }
                "startTerminalService" -> {
                    try {
                        TerminalSessionService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopTerminalService" -> {
                    try {
                        TerminalSessionService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isTerminalServiceRunning" -> {
                    result.success(TerminalSessionService.isRunning)
                }
                "startNodeService" -> {
                    try {
                        result.success(NodeForegroundService.start(applicationContext))
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopNodeService" -> {
                    try {
                        NodeForegroundService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isNodeServiceRunning" -> {
                    result.success(NodeForegroundService.isRunning)
                }
                "updateNodeNotification" -> {
                    val text = call.argument<String>("text") ?: "Node connected"
                    NodeForegroundService.updateStatus(text)
                    result.success(true)
                }
                "requestBatteryOptimization" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${packageName}")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                }
                "isBatteryOptimized" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                }
                "checkStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else {
                        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    }
                }
                "requestStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:${packageName}")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivity(intent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("STORAGE_ERROR", e2.message, null)
                            }
                        }
                    } else {
                        ActivityCompat.requestPermissions(this, arrayOf(
                            Manifest.permission.READ_EXTERNAL_STORAGE,
                            Manifest.permission.WRITE_EXTERNAL_STORAGE
                        ), 1003)
                        result.success(true)
                    }
                }
                "getTotalMemoryMb" -> {
                    val actManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val memInfo = ActivityManager.MemoryInfo()
                    actManager.getMemoryInfo(memInfo)
                    val totalMemory = memInfo.totalMem / (1024 * 1024)
                    result.success(totalMemory.toInt())
                }
                "acquirePartialWakeLock" -> {
                    try {
                        if (wakeLock == null) {
                            val pm = getSystemService(POWER_SERVICE) as PowerManager
                            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "OpenClaw::NativeWakeLock")
                        }
                        if (wakeLock?.isHeld == false) {
                            wakeLock?.acquire(24 * 60 * 60 * 1000L) // 24 hours
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERROR", e.message, null)
                    }
                }
                "releasePartialWakeLock" -> {
                    try {
                        if (wakeLock?.isHeld == true) {
                            wakeLock?.release()
                        }
                        wakeLock = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WAKELOCK_ERROR", e.message, null)
                    }
                }
                "setupDirs" -> {
                    Thread {
                        try {
                            bootstrapManager.setupDirectories()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SETUP_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "installBionicBypass" -> {
                    Thread {
                        try {
                            bootstrapManager.installBionicBypass()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("BYPASS_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "writeResolv" -> {
                    Thread {
                        try {
                            bootstrapManager.writeResolvConf()
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("RESOLV_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "extractDebPackages" -> {
                    Thread {
                        try {
                            val count = bootstrapManager.extractDebPackages()
                            runOnUiThread { result.success(count) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("DEB_EXTRACT_ERROR", e.message, null) }
                        }
                    }.start()
                }
                "extractNodeTarball" -> {
                    val tarPath = call.argument<String>("tarPath")
                    if (tarPath != null) {
                        Thread {
                            try {
                                bootstrapManager.extractNodeTarball(tarPath)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("NODE_EXTRACT_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "tarPath required", null)
                    }
                }
                "createBinWrappers" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        Thread {
                            try {
                                bootstrapManager.createBinWrappers(packageName)
                                runOnUiThread { result.success(true) }
                            } catch (e: Exception) {
                                Log.e("MainActivity", "createBinWrappers failed", e)
                                runOnUiThread { result.error("BIN_WRAPPER_ERROR", e.message, null) }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "packageName required", null)
                    }
                }
                "startSetupService" -> {
                    try {
                        SetupService.start(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "updateSetupNotification" -> {
                    val text = call.argument<String>("text")
                    val progress = call.argument<Int>("progress") ?: -1
                    if (text != null) {
                        SetupService.updateNotification(text, progress)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                "stopSetupService" -> {
                    try {
                        SetupService.stop(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "showUrlNotification" -> {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title") ?: "URL Detected"
                    if (url != null) {
                        showUrlNotification(url, title)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "url required", null)
                    }
                }
                "copyToClipboard" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("URL", text))
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "text required", null)
                    }
                }
                "requestScreenCapture" -> {
                    val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 5000L
                    screenCaptureResult = result
                    screenCaptureDurationMs = durationMs
                    ScreenCaptureService.clearResult()
                    val projectionManager =
                        getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    startActivityForResult(
                        projectionManager.createScreenCaptureIntent(),
                        SCREEN_CAPTURE_REQUEST
                    )
                }
                "stopScreenCapture" -> {
                    try {
                        stopService(Intent(applicationContext, ScreenCaptureService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "getBatteryLevel" -> {
                    val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                    val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                    val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                    val percent = if (level >= 0 && scale > 0) (level * 100) / scale else level
                    result.success(percent)
                }
                "isCharging" -> {
                    val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                    val status = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                    val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL
                    result.success(charging)
                }
                "reverseGeocode" -> {
                    val lat = call.argument<Double>("lat")
                    val lng = call.argument<Double>("lng")
                    if (lat == null || lng == null) {
                        result.error("INVALID_ARGS", "lat and lng required", null)
                    } else {
                        Thread {
                            try {
                                @Suppress("DEPRECATION")
                                val addresses = Geocoder(applicationContext, Locale.getDefault())
                                    .getFromLocation(lat, lng, 1)
                                val first = addresses?.firstOrNull()
                                val payload = hashMapOf<String, Any?>(
                                    "available" to (first != null),
                                    "lat" to lat,
                                    "lng" to lng
                                )
                                if (first != null) {
                                    payload["address"] = first.getAddressLine(0) ?: ""
                                    payload["locality"] = first.locality ?: ""
                                    payload["adminArea"] = first.adminArea ?: ""
                                    payload["country"] = first.countryName ?: ""
                                    payload["postalCode"] = first.postalCode ?: ""
                                }
                                runOnUiThread { result.success(payload) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.success(hashMapOf<String, Any?>(
                                        "available" to false,
                                        "lat" to lat,
                                        "lng" to lng,
                                        "error" to (e.message ?: e.toString())
                                    ))
                                }
                            }
                        }.start()
                    }
                }
                "vibrate" -> {
                    val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 200L
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val vibratorManager =
                                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                            val vibrator = vibratorManager.defaultVibrator
                            vibrator.vibrate(
                                VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator.vibrate(
                                    VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                vibrator.vibrate(durationMs)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VIBRATE_ERROR", e.message, null)
                    }
                }
                "readSensor" -> {
                    val sensorType = call.argument<String>("sensor") ?: "accelerometer"
                    Thread {
                        try {
                            val sensorManager =
                                getSystemService(Context.SENSOR_SERVICE) as SensorManager
                            val type = when (sensorType) {
                                "accelerometer" -> Sensor.TYPE_ACCELEROMETER
                                "gyroscope" -> Sensor.TYPE_GYROSCOPE
                                "magnetometer" -> Sensor.TYPE_MAGNETIC_FIELD
                                "barometer" -> Sensor.TYPE_PRESSURE
                                else -> Sensor.TYPE_ACCELEROMETER
                            }
                            val sensor = sensorManager.getDefaultSensor(type)
                            if (sensor == null) {
                                runOnUiThread {
                                    result.error("SENSOR_ERROR", "Sensor $sensorType not available", null)
                                }
                                return@Thread
                            }
                            var received = false
                            val listener = object : SensorEventListener {
                                override fun onSensorChanged(event: SensorEvent?) {
                                    if (received || event == null) return
                                    received = true
                                    sensorManager.unregisterListener(this)
                                    val data = hashMapOf<String, Any>(
                                        "sensor" to sensorType,
                                        "timestamp" to event.timestamp,
                                        "accuracy" to event.accuracy
                                    )
                                    when (sensorType) {
                                        "accelerometer", "gyroscope", "magnetometer" -> {
                                            data["x"] = event.values[0].toDouble()
                                            data["y"] = event.values[1].toDouble()
                                            data["z"] = event.values[2].toDouble()
                                        }
                                        "barometer" -> {
                                            data["pressure"] = event.values[0].toDouble()
                                        }
                                    }
                                    runOnUiThread { result.success(data) }
                                }
                                override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
                            }
                            sensorManager.registerListener(
                                listener, sensor, SensorManager.SENSOR_DELAY_NORMAL
                            )
                            // Timeout after 3 seconds
                            Thread.sleep(3000)
                            if (!received) {
                                sensorManager.unregisterListener(listener)
                                runOnUiThread {
                                    result.error("SENSOR_ERROR", "Sensor read timed out", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SENSOR_ERROR", e.message, null) }
                        }
                    }.start()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        }

        createUrlNotificationChannel()
        requestNotificationPermission()
        registerNetworkCallback()
        HeartbeatWorker.schedule(this) // PROD UPGRADE: Background heartbeat watchdog
        scheduleExactAlarm()           // DOZE FIX: AlarmManager fallback

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    processManager.startLogStreaming(events)
                }
                override fun onCancel(arguments: Any?) {
                    processManager.stopLogStreaming()
                }
            }
        )

        // Canvas screenshot capture using PixelCopy on the embedded WebView.
        CanvasScreenshotManager.register(this, flutterEngine.dartExecutor.binaryMessenger)
        // The WebView is located by walking the activity content view hierarchy;
        // no view-id lookup is required.

        // Register wake word broadcast receiver
        val wakeFilter = IntentFilter(HotwordService.ACTION_WAKE_WORD_DETECTED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(wakeWordReceiver, wakeFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(wakeWordReceiver, wakeFilter)
        }

        // EventChannel: Flutter subscribes to receive wake word events
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.openclaw.plawie/hotword_events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                hotwordEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                hotwordEventSink = null
            }
        })

        // MethodChannel: Flutter controls the HotwordService
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.openclaw.plawie/hotword"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startHotword" -> {
                    val intent = Intent(applicationContext, HotwordService::class.java)
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("HOTWORD_ERROR", e.message, null)
                    }
                }
                "stopHotword" -> {
                    stopService(Intent(applicationContext, HotwordService::class.java))
                    result.success(true)
                }
                "setHotwordMode" -> {
                    val mode = call.argument<String>("mode") ?: "foreground"
                    val intent = Intent(applicationContext, HotwordService::class.java).apply {
                        action = HotwordService.ACTION_SET_MODE
                        putExtra("mode", mode)
                    }
                    if (mode == "off") {
                        stopService(Intent(applicationContext, HotwordService::class.java))
                    } else {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                        } catch (e: Exception) {
                            result.error("HOTWORD_ERROR", e.message, null)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(true)
                }
                "isHotwordRunning" -> result.success(HotwordService.isRunning)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDebugNativeFullGatewayBootstrapIntent(intent)
    }

    private fun handleDebugNativeFullGatewayBootstrapIntent(intent: Intent?) {
        val action = intent?.action
        val productionMode = action == ACTION_DEBUG_NATIVE_FULL_GATEWAY_PRODUCTION
        if (action != ACTION_DEBUG_NATIVE_FULL_GATEWAY_BOOTSTRAP && !productionMode) return
        if (
            (!productionMode && debugNativeFullGatewayBootstrapStarted) ||
            (productionMode && debugNativeFullGatewayProductionStarted)
        ) {
            Log.i("MainActivity", "Native full Gateway debug intent already handled")
            return
        }

        val isDebuggable =
            (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) {
            Log.w("MainActivity", "Ignoring native full Gateway bootstrap debug intent in release build")
            return
        }

        if (!::nativeNodeSmokeProcess.isInitialized) {
            nativeNodeSmokeProcess =
                NativeNodeSmokeProcess(applicationContext, applicationInfo.nativeLibraryDir)
        }

        if (productionMode) {
            debugNativeFullGatewayProductionStarted = true
        } else {
            debugNativeFullGatewayBootstrapStarted = true
        }
        Log.i(
            "MainActivity",
            "Handling native full Gateway debug intent productionMode=$productionMode"
        )
        Thread {
            val started = if (productionMode) {
                nativeNodeSmokeProcess.startFullGatewayProduction()
            } else {
                nativeNodeSmokeProcess.startFullGatewayBootstrap()
            }
            Log.i(
                "MainActivity",
                "Debug native full Gateway intent handled; productionMode=$productionMode started=$started"
            )
        }.start()
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST
                )
            }
        }
    }

    private fun runOpenClawNativePython(payloadJson: String): String {
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(applicationContext))
        }
        val py = Python.getInstance()
        return py.getModule("openclaw_python_runner")
            .callAttr("run", payloadJson)
            .toString()
    }

    private fun runManagedFfmpeg(args: List<String>, timeoutSeconds: Long): Map<String, Any> {
        if (args.size > 64) {
            throw IllegalArgumentException("Too many ffmpeg arguments.")
        }
        if (args.any { it.isBlank() || it.contains('\u0000') }) {
            throw IllegalArgumentException("Unsafe ffmpeg argument.")
        }

        val managedBin = File(
            filesDir,
            "native-node-embedded/native-home/.openclaw/bin"
        ).canonicalFile
        val managedLib = File(
            filesDir,
            "native-node-embedded/native-home/.openclaw/lib"
        ).canonicalFile
        val ffmpeg = File(managedBin, "ffmpeg").canonicalFile
        if (!ffmpeg.path.startsWith(managedBin.path + File.separator)) {
            throw IllegalStateException("Resolved ffmpeg path escaped managed bin.")
        }
        if (!ffmpeg.exists()) {
            throw IllegalStateException(
                "ffmpeg is missing from android-vision-media-runtime."
            )
        }
        if (!ffmpeg.canExecute()) {
            ffmpeg.setExecutable(true, false)
        }
        if (!ffmpeg.canExecute()) {
            throw IllegalStateException("ffmpeg is not executable.")
        }

        val command = managedNativeElfCommand(ffmpeg, args)
        val process = ProcessBuilder(command)
            .directory(cacheDir)
            .redirectErrorStream(false)
            .apply {
                val inheritedPath = System.getenv("PATH") ?: "/system/bin:/system/xbin"
                val inheritedLdPath = System.getenv("LD_LIBRARY_PATH").orEmpty()
                environment()["PATH"] = "${managedBin.absolutePath}:$inheritedPath"
                environment()["LD_LIBRARY_PATH"] =
                    if (inheritedLdPath.isBlank()) managedLib.absolutePath
                    else "${managedLib.absolutePath}:$inheritedLdPath"
                environment()["OPENCLAW_NATIVE_MANAGED_BIN"] = managedBin.absolutePath
                environment()["TMPDIR"] = cacheDir.absolutePath
            }
            .start()

        val stdout = StringBuilder()
        val stderr = StringBuilder()
        val stdoutThread = Thread {
            stdout.append(readProcessStreamBounded(process.inputStream, 64 * 1024))
        }
        val stderrThread = Thread {
            stderr.append(readProcessStreamBounded(process.errorStream, 64 * 1024))
        }
        stdoutThread.start()
        stderrThread.start()

        val boundedTimeout = timeoutSeconds.coerceIn(1L, 120L)
        val finished = process.waitFor(boundedTimeout, TimeUnit.SECONDS)
        if (!finished) {
            process.destroyForcibly()
        }
        stdoutThread.join(1000L)
        stderrThread.join(1000L)

        return mapOf(
            "exitCode" to if (finished) process.exitValue() else 124,
            "stdout" to stdout.toString(),
            "stderr" to stderr.toString(),
            "binaryPath" to ffmpeg.absolutePath
        )
    }

    private fun runManagedCli(
        binName: String,
        args: List<String>,
        env: Map<String, String>,
        timeoutSeconds: Long
    ): Map<String, Any> {
        val safeBin = binName.trim()
        val binPattern = Regex("^[a-z0-9][a-z0-9._-]{0,63}$")
        val envKeyPattern = Regex("^[A-Z_][A-Z0-9_]{0,127}$")
        if (!binPattern.matches(safeBin) || !managedCliAllowlist.contains(safeBin)) {
            throw IllegalArgumentException("Managed CLI is not allowlisted: $safeBin")
        }
        if (args.size > 64) {
            throw IllegalArgumentException("Too many managed CLI arguments.")
        }
        if (args.any { it.isBlank() || it.contains('\u0000') }) {
            throw IllegalArgumentException("Unsafe managed CLI argument.")
        }
        if (env.size > 64) {
            throw IllegalArgumentException("Too many managed CLI environment values.")
        }
        if (env.any { (key, value) ->
                !envKeyPattern.matches(key) || value.contains('\u0000') || value.length > 16 * 1024
            }) {
            throw IllegalArgumentException("Unsafe managed CLI environment value.")
        }

        val nativeHome = File(filesDir, "native-node-embedded/native-home").canonicalFile
        val managedBin = File(nativeHome, ".openclaw/bin").canonicalFile
        val managedLib = File(nativeHome, ".openclaw/lib").canonicalFile
        val binary = File(managedBin, safeBin).canonicalFile
        if (!binary.path.startsWith(managedBin.path + File.separator)) {
            throw IllegalStateException("Resolved managed CLI path escaped managed bin.")
        }
        if (!binary.exists()) {
            throw IllegalStateException("$safeBin is missing from managed Android CLI packs.")
        }
        if (!binary.canExecute()) {
            binary.setExecutable(true, false)
        }
        if (!binary.canExecute()) {
            throw IllegalStateException("$safeBin is not executable.")
        }

        nativeHome.mkdirs()
        cacheDir.mkdirs()
        val command = managedNativeElfCommand(binary, args)
        val process = ProcessBuilder(command)
            .directory(nativeHome)
            .redirectErrorStream(false)
            .apply {
                val inheritedPath = System.getenv("PATH") ?: "/system/bin:/system/xbin"
                val inheritedLdPath = System.getenv("LD_LIBRARY_PATH").orEmpty()
                environment()["PATH"] = "${managedBin.absolutePath}:$inheritedPath"
                environment()["LD_LIBRARY_PATH"] =
                    if (inheritedLdPath.isBlank()) managedLib.absolutePath
                    else "${managedLib.absolutePath}:$inheritedLdPath"
                environment()["HOME"] = nativeHome.absolutePath
                environment()["XDG_CONFIG_HOME"] = File(nativeHome, ".config").absolutePath
                environment()["OPENCLAW_HOME"] = File(nativeHome, ".openclaw").absolutePath
                environment()["OPENCLAW_NATIVE_MANAGED_BIN"] = managedBin.absolutePath
                environment()["TMPDIR"] = cacheDir.absolutePath
                if (safeBin == "coding-agent" || safeBin == "opencode") {
                    val tagFix = File(managedLib, "libtagfix.so")
                    if (tagFix.exists()) {
                        environment()["LD_PRELOAD"] = tagFix.absolutePath
                    }
                }
                env.forEach { (key, value) -> environment()[key] = value }
            }
            .start()

        val stdout = StringBuilder()
        val stderr = StringBuilder()
        val stdoutThread = Thread {
            stdout.append(readProcessStreamBounded(process.inputStream, 64 * 1024))
        }
        val stderrThread = Thread {
            stderr.append(readProcessStreamBounded(process.errorStream, 64 * 1024))
        }
        stdoutThread.start()
        stderrThread.start()

        val boundedTimeout = timeoutSeconds.coerceIn(1L, 120L)
        val finished = process.waitFor(boundedTimeout, TimeUnit.SECONDS)
        if (!finished) {
            process.destroyForcibly()
        }
        stdoutThread.join(1000L)
        stderrThread.join(1000L)

        return mapOf(
            "exitCode" to if (finished) process.exitValue() else 124,
            "stdout" to stdout.toString(),
            "stderr" to stderr.toString(),
            "binaryPath" to binary.absolutePath
        )
    }

    /**
     * Android SELinux denies execute_no_trans for downloaded ELF files in the
     * app data directory. The verified arm64 packs are Bionic binaries, so
     * launch them through Android's trusted 64-bit dynamic linker. This keeps
     * execution native while avoiding a shell or PRoot compatibility layer.
     */
    private fun managedNativeElfCommand(binary: File, args: List<String>): List<String> {
        val linker = File("/system/bin/linker64")
        if (!linker.isFile || !linker.canExecute()) {
            throw IllegalStateException(
                "Android 64-bit linker is unavailable for managed native packs."
            )
        }
        return listOf(linker.absolutePath, binary.absolutePath) + args
    }

    private fun readProcessStreamBounded(
        stream: java.io.InputStream,
        maxChars: Int
    ): String {
        val output = StringBuilder()
        stream.bufferedReader().use { reader ->
            val buffer = CharArray(4096)
            while (true) {
                val read = reader.read(buffer)
                if (read == -1) break
                val remaining = maxChars - output.length
                if (remaining > 0) {
                    output.append(buffer, 0, minOf(read, remaining))
                }
            }
        }
        return output.toString()
    }

    private fun speakNativeTts(text: String, speed: Float, result: MethodChannel.Result) {
        if (text.isBlank()) {
            result.success(false)
            return
        }

        fun speakNow(tts: TextToSpeech) {
            val utteranceId = "plawie_${System.currentTimeMillis()}"
            var completed = false
            fun finishSuccess(value: Boolean) {
                if (completed) return
                completed = true
                runOnUiThread { result.success(value) }
            }
            fun finishError(code: String, message: String?) {
                if (completed) return
                completed = true
                runOnUiThread { result.error(code, message, null) }
            }

            tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(doneId: String?) {
                    if (doneId == utteranceId) finishSuccess(true)
                }
                @Deprecated("Deprecated in Java")
                override fun onError(errorId: String?) {
                    if (errorId == utteranceId) finishError("TTS_ERROR", "Native TTS failed")
                }
                override fun onError(errorId: String?, errorCode: Int) {
                    if (errorId == utteranceId) finishError("TTS_ERROR", "Native TTS failed: $errorCode")
                }
                override fun onStop(stoppedId: String?, interrupted: Boolean) {
                    if (stoppedId == utteranceId) finishSuccess(false)
                }
            })

            tts.language = Locale.getDefault()
            tts.setSpeechRate(speed.coerceIn(0.5f, 2.0f))
            val params = Bundle().apply {
                putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId)
            }
            val code = tts.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
            if (code == TextToSpeech.ERROR) {
                finishError("TTS_ERROR", "Native TTS speak() returned ERROR")
            }
        }

        val existing = nativeTts
        if (existing != null && nativeTtsReady) {
            speakNow(existing)
            return
        }

        nativeTts = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                nativeTtsReady = true
                nativeTts?.let { speakNow(it) } ?: runOnUiThread {
                    result.error("TTS_ERROR", "Native TTS unavailable", null)
                }
            } else {
                nativeTtsReady = false
                runOnUiThread {
                    result.error("TTS_INIT_ERROR", "Native TTS initialization failed", null)
                }
            }
        }
    }

    private fun createUrlNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                URL_CHANNEL_ID,
                "OpenClaw URLs",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for detected URLs"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private var urlNotificationId = 100

    private fun showUrlNotification(url: String, title: String) {
        val openIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        val openPending = PendingIntent.getActivity(
            this, urlNotificationId, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, URL_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(url)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentIntent(openPending)
                .setAutoCancel(true)
                .setStyle(Notification.BigTextStyle().bigText(url))
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle(title)
                .setContentText(url)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentIntent(openPending)
                .setAutoCancel(true)
                .build()
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(urlNotificationId++, notification)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == GIF_IMPORT_REQUEST) {
            val callback = gifImportResult
            gifImportResult = null
            if (callback == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }
            val uri = data.data!!
            Thread {
                var target: File? = null
                try {
                    val mime = contentResolver.getType(uri)
                    if (mime != null && mime != "image/gif") {
                        throw IllegalArgumentException("Selected file is not a GIF.")
                    }
                    val targetDir = File(
                        filesDir,
                        "native-node-embedded/native-home/.openclaw/canvas/gifgrep/imported"
                    )
                    targetDir.mkdirs()
                    target = File(targetDir, "gif-${System.currentTimeMillis()}.gif")
                    var total = 0L
                    val buffer = ByteArray(32 * 1024)
                    contentResolver.openInputStream(uri).use { input ->
                        if (input == null) throw IllegalStateException("Could not read selected GIF.")
                        FileOutputStream(target!!).use { output ->
                            while (true) {
                                val count = input.read(buffer)
                                if (count <= 0) break
                                total += count
                                if (total > 20L * 1024L * 1024L) {
                                    throw IllegalArgumentException("GIF is larger than the 20 MB limit.")
                                }
                                output.write(buffer, 0, count)
                            }
                        }
                    }
                    runOnUiThread { callback.success(target.absolutePath) }
                } catch (error: Exception) {
                    target?.delete()
                    runOnUiThread {
                        callback.error("GIF_IMPORT_ERROR", error.message, null)
                    }
                }
            }.start()
            return
        }
        if (requestCode == SCREEN_CAPTURE_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val intent = Intent(applicationContext, ScreenCaptureService::class.java).apply {
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("durationMs", screenCaptureDurationMs)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                // Poll for result
                Thread {
                    val startTime = System.currentTimeMillis()
                    val timeout = screenCaptureDurationMs + 5000L
                    while (ScreenCaptureService.resultPath == null &&
                        System.currentTimeMillis() - startTime < timeout
                    ) {
                        Thread.sleep(200)
                    }
                    val path = ScreenCaptureService.resultPath
                    runOnUiThread {
                        screenCaptureResult?.success(path)
                        screenCaptureResult = null
                    }
                }.start()
            } else {
                screenCaptureResult?.success(null)
                screenCaptureResult = null
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: android.content.res.Configuration?
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pipMethodChannel?.invokeMethod("onPiPModeChanged", isInPictureInPictureMode)
    }

    private fun buildPipActions(isListening: Boolean): List<RemoteAction> {
        val micIntent = Intent(ACTION_PIP_MIC).setPackage(packageName)
        val micPendingIntent = PendingIntent.getBroadcast(
            this, 0, micIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Using standard Android icons. 
        // ic_btn_speak_now (outline) for idle
        // ic_lock_idle_lock (filled/different) for listening - or just a different title
        val iconRes = if (isListening) android.R.drawable.ic_lock_idle_lock else android.R.drawable.ic_btn_speak_now
        val title = if (isListening) "Listening..." else "Mic"
        
        val micAction = RemoteAction(
            Icon.createWithResource(this, iconRes),
            title,
            "Toggle microphone",
            micPendingIntent
        )
        // We can't easily tint RemoteAction icons dynamically in PiP without custom icons, 
        // but changing the icon resource and title provides clear feedback.
        return listOf(micAction)
    }

    private fun registerNetworkCallback() {
        try {
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val request = NetworkRequest.Builder().build()
            connectivityManager.registerNetworkCallback(request, networkCallback)
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to register network callback", e)
        }
    }

    private fun scheduleExactAlarm() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, BootReceiver::class.java).apply {
                action = "com.openclaw.plawie.ALARM_HEARTBEAT"
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this, 100, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Trigger every 30 minutes, even in Doze mode
            val triggerAt = SystemClock.elapsedRealtime() + 30 * 60 * 1000L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            }
            Log.i("MainActivity", "Scheduled 30-minute exact alarm for Doze mode.")
        } catch (e: Exception) {
            Log.w("MainActivity", "Could not schedule exact alarm: ${e.message}")
        }
    }

    override fun onDestroy() {
        try {
            val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            connectivityManager.unregisterNetworkCallback(networkCallback)
        } catch (_: Exception) {}
        try { unregisterReceiver(pipMicReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(wakeWordReceiver) } catch (_: Exception) {}
        try {
            nativeTts?.stop()
            nativeTts?.shutdown()
        } catch (_: Exception) {}
        nativeTts = null
        nativeTtsReady = false
        hotwordEventSink = null
        super.onDestroy()
    }
}
