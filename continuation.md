
  js 0.6.7 (0.7.2 available)
  lints 5.1.1 (6.1.0 available)
  matcher 0.12.17 (0.12.19 available)
  material_color_utilities 0.11.1 (0.13.0 available)
  meta 1.17.0 (1.18.1 available)
  permission_handler 11.4.0 (12.0.1 available)
  permission_handler_android 12.1.0 (13.0.1 available)
  pointycastle 3.9.1 (4.0.0 available)
  solana 0.31.2+1 (0.32.0 available)
  test_api 0.7.7 (0.7.10 available)
  win32 5.15.0 (6.0.0 available)
Got dependencies!
1 package is discontinued.
28 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
PS C:\dev-shared\openclaw-projects\openclaw_final> C:\flutter\bin\flutter.bat build apk --release
Resolving dependencies... 
Downloading packages... 
  archive 3.6.1 (4.0.9 available)
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
  test_api 0.7.7 (0.7.10 available)
  win32 5.15.0 (6.0.0 available)
Got dependencies!
1 package is discontinued.
28 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
lib/services/device_identity.dart:64:63: Error: The getter 'bytes' isn't defined for the type 'SimpleKeyPair'.
 - 'SimpleKeyPair' is from 'package:cryptography/src/cryptography/simple_key_pair.dart' ('/C:/Users/coura/AppData/Local/Pub/Cache/hosted/pub.dev/cryptography-2.9.0/lib/src/cryptography/simple_key_pair.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'bytes'.
    final privateKeyBytes = Uint8List.fromList(privateKeyData.bytes);
                                                              ^^^^^
lib/services/device_identity.dart:110:21: Error: The getter 'bytes' isn't defined for the type 'SimpleKeyPair'.
 - 'SimpleKeyPair' is from 'package:cryptography/src/cryptography/simple_key_pair.dart' ('/C:/Users/coura/AppData/Local/Pub/Cache/hosted/pub.dev/cryptography-2.9.0/lib/src/cryptography/simple_key_pair.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'bytes'.
          _keyPair!.bytes,
                    ^^^^^
lib/services/device_identity.dart:111:32: Error: The getter 'publicKey' isn't defined for the type 'SimpleKeyPair'.     
 - 'SimpleKeyPair' is from 'package:cryptography/src/cryptography/simple_key_pair.dart' ('/C:/Users/coura/AppData/Local/Pub/Cache/hosted/pub.dev/cryptography-2.9.0/lib/src/cryptography/simple_key_pair.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'publicKey'.
          publicKey: _keyPair!.publicKey,
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

BUILD FAILED in 2m 23s
Running Gradle task 'assembleRelease'...                          145.8s
Gradle task assembleRelease failed with exit code 1
PS C:\dev-shared\openclaw-projects\openclaw_final> 