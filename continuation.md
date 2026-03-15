
PS C:\dev-shared\openclaw-projects\openclaw_final> C:\flutter\bin\flutter.bat build apk --release;
lib/services/skills_service.dart:978:16: Error: 'toggleSkill' is already declared in this scope.
  Future<void> toggleSkill(String skillId, bool enabled) async {
               ^^^^^^^^^^^
lib/services/skills_service.dart:403:16: Context: Previous declaration of 'toggleSkill'.
  Future<void> toggleSkill(String skillId, bool enabled) async {
               ^^^^^^^^^^^
lib/screens/help_screen.dart:27:17: Error: No named parameter with the name 'filter'.
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                ^^^^^^
/C:/flutter/packages/flutter/lib/src/painting/box_decoration.dart:93:9: Context: Found this candidate, but the arguments don't match.
  const BoxDecoration({
        ^^^^^^^^^^^^^
lib/screens/help_screen.dart:182:16: Error: The getter 'AppColors' isn't defined for the type 'HelpScreen'.
 - 'HelpScreen' is from 'package:clawa/screens/help_screen.dart' ('lib/screens/help_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
        color: AppColors.statusGreen.withValues(alpha: 0.8),
               ^^^^^^^^^
lib/screens/management/status_dashboard.dart:123:16: Error: The getter 'AppColors' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
        color: AppColors.statusGrey.withOpacity(0.8),
               ^^^^^^^^^
lib/screens/management/status_dashboard.dart:153:72: Error: Not a constant expression.
                Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.statusGrey)),
                                                                       ^^^^^^^^^
lib/screens/management/status_dashboard.dart:142:35: Error: The getter 'AppColors' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
              color: (isRunning ? AppColors.statusGreen : Colors.red).withOpacity(0.1),
                                  ^^^^^^^^^
lib/screens/management/status_dashboard.dart:145:50: Error: The getter 'AppColors' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
            child: Icon(icon, color: isRunning ? AppColors.statusGreen : Colors.redAccent, size: 24),
                                                 ^^^^^^^^^
lib/screens/management/status_dashboard.dart:163:39: Error: The getter 'AppColors' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
                  color: (isRunning ? AppColors.statusGreen : Colors.red).withOpacity(0.1),
                                      ^^^^^^^^^
lib/screens/management/status_dashboard.dart:169:40: Error: The getter 'AppColors' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
                    color: isRunning ? AppColors.statusGreen : Colors.redAccent,
                                       ^^^^^^^^^
lib/screens/management/status_dashboard.dart:212:70: Error: The getter 'AppColors' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
            statusColor: _isBatteryOptimized ? Colors.orangeAccent : AppColors.statusGreen,
                                                                     ^^^^^^^^^
lib/screens/management/status_dashboard.dart:248:74: Error: Not a constant expression.
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.statusGrey)),
                                                                         ^^^^^^^^^
lib/screens/management/status_dashboard.dart:252:69: Error: Not a constant expression.
        if (isActive) const Icon(Icons.check_circle_rounded, color: AppColors.statusGreen, size: 18),
                                                                    ^^^^^^^^^
lib/screens/management/status_dashboard.dart:241:37: Error: The getter 'AppColors' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
        Icon(icon, size: 20, color: AppColors.statusGrey),
                                    ^^^^^^^^^
lib/screens/management/status_dashboard.dart:277:58: Error: Not a constant expression.
          const Icon(Icons.chevron_right_rounded, color: AppColors.statusGrey),
                                                         ^^^^^^^^^
lib/screens/management/status_dashboard.dart:266:54: Error: The getter 'AppColors' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
          Icon(icon, size: 20, color: statusColor ?? AppColors.statusGrey),
                                                     ^^^^^^^^^
lib/screens/management/status_dashboard.dart:273:85: Error: The getter 'AppColors' isn't defined for the type '_StatusDashboardState'.
 - '_StatusDashboardState' is from 'package:clawa/screens/management/status_dashboard.dart' ('lib/screens/management/status_dashboard.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'AppColors'.
                Text(subtitle, style: TextStyle(fontSize: 11, color: statusColor ?? AppColors.statusGrey)),
                                                                                    ^^^^^^^^^
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

BUILD FAILED in 27s
Running Gradle task 'assembleRelease'...                           27.8s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 