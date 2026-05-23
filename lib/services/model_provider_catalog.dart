enum ModelRouteKind {
  onDevice,
  ollamaLocal,
  ollamaCloud,
  cloud,
}

class ModelOption {
  final String id;
  final String label;
  final String providerId;
  final ModelRouteKind route;
  final String description;
  final String category;
  final bool recommended;
  final bool supportsToolCalls;
  final bool supportsVision;

  const ModelOption({
    required this.id,
    required this.label,
    required this.providerId,
    required this.route,
    required this.description,
    required this.category,
    this.recommended = false,
    this.supportsToolCalls = true,
    this.supportsVision = false,
  });

  String get shortId => id.contains('/') ? id.split('/').last : id;
  String get ollamaTag =>
      id.startsWith('ollama/') ? id.substring('ollama/'.length) : id;
}

class ProviderOption {
  final String id;
  final String label;
  final String subtitle;
  final String envKey;
  final String keyHint;
  final String keyPrefix;
  final String defaultModel;
  final String description;
  final bool requiresApiKey;

  const ProviderOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.envKey,
    required this.keyHint,
    required this.keyPrefix,
    required this.defaultModel,
    required this.description,
    this.requiresApiKey = true,
  });
}

class ModelProviderCatalog {
  static const String defaultCloudFallbackModel =
      'google/gemini-3.1-pro-preview';
  static const String setupSafeGatewayModel = defaultCloudFallbackModel;

  /// Legacy identifiers retained so old preferences/config can be migrated
  /// without breaking returning users. Normal UI should not expose ollama/*.
  static const String ollamaProviderId = 'ollama';
  static const String localOllamaDefaultModel = defaultCloudFallbackModel;
  static const String plawieNdkProviderId = 'plawie_ndk';
  static const String plawieNdkBaseUrl = 'http://127.0.0.1:11435/v1';

  /// Legacy size label used only by old/deprecated code paths.
  static const int ollamaRuntimeDownloadBytes = 1303711365;
  static const String ollamaRuntimeDownloadLabel = '1.30 GB';

  static const List<ProviderOption> providers = [
    ProviderOption(
      id: 'google',
      label: 'Gemini',
      subtitle: 'by Google',
      envKey: 'GOOGLE_API_KEY',
      keyHint: 'AIzaSy...',
      keyPrefix: 'AIza',
      defaultModel: 'google/gemini-3.1-pro-preview',
      description: 'Strong multimodal model for general chat, vision, video.',
    ),
    ProviderOption(
      id: 'anthropic',
      label: 'Claude',
      subtitle: 'by Anthropic',
      envKey: 'ANTHROPIC_API_KEY',
      keyHint: 'sk-ant-api03-...',
      keyPrefix: 'sk-ant-',
      defaultModel: 'anthropic/claude-opus-4-6',
      description: 'Premium reasoning and long-form tool planning.',
    ),
    ProviderOption(
      id: 'openai',
      label: 'OpenAI',
      subtitle: 'GPT models',
      envKey: 'OPENAI_API_KEY',
      keyHint: 'sk-proj-...',
      keyPrefix: 'sk-',
      defaultModel: 'openai/gpt-5.4',
      description: 'Balanced reasoning, multimodal chat, and tool use.',
    ),
    ProviderOption(
      id: 'xai',
      label: 'Grok',
      subtitle: 'by xAI',
      envKey: 'XAI_API_KEY',
      keyHint: 'xai-...',
      keyPrefix: 'xai-',
      defaultModel: 'xai/grok-4',
      description: 'Grok reasoning, fast variants, and coding models.',
    ),
    ProviderOption(
      id: 'groq',
      label: 'Groq',
      subtitle: 'low-latency cloud',
      envKey: 'GROQ_API_KEY',
      keyHint: 'gsk_...',
      keyPrefix: 'gsk_',
      defaultModel: 'groq/llama-3.3-70b-versatile',
      description: 'Very fast hosted inference for responsive chat.',
    ),
  ];

  static const List<ModelOption> cloudModels = [
    ModelOption(
      id: 'google/gemini-3.1-pro-preview',
      label: 'Gemini 3.1 Pro Preview',
      providerId: 'google',
      route: ModelRouteKind.cloud,
      description: 'Recommended multimodal default.',
      category: 'Multimodal',
      recommended: true,
      supportsVision: true,
    ),
    ModelOption(
      id: 'anthropic/claude-opus-4-6',
      label: 'Claude Opus 4.6',
      providerId: 'anthropic',
      route: ModelRouteKind.cloud,
      description: 'Premium reasoning and agent planning.',
      category: 'Reasoning',
      recommended: true,
    ),
    ModelOption(
      id: 'anthropic/claude-sonnet-4-6',
      label: 'Claude Sonnet 4.6',
      providerId: 'anthropic',
      route: ModelRouteKind.cloud,
      description: 'Balanced Anthropic model.',
      category: 'Reasoning',
    ),
    ModelOption(
      id: 'openai/gpt-5.4',
      label: 'GPT-5.4',
      providerId: 'openai',
      route: ModelRouteKind.cloud,
      description: 'OpenAI API-key route for current OpenClaw docs.',
      category: 'General',
      recommended: true,
      supportsVision: true,
    ),
    ModelOption(
      id: 'openai/gpt-4o',
      label: 'GPT-4o',
      providerId: 'openai',
      route: ModelRouteKind.cloud,
      description: 'Legacy-compatible multimodal fallback.',
      category: 'Multimodal',
      supportsVision: true,
    ),
    ModelOption(
      id: 'xai/grok-4',
      label: 'Grok 4',
      providerId: 'xai',
      route: ModelRouteKind.cloud,
      description: 'xAI default reasoning model.',
      category: 'Reasoning',
      recommended: true,
      supportsVision: true,
    ),
    ModelOption(
      id: 'xai/grok-4-1-fast',
      label: 'Grok 4.1 Fast',
      providerId: 'xai',
      route: ModelRouteKind.cloud,
      description: 'Fast xAI model for responsive chat.',
      category: 'Fast',
      supportsVision: true,
    ),
    ModelOption(
      id: 'xai/grok-code-fast-1',
      label: 'Grok Code Fast 1',
      providerId: 'xai',
      route: ModelRouteKind.cloud,
      description: 'xAI coding model.',
      category: 'Code',
    ),
    ModelOption(
      id: 'groq/llama-3.3-70b-versatile',
      label: 'Llama 3.3 70B Versatile',
      providerId: 'groq',
      route: ModelRouteKind.cloud,
      description: 'Low-latency hosted model.',
      category: 'Fast',
      recommended: true,
    ),
    ModelOption(
      id: 'groq/llama-3.1-8b-instant',
      label: 'Llama 3.1 8B Instant',
      providerId: 'groq',
      route: ModelRouteKind.cloud,
      description: 'Very fast lightweight Groq route.',
      category: 'Fast',
    ),
  ];

  /// Deprecated: embedded Ollama routes are hidden from normal model pickers.
  static const List<ModelOption> ollamaCloudModels = [];

  static List<String> get cloudModelIds =>
      cloudModels.map((m) => m.id).toList(growable: false);

  static List<String> get ollamaCloudModelIds =>
      ollamaCloudModels.map((m) => m.id).toList(growable: false);

  static List<String> get chatDefaultModelIds => cloudModelIds;

  static ProviderOption? providerById(String provider) {
    final normalized = normalizeProvider(provider);
    for (final option in providers) {
      if (option.id == normalized) return option;
    }
    return null;
  }

  static ModelOption? modelById(String modelId) {
    final canonical = canonicalizeModelId(modelId);
    for (final model in cloudModels) {
      if (model.id == canonical) return model;
    }
    return null;
  }

  static String defaultModelForProvider(String provider) {
    final normalized = normalizeProvider(provider);
    final option = providerById(normalized);
    return option?.defaultModel ?? provider;
  }

  /// Model to persist during fresh setup before optional local runtimes exist.
  ///
  /// Legacy Ollama choices boot with a safe gateway model. Current setup no
  /// longer exposes Ollama as a first-run provider.
  static String setupSafeModelForProvider(String provider) {
    final normalized = normalizeProvider(provider);
    return defaultModelForProvider(normalized);
  }

  static String normalizeProvider(String provider) {
    final p = provider.trim().toLowerCase();
    if (p.contains('ollama')) return 'google';
    if (p.contains('claude') || p.contains('anthropic')) return 'anthropic';
    if (p.contains('openai')) return 'openai';
    if (p.contains('xai') || p.contains('grok')) return 'xai';
    if (p.contains('gemini') || p.contains('google')) return 'google';
    if (p.contains('groq')) return 'groq';
    if (p.endsWith('_api_key')) return normalizeProvider(p.split('_').first);
    return p;
  }

  static String apiProviderForSetupId(String setupId) {
    final normalized = normalizeProvider(setupId);
    return normalized;
  }

  static String envKeyForProvider(String provider) =>
      providerById(provider)?.envKey ?? '';

  static List<Map<String, dynamic>> defaultModelsForProvider(String provider) {
    final normalized = normalizeProvider(provider);
    final models = cloudModels
        .where((model) => model.providerId == normalized)
        .map((model) => {'id': model.shortId, 'name': model.label})
        .toList(growable: false);
    if (models.isNotEmpty) return models;
    return const [
      {'id': 'default', 'name': 'Default Model'}
    ];
  }

  static String canonicalizeModelId(String modelId) {
    final trimmed = modelId.trim();
    if (trimmed.startsWith('ollama/')) return defaultCloudFallbackModel;
    switch (trimmed) {
      case 'anthropic/claude-opus-4.6':
        return 'anthropic/claude-opus-4-6';
      case 'anthropic/claude-sonnet-4.6':
        return 'anthropic/claude-sonnet-4-6';
      case 'xai/grok-4.3':
        return 'xai/grok-4';
      case 'groq/llama-3.1-405b':
        return 'groq/llama-3.3-70b-versatile';
      default:
        return trimmed;
    }
  }

  static String labelForModel(String modelId) {
    final model = modelById(modelId);
    if (model != null) return model.label;
    if (modelId.startsWith('ollama/')) return 'Legacy Ollama route';
    if (modelId.startsWith('local-llm/')) {
      return 'Local - ${modelId.substring('local-llm/'.length)}';
    }
    return modelId.contains('/') ? modelId.split('/').last : modelId;
  }

  static String routeLabelForModel(String modelId) {
    if (modelId.startsWith('local-llm/')) return 'ON DEVICE';
    if (modelId.startsWith('ollama/')) return 'LEGACY';
    final model = modelById(modelId);
    return model?.category.toUpperCase() ?? 'CLOUD';
  }

  static bool needsOllamaHub(String modelId) => false;

  static bool needsOllamaSignIn(String modelId) => false;

  static Map<String, dynamic> providerConfigDefaults(String provider) {
    final normalized = normalizeProvider(provider);
    final models = defaultModelsForProvider(normalized);
    switch (normalized) {
      case 'ollama':
      case 'ollama_cloud':
        return {
          'api': 'ollama',
          'apiKey': 'ollama-local',
          'baseUrl': 'http://127.0.0.1:11434',
          'models': models,
        };
      case 'google':
        return {
          'api': 'google-generative-ai',
          'baseUrl': 'https://generativelanguage.googleapis.com/v1beta',
          'models': models,
        };
      case 'xai':
        return {
          'baseUrl': 'https://api.x.ai/v1',
          'models': models,
        };
      case 'groq':
        return {
          'baseUrl': 'https://api.groq.com/openai/v1',
          'models': models,
        };
      default:
        return {'models': models};
    }
  }

  static Map<String, dynamic> mergeProviderConfig(
    String provider,
    Map<dynamic, dynamic>? existing, {
    String? apiKey,
  }) {
    final merged = <String, dynamic>{
      ...providerConfigDefaults(provider),
      if (existing != null)
        ...existing.map((key, value) => MapEntry(key.toString(), value)),
      if (apiKey != null && apiKey.trim().isNotEmpty) 'apiKey': apiKey.trim(),
    };
    merged.removeWhere((_, value) => value == null);
    return merged;
  }
}
