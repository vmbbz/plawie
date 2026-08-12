import 'dart:collection';
import 'dart:convert';

/// Produces a deterministic signature for Gateway configuration maps.
///
/// JSON object key order is not meaningful. Gateway policy passes commonly
/// rebuild provider maps in a different insertion order, so raw [jsonEncode]
/// comparisons can report a false change and unnecessarily pause live chat.
String canonicalGatewayConfigSignature(Map<dynamic, dynamic> value) {
  return jsonEncode(_normalizeGatewayConfigValue(value));
}

dynamic _normalizeGatewayConfigValue(dynamic value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, dynamic>();
    value.forEach((key, child) {
      sorted[key.toString()] = _normalizeGatewayConfigValue(child);
    });
    return sorted;
  }
  if (value is List) {
    return value.map(_normalizeGatewayConfigValue).toList(growable: false);
  }
  return value;
}
