import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'dart:isolate';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:audioplayers/audioplayers.dart';

class PiperTtsService {
  static final PiperTtsService _instance = PiperTtsService._internal();
  factory PiperTtsService() => _instance;
  PiperTtsService._internal();

  sherpa.OfflineTts? _tts;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInit = false;
  bool get isReady => _isInit && _tts != null;
  
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

        final bytesBuilder = BytesBuilder();
        await for (var chunk in response.timeout(const Duration(seconds: 15))) {
          bytesBuilder.add(chunk);
          receivedLength += chunk.length;
          if (totalLength != -1) {
            _downloadProgress = receivedLength / totalLength;
            onDownloadProgress?.call(_downloadProgress * 0.8); // 80% for download
          }
        }
        final bytes = bytesBuilder.takeBytes();
        
        print('PiperTTS: Download complete. Extracting via background isolate...');
        onDownloadProgress?.call(0.85);
        
        final voicesDirPath = voicesDir.path;
        await Isolate.run(() {
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
      
      _audioPlayer.onPlayerComplete.listen((_) {
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
    if (!isReady || text.trim().isEmpty) return;

    try {
      // 1. Generate Raw PCM
      final audioConfig = _tts!.generate(text: text, sid: 0, speed: 1.0);
      if (audioConfig.samples.isEmpty) return;
      
      onStart?.call();

      // 2. Save to WAV file
      final tempDir = await getTemporaryDirectory();
      final wavFile = File('${tempDir.path}/piper_speech.wav');
      await _writeWav(audioConfig.samples, audioConfig.sampleRate, wavFile);

      // 3. Play WAV
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
