class ChatRoutingPolicy {
  static final RegExp _toolCapabilityQuestion = RegExp(
    r'\b(what|which|list|show|tell|explain|describe)\b.{0,80}\b(tool|tools|skill|skills|capabilit(?:y|ies)|can you do|able to do)\b',
    caseSensitive: false,
  );

  static final RegExp _actionVerbNearDeviceTarget = RegExp(
    r'\b(turn|switch|toggle|enable|disable|start|stop|open|navigate|browse|search|google|take|capture|record|read|get|fetch|use|call|invoke|run|vibrate)\b.{0,90}\b(camera|photo|picture|screenshot|screen|location|gps|sensor|accelerometer|gyro|torch|flashlight|haptic|website|browser|canvas|tool|skill|device|node)\b',
    caseSensitive: false,
  );

  static const List<String> _explicitGatewayActionPhrases = <String>[
    'take a photo',
    'take photo',
    'take picture',
    'capture photo',
    'capture picture',
    'take screenshot',
    'screen record',
    'record screen',
    'record my screen',
    'turn on torch',
    'turn off torch',
    'toggle torch',
    'flashlight on',
    'flashlight off',
    'vibrate',
    'haptic',
    'get location',
    'gps',
    'read sensor',
    'accelerometer',
    'gyro',
    'open website',
    'open a website',
    'navigate to',
    'browse to',
    'search the web',
    'google ',
    'use the camera',
    'call tool',
    'use tool',
    'run tool',
    'invoke tool',
    'call skill',
    'use skill',
    'run skill',
    'invoke skill',
  ];

  static bool shouldUseGatewayForText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    // "What tools do you have?" is a normal chat/meta question. Sending it to
    // the agent lane makes the gateway load the full tool pipeline just to
    // answer a description question, which is exactly the slow path on phones.
    if (_toolCapabilityQuestion.hasMatch(normalized) &&
        !_containsExplicitAction(normalized)) {
      return false;
    }

    if (_containsExplicitAction(normalized)) return true;
    return _actionVerbNearDeviceTarget.hasMatch(normalized);
  }

  static bool _containsExplicitAction(String normalized) {
    return _explicitGatewayActionPhrases.any(normalized.contains);
  }
}
