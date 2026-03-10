
  material_color_utilities 0.11.1 (0.13.0 available)
  meta 1.17.0 (1.18.1 available)
  permission_handler 11.4.0 (12.0.1 available)
  permission_handler_android 12.1.0 (13.0.1 available)
  pointycastle 3.9.1 (4.0.0 available)
  solana 0.31.2+1 (0.32.0 available)
  sqflite_android 2.4.2+2 (2.4.2+3 available)
  test_api 0.7.7 (0.7.10 available)
  win32 5.15.0 (6.0.0 available)
Got dependencies!
1 package is discontinued.
28 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
lib/screens/terminal_screen.dart:38:9: Error: No named parameter with the name 'command'.
        command: '/bin/bash', 
        ^^^^^^^
lib/services/terminal_service.dart:50:23: Context: Found this candidate, but the arguments don't match.
  static List<String> buildProotArgs(Map<String, String> config,
                      ^^^^^^^^^^^^^^
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

BUILD FAILED in 1m 41s
Running Gradle task 'assembleRelease'...                          102.1s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 