import 'dart:io';

import 'package:path/path.dart' as path;

import '../native_bridge.dart';

class NativeEnv {
  const NativeEnv._();

  static Future<String?> readFirst(List<String> keys) async {
    try {
      final filesDir = await NativeBridge.getFilesDir();
      final envFile = File(path.join(
        filesDir,
        'native-node-embedded',
        'native-home',
        '.openclaw',
        '.env',
      ));
      if (!await envFile.exists()) return null;
      final text = await envFile.readAsString();
      for (final key in keys) {
        final value = readDotEnvKey(text, key);
        if (value != null && value.trim().isNotEmpty) return value.trim();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? readDotEnvKey(String text, String key) {
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final equals = line.indexOf('=');
      if (equals <= 0) continue;
      final name = line.substring(0, equals).trim();
      if (name != key) continue;
      var value = line.substring(equals + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      return value.trim().isEmpty ? null : value.trim();
    }
    return null;
  }
}
