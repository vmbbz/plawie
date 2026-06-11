String gatewayDisplayUrl(String? rawUrl, {String fallback = ''}) {
  final source = (rawUrl == null || rawUrl.trim().isEmpty)
      ? fallback.trim()
      : rawUrl.trim();
  if (source.isEmpty) return source;

  final uri = Uri.tryParse(source);
  if (uri == null) return _stripTokenFragmentsFallback(source);

  final query = uri.queryParametersAll.entries
      .where((entry) => entry.key.toLowerCase() != 'token')
      .expand((entry) => entry.value.map((value) => MapEntry(entry.key, value)))
      .toList();
  final queryString = query
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
  final fragment = _fragmentContainsToken(uri.fragment) ? '' : uri.fragment;

  var base = uri.replace(query: '', fragment: '').toString();
  while (base.endsWith('?') || base.endsWith('#')) {
    base = base.substring(0, base.length - 1);
  }
  return '$base${queryString.isEmpty ? '' : '?$queryString'}${fragment.isEmpty ? '' : '#$fragment'}';
}

bool _fragmentContainsToken(String fragment) {
  if (fragment.isEmpty) return false;
  final pairs = Uri.splitQueryString(fragment);
  return pairs.keys.any((key) => key.toLowerCase() == 'token');
}

String _stripTokenFragmentsFallback(String source) {
  return source
      .replaceFirst(RegExp(r'([?#&])token=[^#&?]*'), '')
      .replaceFirst(RegExp(r'[?#&]$'), '');
}
