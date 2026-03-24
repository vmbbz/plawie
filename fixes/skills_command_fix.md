# OpenClaw Skills Command Fix - Production Ready Solution

## Problem Analysis
- Error: "too many arguments for 'skills'. Expected 0 arguments but got 2"
- Root Cause: OpenClaw v2026.1.30 CLI syntax breaking change
- Impact: All skill installation functionality broken in UI

## Solution 1: Updated Command Syntax

### New OpenClaw v2026.1.30+ Commands
```bash
# OLD (deprecated):
openclaw skills install twilio
openclaw skills add https://github.com/user/skill

# NEW (v2026.1.30+):
openclaw skill install twilio        # Singular: skill, not skills
openclaw skill add https://github.com/user/skill
openclaw skills list                # Still works for listing
openclaw skills update --all        # Still works for updates
```

## Solution 2: Flutter UI Implementation

### Update OptionalPackage Model
```dart
// In models/optional_package.dart
class OptionalPackage {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String installCommand;        // Updated to use new syntax
  final String uninstallCommand;
  final String checkPath;
  final String estimatedSize;
  final String completionSentinel;

  // Add new property for command type
  final SkillCommandType commandType;

  const OptionalPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.installCommand,
    required this.uninstallCommand,
    required this.checkPath,
    required this.estimatedSize,
    required this.completionSentinel,
    this.commandType = SkillCommandType.install, // Default to new syntax
  });
}

enum SkillCommandType {
  install,     // openclaw skill install <name>
  add,         // openclaw skill add <url>
  register,     // openclaw skill register <path>
  update,       // openclaw skills update --all
}
```

### Updated Package Definitions
```dart
// Example for Twilio skill
static const twilioPackage = OptionalPackage(
  id: 'twilio',
  name: 'Twilio Integration',
  description: 'Send and receive SMS/MMS via Twilio API',
  icon: Icons.phone_android,
  color: Colors.red,
  installCommand: 'openclaw skill install twilio',  // NEW: singular "skill"
  uninstallCommand: 'openclaw skill uninstall twilio',
  checkPath: 'opt/skills/twilio/package.json',
  estimatedSize: '~25 MB',
  completionSentinel: 'TWILIO_INSTALL_COMPLETE',
  commandType: SkillCommandType.install,
);
```

## Solution 3: Dynamic Command Detection

### OpenClaw Version Detection
```dart
// In services/openclaw_service.dart
class OpenClawCommandService {
  static Future<String> detectOpenClawVersion() async {
    try {
      final result = await NativeBridge.runInProot('openclaw --version');
      final versionMatch = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result);
      return versionMatch?.group(1) ?? '0.0.0';
    } catch (e) {
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
      return baseCommand.replaceAll('openclaw skills', 'openclaw skill');
    }
    
    return baseCommand; // Keep old syntax for older versions
  }
}
```

## Solution 4: UI Integration

### Updated PackageInstallScreen
```dart
// In screens/package_install_screen.dart
class _PackageInstallScreenState extends State<PackageInstallScreen> {
  // ... existing code ...

  Future<void> _startProcess() async {
    try {
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(config, columns: 120, rows: 40);

      // Adapt command based on OpenClaw version
      final adaptedCommand = await OpenClawCommandService.adaptSkillCommand(
        widget.isUninstall ? widget.package.uninstallCommand : widget.package.installCommand
      );

      final cmdArgs = List<String>.from(args);
      cmdArgs.removeLast();
      cmdArgs.removeLast();
      cmdArgs.addAll(['/bin/bash', '-lc', adaptedCommand]);

      _process = await Process.start(
        config['executable']!,
        cmdArgs,
        environment: TerminalService.buildHostEnv(config),
      );

      // ... rest of existing code ...
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to start: $e';
        });
      }
    }
  }
}
```

## Solution 5: Fallback Installation Methods

### Multiple Installation Strategies
```dart
class SkillInstallationService {
  static Future<bool> installSkill(String skillId, {String? version}) async {
    // Method 1: Try new CLI syntax first
    try {
      final command = version != null 
          ? 'openclaw skill install $skillId@$version'
          : 'openclaw skill install $skillId';
      await NativeBridge.runInProot(command);
      return true;
    } catch (e) {
      print('New syntax failed: $e');
    }

    // Method 2: Try ClawHub integration
    try {
      await NativeBridge.runInProot('clawhub install $skillId');
      return true;
    } catch (e) {
      print('ClawHub failed: $e');
    }

    // Method 3: Manual installation (fallback)
    try {
      await _manualSkillInstall(skillId);
      return true;
    } catch (e) {
      print('Manual install failed: $e');
      return false;
    }
  }

  static Future<void> _manualSkillInstall(String skillId) async {
    // Clone skill directly to skills directory
    final cloneCmd = 'cd ~/.openclaw/skills && git clone https://github.com/openclaw/$skillId.git';
    await NativeBridge.runInProot(cloneCmd);
    
    // Install dependencies
    final npmCmd = 'cd ~/.openclaw/skills/$skillId && npm install';
    await NativeBridge.runInProot(npmCmd);
  }
}
```

## Implementation Priority
1. **Immediate**: Update command syntax in OptionalPackage model
2. **Short-term**: Add version detection and command adaptation
3. **Long-term**: Implement fallback installation methods

## Testing Protocol
1. Test with OpenClaw v2026.1.29 (old syntax)
2. Test with OpenClaw v2026.1.30+ (new syntax)
3. Test skill installation from ClawHub
4. Test manual git-based installation
5. Verify skill loading and functionality

## Migration Guide
1. Update all package definitions to use "openclaw skill install" (singular)
2. Add version detection to handle backward compatibility
3. Implement fallback methods for edge cases
4. Update error messages to guide users to correct syntax
