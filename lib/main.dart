import 'package:flutter/material.dart';
import 'app.dart';
import 'services/agent_skill_server.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'screens/avatar_overlay.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AvatarOverlay(),
  ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the AgentSkillServer (Port 8765) for native openclaw skills
  final skillServer = AgentSkillServer();
  await skillServer.start();

  runApp(const ClawaApp());
}
