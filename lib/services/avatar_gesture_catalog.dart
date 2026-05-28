import 'dart:convert';

class AvatarGestureCatalog {
  AvatarGestureCatalog._();

  static const defaultGesture = 'wave right';

  static const Map<String, String> fullBodyPaths = {
    'dance': 'assets/vrm/animations/dance_picatrix.vrma',
    'dance picatrix': 'assets/vrm/animations/dance_picatrix.vrma',
    'picatrix dance': 'assets/vrm/animations/dance_picatrix.vrma',
    'dance_alt': 'assets/vrm/animations/gesture_dance.vrma',
    'dance alt': 'assets/vrm/animations/gesture_dance.vrma',
    'gesture dance': 'assets/vrm/animations/gesture_dance.vrma',
    'spin': 'assets/vrm/animations/gesture_spin.vrma',
    'greeting': 'assets/vrm/animations/gesture_greeting.vrma',
    'squat': 'assets/vrm/animations/gesture_squat.vrma',
    'fight': 'assets/vrm/animations/gesture_fight.vrma',
    'cute': 'assets/vrm/animations/gesture_cute.vrma',
    'elegant': 'assets/vrm/animations/gesture_elegant.vrma',
    'peacesign': 'assets/vrm/animations/gesture_peacesign.vrma',
    'peace sign': 'assets/vrm/animations/gesture_peacesign.vrma',
    'pose': 'assets/vrm/animations/gesture_pose.vrma',
    'powerful': 'assets/vrm/animations/gesture_powerful.vrma',
    'ready': 'assets/vrm/animations/gesture_ready.vrma',
    'shoot': 'assets/vrm/animations/gesture_shoot.vrma',
    'talk': 'assets/vrm/animations/gesture_talk.vrma',
    'dance_picatrix': 'assets/vrm/animations/dance_picatrix.vrma',
    'gesture_dance': 'assets/vrm/animations/gesture_dance.vrma',
    'idle': 'assets/vrm/animations/idle_loop.vrma',
  };

  static const Map<String, String> limbPaths = {
    'both wave cheer': 'assets/vrm/animations/limbs/Both_Wave_Cheer_01.vrma',
    'both wave cheer 1':
        'assets/vrm/animations/limbs/Both_Wave_Cheer_01.vrma',
    'both wave cheer 01':
        'assets/vrm/animations/limbs/Both_Wave_Cheer_01.vrma',
    'both wave cheer 2':
        'assets/vrm/animations/limbs/Both_Wave_Cheer_02.vrma',
    'both wave cheer 02':
        'assets/vrm/animations/limbs/Both_Wave_Cheer_02.vrma',
    'bow': 'assets/vrm/animations/limbs/Bowing_01.vrma',
    'bowing': 'assets/vrm/animations/limbs/Bowing_01.vrma',
    'bowing 1': 'assets/vrm/animations/limbs/Bowing_01.vrma',
    'bowing 01': 'assets/vrm/animations/limbs/Bowing_01.vrma',
    'bowing 2': 'assets/vrm/animations/limbs/Bowing_02.vrma',
    'bowing 02': 'assets/vrm/animations/limbs/Bowing_02.vrma',
    'bowing 3': 'assets/vrm/animations/limbs/Bowing_03.vrma',
    'bowing 03': 'assets/vrm/animations/limbs/Bowing_03.vrma',
    'bowing 4': 'assets/vrm/animations/limbs/Bowing_04.vrma',
    'bowing 04': 'assets/vrm/animations/limbs/Bowing_04.vrma',
    'bowing 5': 'assets/vrm/animations/limbs/Bowing_05.vrma',
    'bowing 05': 'assets/vrm/animations/limbs/Bowing_05.vrma',
    'cheerful wave left':
        'assets/vrm/animations/limbs/Cheerful_Wave_Left_01.vrma',
    'cheerful wave right':
        'assets/vrm/animations/limbs/Cheerful_Wave_Right_01.vrma',
    'chill sit wave': 'assets/vrm/animations/limbs/Chill_Sit_Wave_01.vrma',
    'chill sit': 'assets/vrm/animations/limbs/Chill_Sit_Wave_01.vrma',
    'cross leg sitting wave':
        'assets/vrm/animations/limbs/Cross_Leg_Sitting_Wave_01.vrma',
    'cross leg sit':
        'assets/vrm/animations/limbs/Cross_Leg_Sitting_Wave_01.vrma',
    'excited sitting wave':
        'assets/vrm/animations/limbs/Excited_Sitting_Wave_01.vrma',
    'excited sit':
        'assets/vrm/animations/limbs/Excited_Sitting_Wave_01.vrma',
    'excited wave left':
        'assets/vrm/animations/limbs/Excited_Wave_Left_01.vrma',
    'excited wave right':
        'assets/vrm/animations/limbs/Excited_Wave_Right_01.vrma',
    'exaggerated wave':
        'assets/vrm/animations/limbs/Exaggerated_Wave_Both_01.vrma',
    'exaggerated wave both':
        'assets/vrm/animations/limbs/Exaggerated_Wave_Both_01.vrma',
    'exaggerated wave left':
        'assets/vrm/animations/limbs/Exaggerated_Wave_Left_01.vrma',
    'exaggerated wave right':
        'assets/vrm/animations/limbs/Exaggerated_Wave_Right_01.vrma',
    'fearful wave': 'assets/vrm/animations/limbs/Fearful_Wave_01.vrma',
    'light wave left': 'assets/vrm/animations/limbs/Light_Wave_Left_01.vrma',
    'light wave right':
        'assets/vrm/animations/limbs/Light_Wave_Right_01.vrma',
    'shy wave left': 'assets/vrm/animations/limbs/Shy_Wave_Left_01.vrma',
    'shy wave right': 'assets/vrm/animations/limbs/Shy_Wave_Right_01.vrma',
    'sitting both wave':
        'assets/vrm/animations/limbs/Sitting_Both_Wave_01.vrma',
    'sitting wave': 'assets/vrm/animations/limbs/Sitting_Both_Wave_01.vrma',
    'sitting wave left':
        'assets/vrm/animations/limbs/Sitting_Wave_Left_01.vrma',
    'sitting wave right':
        'assets/vrm/animations/limbs/Sitting_Wave_Right_01.vrma',
    'stylized wave': 'assets/vrm/animations/limbs/Stylized_Wave_Left_01.vrma',
    'stylized wave left':
        'assets/vrm/animations/limbs/Stylized_Wave_Left_01.vrma',
    'stylized wave right':
        'assets/vrm/animations/limbs/Stylized_Wave_Right_01.vrma',
    'wave': 'assets/vrm/animations/limbs/Wave_Right_01.vrma',
    'both wave': 'assets/vrm/animations/limbs/Wave_Both_01.vrma',
    'wave both': 'assets/vrm/animations/limbs/Wave_Both_01.vrma',
    'wave left': 'assets/vrm/animations/limbs/Wave_Left_01.vrma',
    'wave right': 'assets/vrm/animations/limbs/Wave_Right_01.vrma',
  };

  static final List<String> toolGestureNames = _buildToolGestureNames();
  static final List<String> _searchNames = _buildSearchNames();

  static String get toolJsonSchema => jsonEncode({
        'type': 'object',
        'properties': {
          'gesture': {
            'type': 'string',
            'enum': toolGestureNames,
            'description':
                'Exact avatar animation name. Examples: dance, spin, greeting, wave right, cheerful wave left, bowing 4, exaggerated wave right.',
          },
        },
        'required': ['gesture'],
      });

  static String normalize(Object? raw) {
    final value = _clean(raw);
    if (value.isEmpty) return defaultGesture;

    if (value == 'gestures.wave' || value == 'gesture.wave') {
      return defaultGesture;
    }
    if (value.contains('hello') || value == 'hi' || value.startsWith('hi ')) {
      return defaultGesture;
    }
    if (value.contains('nod')) return 'greeting';
    if (value.contains('point') || value.contains('peace')) return 'peacesign';
    if (value.contains('speak')) return 'talk';
    if (value == 'dance vrma') return 'dance alt';

    final direct = _directAlias(value);
    if (direct != null) return direct;

    for (final name in _searchNames) {
      if (value.contains(name)) return name;
    }
    return value;
  }

  static String fullBodyPathForText(Object? raw, {String fallback = 'cute'}) {
    final value = _clean(raw);
    final normalized = normalize(value);
    final direct = fullBodyPaths[normalized];
    if (direct != null) return direct;

    for (final name in _searchNames) {
      final path = fullBodyPaths[name];
      if (path != null && value.contains(name)) return path;
    }
    return fullBodyPaths[fallback]!;
  }

  static List<String> limbPathsForText(Object? raw) {
    final value = _clean(raw);
    if (value.isEmpty) return const [];

    final normalized = normalize(value);
    final direct = limbPaths[normalized];
    if (direct != null) return [direct];

    final paths = <String>[];
    final seen = <String>{};
    for (final name in _searchNames) {
      final path = limbPaths[name];
      if (path != null && value.contains(name) && seen.add(path)) {
        paths.add(path);
      }
    }
    return paths;
  }

  static String _clean(Object? raw) {
    return raw
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll('\\', '/')
            .replaceAll('assets/vrm/', '')
            .replaceAll('animations/', '')
            .replaceAll('limbs/', '')
            .replaceAll('gesture_', 'gesture ')
            .replaceAll('.vrma', '')
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'\s+'), ' ') ??
        '';
  }

  static String? _directAlias(String value) {
    if (fullBodyPaths.containsKey(value) || limbPaths.containsKey(value)) {
      return value;
    }
    final noLeadingGesture = value.startsWith('gesture ')
        ? value.substring('gesture '.length)
        : value;
    if (fullBodyPaths.containsKey(noLeadingGesture) ||
        limbPaths.containsKey(noLeadingGesture)) {
      return noLeadingGesture;
    }
    return null;
  }

  static List<String> _buildToolGestureNames() {
    final names = <String>{
      ...fullBodyPaths.keys,
      ...limbPaths.keys,
    }.toList()
      ..sort();
    return List.unmodifiable(names);
  }

  static List<String> _buildSearchNames() {
    final names = <String>{
      ...fullBodyPaths.keys,
      ...limbPaths.keys,
    }.toList()
      ..sort((a, b) {
        final byLength = b.length.compareTo(a.length);
        return byLength != 0 ? byLength : a.compareTo(b);
      });
    return List.unmodifiable(names);
  }
}
