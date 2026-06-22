class GatewayToolCatalog {
  static const wildcard = '*';
  static const mobileSafeProfile = 'full';
  static const allToolsProfile = 'full';

  // OpenClaw gateway primitive IDs that are valid in tools.allow.
  // Device-native capabilities such as camera/location/sensors are exposed
  // through the paired node/custom skills, not through this allow list.
  static const primitiveIds = <String>[
    'browser',
    'files',
    'search',
    'image',
    'shell',
  ];

  static const mobileNodeAllowCommands = <String>[
    'avatar.gesture',
    'avatar.mode',
    'avatar.model',
    'avatar.status',
    'avatar_gesture',
    'avatar_mode',
    'avatar_model',
    'avatar_status',
    'gesture.wave',
    'gestures.wave',
    'wave',
    'blogwatcher.check',
    'blogwatcher_check',
    'blogwatcher',
    'session-logs.query',
    'session_logs_query',
    'session-logs',
    'session_logs',
    'camera.snap',
    'camera.clip',
    'camera.list',
    'camsnap',
    'camera_snap',
    'camera_clip',
    'camera_list',
    'clawhub.search',
    'clawhub.info',
    'clawhub_search',
    'clawhub_info',
    'discord.me',
    'discord_me',
    'discord',
    'discord.status',
    'discord_status',
    'eightctl.status',
    'eightctl_status',
    'eightctl',
    'eightctl.whoami',
    'eightctl_whoami',
    'eightctl.device-info',
    'eightctl_device_info',
    'slack.me',
    'slack_me',
    'slack.status',
    'slack_status',
    'slack.post',
    'slack_post',
    'slack',
    '1password.vaults',
    '1password_vaults',
    '1password',
    'onepassword.vaults',
    'onepassword_vaults',
    'onepassword',
    'op.vaults',
    'op_vaults',
    'gemini.models',
    'gemini_models',
    'gemini.generate',
    'gemini_generate',
    'gemini',
    'github.user',
    'github_user',
    'github',
    'gh-issues.list',
    'gh_issues_list',
    'gh-issues',
    'gh_issues',
    'goplaces.search',
    'goplaces_search',
    'goplaces',
    'mcporter.health',
    'mcporter_health',
    'mcporter.status',
    'mcporter_status',
    'mcporter',
    'notion.search',
    'notion_search',
    'notion',
    'sag.voices',
    'sag_voices',
    'sag.speak',
    'sag_speak',
    'sag.tts',
    'sag_tts',
    'sag',
    'spotify-player.profile',
    'spotify_player_profile',
    'spotify-player.currently-playing',
    'spotify_player_currently_playing',
    'spotify-player',
    'spotify_player',
    'spotify.profile',
    'spotify_profile',
    'spotify',
    'openai-whisper-api.transcribe',
    'openai_whisper_api_transcribe',
    'openai-whisper-api',
    'openai_whisper_api',
    'meme-maker.create',
    'meme_maker_create',
    'meme-maker_create',
    'nano-pdf.extract',
    'nano_pdf_extract',
    'nano-pdf',
    'nano_pdf',
    'canvas.navigate',
    'canvas.eval',
    'canvas.snapshot',
    'canvas.present',
    'canvas.hide',
    'canvas_navigate',
    'canvas_eval',
    'canvas_snapshot',
    'canvas_present',
    'canvas_hide',
    'dir.list',
    'dir_list',
    'dir',
    'flash.on',
    'flash.off',
    'flash.toggle',
    'flash.status',
    'flash_on',
    'flash_off',
    'flash_toggle',
    'flash_status',
    'torch.on',
    'torch.off',
    'torch.toggle',
    'torch.status',
    'torch_on',
    'torch_off',
    'torch_toggle',
    'torch_status',
    'location.get',
    'location_get',
    'device.status',
    'device.info',
    'device.permissions',
    'device.health',
    'device_status',
    'device_info',
    'device_permissions',
    'device_health',
    'screen.record',
    'screen_record',
    'sensor.read',
    'sensor.list',
    'sensor_read',
    'sensor_list',
    'summarize.text',
    'summarize_text',
    'summarize',
    'trello.boards',
    'trello_boards',
    'trello',
    'weather.current',
    'weather.forecast',
    'weather_current',
    'weather_forecast',
    'get_weather',
    'xurl.request',
    'xurl_request',
    'xurl',
    'haptic.vibrate',
    'haptic_vibrate',
    'vibrate',
  ];

  static const validAllowEntries = <String>{
    wildcard,
    ...primitiveIds,
    'exec',
    'process',
    'code_execution',
    'read',
    'write',
    'edit',
    'apply_patch',
    'web_search',
    'x_search',
    'web_fetch',
    'memory_search',
    'memory_get',
    'sessions_list',
    'sessions_history',
    'sessions_send',
    'sessions_spawn',
    'sessions_yield',
    'subagents',
    'session_status',
    'message',
    'cron',
    'gateway',
    'image_generate',
    'music_generate',
    'video_generate',
    'group:runtime',
    'group:fs',
    'group:sessions',
    'group:memory',
    'group:web',
    'group:ui',
    'group:automation',
    'group:messaging',
    'group:nodes',
    'group:media',
  };

  static const uiAllowEntryAliases = <String, List<String>>{
    'browser': ['browser'],
    'files': ['group:fs'],
    'search': ['group:web'],
    'image': ['image'],
    'shell': ['group:runtime'],
  };

  static const uiPrimitiveAliases = <String, List<String>>{
    'group:fs': ['files'],
    'group:web': ['browser', 'search'],
    'group:runtime': ['shell'],
    'group:media': ['image'],
  };

  /// Android default.
  ///
  /// OpenClaw applies tools.profile first, then tools.allow narrows that base.
  /// For the mobile/native owner, narrowing this to groups is unsafe: the
  /// Gateway may remove the callable `nodes` tool even while the Android node
  /// commands are connected. Preserve wildcard access so provider tool schemas
  /// include the real OpenClaw tools, then rely on gateway.nodes.allowCommands
  /// for the Android command allowlist.
  static const defaultMobileAllowList = <String>[
    wildcard,
  ];

  static Map<String, dynamic> defaultMobileToolsConfig() => <String, dynamic>{
        'profile': mobileSafeProfile,
        'allow': defaultMobileAllowList.toList(growable: false),
      };

  static void applyDefaultMobilePolicy(Map<String, dynamic> config) {
    config['tools'] = defaultMobileToolsConfig();
  }

  static bool isValidAllowEntry(String id) =>
      validAllowEntries.contains(id.trim());

  static List<String> normalizeAllowList(
    dynamic rawAllow, {
    bool expandWildcard = true,
  }) {
    if (rawAllow is! List) return const <String>[];

    final values = rawAllow
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty && isValidAllowEntry(value))
        .toSet();

    if (values.contains(wildcard)) {
      return expandWildcard
          ? primitiveIds.toList(growable: false)
          : const <String>[wildcard];
    }

    final expanded = <String>{};
    for (final value in values.where((value) => value != wildcard)) {
      if (primitiveIds.contains(value)) {
        expanded.add(value);
        continue;
      }
      final aliases = uiPrimitiveAliases[value];
      if (aliases != null) expanded.addAll(aliases);
    }

    final sorted = expanded.toList()..sort();
    return sorted;
  }

  static List<String> toConfigAllowList(Iterable<String> selectedTools) {
    final rawSelected = selectedTools
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final selected = selectedTools
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .expand((value) {
      final aliases = uiAllowEntryAliases[value];
      if (aliases != null) return aliases;
      return isValidAllowEntry(value) ? [value] : const <String>[];
    }).toSet();

    if (rawSelected.contains(wildcard) ||
        primitiveIds.every(rawSelected.contains)) {
      return const <String>[wildcard];
    }

    final sorted = selected.where((value) => value != wildcard).toList()
      ..sort();
    return sorted;
  }

  static bool isExplicitAllProfile(dynamic profile) {
    final value = profile?.toString().trim().toLowerCase() ?? '';
    return value == allToolsProfile || value == 'advanced' || value == 'all';
  }

  static String profileForAllowList(Iterable<String> allowList) {
    return allowList.contains(wildcard) ? allToolsProfile : mobileSafeProfile;
  }
}
