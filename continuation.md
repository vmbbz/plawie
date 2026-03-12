
PS C:\dev-shared\openclaw-projects\openclaw_final> C:\flutter\bin\flutter.bat build apk --release;
lib/app.dart:70:43: Error: The method 'AvatarOverlay' isn't defined for the type 'ClawaApp'.
 - 'ClawaApp' is from 'package:clawa/app.dart' ('lib/app.dart').
Try correcting the name to the name of an existing method, or defining a method named 'AvatarOverlay'.
          "/avatar-overlay": (context) => AvatarOverlay(isFloating: true),
                                          ^^^^^^^^^^^^^
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildRelease'.
> Process 'command 'C:\flutter\bin\flutter.bat'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.

BUILD FAILED in 30s
Running Gradle task 'assembleRelease'...                           30.7s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 