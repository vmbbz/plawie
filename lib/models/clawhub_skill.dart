/// A skill entry returned by the ClawHub registry.
/// Enriched with live stats from `https://clawhub.ai/api/v1/skills/{slug}`.
class ClawHubSkill {
  final String slug;
  final String name;
  final String description;
  final String version;
  final String author;
  final bool isInstalled;

  // ── Live API stats (null = not yet fetched) ──────────────────────────────
  final int? stars;
  final int? downloadCount;
  final int? currentInstalls;
  final String? ownerHandle;
  final String? ownerAvatarUrl;

  const ClawHubSkill({
    required this.slug,
    required this.name,
    required this.description,
    this.version = '',
    this.author = '',
    this.isInstalled = false,
    this.stars,
    this.downloadCount,
    this.currentInstalls,
    this.ownerHandle,
    this.ownerAvatarUrl,
  });

  /// Deep clone with optional overrides.
  ClawHubSkill copyWith({
    bool? isInstalled,
    int? stars,
    int? downloadCount,
    int? currentInstalls,
    String? ownerHandle,
    String? ownerAvatarUrl,
  }) =>
      ClawHubSkill(
        slug: slug,
        name: name,
        description: description,
        version: version,
        author: author,
        isInstalled: isInstalled ?? this.isInstalled,
        stars: stars ?? this.stars,
        downloadCount: downloadCount ?? this.downloadCount,
        currentInstalls: currentInstalls ?? this.currentInstalls,
        ownerHandle: ownerHandle ?? this.ownerHandle,
        ownerAvatarUrl: ownerAvatarUrl ?? this.ownerAvatarUrl,
      );

  /// URL to this skill's page on clawhub.ai.
  String get clawhubUrl => 'https://clawhub.ai/skills/$slug';

  /// True when this skill has live API stats loaded.
  bool get hasStats => stars != null;

  /// Parse the ClawHub REST API response:
  /// `GET https://clawhub.ai/api/v1/skills/{slug}`
  ///
  /// Response shape (observed Apr 2026):
  /// ```json
  /// {
  ///   "skill": { "slug", "displayName", "summary", "tags": {"latest": "1.0.0"},
  ///              "stats": { "stars", "downloads", "installsCurrent" } },
  ///   "latestVersion": { "version" },
  ///   "owner": { "handle", "displayName", "image" }
  /// }
  /// ```
  factory ClawHubSkill.fromApiJson(String slug, Map<String, dynamic> json) {
    final skillObj = json['skill'] as Map<String, dynamic>? ?? {};
    final stats    = skillObj['stats'] as Map<String, dynamic>? ?? {};
    final owner    = json['owner'] as Map<String, dynamic>? ?? {};
    final latestV  = json['latestVersion'] as Map<String, dynamic>? ?? {};
    final tags     = skillObj['tags'] as Map<String, dynamic>? ?? {};
    return ClawHubSkill(
      slug:            slug,
      name:            skillObj['displayName']?.toString() ?? slug,
      description:     skillObj['summary']?.toString() ?? '',
      version:         latestV['version']?.toString() ??
                       tags['latest']?.toString() ?? '',
      author:          owner['displayName']?.toString() ??
                       owner['handle']?.toString() ?? '',
      stars:           (stats['stars'] as num?)?.toInt(),
      downloadCount:   (stats['downloads'] as num?)?.toInt(),
      currentInstalls: (stats['installsCurrent'] as num?)?.toInt(),
      ownerHandle:     owner['handle']?.toString(),
      ownerAvatarUrl:  owner['image']?.toString(),
    );
  }

  /// Parse a JSON map from `npx clawhub search --json` or `clawhub info --json`.
  factory ClawHubSkill.fromJson(Map<String, dynamic> json) {
    final slug = json['slug']?.toString() ??
        json['id']?.toString() ??
        json['name']?.toString() ?? '';
    final name = json['title']?.toString() ??
        json['displayName']?.toString() ??
        json['name']?.toString() ?? slug;
    return ClawHubSkill(
      slug: slug,
      name: name,
      description: json['description']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      author: json['author']?.toString() ??
          json['publisher']?.toString() ??
          json['maintainer']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClawHubSkill && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}
