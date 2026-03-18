
  pointycastle 3.9.1 (4.0.0 available)
  sherpa_onnx 1.12.28 (1.12.29 available)
  sherpa_onnx_android 1.12.28 (1.12.29 available)
  sherpa_onnx_ios 1.12.28 (1.12.29 available)
  sherpa_onnx_linux 1.12.28 (1.12.29 available)
  sherpa_onnx_macos 1.12.28 (1.12.29 available)
  sherpa_onnx_windows 1.12.28 (1.12.29 available)
  solana 0.31.2+1 (0.32.0 available)
  sqflite_android 2.4.2+2 (2.4.2+3 available)
  test_api 0.7.7 (0.7.10 available)
  webview_flutter_wkwebview 3.23.8 (3.24.0 available)
  win32 5.15.0 (6.0.0 available)
Got dependencies!
1 package is discontinued.
39 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
PS C:\dev-shared\openclaw-projects\openclaw_final> C:\flutter\bin\flutter.bat build apk --release;
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 24420 bytes (98.5% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
3 warnings
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
3 warnings
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
3 warnings
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
3 warnings
warning: [options] source value 8 is obsolete and will be removed in a future release
warning: [options] target value 8 is obsolete and will be removed in a future release
warning: [options] To suppress warnings about obsolete options, use -Xlint:-options.
3 warnings

FAILURE: Build completed with 4 failures.

1: Task failed with an exception.
-----------
* What went wrong:
Execution failed for task ':app:assembleRelease'.
> Could not copy file 'C:\dev-shared\openclaw-projects\openclaw_final\build\app\outputs\apk\release\app-release.apk' to 'C:\dev-shared\openclaw-projects\openclaw_final\build\app\outputs\flutter-apk\app-release.apk'.
   > java.io.IOException: There is not enough space on the disk

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.
==============================================================================

2: Task failed with an exception.
-----------
* What went wrong:
Execution failed for task ':webview_flutter_android:verifyReleaseResources'.
> A failure occurred while executing com.android.build.gradle.tasks.VerifyLibraryResourcesTask$Action
   > There was a failure while executing work items
      > A failure occurred while executing com.android.build.gradle.internal.res.ResourceCompilerRunnable
         > Resource compilation failed (There is not enough space on the disk. Cause: null). Check logs for more details.

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.
==============================================================================

3: Task failed with an exception.
-----------
* What went wrong:
java.io.IOException: There is not enough space on the disk
> There is not enough space on the disk

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.
==============================================================================

4: Task failed with an exception.
-----------
* What went wrong:
java.io.IOException: There is not enough space on the disk

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.
==============================================================================

BUILD FAILED in 9m 18s
Running Gradle task 'assembleRelease'...                          560.2s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 