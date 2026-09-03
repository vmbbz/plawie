import 'model_execution_policy.dart';

enum ModelRouteKind {
  onDevice,
  cloud,
}

/// How a provider authenticates requests. This is intentionally independent
/// from model discovery and billing readiness: a wallet identity can exist
/// while its proxy, balance, or per-request payment path is still unavailable.
enum ProviderAuthenticationMode {
  apiKey,
  walletIdentity,
  none,
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
  final ModelToolPolicy toolPolicy;
  final int? contextWindow;

  /// Safe per-request output cap written to the gateway config.
  final int? maxTokens;
  final DateTime? deprecationDate;
  final String? replacementModelId;

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
    this.toolPolicy = ModelToolPolicy.reliable,
    this.contextWindow,
    this.maxTokens,
    this.deprecationDate,
    this.replacementModelId,
  });

  String get shortId => id.contains('/') ? id.split('/').last : id;

  /// Model id as it should appear inside `models.providers.<provider>.models`.
  /// Most providers use one segment after the provider prefix, but OpenRouter
  /// preserves nested upstream ids such as `openrouter/free`.
  String get providerModelId {
    if (providerId == 'openrouter' && id == 'openrouter/auto') {
      return 'openrouter/auto';
    }
    final prefix = '$providerId/';
    return id.startsWith(prefix) ? id.substring(prefix.length) : shortId;
  }

  Map<String, dynamic> get providerConfig {
    final config = <String, dynamic>{
      'id': providerModelId,
      'name': label,
    };
    if (contextWindow != null) config['contextWindow'] = contextWindow;
    if (maxTokens != null) config['maxTokens'] = maxTokens;
    return config;
  }

  String get gatewayCapabilityLabel {
    if (!supportsToolCalls || toolPolicy == ModelToolPolicy.disabled) {
      return 'CHAT ONLY';
    }
    if (toolPolicy == ModelToolPolicy.variable) return 'VARIABLE TOOLS';
    return 'FULL TOOLS';
  }

  bool isDeprecatedAt(DateTime now) =>
      deprecationDate != null && !deprecationDate!.isAfter(now.toUtc());
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
  final ProviderAuthenticationMode authenticationMode;

  const ProviderOption({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.envKey,
    required this.keyHint,
    required this.keyPrefix,
    required this.defaultModel,
    required this.description,
    this.authenticationMode = ProviderAuthenticationMode.apiKey,
  });

  bool get requiresApiKey =>
      authenticationMode == ProviderAuthenticationMode.apiKey;
}

class ModelProviderCatalog {
  static const String defaultCloudFallbackModel =
      'openrouter/meta-llama/llama-3.3-70b-instruct:free';
  static const String setupSafeGatewayModel = defaultCloudFallbackModel;

  static const String plawieNdkProviderId = 'plawie_ndk';
  static const String plawieNdkBaseUrl = 'http://127.0.0.1:11435/v1';

  static const List<ProviderOption> providers = [
    ProviderOption(
      id: 'google',
      label: 'Gemini',
      subtitle: 'by Google',
      envKey: 'GOOGLE_API_KEY',
      keyHint: 'AIzaSy...',
      keyPrefix: 'AIza',
      defaultModel: 'google/gemini-3.8-flash',
      description: 'Latest 2026 Gemini Flash & Pro models for software agents, vision, and full tool calls.',
    ),
    ProviderOption(
      id: 'anthropic',
      label: 'Claude',
      subtitle: 'by Anthropic',
      envKey: 'ANTHROPIC_API_KEY',
      keyHint: 'sk-ant-api03-...',
      keyPrefix: 'sk-ant-',
      defaultModel: 'anthropic/claude-fable-5-1',
      description: 'Frontier Generation 5 Claude models for reasoning, long-horizon planning, and agentic coding.',
    ),
    ProviderOption(
      id: 'openai',
      label: 'OpenAI',
      subtitle: 'GPT models',
      envKey: 'OPENAI_API_KEY',
      keyHint: 'sk-proj-...',
      keyPrefix: 'sk-',
      defaultModel: 'openai/gpt-5.6',
      description: 'Current 2026 GPT-5 series for unified chat, multimodal vision, and tool capabilities.',
    ),
    ProviderOption(
      id: 'xai',
      label: 'Grok',
      subtitle: 'by SpaceXAI',
      envKey: 'XAI_API_KEY',
      keyHint: 'xai-...',
      keyPrefix: 'xai-',
      defaultModel: 'xai/grok-4-6',
      description: 'Grok 4.6 flagship models with 500K-2M context, vision, and high-performance agentic coding.',
    ),
    ProviderOption(
      id: 'openrouter',
      label: 'OpenRouter',
      subtitle: 'free + many providers',
      envKey: 'OPENROUTER_API_KEY',
      keyHint: 'sk-or-...',
      keyPrefix: 'sk-or-',
      defaultModel: defaultCloudFallbackModel,
      description: 'One account for free community models and paid fallbacks.',
    ),
    ProviderOption(
      id: 'groq',
      label: 'Groq',
      subtitle: 'low-latency cloud',
      envKey: 'GROQ_API_KEY',
      keyHint: 'gsk_...',
      keyPrefix: 'gsk_',
      defaultModel: 'groq/openai/gpt-oss-120b',
      description: 'Ultra-low-latency LPU inference hosting GPT-OSS 120B and Llama 3.3 70B.',
    ),
    ProviderOption(
      id: 'zenmux',
      label: 'Zenmux',
      subtitle: 'OpenAI-compatible gateway',
      envKey: 'ZENMUX_API_KEY',
      keyHint: 'zm-...',
      keyPrefix: 'zm-',
      defaultModel: 'zenmux/z-ai/glm-5.2-free',
      description: 'OpenAI-compatible API gateway with free community models.',
    ),
    ProviderOption(
      id: 'venice',
      label: 'Venice',
      subtitle: 'Base wallet · prepaid balance',
      envKey: '',
      keyHint: '',
      keyPrefix: '',
      defaultModel: '',
      description:
          'Wallet-funded inference using a Venice balance linked to your Base wallet.',
      authenticationMode: ProviderAuthenticationMode.walletIdentity,
    ),
    ProviderOption(
      id: 'blockrun',
      label: 'BlockRun',
      subtitle: 'Base wallet · pay per request',
      envKey: '',
      keyHint: '',
      keyPrefix: '',
      defaultModel: '',
      description:
          'Wallet-funded inference with explicit Base USDC approval per request.',
      authenticationMode: ProviderAuthenticationMode.walletIdentity,
    ),
  ];

  static const Set<String> nativeGatewaySupportedProviderIds = <String>{
    'google',
    'anthropic',
    'openai',
    'xai',
    'openrouter',
    'zenmux',
    'venice',
    'blockrun',
  };

  static const Set<String> nativeGatewayBundledPluginIds = <String>{
    'anthropic',
    'browser',
    'canvas',
    'device-pair',
    'file-transfer',
    'google',
    'image-generation-core',
    'llm-task',
    'media-understanding-core',
    'memory-core',
    'microsoft',
    'openai',
    'openrouter',
    'phone-control',
    'talk-voice',
    'video-generation-core',
    'xai',
  };

  static const Set<String> nativeGatewayVerifiedPluginIds = <String>{
    'plawie-tool-probe-guard',
    'plawie-venice-compat',
  };

  static const Set<String> nativeGatewayCoreVerifiedPluginIds = <String>{
    'plawie-tool-probe-guard',
  };

  static const Map<String, String> nativeGatewayVerifiedPluginByProvider =
      <String, String>{
    'venice': 'plawie-venice-compat',
  };

  static const Map<String, String> nativeGatewayExternalProviderPackages =
      <String, String>{
    'groq': '@openclaw/groq-provider',
  };

  static bool isProviderSupportedByNativeGateway(String provider) {
    final normalized = normalizeProvider(provider);
    return normalized == plawieNdkProviderId ||
        nativeGatewaySupportedProviderIds.contains(normalized);
  }

  static String? nativeGatewayExternalPackageForProvider(String provider) {
    return nativeGatewayExternalProviderPackages[normalizeProvider(provider)];
  }

  static const List<ModelOption> cloudModels = [
    // --- Google Gemini (2026 Ground Truth) ---
    ModelOption(
      id: 'google/gemini-3.8-flash',
      label: 'Gemini 3.8 Flash',
      providerId: 'google',
      route: ModelRouteKind.cloud,
      description: 'Latest 2026 Flash model for software engineering, autonomous agents & full tools.',
      category: 'Agent',
      recommended: true,
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.googleGemini38FlashContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'google/gemini-3.7-flash',
      label: 'Gemini 3.7 Flash',
      providerId: 'google',
      route: ModelRouteKind.cloud,
      description: 'High-speed agentic & coding model.',
      category: 'Code',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.googleGemini37FlashContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'google/gemini-3.1-pro',
      label: 'Gemini 3.1 Pro',
      providerId: 'google',
      route: ModelRouteKind.cloud,
      description: 'Flagship 1M context Pro reasoning model with full tool capabilities.',
      category: 'Multimodal',
      recommended: true,
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.googleGemini31ProContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'google/gemini-2.5-pro',
      label: 'Gemini 2.5 Pro',
      providerId: 'google',
      route: ModelRouteKind.cloud,
      description: 'Production-stable 2M context Pro reasoning model.',
      category: 'Reasoning',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.googleGemini25ProContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'google/gemini-2.5-flash',
      label: 'Gemini 2.5 Flash',
      providerId: 'google',
      route: ModelRouteKind.cloud,
      description: 'Production-stable ultra fast Flash model.',
      category: 'Fast',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.googleGemini25FlashContextWindow,
      maxTokens: ModelExecutionPolicy.standardOutputTokens,
    ),

    // --- Anthropic Claude (2026 Ground Truth) ---
    ModelOption(
      id: 'anthropic/claude-fable-5-1',
      label: 'Claude Fable 5.1',
      providerId: 'anthropic',
      route: ModelRouteKind.cloud,
      description: 'Frontier 2026 model for demanding reasoning and long-horizon agents.',
      category: 'Reasoning',
      recommended: true,
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.anthropicClaudeFable51ContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'anthropic/claude-opus-5',
      label: 'Claude Opus 5',
      providerId: 'anthropic',
      route: ModelRouteKind.cloud,
      description: 'Flagship agentic coding and enterprise long-form planning.',
      category: 'Reasoning',
      recommended: true,
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.anthropicClaudeOpus5ContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'anthropic/claude-sonnet-5',
      label: 'Claude Sonnet 5',
      providerId: 'anthropic',
      route: ModelRouteKind.cloud,
      description: 'Balanced Generation 5 production tier model (1M context).',
      category: 'Reasoning',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.anthropicClaudeSonnet5ContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'anthropic/claude-haiku-4-5',
      label: 'Claude Haiku 4.5',
      providerId: 'anthropic',
      route: ModelRouteKind.cloud,
      description: 'Fast, lowest-cost Claude model for lightweight turns.',
      category: 'Fast',
      contextWindow: ModelExecutionPolicy.anthropicClaudeHaiku45ContextWindow,
      maxTokens: ModelExecutionPolicy.standardOutputTokens,
    ),
    ModelOption(
      id: 'anthropic/claude-3-7-sonnet-20250219',
      label: 'Claude 3.7 Sonnet',
      providerId: 'anthropic',
      route: ModelRouteKind.cloud,
      description: 'Extended thinking & hybrid reasoning model.',
      category: 'Reasoning',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.anthropicClaude37SonnetContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),

    // --- OpenAI (2026 Ground Truth) ---
    ModelOption(
      id: 'openai/gpt-5.6',
      label: 'GPT-5.6',
      providerId: 'openai',
      route: ModelRouteKind.cloud,
      description: 'Current 2026 flagship unified reasoning and agent model.',
      category: 'Reasoning',
      recommended: true,
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.openAiGpt56ContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'openai/gpt-5.5',
      label: 'GPT-5.5',
      providerId: 'openai',
      route: ModelRouteKind.cloud,
      description: 'Mainstream high-capacity GPT-5 series model.',
      category: 'Multimodal',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.openAiGpt55ContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'openai/gpt-5.4',
      label: 'GPT-5.4',
      providerId: 'openai',
      route: ModelRouteKind.cloud,
      description: 'Workhorse general reasoning & tool execution model.',
      category: 'General',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.openAiGpt54ContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'openai/gpt-4o',
      label: 'GPT-4o',
      providerId: 'openai',
      route: ModelRouteKind.cloud,
      description: 'Multimodal fallback model with full tool support.',
      category: 'Multimodal',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.openAiGpt4oContextWindow,
      maxTokens: ModelExecutionPolicy.standardOutputTokens,
    ),

    // --- xAI Grok (2026 Ground Truth) ---
    ModelOption(
      id: 'xai/grok-4-6',
      label: 'Grok 4.6',
      providerId: 'xai',
      route: ModelRouteKind.cloud,
      description: 'Current 2026 xAI flagship model (500K context, vision & agentic coding).',
      category: 'Reasoning',
      recommended: true,
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.xaiGrok46ContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'xai/grok-4-5',
      label: 'Grok 4.5',
      providerId: 'xai',
      route: ModelRouteKind.cloud,
      description: 'High-performance model for research and agentic coding.',
      category: 'Code',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.xaiGrok45ContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),
    ModelOption(
      id: 'xai/grok-4-1-fast',
      label: 'Grok 4.1 Fast',
      providerId: 'xai',
      route: ModelRouteKind.cloud,
      description: 'Budget fast xAI model with 2M context window.',
      category: 'Fast',
      supportsVision: true,
      contextWindow: ModelExecutionPolicy.xaiGrok41FastContextWindow,
      maxTokens: ModelExecutionPolicy.extendedOutputTokens,
    ),

    // --- Groq (2026 Ground Truth) ---
    ModelOption(
      id: 'groq/openai/gpt-oss-120b',
      label: 'GPT-OSS 120B via Groq',
      providerId: 'groq',
      route: ModelRouteKind.cloud,
      description: 'Flagship 120B model with web search, code execution & reasoning.',
      category: 'Fast',
      recommended: true,
      contextWindow: ModelExecutionPolicy.groqGptOss120bContextWindow,
      maxTokens: ModelExecutionPolicy.compactOutputTokens,
    ),
    ModelOption(
      id: 'groq/openai/gpt-oss-20b',
      label: 'GPT-OSS 20B via Groq',
      providerId: 'groq',
      route: ModelRouteKind.cloud,
      description: 'Fast MoE model optimized for low-latency agentic turns.',
      category: 'Fast',
      contextWindow: ModelExecutionPolicy.groqGptOss20bContextWindow,
      maxTokens: ModelExecutionPolicy.compactOutputTokens,
    ),
    ModelOption(
      id: 'groq/llama-3.3-70b-versatile',
      label: 'Llama 3.3 70B via Groq',
      providerId: 'groq',
      route: ModelRouteKind.cloud,
      description: 'Meta Llama 3.3 70B hosted on Groq LPU.',
      category: 'Fast',
      contextWindow: ModelExecutionPolicy.groqLlama33ContextWindow,
      maxTokens: ModelExecutionPolicy.compactOutputTokens,
    ),

    // --- OpenRouter (2026 Ground Truth) ---
    ModelOption(
      id: 'openrouter/meta-llama/llama-3.3-70b-instruct:free',
      label: 'Llama 3.3 70B Free via OpenRouter',
      providerId: 'openrouter',
      route: ModelRouteKind.cloud,
      description: 'Free high-capacity model with tool-call support.',
      category: 'Free',
      recommended: true,
      contextWindow: ModelExecutionPolicy.openRouterLlama33ContextWindow,
      maxTokens: ModelExecutionPolicy.compactOutputTokens,
    ),
    ModelOption(
      id: 'openrouter/deepseek/deepseek-r1:free',
      label: 'DeepSeek R1 Free via OpenRouter',
      providerId: 'openrouter',
      route: ModelRouteKind.cloud,
      description: 'Free DeepSeek R1 reasoning model.',
      category: 'Free',
      contextWindow: ModelExecutionPolicy.openRouterFreeContextWindow,
      maxTokens: ModelExecutionPolicy.compactOutputTokens,
    ),
    ModelOption(
      id: 'openrouter/auto',
      label: 'OpenRouter Auto',
      providerId: 'openrouter',
      route: ModelRouteKind.cloud,
      description: 'OpenRouter automatic routing across supported models.',
      category: 'Router',
      toolPolicy: ModelToolPolicy.variable,
      contextWindow: ModelExecutionPolicy.openRouterAutoContextWindow,
      maxTokens: ModelExecutionPolicy.standardOutputTokens,
    ),

    // --- Zenmux & Plawie Bridge ---
    ModelOption(
      id: 'zenmux/z-ai/glm-5.2-free',
      label: 'GLM-5.2 Free via Zenmux',
      providerId: 'zenmux',
      route: ModelRouteKind.cloud,
      description: 'Free community model via the Zenmux OpenAI-compatible gateway.',
      category: 'Free',
      recommended: true,
      contextWindow: ModelExecutionPolicy.zenmuxGlm52ContextWindow,
      maxTokens: ModelExecutionPolicy.standardOutputTokens,
    ),
    ModelOption(
      id: 'plawie_ndk/local-llm',
      label: 'Plawie NDK Bridge (Local Gateway)',
      providerId: 'plawie_ndk',
      route: ModelRouteKind.cloud,
      description: 'Routes gateway prompts to the on-device NDK model.',
      category: 'Bridge',
      toolPolicy: ModelToolPolicy.variable,
      contextWindow: ModelExecutionPolicy.ndkBridgeContextWindow,
      maxTokens: ModelExecutionPolicy.ndkBridgeMaxTokens,
    ),
  ];

  static List<String> get cloudModelIds =>
      cloudModels.map((m) => m.id).toList(growable: false);

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

  static String setupSafeModelForProvider(String provider) {
    final normalized = normalizeProvider(provider);
    return defaultModelForProvider(normalized);
  }

  static String normalizeProvider(String provider) {
    final p = provider.trim().toLowerCase();
    if (p.contains('ollama')) return 'google';
    if (p.contains('openrouter')) return 'openrouter';
    if (p.contains('claude') || p.contains('anthropic')) return 'anthropic';
    if (p.contains('openai')) return 'openai';
    if (p.contains('xai') || p.contains('grok')) return 'xai';
    if (p.contains('gemini') || p.contains('google')) return 'google';
    if (p.contains('groq')) return 'groq';
    if (p.contains('zenmux')) return 'zenmux';
    if (p.contains('venice')) return 'venice';
    if (p.contains('blockrun') || p.contains('block run')) return 'blockrun';
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
        .map((model) => model.providerConfig)
        .toList(growable: false);
    if (models.isNotEmpty) return models;
    if (providerById(normalized)?.authenticationMode ==
        ProviderAuthenticationMode.walletIdentity) {
      return const <Map<String, dynamic>>[];
    }
    return const [
      {'id': 'default', 'name': 'Default Model'}
    ];
  }

  static String canonicalizeModelId(String modelId) {
    final trimmed = modelId.trim();
    if (trimmed.startsWith('ollama/')) return defaultCloudFallbackModel;
    switch (trimmed) {
      // Legacy Google mappings
      case 'google/gemini-3.1-pro-preview':
      case 'google/gemini-1.5-pro':
        return 'google/gemini-3.1-pro';
      case 'google/gemini-1.5-flash':
        return 'google/gemini-3.7-flash';

      // Legacy Anthropic mappings
      case 'anthropic/claude-3-opus-20240229':
      case 'anthropic/claude-opus-4-6':
      case 'anthropic/claude-opus-4.6':
        return 'anthropic/claude-opus-5';
      case 'anthropic/claude-sonnet-4-6':
      case 'anthropic/claude-sonnet-4.6':
      case 'anthropic/claude-3-5-sonnet-20241022':
        return 'anthropic/claude-sonnet-5';

      // Legacy OpenAI mappings
      case 'openai/gpt-4':
      case 'openai/gpt-4.5':
      case 'openai/o3-mini':
      case 'openai/o4-mini':
      case 'openai/gpt-5.4':
        return 'openai/gpt-5.6';

      // Legacy xAI mappings
      case 'xai/grok-beta':
      case 'xai/grok-4':
      case 'xai/grok-4.3':
      case 'xai/grok-2-vision-1212':
      case 'xai/grok-2-1212':
        return 'xai/grok-4-6';

      // Legacy Groq mappings
      case 'groq/llama-3.1-8b-instant':
      case 'groq/openai/gpt-oss-20b':
        return 'groq/openai/gpt-oss-120b';

      // Legacy OpenRouter mappings
      case 'openrouter/openai/gpt-oss-20b:free':
      case 'openrouter/openrouter/free':
      case 'openrouter/free':
        return 'openrouter/meta-llama/llama-3.3-70b-instruct:free';

      default:
        return trimmed;
    }
  }

  static bool isLocalModelId(String modelId) {
    final trimmed = modelId.trim();
    if (trimmed == '$plawieNdkProviderId/local-llm') return false;
    if (trimmed.startsWith('$plawieNdkProviderId/local-llm/')) return false;
    if (trimmed.startsWith('local-llm')) return true;
    return false;
  }

  static bool isDirectLocalModelId(String modelId) {
    final trimmed = modelId.trim();
    if (trimmed == '$plawieNdkProviderId/local-llm') return false;
    if (trimmed.startsWith('$plawieNdkProviderId/local-llm/')) return false;
    return trimmed.startsWith('local-llm');
  }

  static String labelForModel(String modelId) {
    final model = modelById(modelId);
    if (model != null) return model.label;
    if (modelId == '$plawieNdkProviderId/local-llm') {
      return 'Plawie NDK Bridge';
    }
    if (modelId.startsWith('ollama/')) return 'Legacy Ollama route';
    if (modelId.startsWith('local-llm/')) {
      return 'Local - ${modelId.substring('local-llm/'.length)}';
    }
    return modelId.contains('/') ? modelId.split('/').last : modelId;
  }

  static String routeLabelForModel(String modelId) {
    if (modelId.startsWith('local-llm/')) return 'ON DEVICE';
    if (modelId == '$plawieNdkProviderId/local-llm') return 'COMPACT BRIDGE';
    if (modelId.startsWith('ollama/')) return 'LEGACY';
    final model = modelById(modelId);
    if (model != null) {
      return '${model.category.toUpperCase()} - ${model.gatewayCapabilityLabel}';
    }
    return model?.category.toUpperCase() ?? 'CLOUD';
  }

  static ModelExecutionLane executionLaneForModel(String modelId) {
    final canonical = canonicalizeModelId(modelId);
    if (isDirectLocalModelId(canonical)) return ModelExecutionLane.directLocal;
    if (canonical == '$plawieNdkProviderId/local-llm') {
      return ModelExecutionLane.ndkGatewayBridge;
    }
    return ModelExecutionLane.cloudFullGateway;
  }

  static bool canUseFullGatewayTools(String modelId) {
    final canonical = canonicalizeModelId(modelId);
    final model = modelById(canonical);
    return executionLaneForModel(canonical) ==
            ModelExecutionLane.cloudFullGateway &&
        (model?.supportsToolCalls ?? true) &&
        model?.toolPolicy != ModelToolPolicy.disabled;
  }

  static Map<String, dynamic> providerConfigDefaults(String provider) {
    final normalized = normalizeProvider(provider);
    final models = defaultModelsForProvider(normalized);
    switch (normalized) {
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
      case 'zenmux':
        return {
          'api': 'openai-completions',
          'baseUrl': 'https://zenmux.ai/api/v1',
          'models': models,
        };
      case 'openrouter':
        return {
          'baseUrl': 'https://openrouter.ai/api/v1',
          'models': models,
        };
      case 'venice':
        return {
          'api': 'openai-completions',
          'baseUrl': 'http://127.0.0.1:11436/venice/v1',
          'models': models,
        };
      case 'blockrun':
        return {
          'api': 'openai-completions',
          'baseUrl': 'http://127.0.0.1:11436/blockrun/v1',
          'models': models,
        };
      case 'plawie_ndk':
        return {
          'api': 'openai-completions',
          'baseUrl': plawieNdkBaseUrl,
          'contextWindow': ModelExecutionPolicy.ndkBridgeContextWindow,
          'maxTokens': ModelExecutionPolicy.ndkBridgeMaxTokens,
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
    final existingModels = existing?['models'];
    final merged = <String, dynamic>{
      ...providerConfigDefaults(provider),
      if (existing != null)
        ...existing.map((key, value) => MapEntry(key.toString(), value)),
      if (apiKey != null && apiKey.trim().isNotEmpty) 'apiKey': apiKey.trim(),
    };
    merged['models'] = _mergeModelDefaults(provider, existingModels);
    merged.removeWhere((_, value) => value == null);
    return merged;
  }

  static List<Map<String, dynamic>> _mergeModelDefaults(
    String provider,
    dynamic existingModels,
  ) {
    final defaults = defaultModelsForProvider(provider);
    if (existingModels is! List) return defaults;

    final defaultsById = <String, Map<String, dynamic>>{
      for (final model in defaults) model['id'].toString(): model,
    };
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    for (final entry in existingModels) {
      if (entry is! Map) continue;
      final normalized = entry.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final id = normalized['id']?.toString();
      if (id == null || id.trim().isEmpty) continue;
      final canonicalId = _canonicalProviderModelId(provider, id);
      if (canonicalId.isEmpty || seen.contains(canonicalId)) continue;
      if (canonicalId != id) normalized['id'] = canonicalId;

      final defaultsForModel = defaultsById[canonicalId];
      if (defaultsForModel == null) {
        merged.add(normalized);
        seen.add(canonicalId);
      } else {
        final healed = <String, dynamic>{...normalized};
        for (final field in const ['id', 'name']) {
          healed.putIfAbsent(field, () => defaultsForModel[field]);
        }
        for (final field in const ['contextWindow', 'maxTokens']) {
          if (defaultsForModel.containsKey(field)) {
            healed[field] = defaultsForModel[field];
          }
        }
        merged.add(healed);
        seen.add(canonicalId);
      }
    }

    for (final entry in defaults) {
      final id = entry['id']?.toString();
      if (id != null && !seen.contains(id)) merged.add(entry);
    }
    return merged;
  }

  static String _canonicalProviderModelId(String provider, String id) {
    final normalizedProvider = normalizeProvider(provider);
    final trimmed = id.trim();
    if (normalizedProvider == 'openrouter' && trimmed == 'auto') {
      return 'openrouter/auto';
    }
    if (normalizedProvider == 'openrouter' && trimmed == 'free') {
      return 'openrouter/free';
    }
    return trimmed;
  }
}
