/// Release boundary for third-party skills that create, import, or operate a
/// wallet outside Plawie's Android-owned approval surfaces.
///
/// This is intentionally a narrow denylist, not a claim that every other
/// community skill is safe. Generic ClawHub installs still require inspection.
/// These entries are blocked because Plawie previously promoted them as if they
/// shared the Personal Wallet or KeeperHub approval contract, which they do not.
class ExternalFinancialSkillPolicy {
  ExternalFinancialSkillPolicy._();

  static const List<String> agentCardReadMethods = <String>[
    'get_balance',
  ];

  static const List<String> moonPayReadMethods = <String>[
    'get_portfolio',
    'get_price',
    'dca_list',
  ];

  static const Set<String> _blockedInstallSlugs = <String>{
    'agent-card',
    'agentcard',
    'moonpay',
    'x402-client',
    'agentkit',
    'cdp-agentkit',
    'coinbase-agentkit',
  };

  static String normalizeSlug(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll('\\', '/').replaceAll('_', '-');
    final segments =
        normalized.split('/').where((segment) => segment.isNotEmpty).toList();
    final lastSegment = segments.isEmpty ? normalized : segments.last;
    return lastSegment.replaceFirst(RegExp(r'@[0-9][0-9a-z.+-]*$'), '');
  }

  static bool isInstallBlocked(String slug) =>
      _blockedInstallSlugs.contains(normalizeSlug(slug));

  static String? installBlockReason(String slug) {
    final normalized = normalizeSlug(slug);
    if (!_blockedInstallSlugs.contains(normalized)) return null;
    if (normalized == 'x402-client') {
      return 'x402-client is a community protocol-instruction skill, not '
          'Coinbase AgentKit. It describes wallet payments outside Plawie\'s '
          'one-use approval broker, so this preview will not install it.';
    }
    if (normalized == 'agentkit' ||
        normalized == 'cdp-agentkit' ||
        normalized == 'coinbase-agentkit') {
      return 'Coinbase AgentKit is not integrated in this Plawie build. A '
          'vetted wallet provider, credential boundary, named wallet route, '
          'and foreground approval adapter are required before installation.';
    }
    if (normalized == 'moonpay') {
      return 'MoonPay CLI creates or imports a separate external HD wallet and '
          'can sign financial operations outside Plawie\'s Wallet approval '
          'broker. In-app installation is blocked until those writes can be '
          'simulated, reviewed, and authorized in Plawie.';
    }
    return 'AgentCard is a separate external payment account. Plawie currently '
        'supports only a read-only connector preview; card creation, refill, '
        'and spending are not installable agent actions.';
  }

  static bool canExecuteAgentCardMethod(String method) =>
      agentCardReadMethods.contains(method.trim());

  static bool canExecuteMoonPayMethod(String method) =>
      moonPayReadMethods.contains(method.trim());

  static String executionBlockReason({
    required String provider,
    required String method,
  }) =>
      'HUMAN_APPROVAL_BOUNDARY: $provider.$method is not exposed by Plawie. '
      'This external provider has separate custody and is not connected to '
      'Plawie\'s one-use Wallet approval broker.';
}
