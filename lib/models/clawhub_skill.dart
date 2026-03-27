/// A skill entry returned by the ClawHub registry (`npx clawhub search/info`).
class ClawHubSkill {
  final String slug;
  final String name;
  final String description;
  final String version;
  final String author;
  final bool isInstalled;

  const ClawHubSkill({
    required this.slug,
    required this.name,
    required this.description,
    this.version = '',
    this.author = '',
    this.isInstalled = false,
  });

  ClawHubSkill copyWith({bool? isInstalled}) => ClawHubSkill(
        slug: slug,
        name: name,
        description: description,
        version: version,
        author: author,
        isInstalled: isInstalled ?? this.isInstalled,
      );

  /// Parses a JSON map from `npx clawhub search --json` or `npx clawhub info --json`.
  /// Field names are guessed generously to survive version changes in clawhub.
  factory ClawHubSkill.fromJson(Map<String, dynamic> json) {
    final slug = json['slug']?.toString() ??
        json['id']?.toString() ??
        json['name']?.toString() ??
        '';
    final name = json['title']?.toString() ??
        json['displayName']?.toString() ??
        json['name']?.toString() ??
        slug;
    return ClawHubSkill(
      slug: slug,
      name: name,
      description: json['description']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      author: json['author']?.toString() ??
          json['publisher']?.toString() ??
          json['maintainer']?.toString() ??
          '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClawHubSkill && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}
