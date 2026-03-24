import 'package:flutter/material.dart';

/// Metadata for an optional development tool that can be installed
/// inside proot Ubuntu environment.
class OptionalPackage {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String installCommand;
  final String uninstallCommand;
  final String checkPath;
  final String estimatedSize;
  final String completionSentinel;
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

  static const goPackage = OptionalPackage(
    id: 'go',
    name: 'Go (Golang)',
    description: 'Go programming language compiler and tools',
    icon: Icons.integration_instructions,
    color: Colors.cyan,
    installCommand:
        'set -e; '
        'echo ">>> Installing Go via apt..."; '
        'apt-get update -qq && apt-get install -y golang; '
        'go version; '
        'echo ">>> GO_INSTALL_COMPLETE"',
    uninstallCommand:
        'set -e; '
        'echo ">>> Removing Go..."; '
        'apt-get remove -y golang golang-go && apt-get autoremove -y; '
        'echo ">>> GO_UNINSTALL_COMPLETE"',
    checkPath: 'usr/bin/go',
    estimatedSize: '~150 MB',
    completionSentinel: 'GO_INSTALL_COMPLETE',
    commandType: SkillCommandType.install,
  );

  static final brewPackage = OptionalPackage(
    id: 'brew',
    name: 'Homebrew',
    description: 'The missing package manager for Linux',
    icon: Icons.science,
    color: Colors.amber,
    installCommand:
        'set -e; '
        'echo ">>> Installing Homebrew (this may take a while)..."; '
        'touch /.dockerenv; '
        'apt-get update -qq && apt-get install -y -qq '
        'build-essential procps curl file git; '
        'curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/install.sh; '
        'chmod +x /tmp/install.sh; '
        'NONINTERACTIVE=1 /tmp/install.sh; '
        'grep -q linuxbrew /root/.bashrc 2>/dev/null || {'
        ' echo "eval /home/linuxbrew/.linuxbrew/bin/brew shellenv" >> /root/.bashrc; '
        '}; '
        'eval /home/linuxbrew/.linuxbrew/bin/brew shellenv; '
        'brew --version; '
        'echo ">>> BREW_INSTALL_COMPLETE"',
    uninstallCommand:
        'set -e; '
        'echo ">>> Removing Homebrew..."; '
        'touch /.dockerenv; '
        'curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh -o /tmp/uninstall.sh; '
        'chmod +x /tmp/uninstall.sh; '
        'NONINTERACTIVE=1 /tmp/uninstall.sh || true; '
        'rm -rf /home/linuxbrew/.linuxbrew; '
        'sed -i "/linuxbrew/d" /root/.bashrc; '
        'echo ">>> BREW_UNINSTALL_COMPLETE"',
    checkPath: 'home/linuxbrew/.linuxbrew/bin/brew',
    estimatedSize: '~500 MB',
    completionSentinel: 'BREW_INSTALL_COMPLETE',
    commandType: SkillCommandType.install,
  );

  // Example skill packages with new syntax
  static const twilioSkill = OptionalPackage(
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

  static const callsSkill = OptionalPackage(
    id: 'calls',
    name: 'Calls',
    description: 'ERC-8004 identity on Base chain',
    icon: Icons.call,
    color: Colors.blue,
    installCommand: 'openclaw skill install calls',  // NEW: singular "skill"
    uninstallCommand: 'openclaw skill uninstall calls',
    checkPath: 'opt/skills/calls/package.json',
    estimatedSize: '~15 MB',
    completionSentinel: 'CALLS_INSTALL_COMPLETE',
    commandType: SkillCommandType.install,
  );

  /// All available optional packages.
  static final all = [goPackage, brewPackage, twilioSkill, callsSkill];

  /// Sentinel for uninstall completion (derived from install sentinel).
  String get uninstallSentinel =>
      completionSentinel.replaceFirst('INSTALL', 'UNINSTALL');
}

enum SkillCommandType {
  install,     // openclaw skill install <name>
  add,         // openclaw skill add <url>
  register,     // openclaw skill register <path>
  update,       // openclaw skills update --all
}
