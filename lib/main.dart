import 'dart:async';

import 'package:flutter/material.dart';
import 'app.dart';
import 'services/agent_skill_server.dart';
import 'services/skills_service.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
