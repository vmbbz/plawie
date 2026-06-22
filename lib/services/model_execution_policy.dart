enum ModelExecutionLane {
  cloudFullGateway,
  ndkGatewayBridge,
  directLocal,
}

enum ModelToolPolicy {
  reliable,
  variable,
  disabled,
}

class ModelExecutionPolicy {
  const ModelExecutionPolicy._();

  /// Conservative per-request output caps. These are not the advertised maximum
  /// output lengths; they are safe interactive defaults that leave room for the
  /// gateway prompt, tool schemas, tool results, and reasoning tokens.
  static const int compactOutputTokens = 8192;
  static const int standardOutputTokens = 16384;
  static const int extendedOutputTokens = 32768;

  static const int googleGemini31ProContextWindow = 1048576;
  static const int openAiGpt54ContextWindow = 1050000;
  static const int openAiGpt4oContextWindow = 128000;
  static const int anthropicClaude46ContextWindow = 1000000;
  static const int xaiGrok4ContextWindow = 1000000;
  static const int xaiGrok41FastContextWindow = 2000000;
  static const int xaiGrokCodeFastContextWindow = 256000;
  static const int openRouterGptOss20bContextWindow = 131072;
  static const int openRouterAutoContextWindow = 2000000;
  static const int openRouterFreeContextWindow = 200000;
  static const int openRouterKimiK26ContextWindow = 262144;
  static const int groqLlamaContextWindow = 131072;
  static const int zenmuxGlm52ContextWindow = 131072;

  static const int ndkBridgeContextWindow = 4096;
  static const int ndkBridgeMaxTokens = 768;
  static const int ndkBridgeMaxHistoryTurns = 3;
  static const int ndkBridgeMaxToolResultChars = 1400;

  static const String ndkBridgeCompactPromptNoTools =
      'You are Plawie, a helpful AI assistant running locally on this device. '
      'Be concise and helpful. No native tools are attached for this turn.';

  static const String ndkBridgeCompactPromptWithTools =
      'You are Plawie, a helpful AI assistant running locally on this device. '
      'Be concise and helpful. Native tools may be attached for this turn. '
      'Use a tool call for explicit device, avatar, TTS, shell, sensor, screen, '
      'or automation requests, then answer from the real tool result.';

  static String ndkBridgeCompactPrompt({required bool toolsAvailable}) =>
      toolsAvailable
          ? ndkBridgeCompactPromptWithTools
          : ndkBridgeCompactPromptNoTools;

  static bool isKnownOutputBudgetOverflow(String message) {
    final lower = message.toLowerCase();
    return lower.contains('maximum context length') &&
        lower.contains('in the output');
  }
}
