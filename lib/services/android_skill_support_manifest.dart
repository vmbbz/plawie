enum AndroidSkillSupportStatus {
  readyRequired,
  readyOptional,
  needsConfig,
  needsPack,
  unsupportedOnAndroid,
  manualProotCompat,
  hiddenDesktopOnly,
}

extension AndroidSkillSupportStatusWireName on AndroidSkillSupportStatus {
  String get wireName {
    return switch (this) {
      AndroidSkillSupportStatus.readyRequired => 'ready_required',
      AndroidSkillSupportStatus.readyOptional => 'ready_optional',
      AndroidSkillSupportStatus.needsConfig => 'needs_config',
      AndroidSkillSupportStatus.needsPack => 'needs_pack',
      AndroidSkillSupportStatus.unsupportedOnAndroid =>
        'unsupported_on_android',
      AndroidSkillSupportStatus.manualProotCompat => 'manual_proot_compat',
      AndroidSkillSupportStatus.hiddenDesktopOnly => 'hidden_desktop_only',
    };
  }
}

enum AndroidSkillOwnerLayer {
  openclawSkill,
  androidBridge,
  appNativeCapability,
  gatewayRuntime,
  clawhubSkill,
}

enum AndroidSkillExecutionMode {
  androidBridge,
  appNativeTool,
  gatewayTool,
  httpAdapter,
  nodeScript,
  pythonAdapter,
  instructionOnly,
  dependencyPack,
  prootCompat,
  unsupported,
}

class AndroidSkillSupportEntry {
  final String skillId;
  final AndroidSkillSupportStatus status;
  final AndroidSkillOwnerLayer ownerLayer;
  final AndroidSkillExecutionMode executionMode;
  final List<String> requiredPacks;
  final List<String> requiredConfig;
  final String? unsupportedReason;
  final String smokePrompt;
  final bool launchCritical;

  const AndroidSkillSupportEntry({
    required this.skillId,
    required this.status,
    required this.ownerLayer,
    required this.executionMode,
    this.requiredPacks = const <String>[],
    this.requiredConfig = const <String>[],
    this.unsupportedReason,
    required this.smokePrompt,
    this.launchCritical = false,
  });

  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'androidSupport': status.wireName,
        'ownerLayer': ownerLayer.name,
        'executionMode': executionMode.name,
        'launchCritical': launchCritical,
        if (requiredPacks.isNotEmpty) 'requiredPacks': requiredPacks,
        if (requiredConfig.isNotEmpty) 'requiredConfig': requiredConfig,
        if (unsupportedReason != null && unsupportedReason!.isNotEmpty)
          'unsupportedReason': unsupportedReason,
        if (smokePrompt.isNotEmpty) 'smokePrompt': smokePrompt,
      };
}

class AndroidSkillSupportManifest {
  AndroidSkillSupportManifest._(this.entries);

  factory AndroidSkillSupportManifest.forTesting(
    List<AndroidSkillSupportEntry> entries,
  ) {
    return AndroidSkillSupportManifest._(List.unmodifiable(entries));
  }

  static final AndroidSkillSupportManifest instance =
      AndroidSkillSupportManifest._(_entries);

  final List<AndroidSkillSupportEntry> entries;

  List<String> get skillIds => entries.map((entry) => entry.skillId).toList();

  List<String> get duplicateSkillIds {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final id in skillIds) {
      if (!seen.add(_normalizeSkillId(id))) duplicates.add(id);
    }
    return duplicates.toList()..sort();
  }

  AndroidSkillSupportEntry? entryFor(String skillId) {
    final normalized = _normalizeSkillId(skillId);
    for (final entry in entries) {
      if (_normalizeSkillId(entry.skillId) == normalized) return entry;
    }
    return null;
  }

  List<AndroidSkillSupportEntry> entriesForStatus(
    AndroidSkillSupportStatus status,
  ) {
    return entries.where((entry) => entry.status == status).toList();
  }

  Map<String, int> get countsByStatus {
    final counts = <String, int>{};
    for (final entry in entries) {
      counts.update(entry.status.wireName, (count) => count + 1,
          ifAbsent: () => 1);
    }
    return counts;
  }

  List<String> unclassifiedSkillIds(Set<String> expectedIds) {
    final classified = skillIds.map(_normalizeSkillId).toSet();
    final missing = expectedIds
        .map(_normalizeSkillId)
        .where((id) => !classified.contains(id))
        .toList()
      ..sort();
    return missing;
  }

  static String _normalizeSkillId(String value) => value.trim().toLowerCase();
}

final List<AndroidSkillSupportEntry> _entries =
    List.unmodifiable(<AndroidSkillSupportEntry>[
  _needsConfig(
    '1password',
    config: ['OP_SERVICE_ACCOUNT_TOKEN'],
    smoke: 'List available 1Password vault metadata after account config.',
  ),
  _unsupported(
    'apple-notes',
    reason: 'Apple Notes automation requires macOS app integration.',
  ),
  _unsupported(
    'apple-reminders',
    reason: 'Apple Reminders automation requires macOS app integration.',
  ),
  _ready(
    'avatar_forge',
    owner: AndroidSkillOwnerLayer.androidBridge,
    mode: AndroidSkillExecutionMode.androidBridge,
    smoke: 'Set an avatar expression through the Android bridge.',
  ),
  _ready(
    'battery',
    owner: AndroidSkillOwnerLayer.androidBridge,
    mode: AndroidSkillExecutionMode.androidBridge,
    smoke: 'Report Android battery level through the bridge.',
  ),
  _unsupported(
    'bear-notes',
    reason: 'Bear Notes is a macOS/iOS app workflow without Android bridge.',
  ),
  _readyOptional(
    'blogwatcher',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.httpAdapter,
    smoke: 'Check a small RSS or Atom feed through the app-native adapter.',
  ),
  _needsPack(
    'blucli',
    packs: ['android-cli-core-pack'],
    smoke: 'Run blu command discovery from a verified Android CLI pack.',
  ),
  _readyOptional(
    'camsnap',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.appNativeTool,
    smoke: 'Capture a camera still through the app-native camera adapter.',
  ),
  _ready(
    'canvas',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.appNativeTool,
    smoke: 'Open the in-app canvas and evaluate a small page action.',
  ),
  _ready(
    'clawhub',
    owner: AndroidSkillOwnerLayer.clawhubSkill,
    mode: AndroidSkillExecutionMode.httpAdapter,
    smoke: 'List ClawHub skill metadata through the Android REST adapter.',
  ),
  _needsPack(
    'coding-agent',
    packs: ['android-node-debug-pack'],
    smoke: 'Run a dry coding-agent command in the app-owned workspace.',
  ),
  _readyOptional(
    'diagram-maker',
    owner: AndroidSkillOwnerLayer.openclawSkill,
    mode: AndroidSkillExecutionMode.instructionOnly,
    smoke: 'Create a tiny standalone diagram artifact from instructions.',
  ),
  _needsConfig(
    'discord',
    config: ['DISCORD_BOT_TOKEN'],
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.httpAdapter,
    smoke:
        'Read Discord bot status metadata through the app-native REST adapter.',
  ),
  _needsPack(
    'eightctl',
    packs: ['android-cli-core-pack'],
    smoke: 'Run eightctl version from the verified Android CLI pack.',
  ),
  _needsPack(
    'gemini',
    packs: ['android-node-debug-pack'],
    smoke: 'Run Gemini CLI smoke through the verified Node tool pack.',
  ),
  _needsConfig(
    'gh-issues',
    config: ['GITHUB_TOKEN'],
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.httpAdapter,
    smoke:
        'List GitHub issues for a configured repository through the app-native REST adapter.',
  ),
  _needsPack(
    'gifgrep',
    packs: ['android-vision-media-runtime'],
    smoke: 'Run gifgrep against a bundled tiny media fixture.',
  ),
  _needsConfig(
    'github',
    config: ['GITHUB_TOKEN'],
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.httpAdapter,
    smoke:
        'Read authenticated GitHub user metadata through the app-native REST adapter.',
  ),
  _needsConfig(
    'gog',
    config: ['GOG_ACCOUNT_TOKEN'],
    smoke: 'Read configured GOG library metadata.',
  ),
  _needsConfig(
    'goplaces',
    config: ['GOOGLE_PLACES_API_KEY'],
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.httpAdapter,
    smoke:
        'Resolve a configured Places text search query through the app-native REST adapter.',
  ),
  _ready(
    'healthcheck',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.appNativeTool,
    smoke: 'Run device.health and verify Android readiness fields.',
  ),
  _needsPack(
    'himalaya',
    packs: ['android-cli-core-pack'],
    smoke: 'Run himalaya account discovery from the verified CLI pack.',
  ),
  _unsupported(
    'imsg',
    reason: 'iMessage automation requires macOS Messages integration.',
  ),
  _needsConfig(
    'mcporter',
    config: ['MCPORTER_ENDPOINT', 'MCPORTER_TOKEN'],
    smoke: 'Call the configured mcporter endpoint health route.',
  ),
  _ready(
    'meme-maker',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.appNativeTool,
    smoke: 'Generate a small meme PNG through the Android app-native renderer.',
  ),
  _hiddenDesktop(
    'model-usage',
    reason: 'Local desktop model usage accounting is not an Android GTM gate.',
  ),
  _readyOptional(
    'nano-pdf',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.appNativeTool,
    smoke: 'Extract bounded text from a tiny text-based PDF byte fixture.',
  ),
  _manualProot(
    'node-connect',
    reason: 'Node connector workflows assume a broader Linux shell session.',
  ),
  _needsPack(
    'node-inspect-debugger',
    packs: ['android-node-debug-pack'],
    smoke: 'Run node inspector discovery against a local debug fixture.',
  ),
  _needsConfig(
    'notion',
    config: ['NOTION_TOKEN'],
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.httpAdapter,
    smoke:
        'Read bounded Notion workspace search metadata through the app-native REST adapter.',
  ),
  _hiddenDesktop(
    'obsidian',
    reason: 'Local Obsidian vault automation is a desktop/remote-host concern.',
  ),
  _needsPack(
    'openai-whisper',
    packs: ['android-whisper-runtime'],
    smoke: 'Transcribe a tiny bundled audio fixture with local Whisper.',
  ),
  _needsConfig(
    'openai-whisper-api',
    config: ['OPENAI_API_KEY'],
    smoke: 'Transcribe a tiny audio fixture through the configured OpenAI API.',
  ),
  _needsPack(
    'openhue',
    packs: ['android-cli-core-pack'],
    smoke: 'Run OpenHue discovery from a verified Android CLI pack.',
  ),
  _manualProot(
    'oracle',
    reason: 'Oracle workflow is shell-heavy and belongs in compatibility mode.',
  ),
  _needsConfig(
    'ordercli',
    config: ['ORDERCLI_API_KEY'],
    smoke: 'Read a configured order status fixture.',
  ),
  _unsupported(
    'peekaboo',
    reason: 'Peekaboo depends on macOS screen/window automation.',
  ),
  _needsPack(
    'python-debugpy',
    packs: ['android-python-debug-runtime'],
    smoke: 'Start and stop a debugpy smoke session in the Android runtime.',
  ),
  _needsConfig(
    'sag',
    config: ['SAG_API_KEY'],
    smoke: 'Run a configured SAG API smoke request.',
  ),
  _ready(
    'sensors',
    owner: AndroidSkillOwnerLayer.androidBridge,
    mode: AndroidSkillExecutionMode.androidBridge,
    smoke: 'Read Android sensor availability through the bridge.',
  ),
  _readyOptional(
    'session-logs',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.appNativeTool,
    smoke: 'List, read, or search app-owned chat sessions through Gateway.',
  ),
  _needsPack(
    'sherpa-onnx-tts',
    packs: ['android-tts-runtime'],
    smoke: 'Synthesize a short phrase with the verified Sherpa ONNX pack.',
  ),
  _ready(
    'skill-creator',
    owner: AndroidSkillOwnerLayer.openclawSkill,
    mode: AndroidSkillExecutionMode.instructionOnly,
    smoke: 'Draft a skill scaffold plan without desktop dependencies.',
  ),
  _needsConfig(
    'slack',
    config: ['SLACK_BOT_TOKEN', 'channels.slack'],
    smoke: 'Read Slack bot identity and configured channel metadata.',
  ),
  _needsPack(
    'songsee',
    packs: ['android-audio-runtime'],
    smoke: 'Analyze a tiny bundled audio fixture through the audio pack.',
  ),
  _needsPack(
    'sonoscli',
    packs: ['android-cli-core-pack'],
    smoke: 'Run sonos discovery from the verified Android CLI pack.',
  ),
  _ready(
    'spike',
    owner: AndroidSkillOwnerLayer.openclawSkill,
    mode: AndroidSkillExecutionMode.instructionOnly,
    smoke: 'Create a small Spike planning artifact.',
  ),
  _needsPack(
    'spotify-player',
    packs: ['android-audio-runtime'],
    smoke: 'Run Spotify player status through the verified audio pack.',
  ),
  _readyOptional(
    'summarize',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.appNativeTool,
    smoke:
        'Summarize a provided local text fixture with the app-native adapter.',
  ),
  _ready(
    'taskflow',
    owner: AndroidSkillOwnerLayer.openclawSkill,
    mode: AndroidSkillExecutionMode.instructionOnly,
    smoke: 'Create and inspect a tiny local taskflow.',
  ),
  _ready(
    'taskflow-inbox-triage',
    owner: AndroidSkillOwnerLayer.openclawSkill,
    mode: AndroidSkillExecutionMode.instructionOnly,
    smoke: 'Triage a tiny local task inbox fixture.',
  ),
  _unsupported(
    'things-mac',
    reason: 'Things automation requires the macOS Things app.',
  ),
  _needsPack(
    'tmux',
    packs: ['android-terminal-pack'],
    smoke: 'Run tmux version from the verified terminal pack.',
  ),
  _needsConfig(
    'trello',
    config: ['TRELLO_API_KEY', 'TRELLO_TOKEN'],
    smoke: 'Read a configured Trello board summary.',
  ),
  _ready(
    'vibrate',
    owner: AndroidSkillOwnerLayer.androidBridge,
    mode: AndroidSkillExecutionMode.androidBridge,
    smoke: 'Trigger a short Android haptic action through the bridge.',
  ),
  _needsPack(
    'video-frames',
    packs: ['android-vision-media-runtime'],
    smoke: 'Extract frames from a tiny bundled video fixture.',
  ),
  _needsConfig(
    'voice-call',
    config: ['VOICE_CALL_PROVIDER', 'VOICE_CALL_ACCOUNT'],
    smoke: 'Read configured voice-call provider status.',
  ),
  _needsPack(
    'wacli',
    packs: ['android-cli-core-pack'],
    smoke: 'Run wacli status from the verified Android CLI pack.',
  ),
  _ready(
    'weather',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.httpAdapter,
    smoke: 'Use weather.current for Johannesburg with no web fallback.',
  ),
  _readyOptional(
    'xurl',
    owner: AndroidSkillOwnerLayer.appNativeCapability,
    mode: AndroidSkillExecutionMode.httpAdapter,
    smoke: 'Run xurl GET against a local HTTP fixture.',
  ),
]);

AndroidSkillSupportEntry _ready(
  String id, {
  required AndroidSkillOwnerLayer owner,
  required AndroidSkillExecutionMode mode,
  required String smoke,
}) {
  return AndroidSkillSupportEntry(
    skillId: id,
    status: AndroidSkillSupportStatus.readyRequired,
    ownerLayer: owner,
    executionMode: mode,
    smokePrompt: smoke,
    launchCritical: true,
  );
}

AndroidSkillSupportEntry _needsConfig(
  String id, {
  required List<String> config,
  required String smoke,
  AndroidSkillOwnerLayer owner = AndroidSkillOwnerLayer.openclawSkill,
  AndroidSkillExecutionMode mode = AndroidSkillExecutionMode.gatewayTool,
}) {
  return AndroidSkillSupportEntry(
    skillId: id,
    status: AndroidSkillSupportStatus.needsConfig,
    ownerLayer: owner,
    executionMode: mode,
    requiredConfig: List.unmodifiable(config),
    smokePrompt: smoke,
  );
}

AndroidSkillSupportEntry _readyOptional(
  String id, {
  required AndroidSkillOwnerLayer owner,
  required AndroidSkillExecutionMode mode,
  required String smoke,
}) {
  return AndroidSkillSupportEntry(
    skillId: id,
    status: AndroidSkillSupportStatus.readyOptional,
    ownerLayer: owner,
    executionMode: mode,
    smokePrompt: smoke,
  );
}

AndroidSkillSupportEntry _needsPack(
  String id, {
  required List<String> packs,
  required String smoke,
}) {
  return AndroidSkillSupportEntry(
    skillId: id,
    status: AndroidSkillSupportStatus.needsPack,
    ownerLayer: AndroidSkillOwnerLayer.openclawSkill,
    executionMode: AndroidSkillExecutionMode.dependencyPack,
    requiredPacks: List.unmodifiable(packs),
    smokePrompt: smoke,
  );
}

AndroidSkillSupportEntry _unsupported(
  String id, {
  required String reason,
}) {
  return AndroidSkillSupportEntry(
    skillId: id,
    status: AndroidSkillSupportStatus.unsupportedOnAndroid,
    ownerLayer: AndroidSkillOwnerLayer.openclawSkill,
    executionMode: AndroidSkillExecutionMode.unsupported,
    unsupportedReason: reason,
    smokePrompt: '',
  );
}

AndroidSkillSupportEntry _manualProot(
  String id, {
  required String reason,
}) {
  return AndroidSkillSupportEntry(
    skillId: id,
    status: AndroidSkillSupportStatus.manualProotCompat,
    ownerLayer: AndroidSkillOwnerLayer.gatewayRuntime,
    executionMode: AndroidSkillExecutionMode.prootCompat,
    unsupportedReason: reason,
    smokePrompt: 'Run only after the user explicitly switches to PRoot mode.',
  );
}

AndroidSkillSupportEntry _hiddenDesktop(
  String id, {
  required String reason,
}) {
  return AndroidSkillSupportEntry(
    skillId: id,
    status: AndroidSkillSupportStatus.hiddenDesktopOnly,
    ownerLayer: AndroidSkillOwnerLayer.openclawSkill,
    executionMode: AndroidSkillExecutionMode.unsupported,
    unsupportedReason: reason,
    smokePrompt: '',
  );
}
