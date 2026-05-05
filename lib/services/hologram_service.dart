import 'dart:async';

/// Types of content the Hologram overlay can display.
enum HologramType { image, webPreview, canvas }

class HologramPayload {
  final HologramType type;
  /// For [HologramType.image]: raw base64 bytes (no data-URL prefix).
  final String? imageBase64;
  /// For [HologramType.webPreview]: the URL label shown in the overlay header.
  final String? label;

  const HologramPayload._({
    required this.type,
    this.imageBase64,
    this.label,
  });

  factory HologramPayload.image(String base64, {String? label}) =>
      HologramPayload._(type: HologramType.image, imageBase64: base64, label: label);

  factory HologramPayload.canvas({String? label}) =>
      HologramPayload._(type: HologramType.canvas, label: label ?? 'Canvas');

  factory HologramPayload.webPreview(String url) =>
      HologramPayload._(type: HologramType.webPreview, label: url);
}

/// Broadcast channel for routing media to the Hologram overlay in ChatScreen.
/// Call [show] to push a payload; the overlay widget listens and displays it.
class HologramService {
  static final HologramService instance = HologramService._();
  HologramService._();

  final _controller = StreamController<HologramPayload?>.broadcast();

  Stream<HologramPayload?> get stream => _controller.stream;

  void show(HologramPayload payload) => _controller.add(payload);

  void dismiss() => _controller.add(null);

  void dispose() => _controller.close();
}
