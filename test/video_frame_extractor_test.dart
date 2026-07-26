import 'dart:io';
import 'dart:typed_data';

import 'package:clawa/services/native_bridge.dart';
import 'package:clawa/utils/video_frame_extractor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('Android bridge exposes bounded managed ffmpeg runner', () async {
    final activity = await File(
      'android/app/src/main/kotlin/com/openclaw/plawie/MainActivity.kt',
    ).readAsString();

    expect(activity, contains('"runManagedFfmpeg"'));
    expect(activity, contains('native-home/.openclaw/bin'));
    expect(activity, contains('"ffmpeg"'));
    expect(activity, contains('managedNativeElfCommand(ffmpeg, args)'));
    expect(activity, contains('File("/system/bin/linker64")'));
    expect(activity, contains('ProcessBuilder(command)'));
    expect(activity, contains('readProcessStreamBounded(process.inputStream'));
    expect(activity, contains('64 * 1024'));
    expect(
        activity,
        isNot(contains('runManagedFfmpeg" -> {\n'
            '                    val command = call.argument<String>("command")')));
  });

  test('video frame failure copy points to vision media provisioning',
      () async {
    final runtime =
        await File('lib/services/chat_runtime_service.dart').readAsString();
    final screen = await File('lib/screens/chat_screen.dart').readAsString();

    expect(runtime, isNot(contains('installed in PRoot')));
    expect(screen, isNot(contains('installed in PRoot')));
    expect(runtime, contains('android-vision-media-runtime'));
    expect(screen, contains('android-vision-media-runtime'));
  });

  test('extractFrames uses Native ffmpeg with app-owned temp paths', () async {
    final temp = await Directory.systemTemp.createTemp('video_frames_native_');
    addTearDown(() async {
      try {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    });

    final captured = <List<String>>[];
    final frames = await VideoFrameExtractor.extractFrames(
      Uint8List.fromList(List<int>.filled(32, 7)),
      fps: 1,
      maxFrames: 2,
      tempDirectoryProvider: () async => temp,
      ffmpegRunner: (args, {required timeoutSeconds}) async {
        captured.add(List<String>.from(args));
        expect(timeoutSeconds, 30);
        expect(args, isNot(contains('runInProot')));
        expect(args.join(' '), isNot(contains('/root/.openclaw')));
        expect(args.join(' '), isNot(contains('rootfs')));

        final outputPattern = args.last;
        await File(outputPattern.replaceFirst('%03d', '001'))
            .writeAsBytes(<int>[0xff, 0xd8, 0xff, 0xd9]);
        await File(outputPattern.replaceFirst('%03d', '002'))
            .writeAsBytes(<int>[0xff, 0xd8, 0x00, 0xff, 0xd9]);
        return const NativeFfmpegRunResult(
          exitCode: 0,
          stdout: '',
          stderr: '',
        );
      },
    );

    expect(frames, hasLength(2));
    expect(frames.first, Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9]));
    expect(captured, hasLength(1));
    expect(
        captured.single,
        containsAllInOrder(<String>[
          '-hide_banner',
          '-loglevel',
          'error',
          '-i',
        ]));
    expect(
        captured.single,
        containsAll(<String>[
          '-vf',
          'fps=1',
          '-frames:v',
          '2',
          '-y',
        ]));

    final inputPath = captured.single[captured.single.indexOf('-i') + 1];
    expect(inputPath, startsWith(temp.path));
    expect(path.basename(inputPath), startsWith('clip_'));
  });

  test('extractFrames returns empty when Native ffmpeg is unavailable',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('video_frames_missing_ffmpeg_');
    addTearDown(() async {
      try {
        if (await temp.exists()) {
          await temp.delete(recursive: true);
        }
      } catch (_) {}
    });

    final frames = await VideoFrameExtractor.extractFrames(
      Uint8List.fromList(<int>[1, 2, 3]),
      tempDirectoryProvider: () async => temp,
      ffmpegRunner: (args, {required timeoutSeconds}) async {
        return const NativeFfmpegRunResult(
          exitCode: 127,
          stdout: '',
          stderr: 'ffmpeg missing from android-vision-media-runtime',
        );
      },
    );

    expect(frames, isEmpty);
  });
}
