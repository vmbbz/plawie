
  permission_handler 11.4.0 (12.0.1 available)
  permission_handler_android 12.1.0 (13.0.1 available)
  pointycastle 3.9.1 (4.0.0 available)
  solana 0.31.2+1 (0.32.0 available)
  test_api 0.7.7 (0.7.10 available)
  win32 5.15.0 (6.0.0 available)
Got dependencies!
1 package is discontinued.
27 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
lib/services/agent_skill_server.dart:62:19: Error: The method 'saveSelectedAvatar' isn't defined for the type 'PreferencesService'.
 - 'PreferencesService' is from 'package:clawa/services/preferences_service.dart' ('lib/services/preferences_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'saveSelectedAvatar'.
      await prefs.saveSelectedAvatar(avatarFileName);
                  ^^^^^^^^^^^^^^^^^^
lib/screens/chat_screen.dart:210:14: Error: The getter '_flutterTts' isn't defined for the type '_ChatScreenState'.
 - '_ChatScreenState' is from 'package:clawa/screens/chat_screen.dart' ('lib/screens/chat_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named '_flutterTts'.
       await _flutterTts.stop();
             ^^^^^^^^^^^
lib/screens/chat_screen.dart:211:14: Error: The getter '_flutterTts' isn't defined for the type '_ChatScreenState'.     
 - '_ChatScreenState' is from 'package:clawa/screens/chat_screen.dart' ('lib/screens/chat_screen.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named '_flutterTts'.
       await _flutterTts.speak(fullResponse);
             ^^^^^^^^^^^
lib/services/piper_tts_service.dart:73:9: Error: No named parameter with the name 'maxNumSentences'.
        maxNumSentences: 1,
        ^^^^^^^^^^^^^^^
/C:/Users/coura/AppData/Local/Pub/Cache/hosted/pub.dev/sherpa_onnx-1.12.28/lib/src/tts.dart:466:9: Context: Found this candidate, but the arguments don't match.
  const OfflineTtsConfig({
        ^^^^^^^^^^^^^^^^
lib/services/piper_tts_service.dart:95:41: Error: Too many positional arguments: 0 allowed, but 1 found.
Try removing the extra positional arguments.
      final audioConfig = _tts!.generate(text, sid: 0, speed: 1.0);
                                        ^
lib/screens/avatar_forge_page.dart:38:17: Error: The method 'saveSelectedAvatar' isn't defined for the type 'PreferencesService'.
 - 'PreferencesService' is from 'package:clawa/services/preferences_service.dart' ('lib/services/preferences_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'saveSelectedAvatar'.
    await prefs.saveSelectedAvatar(avatar);
                ^^^^^^^^^^^^^^^^^^
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

BUILD FAILED in 7m 36s
Running Gradle task 'assembleRelease'...                          457.5s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 