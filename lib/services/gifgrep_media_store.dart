import 'package:shared_preferences/shared_preferences.dart';

import 'native_bridge.dart';

/// Resolves the last GIF imported through Plawie's bounded Android picker.
/// The stored path is app-owned and is revalidated by GifgrepCapability before
/// every local operation.
class GifgrepMediaStore {
  GifgrepMediaStore._();

  static const _latestPathKey = 'gifgrep_latest_imported_path';
  static String? _latestPath;

  static String? get latestPath => _latestPath;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _latestPath = prefs.getString(_latestPathKey);
  }

  static Future<String?> importGif() async {
    final imported = await NativeBridge.pickGif();
    if (imported == null || imported.trim().isEmpty) return null;
    _latestPath = imported.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_latestPathKey, _latestPath!);
    return _latestPath;
  }

  static Future<void> clear() async {
    _latestPath = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latestPathKey);
  }
}
