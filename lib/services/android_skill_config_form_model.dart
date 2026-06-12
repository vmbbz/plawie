enum AndroidSkillConfigFieldTarget { env, config }

enum AndroidSkillConfigInputKind {
  secret,
  text,
  url,
  channelId,
  accountId,
  provider,
  toggle,
}

class AndroidSkillConfigFieldModel {
  final String key;
  final AndroidSkillConfigFieldTarget target;
  final String label;
  final String helper;
  final String inputHint;
  final String group;
  final AndroidSkillConfigInputKind inputKind;
  final bool secret;
  final bool required;
  final List<String> enumOptions;
  final String? validationPattern;

  const AndroidSkillConfigFieldModel({
    required this.key,
    required this.target,
    required this.label,
    required this.helper,
    required this.inputHint,
    required this.group,
    required this.inputKind,
    required this.secret,
    required this.required,
    this.enumOptions = const <String>[],
    this.validationPattern,
  });
}

class AndroidSkillConfigFormModel {
  final String skillId;
  final String title;
  final List<String> envKeys;
  final List<String> configKeys;
  final List<AndroidSkillConfigFieldModel> fields;
  final String? runtimeGate;
  final bool configOnlyCanSatisfy;

  const AndroidSkillConfigFormModel({
    required this.skillId,
    required this.title,
    required this.envKeys,
    required this.configKeys,
    required this.fields,
    required this.runtimeGate,
    required this.configOnlyCanSatisfy,
  });

  List<String> get allKeys => [
        ...envKeys,
        ...configKeys,
      ];

  bool get hasFields => envKeys.isNotEmpty || configKeys.isNotEmpty;

  Map<String, List<AndroidSkillConfigFieldModel>> get groupedFields {
    final grouped = <String, List<AndroidSkillConfigFieldModel>>{};
    for (final field in fields) {
      grouped.putIfAbsent(field.group, () => <AndroidSkillConfigFieldModel>[]);
      grouped[field.group]!.add(field);
    }
    return grouped;
  }

  String get runtimeGateLabel {
    if (runtimeGate == null || runtimeGate!.isEmpty) return 'config';
    final normalized = runtimeGate!.trim().toLowerCase();
    if (normalized == 'missing_native_config' ||
        normalized == 'missing_native_env' ||
        normalized == 'needs_user_config') {
      return 'needs config';
    }
    return runtimeGate!.replaceAll('_', ' ');
  }

  factory AndroidSkillConfigFormModel.fromSkill(
    Map<String, dynamic> skill,
  ) {
    final requiredEnv = _stringList(skill['requiredEnv']);
    final requiredConfig = _stringList(skill['requiredConfig']);
    final envKeys = <String>[...requiredEnv];
    final configKeys = <String>[];
    for (final key in requiredConfig) {
      if (_looksLikeEnvKey(key)) {
        if (!envKeys.contains(key)) envKeys.add(key);
      } else {
        configKeys.add(key);
      }
    }
    final skillId = skill['skillId']?.toString().trim() ?? 'unknown';
    final requiredFields = [
      ...envKeys,
      ...configKeys,
    ];
    final fields = requiredFields
        .map((key) => _fieldFor(skillId, key))
        .toList(growable: false);

    final gate = _firstNonEmpty([
      skill['primaryGate'],
      skill['runtimeStatus'],
    ]);

    return AndroidSkillConfigFormModel(
      skillId: skillId,
      title: _titleForSkill(skillId),
      envKeys: envKeys,
      configKeys: configKeys,
      fields: fields,
      runtimeGate: gate,
      configOnlyCanSatisfy:
          requiredFields.isNotEmpty && !_skillNeedsMoreThanConfig(skill),
    );
  }

  static AndroidSkillConfigFormModel? fromReadiness(
    Map<String, dynamic> readiness,
    String skillId,
  ) {
    final normalized = _normalizeSkillId(skillId);
    for (final skill in _mapList(readiness['skills'])) {
      if (_normalizeSkillId(skill['skillId']?.toString() ?? '') == normalized) {
        return AndroidSkillConfigFormModel.fromSkill(skill);
      }
    }
    return null;
  }

  static List<AndroidSkillConfigFormModel> allFromReadiness(
    Map<String, dynamic> readiness,
  ) {
    return _mapList(readiness['skills'])
        .where(_isConfigurableReadinessGate)
        .map(AndroidSkillConfigFormModel.fromSkill)
        .where((form) => form.hasFields)
        .toList(growable: false);
  }

  static bool _gateNeedsMoreThanConfig(String? gate) {
    final normalized = gate?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return normalized == 'missing_native_bin' ||
        normalized == 'missing_native_runtime' ||
        normalized == 'missing_native_python_package' ||
        normalized == 'missing_native_node_package' ||
        normalized == 'missing_native_plugin' ||
        normalized == 'missing_native_skill' ||
        normalized == 'missing_binary' ||
        normalized == 'missing_dependency' ||
        normalized == 'missing_plugin' ||
        normalized == 'missing_pack' ||
        normalized == 'missing_manifest' ||
        normalized == 'dependency_pack' ||
        normalized == 'manual_proot_required' ||
        normalized == 'unsupported_native' ||
        normalized == 'unsupported_on_android';
  }

  static bool _isConfigurableReadinessGate(Map<String, dynamic> skill) {
    if (skill['androidSupport']?.toString() == 'needs_config') return true;
    if (skill['androidSupport']?.toString() != 'needs_pack') return false;
    final isConfigGate = skill['runtimeStatus']?.toString() == 'needs_config' ||
        skill['provisioningStatus']?.toString() == 'needs_user_config';
    return isConfigGate && !_skillNeedsMoreThanConfig(skill);
  }

  static bool _skillNeedsMoreThanConfig(Map<String, dynamic> skill) {
    if (_stringList(skill['missingBins']).isNotEmpty ||
        _stringList(skill['missingPacks']).isNotEmpty) {
      return true;
    }
    if (_gateNeedsMoreThanConfig(skill['dependencyGateStatus']?.toString())) {
      return true;
    }
    if (_gateNeedsMoreThanConfig(skill['primaryGate']?.toString())) {
      return true;
    }
    return _stringList(skill['gates']).any(_gateNeedsMoreThanConfig);
  }
}

String _normalizeSkillId(String value) =>
    value.trim().toLowerCase().replaceAll('_', '-');

AndroidSkillConfigFieldModel _fieldFor(String skillId, String key) {
  switch (key) {
    case 'OP_SERVICE_ACCOUNT_TOKEN':
      return _envSecret(
        key,
        label: 'Service account token',
        inputHint: 'Paste the 1Password service account token',
      );
    case 'OP_CONNECT_HOST':
      return _envField(
        key,
        label: 'Connect host',
        group: 'Connection',
        inputKind: AndroidSkillConfigInputKind.url,
        inputHint: 'https://connect.example.com',
      );
    case 'OP_CONNECT_TOKEN':
      return _envSecret(
        key,
        label: 'Connect token',
        inputHint: 'Paste the 1Password Connect bearer token',
      );
    case 'DISCORD_BOT_TOKEN':
      return _envSecret(
        key,
        label: 'Bot token',
        inputHint: 'Paste the Discord bot token',
      );
    case 'GITHUB_TOKEN':
      return _envSecret(
        key,
        label: 'GitHub token',
        inputHint: 'Paste a GitHub token',
      );
    case 'GOG_ACCOUNT_TOKEN':
      return _envSecret(
        key,
        label: 'Account token',
        inputHint: 'Paste the GOG account token',
      );
    case 'EIGHTCTL_PASSWORD':
      return _envSecret(
        key,
        label: 'Eight Sleep password',
        inputHint: 'Paste the Eight Sleep account password',
      );
    case 'EIGHTCTL_EMAIL':
      return _envField(
        key,
        label: 'Eight Sleep email',
        group: 'Account',
        inputKind: AndroidSkillConfigInputKind.text,
        inputHint: 'you@example.com',
      );
    case 'EIGHT_SLEEP_EMAIL':
      return _envField(
        key,
        label: 'Eight Sleep email',
        group: 'Account',
        inputKind: AndroidSkillConfigInputKind.text,
        inputHint: 'you@example.com',
      );
    case 'eightctl.deviceId':
      return _configField(
        key,
        label: 'Eight Sleep device ID',
        group: 'Device',
        inputKind: AndroidSkillConfigInputKind.accountId,
        inputHint: 'Eight Sleep device ID',
      );
    case 'plugins.entries.voice-call.enabled':
      return _configField(
        key,
        label: 'Enable voice-call skill',
        group: 'Skill',
        inputKind: AndroidSkillConfigInputKind.toggle,
        inputHint: 'Enable this configured provider',
      );
    case 'GOOGLE_PLACES_API_KEY':
      return _envSecret(
        key,
        label: 'Google Places API key',
        inputHint: 'Paste the Google Places API key',
      );
    case 'GEMINI_API_KEY':
      return _envSecret(
        key,
        label: 'Gemini API key',
        inputHint: 'Paste the Gemini API key',
      );
    case 'MCPORTER_ENDPOINT':
      return _envField(
        key,
        label: 'MCPorter endpoint',
        group: 'Connection',
        inputKind: AndroidSkillConfigInputKind.url,
        inputHint: 'https://example.com',
      );
    case 'MCPORTER_TOKEN':
      return _envSecret(
        key,
        label: 'MCPorter token',
        inputHint: 'Paste the MCPorter token',
      );
    case 'NOTION_TOKEN':
      return _envSecret(
        key,
        label: 'Integration token',
        inputHint: 'Paste the Notion integration token',
      );
    case 'OPENAI_API_KEY':
      return _envSecret(
        key,
        label: 'OpenAI API key',
        inputHint: 'Paste the OpenAI API key',
      );
    case 'ORDERCLI_API_KEY':
      return _envSecret(
        key,
        label: 'Order API key',
        inputHint: 'Paste the Order API key',
      );
    case 'SAG_API_KEY':
      return _envSecret(
        key,
        label: 'SAG API key',
        inputHint: 'Paste the SAG API key',
      );
    case 'ELEVENLABS_API_KEY':
      return _envSecret(
        key,
        label: 'ElevenLabs API key',
        inputHint: 'Paste the ElevenLabs API key',
      );
    case 'SLACK_BOT_TOKEN':
      return _envSecret(
        key,
        label: 'Bot token',
        inputHint: 'Paste the Slack bot token',
      );
    case 'SPOTIFY_ACCESS_TOKEN':
      return _envSecret(
        key,
        label: 'Access token',
        inputHint: 'Paste the Spotify OAuth access token',
      );
    case 'channels.slack':
      return _configField(
        key,
        label: 'Default Slack channel',
        group: 'Workspace',
        inputKind: AndroidSkillConfigInputKind.channelId,
        inputHint: 'Channel name or ID',
      );
    case 'TRELLO_API_KEY':
      return _envSecret(
        key,
        label: 'API key',
        inputHint: 'Paste the Trello API key',
      );
    case 'TRELLO_TOKEN':
      return _envSecret(
        key,
        label: 'Token',
        inputHint: 'Paste the Trello token',
      );
    case 'VOICE_CALL_PROVIDER':
      return _envField(
        key,
        label: 'Provider',
        group: 'Provider',
        inputKind: AndroidSkillConfigInputKind.provider,
        inputHint: 'Select provider',
        enumOptions: const ['twilio', 'telnyx', 'custom'],
      );
    case 'VOICE_CALL_ACCOUNT':
      return _envField(
        key,
        label: 'Account identifier',
        group: 'Provider',
        inputKind: AndroidSkillConfigInputKind.accountId,
        inputHint: 'Provider account ID',
      );
  }

  if (_looksLikeEnvKey(key)) {
    final secret = _looksSecretLike(key);
    return _envField(
      key,
      label: _labelFromKey(key),
      group: secret ? 'Credentials' : 'Config',
      inputKind: secret
          ? AndroidSkillConfigInputKind.secret
          : AndroidSkillConfigInputKind.text,
      secret: secret,
    );
  }

  final secret = _looksSecretLike(key);
  return _configField(
    key,
    label: _labelFromKey(key),
    group: secret ? 'Credentials' : 'Config',
    inputKind: secret
        ? AndroidSkillConfigInputKind.secret
        : AndroidSkillConfigInputKind.text,
    secret: secret,
  );
}

AndroidSkillConfigFieldModel _envSecret(
  String key, {
  required String label,
  String group = 'Credentials',
  String helper = '',
  String inputHint = '',
}) {
  return _envField(
    key,
    label: label,
    group: group,
    helper: helper,
    inputHint: inputHint,
    inputKind: AndroidSkillConfigInputKind.secret,
    secret: true,
  );
}

AndroidSkillConfigFieldModel _envField(
  String key, {
  required String label,
  required String group,
  required AndroidSkillConfigInputKind inputKind,
  String helper = '',
  String inputHint = '',
  bool? secret,
  List<String> enumOptions = const <String>[],
}) {
  final isSecret = secret ?? inputKind == AndroidSkillConfigInputKind.secret;
  return AndroidSkillConfigFieldModel(
    key: key,
    target: AndroidSkillConfigFieldTarget.env,
    label: label,
    helper: helper,
    inputHint: inputHint,
    group: group,
    inputKind: inputKind,
    secret: isSecret,
    required: true,
    enumOptions: enumOptions,
  );
}

AndroidSkillConfigFieldModel _configField(
  String key, {
  required String label,
  required String group,
  required AndroidSkillConfigInputKind inputKind,
  String helper = '',
  String inputHint = '',
  bool secret = false,
  List<String> enumOptions = const <String>[],
}) {
  return AndroidSkillConfigFieldModel(
    key: key,
    target: AndroidSkillConfigFieldTarget.config,
    label: label,
    helper: helper,
    inputHint: inputHint,
    group: group,
    inputKind: inputKind,
    secret: secret,
    required: true,
    enumOptions: enumOptions,
  );
}

String _titleForSkill(String skillId) {
  final normalized = _normalizeSkillId(skillId);
  const titles = {
    '1password': '1Password',
    'discord': 'Discord',
    'eightctl': 'Eight Sleep',
    'gemini': 'Gemini',
    'github': 'GitHub',
    'gh-issues': 'GitHub Issues',
    'gog': 'GOG',
    'goplaces': 'Google Places',
    'mcporter': 'MCPorter',
    'notion': 'Notion',
    'openai-whisper-api': 'OpenAI Whisper API',
    'ordercli': 'Order CLI',
    'sag': 'SAG',
    'slack': 'Slack',
    'spotify-player': 'Spotify',
    'trello': 'Trello',
    'voice-call': 'Voice Call',
  };
  return titles[normalized] ?? _labelFromKey(normalized.replaceAll('-', ' '));
}

bool _looksSecretLike(String key) {
  final normalized = key.toUpperCase();
  return normalized.contains('KEY') ||
      normalized.contains('TOKEN') ||
      normalized.contains('SECRET') ||
      normalized.contains('PASSWORD');
}

String _labelFromKey(String key) {
  final words = key
      .replaceAll('.', ' ')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .toList(growable: false);
  return words.map(_titleCaseWord).join(' ');
}

String _titleCaseWord(String word) {
  final lower = word.toLowerCase();
  if (lower.isEmpty) return lower;
  const acronyms = {
    'api': 'API',
    'id': 'ID',
    'url': 'URL',
    'gog': 'GOG',
    'sag': 'SAG',
  };
  final acronym = acronyms[lower];
  if (acronym != null) return acronym;
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

bool _looksLikeEnvKey(String key) {
  final trimmed = key.trim();
  if (trimmed.contains('.')) return false;
  return RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(trimmed);
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
