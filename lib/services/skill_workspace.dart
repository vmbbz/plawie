/// Canonical workspace-relative skill paths for agent/gateway context.
///
/// Anything the LLM or gateway tools can name must use [relativeDoc] — never
/// bundle paths under `full-openclaw` or `node_modules/openclaw/skills`.
class SkillWorkspace {
  SkillWorkspace._();

  static const String kDocRelativePrefix = 'skills/';

  static String normalizeSkillId(String skillId) {
    return skillId.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');
  }

  /// Always `skills/<id>/SKILL.md` — safe for the gateway `read` tool.
  static String relativeDoc(String skillId) {
    final normalized = normalizeSkillId(skillId);
    return '$kDocRelativePrefix$normalized/SKILL.md';
  }

  /// Detect paths that will double-join against the workspace root.
  static bool isBundleOrAbsoluteLeak(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('node_modules/openclaw/skills') ||
        normalized.contains('full-openclaw/') ||
        normalized.startsWith('/data/') ||
        normalized.startsWith('./data/');
  }

  /// Best-effort repair for double-joined or bundle-leaked read paths.
  static String? repairLeakedReadPath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return null;

    final normalized = trimmed.replaceAll('\\', '/');
    final skillsIdx = normalized.lastIndexOf('/skills/');
    if (skillsIdx >= 0) {
      final tail = normalized.substring(skillsIdx + 1);
      if (tail.startsWith('skills/') && tail.endsWith('/SKILL.md')) {
        return tail;
      }
      final parts = tail.split('/');
      if (parts.length >= 2) {
        final id = parts[1];
        if (id.isNotEmpty) return relativeDoc(id);
      }
    }

    if (isBundleOrAbsoluteLeak(normalized)) {
      final match =
          RegExp(r'/skills/([a-z0-9_-]+)/SKILL\.md', caseSensitive: false)
              .firstMatch(normalized);
      if (match != null) {
        return relativeDoc(match.group(1)!);
      }
    }
    return null;
  }
}
