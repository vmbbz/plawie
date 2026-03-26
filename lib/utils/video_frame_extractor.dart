import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../services/native_bridge.dart';

/// Extracts JPEG frames from an MP4 clip using the ffmpeg binary inside PRoot.
///
/// Strategy:
///   1. Write the MP4 to a host path that is mapped into PRoot.
///   2. Run: ffmpeg -i <input> -vf fps=<fps> <output_pattern> -y
///   3. Read back the JPEG files and return as List<Uint8List>.
///   4. Clean up temp files.
///
/// Requires ffmpeg to be installed in PRoot: `apt-get install -y ffmpeg`
class VideoFrameExtractor {
  /// Extract [fps] frames per second from [mp4Bytes].
  /// Returns an empty list if ffmpeg is unavailable or extraction fails.
  static Future<List<Uint8List>> extractFrames(
    Uint8List mp4Bytes, {
    int fps = 1,
    int maxFrames = 10,
  }) async {
    try {
      // Map app support dir to PRoot-accessible host path
      final appSupportDir = await getApplicationSupportDirectory();
      final hostBase = '${appSupportDir.path}/rootfs';
      final prootTmpDir = '/root/.openclaw/tmp';
      final hostTmpDir = '$hostBase$prootTmpDir';

      // Ensure temp directory exists
      await Directory(hostTmpDir).create(recursive: true);

      final ts = DateTime.now().millisecondsSinceEpoch;
      final hostMp4 = '$hostTmpDir/clip_$ts.mp4';
      final prootMp4 = '$prootTmpDir/clip_$ts.mp4';
      final prootFramePattern = '$prootTmpDir/frame_${ts}_%03d.jpg';

      // Write MP4 to host-mapped PRoot path
      await File(hostMp4).writeAsBytes(mp4Bytes);

      // Run ffmpeg inside PRoot
      final extractCmd =
          'ffmpeg -i "$prootMp4" -vf "fps=$fps" -frames:v $maxFrames "$prootFramePattern" -y 2>/dev/null';
      await NativeBridge.runInProot(extractCmd, timeout: 30);

      // Read back extracted JPEG frames
      final frames = <Uint8List>[];
      for (int i = 1; i <= maxFrames; i++) {
        final hostFrame = '$hostTmpDir/frame_${ts}_${i.toString().padLeft(3, '0')}.jpg';
        final f = File(hostFrame);
        if (await f.exists()) {
          frames.add(await f.readAsBytes());
        } else {
          break; // No more frames
        }
      }

      // Clean up
      _cleanupAsync(hostMp4, hostTmpDir, ts);

      return frames;
    } catch (_) {
      return [];
    }
  }

  static void _cleanupAsync(String mp4Path, String dir, int ts) {
    Future.microtask(() async {
      try { await File(mp4Path).delete(); } catch (_) {}
      for (int i = 1; i <= 10; i++) {
        final f = File('$dir/frame_${ts}_${i.toString().padLeft(3, '0')}.jpg');
        try { if (await f.exists()) await f.delete(); } catch (_) {}
      }
    });
  }
}
