/// Represents a single OpenClaw agent or session discovered from the gateway.
class AgentInfo {
  final String id;
  final String name;
  final bool isDefault;

  const AgentInfo({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  /// The model-selector key used in ChatScreen (e.g. "agent/main").
  String get modelKey => 'agent/$id';

  factory AgentInfo.fromJson(Map<String, dynamic> json, {String? defaultId}) {
    final id = json['id'] as String? ?? json['name'] as String? ?? 'unknown';
    final name = json['name'] as String? ?? id;
    return AgentInfo(
      id: id,
      name: name,
      isDefault: id == defaultId,
    );
  }

  @override
  String toString() => 'AgentInfo(id: $id, name: $name, isDefault: $isDefault)';
}
