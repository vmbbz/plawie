/// Canonical Android-facing contract for the gifgrep skill.
///
/// The upstream skill document describes CLI commands that are not implemented
/// by the verified Android binary. These app-native actions are the source of
/// truth for Gateway registration, deterministic chat routing, and UI copy.
class GifgrepContract {
  const GifgrepContract._();

  static const actions = <String>['status', 'search', 'still', 'sheet'];
  static const localActions = <String>['still', 'sheet'];

  static bool isLocalAction(String? action) => localActions.contains(action);

  static String? localActionForMessage(String message) {
    final lower = message.toLowerCase();
    if (RegExp(
      r'\b(?:first\s+frame|single\s+frame|thumbnail|still\s+image|snapshot)\b',
    ).hasMatch(lower)) {
      return 'still';
    }
    if (RegExp(
      r'\b(?:contact\s+sheet|storyboard|montage|sheet\s+of\s+frames)\b',
    ).hasMatch(lower)) {
      return 'sheet';
    }
    if (RegExp(r'\bstill\b').hasMatch(lower)) return 'still';
    if (RegExp(r'\bsheet\b').hasMatch(lower)) return 'sheet';
    return null;
  }

  static Map<String, dynamic> inputSchema() => {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': actions,
            'description':
                'status checks the Android runtime; search queries online providers; still extracts one local frame; sheet creates a local storyboard/contact sheet.',
          },
          'query': {
            'type': 'string',
            'description': 'Online search text. Required for search.',
          },
          'source': {
            'type': 'string',
            'enum': ['auto', 'giphy', 'klipy', 'tenor'],
            'description':
                'Online provider. auto selects a configured provider.',
          },
          'max': {'type': 'integer', 'minimum': 1, 'maximum': 10},
          'limit': {'type': 'integer', 'minimum': 1, 'maximum': 10},
          'inputPath': {
            'type': 'string',
            'description':
                'Existing GIF in Plawie app-owned storage. For still/sheet, never invent a filesystem path; use the app-provided imported path.',
          },
          'mediaPath': {
            'type': 'string',
            'description':
                'Alias for an app-provided imported GIF path. Prefer this when the attachment resolver supplies it.',
          },
          'outputPath': {
            'type': 'string',
            'description': 'Optional PNG path inside app-owned storage.',
          },
          'atMs': {
            'type': 'integer',
            'minimum': 0,
            'description': 'Frame time offset in milliseconds for still.',
          },
          'frames': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 12,
            'description': 'Number of sampled frames for sheet.',
          },
          'cols': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 8,
            'description': 'Number of columns for sheet.',
          },
        },
        'required': ['action'],
      };

  static const String mobileGuidance =
      'gifgrep Android: status checks the installed managed binary; search is online and may require GIPHY_API_KEY or KLIPY_API_KEY; still and sheet are key-free app-native Dart operations over an app-owned GIF inputPath. If search returns GIFGREP_PROVIDER_CONFIG_REQUIRED, open the gifgrep configuration UI; do not reinstall the skill.';
}
