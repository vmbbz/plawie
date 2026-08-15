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
// Lift Flutter plugins that still declare an old compileSdk. finalizeDsl runs
// after each plugin's own android block, so a later compileSdkVersion call
// cannot undo the compatibility floor. This does not alter minSdk or targetSdk.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
            finalizeDsl { library ->
                library.compileSdk = maxOf(library.compileSdk ?: 0, 36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    // Clean both the local Gradle build dir and the Flutter build dir
    delete(rootProject.layout.buildDirectory)
    delete(flutterBuildDir)
}
