
PS C:\dev-shared\openclaw-projects\openclaw_final> C:\flutter\bin\flutter.bat build apk --release;
lib/screens/management/status_dashboard.dart:25:29: Error: The getter 'NativeBridge' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'NativeBridge'.       
    final optimized = await NativeBridge.isBatteryOptimized();
                            ^^^^^^^^^^^^
lib/screens/management/status_dashboard.dart:26:24: Error: The getter 'NativeBridge' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'NativeBridge'.       
    final node = await NativeBridge.isNodeServiceRunning();
                       ^^^^^^^^^^^^
lib/screens/management/status_dashboard.dart:27:27: Error: The getter 'NativeBridge' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'NativeBridge'.       
    final gateway = await NativeBridge.isGatewayRunning();
                          ^^^^^^^^^^^^
lib/screens/management/status_dashboard.dart:201:19: Error: The getter 'NativeBridge' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'NativeBridge'.       
            () => NativeBridge.acquirePartialWakeLock(),
                  ^^^^^^^^^^^^
lib/screens/management/status_dashboard.dart:208:19: Error: The getter 'NativeBridge' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'NativeBridge'.       
            () => NativeBridge.requestBatteryOptimization(),
                  ^^^^^^^^^^^^
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

BUILD FAILED in 1m 8s
Running Gradle task 'assembleRelease'...                           68.5s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 