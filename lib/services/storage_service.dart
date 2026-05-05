import 'dart:async';
import 'native_bridge.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  bool _hasFullAccess = false;
  bool get hasFullAccess => _hasFullAccess;

  /// Check current native permission status
  Future<bool> updateStatus() async {
    _hasFullAccess = await NativeBridge.checkStoragePermission();
    return _hasFullAccess;
  }

  /// Trigger the native permission request flow
  Future<bool> requestAccess() async {
    final success = await NativeBridge.requestStoragePermission();
    if (success) {
      // We don't know yet if they actually granted it in the settings page,
      // so we'll need to check again when they return.
      return await updateStatus();
    }
    return false;
  }

  /// Helpful message for the UI explaining WHY we need this.
  String get permissionReason => 
    'Granting "All Files Access" allows Plawie to bind-mount your phone\'s '
    'internal storage (/sdcard) directly into the PRoot Ubuntu environment. '
    'This makes it easy to transfer files, models, and scripts between your '
    'phone and the AI agent.';
}
