import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

    // Try REST API first — works without PRoot/gateway.
    final apiResults = await _searchFromApi(query);
    if (apiResults.isNotEmpty) {
      _cache[cacheKey] = _CacheEntry(apiResults);
      return _markInstalled(apiResults, installedSlugs);
    }

    // Fallback: PRoot CLI (requires gateway to be running).
    try {
      final raw = await NativeBridge.runInProot(
        'openclaw skills search "${_sanitize(query)}" --json 2>/dev/null || '
        'openclaw skill search "${_sanitize(query)}" --json 2>/dev/null',
        timeout: 20,
      );

      List<ClawHubSkill> skills = [];
      if (raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw.trim());
          if (decoded is List) {
            skills = decoded
                .whereType<Map<String, dynamic>>()
                .map(ClawHubSkill.fromJson)
                .toList();
          }
        } catch (_) {
          skills = _parseOutput(raw);
        }
      }

      _cache[cacheKey] = _CacheEntry(skills);
      return _markInstalled(skills, installedSlugs);
    } catch (_) {
      return [];
    }
  }

  /// Direct REST API search — no PRoot required, just internet.
  Future<List<ClawHubSkill>> _searchFromApi(String query) async {
    try {
      final uri = Uri.parse('https://clawhub.ai/api/v1/skills')
          .replace(queryParameters: {'q': query.trim()});
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json', 'User-Agent': 'plawie-app/1.0'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded is List
            ? decoded
            : (decoded is Map ? decoded['results'] ?? decoded['skills'] ?? decoded['data'] : null);
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(ClawHubSkill.fromJson)
              .where((s) => s.slug.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Fetch detailed info for a single [slug] via the ClawHub REST API.
  ///
  /// Calls `https://clawhub.ai/api/v1/skills/{slug}` directly — no PRoot,
  /// no rate-limit window, instant (network only). Cache TTL is 30 minutes.
  /// Returns null on any network or parse error.
  Future<ClawHubSkill?> infoFromApi(
    String slug, {
    bool isInstalled = false,
  }) async {
    final cacheKey = 'api:$slug';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired && cached.results.isNotEmpty &&
        cached.results.first.description.isNotEmpty) {
      return cached.results.first.copyWith(isInstalled: isInstalled);
    }
    try {
      final uri = Uri.parse('https://clawhub.ai/api/v1/skills/$slug');
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json', 'User-Agent': 'plawie-app/1.0'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        // Try the nested API shape first; fall back to flat JSON if it yields no description.
        ClawHubSkill skill = ClawHubSkill.fromApiJson(slug, decoded);
        if (skill.description.isEmpty && skill.name == slug) {
          // API shape didn't match — try flat parse.
          skill = ClawHubSkill.fromJson({...decoded, 'slug': slug});
        }
        final result = skill.copyWith(isInstalled: isInstalled);
        _cache[cacheKey] = _CacheEntry([result], ttl: const Duration(minutes: 30));
        return result;
      }
    } catch (_) {}
    return null;
  }

  /// Fetch detailed info for a single [slug] via the CLI (PRoot).
  ///
  /// Prefer [infoFromApi] for speed; this is a fallback when the network is
  /// unavailable or the slug is not in the REST API.
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

  /// Fetch a set of featured/well-known slugs.
  ///
  /// Strategy: try REST API first (fast, rich stats), fall back to CLI per slug.
  Future<List<ClawHubSkill>> fetchFeatured(
    List<String> slugs, {
    Set<String> installedSlugs = const {},
  }) async {
    final results = <ClawHubSkill>[];
    for (final slug in slugs) {
      final installed = installedSlugs.contains(slug);
      // REST API first — fast, gives stars/downloads
      final fromApi = await infoFromApi(slug, isInstalled: installed);
      if (fromApi != null && fromApi.description.isNotEmpty) {
        results.add(fromApi);
        continue;
      }
      // CLI fallback
      final fromCli = await info(slug, isInstalled: installed);
      if (fromCli != null && fromCli.description.isNotEmpty) {
        results.add(fromCli);
        continue;
      }
      // Last resort: minimal card from the API result (even if description empty)
      // or a stub — so the slot is never silently dropped from the featured list.
      if (fromApi != null) {
        results.add(fromApi);
      } else {
        results.add(ClawHubSkill(
          slug: slug,
          name: _slugToDisplayName(slug),
          description: 'View on clawhub.ai',
          isInstalled: installed,
        ));
      }
    }
    return results;
  }

  /// Converts a slug like "coding-agent" → "Coding Agent".
  static String _slugToDisplayName(String slug) =>
      slug.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

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
  final Duration _ttl;
  _CacheEntry(this.results, {Duration? ttl})
      : _at = DateTime.now(),
        _ttl = ttl ?? ClawHubService._cacheTtl;
  bool get isExpired => DateTime.now().difference(_at) > _ttl;
}
