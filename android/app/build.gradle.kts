import java.security.MessageDigest

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.chaquo.python")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val internalNoProotProof =
    (project.findProperty("plawieInternalNoProotProof") as String?)
        ?.toBooleanStrictOrNull() == true

val releaseStoreFile = providers.environmentVariable("PLAWIE_UPLOAD_STORE_FILE").orNull
val releaseStorePassword =
    providers.environmentVariable("PLAWIE_UPLOAD_STORE_PASSWORD").orNull
val releaseKeyAlias = providers.environmentVariable("PLAWIE_UPLOAD_KEY_ALIAS").orNull
val releaseKeyPassword =
    providers.environmentVariable("PLAWIE_UPLOAD_KEY_PASSWORD").orNull
val releaseSigningConfigured = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

val embeddedNodeRuntime =
    layout.projectDirectory.file("src/main/jniLibs/arm64-v8a/libnode.so")
val embeddedNodeManifest =
    layout.projectDirectory.file("src/main/jniLibs/arm64-v8a/libnode.so.manifest.json")

val verifyEmbeddedNodeRuntime = tasks.register("verifyEmbeddedNodeRuntime") {
    group = "verification"
    description = "Verifies the ignored native-first Node runtime before packaging."
    inputs.files(embeddedNodeRuntime, embeddedNodeManifest)

    doLast {
        val runtimeFile = embeddedNodeRuntime.asFile
        val manifestFile = embeddedNodeManifest.asFile
        check(runtimeFile.isFile) {
            "Native-first APK packaging requires ${runtimeFile.path}. " +
                "Package the approved Node 22.22.3 Android arm64 artifact first."
        }
        check(manifestFile.isFile) {
            "Native-first APK packaging requires the provenance manifest ${manifestFile.path}."
        }

        val manifest = manifestFile.readText()
        fun manifestString(name: String): String =
            Regex("\\\"${Regex.escape(name)}\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"")
                .find(manifest)
                ?.groupValues
                ?.get(1)
                ?: error("Embedded Node manifest is missing $name.")
        fun manifestLong(name: String): Long =
            Regex("\\\"${Regex.escape(name)}\\\"\\s*:\\s*(\\d+)")
                .find(manifest)
                ?.groupValues
                ?.get(1)
                ?.toLongOrNull()
                ?: error("Embedded Node manifest has an invalid $name.")

        val digest = MessageDigest.getInstance("SHA-256")
        runtimeFile.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val actualSha256 = digest.digest().joinToString("") {
            "%02x".format(it.toInt() and 0xff)
        }

        check(manifestString("nodeVersion") == "22.22.3") {
            "Embedded Node manifest must declare Node 22.22.3."
        }
        check(manifestString("packagedSha256").equals(actualSha256, ignoreCase = true)) {
            "Embedded Node SHA-256 does not match its provenance manifest."
        }
        check(manifestLong("packagedBytes") == runtimeFile.length()) {
            "Embedded Node byte length does not match its provenance manifest."
        }
    }
}

tasks.matching {
    it.name in setOf(
        "assembleDebug",
        "assembleProfile",
        "assembleRelease",
        "bundleDebug",
        "bundleProfile",
        "bundleRelease",
    )
}.configureEach {
    dependsOn(verifyEmbeddedNodeRuntime)
}

android {
    namespace = "com.openclaw.plawie"
    compileSdk = 36
    // Minimum NDK required across all plugins (speech_to_text requires 28.2.13676358).
    // NDK versions are backward compatible — safe to use the highest required.
    // fllama's Dart hooks_runner picks the highest installed NDK independently.
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // Web3j 4.12 is compiled for Java 17 and contains records. Keep the
        // app's Java and Kotlin bytecode targets aligned so D8 can desugar it
        // into the APK's global-synthetics consumer.
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.openclaw.plawie"
        minSdk = 29
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            // arm64-v8a only: all modern Android devices (2017+) are 64-bit.
            // armeabi-v7a (32-bit) is excluded — a 32-bit process can only
            // address ~3.5 GB RAM, making local LLM inference unviable anyway.
            // Excluding it halves fllama's NDK build time and reduces APK size.
            abiFilters += listOf("arm64-v8a")
        }

        externalNativeBuild {
            cmake {
                abiFilters += listOf("arm64-v8a")
                arguments += listOf("-DANDROID_STL=c++_shared")
                cppFlags += listOf("-std=c++17")
            }
        }
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            // Never publish an artifact carrying Android's universally known
            // debug certificate. Release packaging fails below unless the
            // upload keystore is supplied through the build environment.
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            if (internalNoProotProof) {
                excludes += setOf(
                    "**/libproot.so",
                    "**/libprootloader.so",
                    "**/libprootloader32.so",
                    "**/libproot_wrapper.sh",
                    "**/libtalloc.so",
                )
            }
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDir("src/main/jniLibs")
            assets.setSrcDirs(listOf("src/main/assets"))
        }
    }

    lint {
        // Flutter rewrites the ignored, machine-local android/local.properties
        // during every build. Its Windows path escaping is valid for Gradle but
        // triggers PropertyEscape, so suppress only that generated-file check.
        disable += "PropertyEscape"
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
}

chaquopy {
    defaultConfig {
        version = "3.11"
        buildPython("python")
        pip {
            // Install C-extension packages at build time so the wheels are
            // compiled against the correct Chaquopy 17.0 CPython ABI.
            // Runtime wheel provisioning (from pypi-13.1) produces ABI-
            // incompatible .so files that crash with _pandas_datetime_CAPI.
            // Pin pandas to <2.2 because pandas >=2.2 C extensions are
            // incompatible with the Chaquopy 17.0 ABI on Android.
            install("numpy")
            install("pandas<2.2")
            install("yfinance")
            install("python-dateutil")
            install("requests")
            install("six")
            // Pydantic v2 requires pydantic-core, which has no approved
            // Chaquopy Android wheel. Stocks uses the v1 API surface.
            install("pydantic<2")
            install("beautifulsoup4")
            install("frozendict")
            install("peewee")
            install("websockets")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Web3j 4.12 uses Java record APIs. D8 must have a global-synthetics
    // consumer when dexing these Android artifacts on API 29.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("org.apache.commons:commons-compress:1.26.0")
    implementation("org.tukaani:xz:1.9")
    implementation("com.github.luben:zstd-jni:1.5.6-4@aar")
    // MLC-LLM: NanoHTTPD for the OpenAI-compatible HTTP proxy
    implementation("org.nanohttpd:nanohttpd:2.3.1")
    // MLC-LLM: TVM runtime for native GPU inference (from libs/)
    // implementation(files("libs/tvm4j_core.jar"))
    implementation("androidx.work:work-runtime-ktx:2.10.0")
    // Vosk offline speech recognition for wake word "Plawie"
    // Correct group is com.alphacephei — published on Maven Central
    implementation("com.alphacephei:vosk-android:0.3.47") { isTransitive = false }
    implementation("net.java.dev.jna:jna:5.13.0@aar")
    // Android-optimised Web3j crypto only. Private EVM key material is
    // decrypted and used inside the Android process; it is never returned to
    // Dart for ordinary transfers or x402 authorizations.
    implementation("org.web3j:crypto:4.12.3-android")
    implementation("org.web3j:rlp:4.12.3-android")
    implementation("org.web3j:utils:4.12.3-android")
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")
    implementation("com.solanamobile:mobile-wallet-adapter-clientlib-ktx:2.1.0")
    testImplementation("junit:junit:4.13.2")
}

gradle.taskGraph.whenReady {
    val releasePackagingRequested = allTasks.any {
        it.name in setOf("assembleRelease", "bundleRelease")
    }
    check(!releasePackagingRequested || releaseSigningConfigured) {
        "Release signing is not configured. Set PLAWIE_UPLOAD_STORE_FILE, " +
            "PLAWIE_UPLOAD_STORE_PASSWORD, PLAWIE_UPLOAD_KEY_ALIAS, and " +
            "PLAWIE_UPLOAD_KEY_PASSWORD. Debug signing is forbidden for release artifacts."
    }
}
