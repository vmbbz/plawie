enum SetupStep {
  checkingStatus,
  downloadingRootfs,
  extractingRootfs,
  installingNode,
  installingOpenClaw,
  configuringBypass,
  hardening,
  startingGateway,
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
      case SetupStep.hardening:
        return 'Applying industrial hardening';
      case SetupStep.startingGateway:
        return 'Starting AI Gateway';
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
      case SetupStep.downloadingRootfs:
        return 1;
      case SetupStep.extractingRootfs:
        return 2;
      case SetupStep.installingNode:
        return 3;
      case SetupStep.installingOpenClaw:
        return 4;
      case SetupStep.configuringBypass:
        return 5;
      case SetupStep.hardening:
        return 6;
      case SetupStep.startingGateway:
        return 7;
      case SetupStep.cleanup:
        return 8;
      case SetupStep.complete:
        return 9;
      case SetupStep.error:
        return -1;
    }
  }

  static const int totalSteps = 9;
}
