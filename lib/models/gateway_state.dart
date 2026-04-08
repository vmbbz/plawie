enum GatewayStatus {
  stopped,
  starting,
  running,
  error,
}

class GatewayState {
  final GatewayStatus status;
  final List<String> logs;
  final String? errorMessage;
  final DateTime? startedAt;
  final String? dashboardUrl;
  final Map<String, dynamic>? detailedHealth;
  final List<Map<String, dynamic>>? activeSkills;
  final List<String>? capabilities;
  final bool isWebsocketConnected;
  /// Ollama Hub model names that were successfully synced in the last sync run.
  /// Each entry is the raw Ollama name (e.g. "qwen2-5-0-5b-instruct-q4-k-m:latest").
  /// The chat screen prefixes these with "ollama/" for the model dropdown.
  final List<String> ollamaHubModels;
  final bool isOllamaRunning;
  /// True when a background repair or "doctor --fix" is in progress.
  final bool isRepairing;
  /// Current progress (0.0 to 1.0) of the background repair.
  final double repairProgress;
  /// Current status message for the background repair.
  final String repairMessage;

  const GatewayState({
    this.status = GatewayStatus.stopped,
    this.logs = const [],
    this.errorMessage,
    this.startedAt,
    this.dashboardUrl,
    this.detailedHealth,
    this.activeSkills,
    this.capabilities,
    this.isWebsocketConnected = false,
    this.ollamaHubModels = const [],
    this.isOllamaRunning = false,
    this.isRepairing = false,
    this.repairProgress = 0.0,
    this.repairMessage = '',
  });

  GatewayState copyWith({
    GatewayStatus? status,
    List<String>? logs,
    String? errorMessage,
    bool clearError = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    String? dashboardUrl,
    bool clearDashboardUrl = false,
    Map<String, dynamic>? detailedHealth,
    bool clearDetailedHealth = false,
    List<Map<String, dynamic>>? activeSkills,
    bool clearActiveSkills = false,
    List<String>? capabilities,
    bool clearCapabilities = false,
    bool? isWebsocketConnected,
    List<String>? ollamaHubModels,
    bool? isOllamaRunning,
    bool? isRepairing,
    double? repairProgress,
    String? repairMessage,
  }) {
    return GatewayState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      dashboardUrl: clearDashboardUrl ? null : (dashboardUrl ?? this.dashboardUrl),
      detailedHealth: clearDetailedHealth ? null : (detailedHealth ?? this.detailedHealth),
      activeSkills: clearActiveSkills ? null : (activeSkills ?? this.activeSkills),
      capabilities: clearCapabilities ? null : (capabilities ?? this.capabilities),
      isWebsocketConnected: isWebsocketConnected ?? this.isWebsocketConnected,
      ollamaHubModels: ollamaHubModels ?? this.ollamaHubModels,
      isOllamaRunning: isOllamaRunning ?? this.isOllamaRunning,
      isRepairing: isRepairing ?? this.isRepairing,
      repairProgress: repairProgress ?? this.repairProgress,
      repairMessage: repairMessage ?? this.repairMessage,
    );
  }

  bool get isRunning => status == GatewayStatus.running;
  bool get isStopped => status == GatewayStatus.stopped;

  String get statusText {
    switch (status) {
      case GatewayStatus.stopped:
        return 'Stopped';
      case GatewayStatus.starting:
        return 'Starting...';
      case GatewayStatus.running:
        return 'Running';
      case GatewayStatus.error:
        return 'Error';
    }
  }
}
