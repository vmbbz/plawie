class GatewayToolCatalog {
  static const wildcard = '*';

  // OpenClaw gateway primitive IDs that are valid in tools.allow.
  // Device-native capabilities such as camera/location/sensors are exposed
  // through the paired node/custom skills, not through this allow list.
  static const primitiveIds = <String>[
    'browser',
    'computer',
    'files',
    'memory',
    'search',
    'image',
    'canvas',
    'shell',
  ];

  static const validAllowEntries = <String>{
    wildcard,
    ...primitiveIds,
  };

  static bool isValidAllowEntry(String id) =>
      validAllowEntries.contains(id.trim());

  static List<String> normalizeAllowList(
    dynamic rawAllow, {
    bool expandWildcard = true,
  }) {
    if (rawAllow is! List) return const <String>[];

    final values = rawAllow
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty && isValidAllowEntry(value))
        .toSet();

    if (values.contains(wildcard)) {
      return expandWildcard
          ? primitiveIds.toList(growable: false)
          : const <String>[wildcard];
    }

    final sorted = values.where((value) => value != wildcard).toList()..sort();
    return sorted;
  }

  static List<String> toConfigAllowList(Iterable<String> selectedTools) {
    final selected = selectedTools
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && isValidAllowEntry(value))
        .toSet();

    if (selected.contains(wildcard) || primitiveIds.every(selected.contains)) {
      return const <String>[wildcard];
    }

    final sorted = selected.where((value) => value != wildcard).toList()
      ..sort();
    return sorted;
  }
}
