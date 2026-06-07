import '../../models/clawhub_skill.dart';
import '../../models/node_frame.dart';
import '../clawhub_service.dart';
import 'capability_handler.dart';

/// App-native ClawHub metadata adapter for Android.
///
/// This is intentionally read-side only: search and info can run through the
/// ClawHub REST path without Node/npm/PRoot. Install/update/uninstall mutation
/// remains owned by the existing Skills Manager and NativeClawHubSkillInstaller.
class ClawHubCapability extends CapabilityHandler {
  ClawHubCapability({
    ClawHubService? service,
  }) : _service = service ?? ClawHubService.instance;

  final ClawHubService _service;

  @override
  String get name => 'clawhub';

  @override
  List<String> get commands => ['search', 'info'];

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<NodeFrame> handle(String command, Map<String, dynamic> params) async {
    final canonical = _canonicalCommand(command);
    try {
      switch (canonical) {
        case 'clawhub.search':
          return _search(params);
        case 'clawhub.info':
          return _info(params);
        default:
          return NodeFrame.response('', error: {
            'code': 'UNKNOWN_COMMAND',
            'message': 'Unknown ClawHub command: $command',
          });
      }
    } catch (error) {
      return NodeFrame.response('', error: {
        'code': 'CLAWHUB_ERROR',
        'message': error.toString(),
      });
    }
  }

  Future<NodeFrame> _search(Map<String, dynamic> params) async {
    final query = _stringParam(params, const ['query', 'q', 'text', 'slug']);
    if (query == null || query.length < 2) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_QUERY',
        'message': 'clawhub.search requires a query.',
      });
    }
    final limit = _intValue(params['limit'], fallback: 8).clamp(1, 20).toInt();
    final skills = await _service.search(query);
    return NodeFrame.response('', payload: {
      'provider': 'clawhub',
      'action': 'search',
      'query': query,
      'count': skills.length > limit ? limit : skills.length,
      'results': skills.take(limit).map(_skillToJson).toList(),
    });
  }

  Future<NodeFrame> _info(Map<String, dynamic> params) async {
    final slug = _stringParam(params, const ['slug', 'skillId', 'id', 'query']);
    if (slug == null || slug.length < 2) {
      return NodeFrame.response('', error: {
        'code': 'MISSING_SLUG',
        'message': 'clawhub.info requires a slug.',
      });
    }
    final skill = await _service.infoFromApi(slug);
    if (skill == null) {
      return NodeFrame.response('', error: {
        'code': 'CLAWHUB_NOT_FOUND',
        'message': 'No ClawHub metadata found for "$slug".',
      });
    }
    return NodeFrame.response('', payload: {
      'provider': 'clawhub',
      'action': 'info',
      'skill': _skillToJson(skill),
    });
  }

  static String _canonicalCommand(String command) {
    final trimmed = command.trim().toLowerCase();
    return switch (trimmed) {
      'search' || 'clawhub_search' => 'clawhub.search',
      'info' || 'clawhub_info' => 'clawhub.info',
      _ => trimmed,
    };
  }

  static String? _stringParam(
    Map<String, dynamic> params,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = params[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Map<String, dynamic> _skillToJson(ClawHubSkill skill) => {
        'slug': skill.slug,
        'name': skill.name,
        'description': skill.description,
        if (skill.version.isNotEmpty) 'version': skill.version,
        if (skill.author.isNotEmpty) 'author': skill.author,
        'url': skill.clawhubUrl,
        'isInstalled': skill.isInstalled,
        if (skill.stars != null) 'stars': skill.stars,
        if (skill.downloadCount != null) 'downloadCount': skill.downloadCount,
        if (skill.currentInstalls != null)
          'currentInstalls': skill.currentInstalls,
        if (skill.ownerHandle != null && skill.ownerHandle!.isNotEmpty)
          'ownerHandle': skill.ownerHandle,
        if (skill.ownerAvatarUrl != null && skill.ownerAvatarUrl!.isNotEmpty)
          'ownerAvatarUrl': skill.ownerAvatarUrl,
      };
}
