import 'dart:async';

class ToolMediaEvent {
  final String source;
  final String base64;
  final String mimeType;
  final int? width;
  final int? height;
  final String timestamp;

  ToolMediaEvent({
    required this.source,
    required this.base64,
    required this.mimeType,
    this.width,
    this.height,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMetadata() => {
        'source': source,
        'mimeType': mimeType,
        'attachedImage': true,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'timestamp': timestamp,
      };
}

class ToolMediaEventBus {
  ToolMediaEventBus._();
  static final ToolMediaEventBus instance = ToolMediaEventBus._();

  final _controller = StreamController<ToolMediaEvent>.broadcast();

  Stream<ToolMediaEvent> get stream => _controller.stream;

  void publish(ToolMediaEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }
}
