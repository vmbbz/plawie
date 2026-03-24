import 'dart:async';
import 'dart:convert';
import '../services/native_bridge.dart';

/// Service for detecting OpenClaw version and adapting command syntax
class OpenClawCommandService {
  static Future<String> detectOpenClawVersion() async {
    try {
      final result = await NativeBridge.runInProot('openclaw --version');
      final versionMatch = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result);
      return versionMatch?.group(1) ?? '0.0.0';
    } catch (e) {
      print('Failed to detect OpenClaw version: $e');
      return '0.0.0';
    }
  }

  static Future<bool> isNewSkillSyntax() async {
    final version = await detectOpenClawVersion();
    final parts = version.split('.').map(int.parse).toList();
    
    // v2026.1.30+ uses new syntax
    if (parts[0] > 2026) return true;
    if (parts[0] == 2026 && parts[1] > 1) return true;
    if (parts[0] == 2026 && parts[1] == 1 && parts[2] >= 30) return true;
    
    return false;
  }

  static Future<String> adaptSkillCommand(String baseCommand) async {
    final useNewSyntax = await isNewSkillSyntax();
    
    if (useNewSyntax) {
      // Convert "openclaw skills install" to "openclaw skill install"
      if (baseCommand.contains('openclaw skills install')) {
        return baseCommand.replaceAll('openclaw skills install', 'openclaw skill install');
      }
      if (baseCommand.contains('openclaw skills add')) {
        return baseCommand.replaceAll('openclaw skills add', 'openclaw skill add');
      }
      if (baseCommand.contains('openclaw skills uninstall')) {
        return baseCommand.replaceAll('openclaw skills uninstall', 'openclaw skill uninstall');
      }
    }
    
    return baseCommand; // Keep old syntax for older versions
  }

  static Future<bool> isVersionAtLeast(String targetVersion) async {
    final currentVersion = await detectOpenClawVersion();
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    final targetParts = targetVersion.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      if (currentParts[i] > targetParts[i]) return true;
      if (currentParts[i] < targetParts[i]) return false;
    }
    
    return currentParts[2] >= targetParts[2]; // Compare patch version
  }

  static Future<String> getSkillInstallCommand(String skillName, {String? version}) async {
    final useNewSyntax = await isNewSkillSyntax();
    
    if (useNewSyntax) {
      // New syntax: openclaw skill install <name>[@version]
      final versionStr = version != null ? '@$version' : '';
      return 'openclaw skill install $skillName$versionStr';
    } else {
      // Old syntax: openclaw skills install <name>
      return 'openclaw skills install $skillName';
    }
  }

  static Future<String> getSkillUninstallCommand(String skillName) async {
    final useNewSyntax = await isNewSkillSyntax();
    
    if (useNewSyntax) {
      return 'openclaw skill uninstall $skillName';
    } else {
      return 'openclaw skills uninstall $skillName';
    }
  }

  static Future<String> getSkillAddCommand(String skillUrl) async {
    final useNewSyntax = await isNewSkillSyntax();
    
    if (useNewSyntax) {
      return 'openclaw skill add $skillUrl';
    } else {
      return 'openclaw skills add $skillUrl';
    }
  }

  static Future<String> getSkillListCommand() async {
    final useNewSyntax = await isNewSkillSyntax();
    return useNewSyntax ? 'openclaw skills list' : 'openclaw skills list';
  }

  static Future<String> getSkillUpdateCommand() async {
    final useNewSyntax = await isNewSkillSyntax();
    return useNewSyntax ? 'openclaw skills update --all' : 'openclaw skills update --all';
  }

  static Future<void> validateCommandCompatibility(String command) async {
    final useNewSyntax = await isNewSkillSyntax();
    
    if (useNewSyntax && command.contains('openclaw skills')) {
      throw Exception(
        'OpenClaw v2026.1.30+ detected. The "skills" command no longer accepts arguments. '
        'Use "openclaw skill install <name>" instead of "openclaw skills install <name>".'
      );
    }
  }

  static Future<Map<String, String>> getCommandHelp() async {
    final useNewSyntax = await isNewSkillSyntax();
    
    if (useNewSyntax) {
      return {
        'install': 'openclaw skill install <skill-name>[@version]',
        'add': 'openclaw skill add <url>',
        'list': 'openclaw skills list',
        'update': 'openclaw skills update --all',
        'uninstall': 'openclaw skill uninstall <skill-name>',
        'help': 'openclaw skills --help',
      };
    } else {
      return {
        'install': 'openclaw skills install <skill-name>',
        'add': 'openclaw skills add <url>',
        'list': 'openclaw skills list',
        'update': 'openclaw skills update --all',
        'uninstall': 'openclaw skills uninstall <skill-name>',
        'help': 'openclaw skills --help',
      };
    }
  }
}
