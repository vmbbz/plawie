import 'dart:async';

import 'package:flutter/material.dart';
import 'app.dart';
import 'services/agent_skill_server.dart';
import 'services/skills_service.dart';
import 'services/native_bridge.dart';
import 'services/preferences_service.dart';
import 'services/ui_chrome_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = PreferencesService();
  await prefs.init();
  await prefs.applyNativeGatewayDefaultCutoverIfNeeded();
  await UiChromeService.applyFromPreferences();
  NativeBridge.init();

  runApp(const PlawieApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_startBackgroundServices());
  });
}

Future<void> _startBackgroundServices() async {
  // These services are useful soon after launch, but they must not block the
  // first Flutter frame. SkillsService can run PRoot/OpenClaw commands.
  await AgentSkillServer().start();
  await SkillsService().initialize();
}
