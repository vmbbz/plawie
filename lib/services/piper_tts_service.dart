import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'dart:isolate';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:audioplayers/audioplayers.dart';

// ignore_for_file: unused_import

class PiperTtsService {
  static final PiperTtsService _instance = PiperTtsService._internal();
  factory PiperTtsService() => _instance;
  PiperTtsService._internal();

  sherpa.OfflineTts? _tts;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInit = false;
  bool get isReady => _isInit && _tts != null;

  /// Safety timer: forces onComplete if AudioPlayer doesn't fire onPlayerComplete
  /// (e.g. Android audio focus loss, silent playback errors).
  Timer? _safetyTimer;

  /// Speech rate passed to sherpa-onnx generate(). 1.0 = normal, 0.8 = slower, 1.4 = faster.
  /// Exposed so future TTS settings UI can call `piperTts.speed = value`.
  double speed = 1.0;

  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;

  // Handlers to emulate the flutter_tts interface for VRM lip sync
  Function? onStart;
  Function? onComplete;
  Function(double)? onDownloadProgress;

  Future<bool> isModelDownloaded() async {
    final docDir = await getApplicationDocumentsDirectory();
    final modelExtractedDir = Directory('${docDir.path}/voices/vits-piper-en_US-amy-low');
    return await modelExtractedDir.exists();
  }

  Future<void> init({bool forceDownload = false}) async {
    if (_isInit && !forceDownload) return;
    
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final voicesDir = Directory('${docDir.path}/voices');
      final modelExtractedDir = Directory('${voicesDir.path}/vits-piper-en_US-amy-low');

      if (!await modelExtractedDir.exists() || forceDownload) {
        if (!forceDownload && !await modelExtractedDir.exists()) {
          print('PiperTTS: Model missing and forceDownload is false. Aborting silent init.');
          _isInit = false;
          return;
        }

        print('PiperTTS: Preparing to download ONNX model...');
        await voicesDir.create(recursive: true);
        
        final url = Uri.parse('https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-amy-low.tar.bz2');
        final httpClient = HttpClient();
        httpClient.connectionTimeout = const Duration(seconds: 15);
        final request = await httpClient.getUrl(url).timeout(const Duration(seconds: 20));
        final response = await request.close().timeout(const Duration(seconds: 20));
        
        if (response.statusCode != 200) {
          throw HttpException('Server returned status code ${response.statusCode}');
        }

        final totalLength = response.contentLength;
        int receivedLength = 0;

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/piper_model_download.tar.bz2');
        final sink = tempFile.openWrite();

        try {
          await for (var chunk in response.timeout(const Duration(seconds: 30))) {
            sink.add(chunk);
            receivedLength += chunk.length;
            if (totalLength != -1) {
              _downloadProgress = receivedLength / totalLength;
              onDownloadProgress?.call(_downloadProgress * 0.8); // 80% for download
            }
          }
        } finally {
          await sink.close();
        }
        
        print('PiperTTS: Download complete. Extracting via background isolate...');
        onDownloadProgress?.call(0.85);
        
        final voicesDirPath = voicesDir.path;
        final tempFilePath = tempFile.path;
        
        await Isolate.run(() {
          final bytes = File(tempFilePath).readAsBytesSync();
          final tarBytes = BZip2Decoder().decodeBytes(bytes);
          final archive = TarDecoder().decodeBytes(tarBytes);
          
          for (final file in archive) {
            final filename = file.name;
            if (file.isFile) {
              final data = file.content as List<int>;
              final outFile = File('$voicesDirPath/$filename');
              outFile.parent.createSync(recursive: true);
              outFile.writeAsBytesSync(data, flush: true);
            }
          }
        });
        
        // Clean up temp file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        
        onDownloadProgress?.call(1.0);
        print('PiperTTS: Extraction complete.');
      }

      final base = modelExtractedDir.path;
      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: '$base/en_US-amy-low.onnx',
            lexicon: '',
            tokens: '$base/tokens.txt',
            dataDir: '$base/espeak-ng-data',
            noiseScale: 0.667,
            noiseScaleW: 0.8,
            lengthScale: 1.0,
          ),
          numThreads: 2,
          debug: false,
          provider: "cpu",
        ),
        ruleFsts: '',
      );

      _tts = sherpa.OfflineTts(config);

      // Configure AudioPlayer for speech output on Android.
      // Without AudioContext, Android may route to the wrong stream (e.g., MUSIC)
      // or be blocked by audio focus held by the speech recogniser.
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.duckOthers},
          ),
        ),
      );
      // Stop releases resources after each utterance so the next play() starts clean
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);

      _audioPlayer.onPlayerComplete.listen((_) {
        _safetyTimer?.cancel();
        onComplete?.call();
      });

      _isInit = true;
      print('PiperTTS: Initialization successful.');
    } catch (e) {
      print('PiperTTS Error: $e');
      _isInit = false;
    }
  }

  Future<void> speak(String text) async {
    if (!isReady || text.trim().isEmpty) {
      onComplete?.call(); // Unblock the TTS queue even when skipping
      return;
    }

    try {
      // 1. Generate PCM — pass current speed so UI slider takes immediate effect
      final audioConfig = _tts!.generate(text: text, sid: 0, speed: speed);
      if (audioConfig.samples.isEmpty) {
        // Nothing to play — still fire onComplete so VRM lip-sync resets
        onComplete?.call();
        return;
      }

      onStart?.call();

      // 2. Write WAV to temp file
      final tempDir = await getTemporaryDirectory();
      final wavFile = File('${tempDir.path}/piper_speech.wav');
      await _writeWav(audioConfig.samples, audioConfig.sampleRate, wavFile);

      // 3. Stop any previous playback so the AudioPlayer is in a clean state.
      //    Without this, audioplayers v6 on Android can silently skip play()
      //    if the previous session wasn't fully released.
      await _audioPlayer.stop();

      // 4. Safety timeout: if onPlayerComplete doesn't fire within the expected
      //    duration + 2 s headroom, force-complete to prevent the entire TTS
      //    pipeline from getting stuck (which causes the "goes silent" bug).
      final estimatedMs = (audioConfig.samples.length / audioConfig.sampleRate * 1000).toInt() + 2000;
      _safetyTimer?.cancel();
      _safetyTimer = Timer(Duration(milliseconds: estimatedMs), () {
        print('PiperTTS: Safety timeout fired — forcing onComplete');
        onComplete?.call();
      });

      // 5. Play — returns when playback STARTS (not finishes).
      //    onComplete fires via onPlayerComplete listener set in init().
      await _audioPlayer.play(DeviceFileSource(wavFile.path));

    } catch (e) {
      print('PiperTTS Speak Error: $e');
      onComplete?.call();
    }
  }
  
  Future<void> stop() async {
    await _audioPlayer.stop();
    onComplete?.call();
  }

  // Quick helper to package Float32 PCM samples into a playable WAV file
  Future<void> _writeWav(List<double> samples, int sampleRate, File file) async {
    // Convert Float32 [-1.0, 1.0] to Int16
    final int16Samples = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
        double s = samples[i];
        s = s.clamp(-1.0, 1.0);
        int16Samples[i] = (s * 32767).toInt();
    }

    final byteData = ByteData(44 + int16Samples.length * 2);
    // RIFF chunk descriptor
    byteData.setUint32(0, 0x52494646, Endian.big); // 'RIFF'
    byteData.setUint32(4, 36 + int16Samples.length * 2, Endian.little);
    byteData.setUint32(8, 0x57415645, Endian.big); // 'WAVE'

    // fmt sub-chunk
    byteData.setUint32(12, 0x666d7420, Endian.big); // 'fmt '
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size
    byteData.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    byteData.setUint16(22, 1, Endian.little); // NumChannels
    byteData.setUint32(24, sampleRate, Endian.little); // SampleRate
    byteData.setUint32(28, sampleRate * 1 * 2, Endian.little); // ByteRate
    byteData.setUint16(32, 2, Endian.little); // BlockAlign
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample

    // data sub-chunk
    byteData.setUint32(36, 0x64617461, Endian.big); // 'data'
    byteData.setUint32(40, int16Samples.length * 2, Endian.little);

    // Write samples
    int offset = 44;
    for (int i = 0; i < int16Samples.length; i++) {
      byteData.setInt16(offset, int16Samples[i], Endian.little);
      offset += 2;
    }

    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  }
}
