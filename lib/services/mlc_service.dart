// Local MLC support removed: minimal stub to avoid accidental reintroduction.

class MlcService {
  /// No-op: local MLC removed.
  static Future<void> startMlcEngine() async {}

  /// No-op: local MLC removed.
  static Future<void> stopMlcEngine() async {}

  /// Always returns false: MLC engine is not available.
  static Future<bool> isMlcAvailable() async => false;
}
