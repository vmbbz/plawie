import 'dart:async';
import 'dart:convert';
import '../models/clawhub_skill.dart';
import 'native_bridge.dart';

/// Wraps `npx clawhub search` / `npx clawhub info` with:
///   - Per-query result caching (5-min TTL)
///   - Rate-limit tracking parsed from stderr output
///   - JSON + plain-text output fallback parsing
///
/// Use the singleton [ClawHubService.instance].
class ClawHubService {
  ClawHubService._();
  static final instance = ClawHubService._();

  // ── Result cache ──────────────────────────────────────────────────────────
  final _cache = <String, _CacheEntry>{};
  static const _cacheTtl = Duration(minutes: 5);

  // ── Rate-limit state ──────────────────────────────────────────────────────
  // Parsed from ClawHub stderr: "remaining: 178/180, reset in 48s"
  int _remaining = 180;
  int _windowTotal = 180;
  DateTime? _windowStart;
  static const _windowFallbackSecs = 48;

  /// True when the ClawHub API window is exhausted.
  bool get isRateLimited => _remaining <= 0;

  /// Seconds until the current rate-limit window resets (0 if not limited).
  int get secondsUntilReset {
    if (!isRateLimited || _windowStart == null) return 0;
    final elapsed = DateTime.now().difference(_windowStart!).inSeconds;
    return (_windowFallbackSecs - elapsed).clamp(0, _windowFallbackSecs);
  }

  /// How many API calls remain in the current window.
  int get remaining => _remaining;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Search the ClawHub registry for [query].
  ///
  /// [installedSlugs] is used to set [ClawHubSkill.isInstalled] on results.
  /// Returns [] on rate-limit or network error — check [isRateLimited].
  Future<List<ClawHubSkill>> search(
    String query, {
    Set<String> installedSlugs = const {},
  }) async {
    if (query.trim().isEmpty) return [];

    final cacheKey = 'search:${query.trim().toLowerCase()}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return _markInstalled(cached.results, installedSlugs);
    }

    try {
      final raw = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'npx --yes clawhub search "${_sanitize(query)}" 2>&1',
        timeout: 30,
      );
      _parseRateLimit(raw);
      final skills = _parseOutput(raw);
      _cache[cacheKey] = _CacheEntry(skills);
      return _markInstalled(skills, installedSlugs);
    } catch (_) {
      return [];
    }
  }

  /// Fetch detailed info for a single [slug].
  ///
  /// Returns null on error or if the slug is not found.
  Future<ClawHubSkill?> info(
    String slug, {
    bool isInstalled = false,
  }) async {
    final cacheKey = 'info:$slug';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired && cached.results.isNotEmpty) {
      return cached.results.first.copyWith(isInstalled: isInstalled);
    }

    try {
      final raw = await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && '
        'npx --yes clawhub info "$slug" 2>&1',
        timeout: 20,
      );
      _parseRateLimit(raw);
      final skill = _parseInfoOutput(raw, slug);
      if (skill != null) {
        _cache[cacheKey] = _CacheEntry([skill]);
      }
      return skill?.copyWith(isInstalled: isInstalled);
    } catch (_) {
      return null;
    }
  }

  /// Fetch a set of featured/well-known slugs to pre-populate the Discover tab.
  ///
  /// [slugs] should be a curated list confirmed to exist in the registry.
  Future<List<ClawHubSkill>> fetchFeatured(
    List<String> slugs, {
    Set<String> installedSlugs = const {},
  }) async {
    final results = <ClawHubSkill>[];
    for (final slug in slugs) {
      final skill = await info(slug, isInstalled: installedSlugs.contains(slug));
      if (skill != null) results.add(skill);
    }
    return results;
  }

  /// Drop all cached results (e.g. after install/uninstall).
  void invalidateCache() => _cache.clear();

  // ── Parsing ───────────────────────────────────────────────────────────────

  /// Tries JSON first, falls back to line-by-line text parsing.
  List<ClawHubSkill> _parseOutput(String raw) {
    // ── JSON path ──
    final jsonStart = raw.indexOf('[');
    if (jsonStart != -1) {
      try {
        final decoded = jsonDecode(raw.substring(jsonStart));
        if (decoded is List) {
          final skills = decoded
              .whereType<Map<String, dynamic>>()
              .map(ClawHubSkill.fromJson)
              .where((s) => s.slug.isNotEmpty)
              .toList();
          if (skills.isNotEmpty) return skills;
        }
      } catch (_) {}
    }
    // ── Text path ──
    // Matches: "  slug-name (1.2.3) - Description text"
    return _parseTextLines(raw);
  }

  ClawHubSkill? _parseInfoOutput(String raw, String slug) {
    // ── JSON path ──
    final objStart = raw.indexOf('{');
    if (objStart != -1) {
      try {
        final decoded = jsonDecode(raw.substring(objStart));
        if (decoded is Map<String, dynamic>) {
          return ClawHubSkill.fromJson({'slug': slug, ...decoded});
        }
      } catch (_) {}
    }
    // ── Text path: "Name: Foo\nVersion: 1.0.0\nDescription: ..." ──
    String? name, version, description, author;
    for (final line in raw.split('\n')) {
      final kv = line.split(':');
      if (kv.length >= 2) {
        final key = kv[0].trim().toLowerCase();
        final val = kv.sublist(1).join(':').trim();
        if (key == 'name') name = val;
        if (key == 'version') version = val;
        if (key == 'description') description = val;
        if (key == 'author' || key == 'publisher') author = val;
      }
    }
    if (name != null || description != null) {
      return ClawHubSkill(
        slug: slug,
        name: name ?? slug,
        description: description ?? '',
        version: version ?? '',
        author: author ?? '',
      );
    }
    return null;
  }

  /// Parses plain text lines like:
  ///   "  my-skill (1.0.2) - A description of the skill"
  List<ClawHubSkill> _parseTextLines(String raw) {
    final results = <ClawHubSkill>[];
    final lineRe = RegExp(r'^\s+([\w@/-]+)\s+\(([^)]+)\)\s+-\s+(.+)$');
    for (final line in raw.split('\n')) {
      final m = lineRe.firstMatch(line);
      if (m != null) {
        results.add(ClawHubSkill(
          slug: m.group(1)!.trim(),
          name: m.group(1)!.trim(),
          version: m.group(2)!.trim(),
          description: m.group(3)!.trim(),
        ));
      }
    }
    return results;
  }

  void _parseRateLimit(String output) {
    // "remaining: 178/180, reset in 48s"
    final m = RegExp(r'remaining:\s*(\d+)/(\d+)').firstMatch(output);
    if (m != null) {
      _remaining = int.tryParse(m.group(1) ?? '') ?? _remaining;
      _windowTotal = int.tryParse(m.group(2) ?? '') ?? _windowTotal;
      _windowStart = DateTime.now();
    }
  }

  List<ClawHubSkill> _markInstalled(
    List<ClawHubSkill> skills,
    Set<String> installedSlugs,
  ) {
    if (installedSlugs.isEmpty) return skills;
    return skills
        .map((s) => s.copyWith(isInstalled: installedSlugs.contains(s.slug)))
        .toList();
  }

  String _sanitize(String input) =>
      input.replaceAll('"', '').replaceAll(r'\', '').trim();
}

// ── Private cache entry ───────────────────────────────────────────────────────

class _CacheEntry {
  final List<ClawHubSkill> results;
  final DateTime _at;
  _CacheEntry(this.results) : _at = DateTime.now();
  bool get isExpired =>
      DateTime.now().difference(_at) > ClawHubService._cacheTtl;
}
