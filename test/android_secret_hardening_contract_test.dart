import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android backup and device-transfer paths exclude all app state', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final legacyRules = File(
      'android/app/src/main/res/xml/backup_rules.xml',
    ).readAsStringSync();
    final extractionRules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(legacyRules, contains('domain="sharedpref" path="."'));
    expect(legacyRules, contains('domain="file" path="."'));
    expect(extractionRules, contains('<cloud-backup'));
    expect(extractionRules, contains('<device-transfer>'));
    expect(
      RegExp('domain="sharedpref" path="\\."')
          .allMatches(extractionRules)
          .length,
      2,
    );
  });

  test('release signing and build artifact audit fail closed', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final buildScript =
        File('scripts/build_plawie_android.ps1').readAsStringSync();

    final releaseBlock = RegExp(
      r'release\s*\{([\s\S]*?)\n\s*\}',
    ).firstMatch(gradle)?.group(1);
    expect(releaseBlock, isNotNull);
    expect(releaseBlock, isNot(contains('getByName("debug")')));
    expect(gradle, contains('PLAWIE_UPLOAD_STORE_FILE'));
    expect(gradle, contains('Debug signing is forbidden'));
    expect(buildScript, contains('audit_android_artifact_secrets.ps1'));
    expect(
      File('scripts/audit_android_artifact_secrets.ps1').existsSync(),
      isTrue,
    );
  });

  test('native command logs never include terminal or PRoot command text', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    ).readAsStringSync();
    final terminalService = File(
      'android/app/src/main/kotlin/com/openclaw/plawie/TerminalSessionService.kt',
    ).readAsStringSync();

    expect(mainActivity, isNot(contains('runInProot failed: command=')));
    expect(terminalService, isNot(contains(': \$command')));
  });

  test('node diagnostics never print authentication token fragments', () {
    final nodeService =
        File('lib/services/node_service.dart').readAsStringSync();

    expect(nodeService, isNot(contains('token: \$preview')));
    expect(nodeService, isNot(contains('token (\$preview)')));
    expect(
      nodeService,
      isNot(contains('approvedToken.substring')),
    );
    expect(
      nodeService,
      isNot(contains('activeDeviceToken.substring')),
    );
  });
}
