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
  });

  GatewayState copyWith({
    GatewayStatus? status,
    List<String>? logs,
    String? errorMessage,
    bool clearError = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    String? dashboardUrl,
    Map<String, dynamic>? detailedHealth,
    bool clearDetailedHealth = false,
    List<Map<String, dynamic>>? activeSkills,
    bool clearActiveSkills = false,
    List<String>? capabilities,
    bool clearCapabilities = false,
    bool? isWebsocketConnected,
  }) {
    return GatewayState(
      status: status ?? this.status,
      logs: logs ?? this.logs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      dashboardUrl: dashboardUrl ?? this.dashboardUrl,
      detailedHealth: clearDetailedHealth ? null : (detailedHealth ?? this.detailedHealth),
      activeSkills: clearActiveSkills ? null : (activeSkills ?? this.activeSkills),
      capabilities: clearCapabilities ? null : (capabilities ?? this.capabilities),
      isWebsocketConnected: isWebsocketConnected ?? this.isWebsocketConnected,
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
