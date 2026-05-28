import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'preferences_service.dart';

class UiChromeService {
  UiChromeService._();

  static Future<void> applyFromPreferences() async {
    final prefs = PreferencesService();
    await prefs.init();
    await apply(immersive: prefs.immersiveUiEnabled);
  }

  static Future<void> setImmersive(bool enabled) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.immersiveUiEnabled = enabled;
    await apply(immersive: enabled);
  }

  static Future<void> apply({required bool immersive}) async {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    await SystemChrome.setEnabledSystemUIMode(
      immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }
}
