allprojects {
    repositories {
        google()
        mavenCentral()
        // No extra repo needed — com.alphacephei:vosk-android is on Maven Central
    }
}

// The app subproject's build dir is redirected to ../../build/app so Flutter
// can find the APK at {flutter_project}/build/app/outputs/flutter-apk/.
// The ROOT project build dir is intentionally left as-is (android/build)
// so Gradle writes its own reports there instead of the Flutter build dir,
// avoiding conflicts with files from previous build sessions.
val flutterBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

subprojects {
    val newSubprojectBuildDir: Directory = flutterBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
// Lift any Flutter plugin that ships with compileSdk < 36 to avoid AAR metadata
// version-check failures (e.g. solana_mobile_client still targets API 31).
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = maxOf(compileSdk ?: 0, 36)
        }
    }
}

tasks.register<Delete>("clean") {
    // Clean both the local Gradle build dir and the Flutter build dir
    delete(rootProject.layout.buildDirectory)
    delete(flutterBuildDir)
}
