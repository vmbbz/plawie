import 'dart:io';
import '../models/optional_package.dart';
import 'native_bridge.dart';

/// Checks installation status of PRoot rollback extras by looking inside the
/// Ubuntu rootfs from Android. This is not native libnode.so runtime health.
class PackageService {
  static String? _rootfsDir;

  static Future<String> _getRootfsDir() async {
    if (_rootfsDir != null) return _rootfsDir!;
    final filesDir = await NativeBridge.getFilesDir();
    _rootfsDir = '$filesDir/rootfs/ubuntu';
    return _rootfsDir!;
  }

  /// Check if a single package is installed.
  static Future<bool> isInstalled(OptionalPackage package) async {
    final rootfs = await _getRootfsDir();
    return File('$rootfs/${package.checkPath}').existsSync();
  }

  /// Check installation status for all optional packages.
  /// Returns a map of package id → installed boolean.
  static Future<Map<String, bool>> checkAllStatuses() async {
    final rootfs = await _getRootfsDir();
    final statuses = <String, bool>{};
    for (final pkg in OptionalPackage.all) {
      statuses[pkg.id] = File('$rootfs/${pkg.checkPath}').existsSync();
    }
    return statuses;
  }
}
