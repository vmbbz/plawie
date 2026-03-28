plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nxg.openclawproot"
    compileSdk = 36
    // NDK pinned for Gradle's own JNI builds (Vosk, etc.).
    // fllama's Dart hooks_runner uses the highest installed NDK independently —
    // that's fine, both produce ABI-compatible arm64-v8a .so files.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.nxg.openclawproot"
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
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDir("src/main/jniLibs")
            assets.setSrcDirs(listOf("src/main/assets"))
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
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
}
