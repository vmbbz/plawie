import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';

/// Records a short MP4 clip using the device camera.
/// Reuses the `camera` package already installed in pubspec.yaml.
class VideoCaptureService {
  /// Record a clip for [durationMs] milliseconds.
  /// Returns the raw MP4 bytes, or null on failure.
  static Future<Uint8List?> recordClip({
    int durationMs = 5000,
    bool frontCamera = false,
  }) async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return null;

      // Pick front or back camera
      final camera = frontCamera
          ? cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => cameras.first,
            )
          : cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => cameras.first,
            );

      controller = CameraController(
        camera,
        ResolutionPreset.low, // Low quality: smaller file, faster inference
        enableAudio: false,   // No audio needed for vision analysis
      );
      await controller.initialize();

      await controller.startVideoRecording();
      await Future.delayed(Duration(milliseconds: durationMs));
      final xFile = await controller.stopVideoRecording();

      // Move/copy to our temp path and read bytes
      final file = File(xFile.path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();

      // Clean up temp file
      try { await file.delete(); } catch (_) {}

      return bytes;
    } catch (e) {
      return null;
    } finally {
      await controller?.dispose();
    }
  }
}
