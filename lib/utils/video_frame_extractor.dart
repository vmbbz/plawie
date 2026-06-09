import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../services/native_bridge.dart';

typedef NativeFfmpegRunner = Future<NativeFfmpegRunResult> Function(
  List<String> args, {
  required int timeoutSeconds,
});

typedef VideoFrameTempDirectoryProvider = Future<Directory> Function();

/// Extracts JPEG frames from an MP4 clip using the provisioned Native ffmpeg.
///
/// The executable is resolved by the Android bridge from the app-owned Native
/// managed bin: `native-node-embedded/native-home/.openclaw/bin/ffmpeg`.
class VideoFrameExtractor {
  /// Extract [fps] frames per second from [mp4Bytes].
  /// Returns an empty list if ffmpeg is unavailable or extraction fails.
  static Future<List<Uint8List>> extractFrames(
    Uint8List mp4Bytes, {
    int fps = 1,
    int maxFrames = 10,
    VideoFrameTempDirectoryProvider? tempDirectoryProvider,
    NativeFfmpegRunner? ffmpegRunner,
  }) async {
    final boundedFps = fps.clamp(1, 10).toInt();
    final boundedMaxFrames = maxFrames.clamp(1, 60).toInt();
    Directory? runDir;
    try {
      final baseDir = tempDirectoryProvider == null
          ? await getTemporaryDirectory()
          : await tempDirectoryProvider();
      final ts = DateTime.now().microsecondsSinceEpoch;
      runDir = Directory(path.join(baseDir.path, 'video_frames_$ts'));
      await runDir.create(recursive: true);

      final input = File(path.join(runDir.path, 'clip_$ts.mp4'));
      final outputPattern = path.join(runDir.path, 'frame_%03d.jpg');
      await input.writeAsBytes(mp4Bytes, flush: true);

      final runner = ffmpegRunner ?? NativeBridge.runManagedFfmpeg;
      final result = await runner(
        <String>[
          '-hide_banner',
          '-loglevel',
          'error',
          '-i',
          input.path,
          '-vf',
          'fps=$boundedFps',
          '-frames:v',
          '$boundedMaxFrames',
          '-y',
          outputPattern,
        ],
        timeoutSeconds: 30,
      );
      if (!result.ok) return <Uint8List>[];

      final frames = <Uint8List>[];
      for (var i = 1; i <= boundedMaxFrames; i++) {
        final frame = File(
          path.join(runDir.path, 'frame_${i.toString().padLeft(3, '0')}.jpg'),
        );
        if (!await frame.exists()) break;
        frames.add(await frame.readAsBytes());
      }
      return frames;
    } catch (_) {
      return <Uint8List>[];
    } finally {
      if (runDir != null) {
        unawaitedDelete(runDir);
      }
    }
  }

  static void unawaitedDelete(Directory directory) {
    Future.microtask(() async {
      try {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      } catch (_) {}
    });
  }
}
