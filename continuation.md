
PS C:\dev-shared\openclaw-projects\openclaw_final> C:\flutter\bin\flutter.bat build apk --release;
lib/services/node_service.dart:93:7: Error: The getter '_reconnectTimer' isn't defined for the type 'NodeService'.
 - 'NodeService' is from 'package:clawa/services/node_service.dart' ('lib/services/node_service.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named '_reconnectTimer'.    
      _reconnectTimer?.cancel();
      ^^^^^^^^^^^^^^^
lib/services/node_service.dart:94:7: Error: The setter '_reconnectTimer' isn't defined for the type 'NodeService'.   
 - 'NodeService' is from 'package:clawa/services/node_service.dart' ('lib/services/node_service.dart').
Try correcting the name to the name of an existing setter, or defining a setter or field named '_reconnectTimer'.    
      _reconnectTimer = Timer(const Duration(seconds: 2), () {
      ^^^^^^^^^^^^^^^
lib/services/node_ws_service.dart:80:17: Error: The getter 'isResponse' isn't defined for the type 'NodeWsService'.
 - 'NodeWsService' is from 'package:clawa/services/node_ws_service.dart' ('lib/services/node_ws_service.dart').      
Try correcting the name to the name of an existing getter, or defining a getter or field named 'isResponse'.
            if (isResponse && frame.id != null) {
                ^^^^^^^^^^
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

BUILD FAILED in 1m 14s
Running Gradle task 'assembleRelease'...                           75.7s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 