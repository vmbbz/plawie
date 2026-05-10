import 'package:flutter/material.dart';
import 'app.dart';
import 'services/agent_skill_server.dart';
import 'services/skills_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the AgentSkillServer (Port 8765) for native openclaw skills
  final skillServer = AgentSkillServer();
  await skillServer.start();

  // Initialize Skills System
  await SkillsService().initialize();

  runApp(const PlawieApp());
}
