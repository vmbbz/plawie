import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Plawie';
  static const String version = '2.2.1';
  static const String packageName = 'com.nxg.openclawproot';

  /// Matches ANSI escape sequences (e.g. color codes in terminal output).
  static final ansiEscape = RegExp(r'\x1b\[[0-9;]*[a-zA-Z]');

  static const String appMotto = 'OpenClaw in your Pocket';
  static const String license = 'MIT';

  static const String gatewayHost = '127.0.0.1';
  static const int gatewayPort = 18789;
  static const String gatewayUrl = 'http://$gatewayHost:$gatewayPort';
  static const String gatewayWsUrl = 'ws://$gatewayHost:$gatewayPort';

  static const String ubuntuRootfsUrl =
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.3-base-';
  static const String rootfsArm64 = '${ubuntuRootfsUrl}arm64.tar.gz';
  static const String rootfsArmhf = '${ubuntuRootfsUrl}armhf.tar.gz';
  static const String rootfsAmd64 = '${ubuntuRootfsUrl}amd64.tar.gz';

  // Node.js binary tarball — downloaded directly by Flutter, extracted by Java.
  // Bypasses curl/gpg/NodeSource which fail inside proot.
  static const String nodeVersion = '22.22.2';
  static const String nodeBaseUrl =
      'https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-linux-';

  static String getNodeTarballUrl(String arch) {
    switch (arch) {
      case 'aarch64':
        return '${nodeBaseUrl}arm64.tar.xz';
      case 'arm':
        return '${nodeBaseUrl}armv7l.tar.xz';
      case 'x86_64':
        return '${nodeBaseUrl}x64.tar.xz';
      default:
        return '${nodeBaseUrl}arm64.tar.xz';
    }
  }

  static const int healthCheckIntervalMs = 15000; // Reduced from 5000ms to 15s
  static const int maxAutoRestarts = 3;

  // Node constants
  static const int wsReconnectBaseMs = 2000;
  static const double wsReconnectMultiplier = 1.7;
  static const int wsReconnectCapMs =
      15000; // Increased cap to 15s for stability
  static const String nodeRole = 'node';
  static const int pairingTimeoutMs = 300000;
  // Gateway WS protocol negotiation range. Keep min at 3 for legacy
  // compatibility while allowing current v4 gateways.
  static const int wsProtocolMinVersion = 3;
  static const int wsProtocolMaxVersion = 4;

  static const String channelName = 'com.nxg.openclawproot/native';
  static const String eventChannelName = 'com.nxg.openclawproot/gateway_logs';

  static String getRootfsUrl(String arch) {
    switch (arch) {
      case 'aarch64':
        return rootfsArm64;
      case 'arm':
        return rootfsArmhf;
      case 'x86_64':
        return rootfsAmd64;
      default:
        return rootfsArm64;
    }
  }
}

/// Centralized premium metallic color palette for entire app.
class AppColors {
  AppColors._();

  // Premium metallic palette - Black & White with grey accents

  // Dark mode (premium black with metallic accents)
  static const Color darkBg = Color(0xFF000000); // Pure black
  static const Color darkSurface = Color(0xFF0A0A0A); // Slightly lifted black
  static const Color darkSurfaceAlt = Color(0xFF141414); // Elevated surface
  static const Color darkBorder = Color(0xFF2A2A2A); // Subtle border
  static const Color darkMetallic = Color(0xFF1A1A1A); // Metallic sheen
  static const Color darkHighlight = Color(0xFF333333); // Highlight accent

  // Light mode (premium white with metallic accents)
  static const Color lightBg = Color(0xFFFFFFFF); // Pure white
  static const Color lightSurface = Color(0xFFFAFAFA); // Soft white
  static const Color lightSurfaceAlt = Color(0xFFF5F5F5); // Elevated surface
  static const Color lightBorder = Color(0xFFE0E0E0); // Subtle border
  static const Color lightMetallic = Color(0xFFF0F0F0); // Metallic sheen
  static const Color lightHighlight = Color(0xFFCCCCCC); // Highlight accent

  // Status colors (monochromatic with intensity)
  static const Color statusGreen = Color(0xFF00FFA3); // Premium Neon Mint
  static const Color statusAmber = Color(0xFFFFB300); // Vibrant amber
  static const Color statusRed = Color(0xFFFF1744); // Vibrant red
  static const Color statusGrey = Color(0xFF757575); // Neutral grey

  // Text hierarchy
  static const Color primaryText =
      Color(0xFF000000); // Pure black for light mode
  static const Color secondaryText = Color(0xFF666666); // Muted text
  static const Color mutedText = Color(0xFF999999); // Subtle text
  static const Color inverseText =
      Color(0xFFFFFFFF); // Pure white for dark mode
}
