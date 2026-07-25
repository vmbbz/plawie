enum SetupStep {
  checkingStatus,
  provisioningGateway,
  configuringGateway,
  downloadingRootfs,
  extractingRootfs,
  installingNode,
  installingOpenClaw,
  configuringBypass,
  downloadingPacks,
  cleanup,
  complete,
  error,
}

class SetupState {
  final SetupStep step;
  final double progress;
  final String message;
  final String? subMessage;
  final String? error;

  const SetupState({
    this.step = SetupStep.checkingStatus,
    this.progress = 0.0,
    this.message = '',
    this.subMessage,
    this.error,
  });

  SetupState copyWith({
    SetupStep? step,
    double? progress,
    String? message,
    String? subMessage,
    String? error,
  }) {
    return SetupState(
      step: step ?? this.step,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      subMessage: subMessage ?? this.subMessage,
      error: error,
    );
  }

  bool get isComplete => step == SetupStep.complete;
  bool get hasError => step == SetupStep.error;

  String get stepLabel {
    switch (step) {
      case SetupStep.checkingStatus:
        return 'Checking status...';
      case SetupStep.provisioningGateway:
        return 'Downloading official OpenClaw gateway';
      case SetupStep.configuringGateway:
        return 'Configuring native gateway';
      case SetupStep.downloadingRootfs:
        return 'Downloading Ubuntu rootfs';
      case SetupStep.extractingRootfs:
        return 'Extracting rootfs';
      case SetupStep.installingNode:
        return 'Installing Node.js';
      case SetupStep.installingOpenClaw:
        return 'Installing OpenClaw';
      case SetupStep.configuringBypass:
        return 'Configuring Bionic Bypass';
      case SetupStep.downloadingPacks:
        return 'Downloading dependency packs';
      case SetupStep.cleanup:
        return 'Cleaning up system...';
      case SetupStep.complete:
        return 'Setup complete';
      case SetupStep.error:
        return 'Error';
    }
  }

  int get stepNumber {
    switch (step) {
      case SetupStep.checkingStatus:
        return 0;
      case SetupStep.provisioningGateway:
        return 1;
      case SetupStep.configuringGateway:
        return 2;
      case SetupStep.downloadingRootfs:
        return 3;
      case SetupStep.extractingRootfs:
        return 4;
      case SetupStep.installingNode:
        return 5;
      case SetupStep.installingOpenClaw:
        return 6;
      case SetupStep.configuringBypass:
        return 7;
      case SetupStep.downloadingPacks:
        return 8;
      case SetupStep.cleanup:
        return 9;
      case SetupStep.complete:
        return 10;
      case SetupStep.error:
        return -1;
    }
  }

  static const int totalSteps = 10;
}
