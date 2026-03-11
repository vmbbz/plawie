this is getting worse and more horrible now whats going on to my file structure now come on be careful think things thru please and test the page after::


Running Gradle task 'assembleRelease'...                           18.2s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> C:\flutter\bin\flutter.bat build apk --release
Resolving dependencies... 
Downloading packages... 
  camera 0.11.4 (0.12.0 available)
  camera_android_camerax 0.6.30 (0.7.1 available)
  camera_avfoundation 0.9.23+2 (0.10.1 available)
  characters 1.4.0 (1.4.1 available)
  decimal 2.3.3 (3.2.4 available)
  flutter_lints 5.0.0 (6.0.0 available)
  flutter_markdown 0.7.7+1 (discontinued replaced by flutter_markdown_plus)
  flutter_secure_storage 9.2.4 (10.0.0 available)
  flutter_secure_storage_linux 1.2.3 (3.0.0 available)
  flutter_secure_storage_macos 3.1.3 (4.0.0 available)
  flutter_secure_storage_platform_interface 1.1.2 (2.0.1 available)
  flutter_secure_storage_web 1.2.1 (2.1.0 available)
  flutter_secure_storage_windows 3.1.2 (4.1.0 available)
  freezed_annotation 2.4.4 (3.1.0 available)
  geolocator 12.0.0 (14.0.2 available)
  geolocator_android 4.6.2 (5.0.2 available)
  google_fonts 6.3.3 (8.0.2 available)
  js 0.6.7 (0.7.2 available)
  lints 5.1.1 (6.1.0 available)
  matcher 0.12.17 (0.12.19 available)
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
lib/screens/chat_screen.dart:929:31: Error: Can't find ')' to match '('.
        title: AnimatedOpacity(
                              ^
lib/screens/chat_screen.dart:922:21: Error: Can't find ')' to match '('.
      appBar: AppBar(
                    ^
lib/screens/chat_screen.dart:918:20: Error: Can't find ')' to match '('.
    return Scaffold(
                   ^
lib/screens/chat_screen.dart:908:13: Error: No named parameter with the name 'isSpeaking'.
            isSpeaking: _isGenerating,
            ^^^^^^^^^^
lib/widgets/vrm_avatar_widget.dart:22:9: Context: Found this candidate, but the arguments don't match.
  const VrmAvatarWidget({
        ^^^^^^^^^^^^^^^
lib/screens/chat_screen.dart:1003:9: Error: No named parameter with the name 'centerTitle'.
        centerTitle: true,
        ^^^^^^^^^^^
/C:/flutter/packages/flutter/lib/src/widgets/container.dart:255:3: Context: Found this candidate, but the arguments don't match.        
  Container({
  ^^^^^^^^^
lib/screens/chat_screen.dart:1033:7: Error: No named parameter with the name 'body'.
      body: Stack(
      ^^^^
/C:/flutter/packages/flutter/lib/src/widgets/gesture_detector.dart:237:3: Context: Found this candidate, but the arguments don't match. 
  GestureDetector({
  ^^^^^^^^^^^^^^^
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
Running Gradle task 'assembleRelease'...                           27.9s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 
 *  History restored 

PS C:\dev-shared> cd 'c:\dev-shared\openclaw-projects\openclaw_final'
PS C:\dev-shared\openclaw-projects\openclaw_final> C:\flutter\bin\flutter.bat build apk --release;    
Resolving dependencies... 
Downloading packages... 
  camera 0.11.4 (0.12.0 available)
  camera_android_camerax 0.6.30 (0.7.1 available)
  camera_avfoundation 0.9.23+2 (0.10.1 available)
  characters 1.4.0 (1.4.1 available)
  decimal 2.3.3 (3.2.4 available)
  flutter_lints 5.0.0 (6.0.0 available)
  flutter_markdown 0.7.7+1 (discontinued replaced by flutter_markdown_plus)
  flutter_secure_storage 9.2.4 (10.0.0 available)
  flutter_secure_storage_linux 1.2.3 (3.0.0 available)
  flutter_secure_storage_macos 3.1.3 (4.0.0 available)
  flutter_secure_storage_platform_interface 1.1.2 (2.0.1 available)
  flutter_secure_storage_web 1.2.1 (2.1.0 available)
  flutter_secure_storage_windows 3.1.2 (4.1.0 available)
  freezed_annotation 2.4.4 (3.1.0 available)
  geolocator 12.0.0 (14.0.2 available)
  geolocator_android 4.6.2 (5.0.2 available)
  google_fonts 6.3.3 (8.0.2 available)
  js 0.6.7 (0.7.2 available)
  lints 5.1.1 (6.1.0 available)
  matcher 0.12.17 (0.12.19 available)
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
lib/screens/chat_screen.dart:929:31: Error: Can't find ')' to match '('.
        title: AnimatedOpacity(
                              ^
lib/screens/chat_screen.dart:922:21: Error: Can't find ')' to match '('.
      appBar: AppBar(
                    ^
lib/screens/chat_screen.dart:918:20: Error: Can't find ')' to match '('.
    return Scaffold(
                   ^
lib/screens/chat_screen.dart:908:13: Error: No named parameter with the name 'isSpeaking'.
            isSpeaking: _isGenerating,
            ^^^^^^^^^^
lib/widgets/vrm_avatar_widget.dart:22:9: Context: Found this candidate, but the arguments don't match.
  const VrmAvatarWidget({
        ^^^^^^^^^^^^^^^
lib/screens/chat_screen.dart:1003:9: Error: No named parameter with the name 'centerTitle'.
        centerTitle: true,
        ^^^^^^^^^^^
/C:/flutter/packages/flutter/lib/src/widgets/container.dart:255:3: Context: Found this candidate, but the arguments don't match.        
  Container({
  ^^^^^^^^^
lib/screens/chat_screen.dart:1033:7: Error: No named parameter with the name 'body'.
      body: Stack(
      ^^^^
/C:/flutter/packages/flutter/lib/src/widgets/gesture_detector.dart:237:3: Context: Found this candidate, but the arguments don't match. 
  GestureDetector({
  ^^^^^^^^^^^^^^^
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

BUILD FAILED in 29s
Running Gradle task 'assembleRelease'...                           30.3s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 