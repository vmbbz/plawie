import 'package:flutter/material.dart';
import 'app.dart';
import 'services/agent_skill_server.dart';
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_floatwing/flutter_floatwing.dart';
import 'screens/avatar_overlay.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the AgentSkillServer (Port 8765) for native openclaw skills
  final skillServer = AgentSkillServer();
  await skillServer.start();

  runApp(const ClawaApp());
}

// Add this anywhere in main.dart (outside any class)
Future<void> startFloatingAvatar() async {
  final plugin = FloatwingPlugin();

  // Permission
  bool granted = await plugin.checkPermission();
  if (!granted) {
    await plugin.openPermissionSetting();
    return; // user must grant then call again
  }

  await plugin.initialize();

  // Start the floating window (bust size, draggable, right side like before)
  WindowConfig(
    id: "clawa-avatar",
    route: "/avatar-overlay",
    width: 280,
    height: 380,
    gravity: GravityType.RightTop,     // or RightBottom
    draggable: true,
    clickable: true,
  ).to().create(start: true);
}
