import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Metadata for a single downloadable cloud VRM.
class CloudVrmEntry {
  final String fileName;    // e.g. 'ironman.vrm'
  final String displayName; // e.g. 'Iron Man'
  final int sizeBytes;
  final String downloadUrl;

  const CloudVrmEntry({
    required this.fileName,
    required this.displayName,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// Bundled VRMs that are always available (no download needed).
const List<String> kBundledVrms = ['gemini.vrm', 'boruto.vrm'];

// Base URL for GitHub Releases VRM pack (tag: vrm-pack-v on github.com/vmbbz/plawie).
const String _kReleaseBase =
    'https://github.com/vmbbz/plawie/releases/download/vrm-pack-v';

/// Full catalog of cloud-hosted VRM models.
const List<CloudVrmEntry> kCloudVrmCatalog = [
  CloudVrmEntry(fileName: 'ironman.vrm',          displayName: 'Iron Man',         sizeBytes: 1726112,  downloadUrl: '$_kReleaseBase/ironman.vrm'),
  CloudVrmEntry(fileName: 'kungfu-panda.vrm',      displayName: 'Kung Fu Panda',    sizeBytes: 2165200,  downloadUrl: '$_kReleaseBase/kungfu-panda.vrm'),
  CloudVrmEntry(fileName: 'spiderman.vrm',         displayName: 'Spider-Man',       sizeBytes: 4913572,  downloadUrl: '$_kReleaseBase/spiderman.vrm'),
  CloudVrmEntry(fileName: 'hosizorano.vrm',        displayName: 'Hosizorano',       sizeBytes: 6374532,  downloadUrl: '$_kReleaseBase/hosizorano.vrm'),
  CloudVrmEntry(fileName: 'hinata-hyuga.vrm',      displayName: 'Hinata Hyuga',     sizeBytes: 10066004, downloadUrl: '$_kReleaseBase/hinata-hyuga.vrm'),
  CloudVrmEntry(fileName: 'stranger.vrm',          displayName: 'Stranger',         sizeBytes: 10917640, downloadUrl: '$_kReleaseBase/stranger.vrm'),
  CloudVrmEntry(fileName: 'boudicca_chilled.vrm',  displayName: 'Boudicca',         sizeBytes: 15049528, downloadUrl: '$_kReleaseBase/boudicca_chilled.vrm'),
  CloudVrmEntry(fileName: 'trump.vrm',             displayName: 'Trump',            sizeBytes: 15090720, downloadUrl: '$_kReleaseBase/trump.vrm'),
  CloudVrmEntry(fileName: 'joker.vrm',             displayName: 'Joker',            sizeBytes: 18868256, downloadUrl: '$_kReleaseBase/joker.vrm'),
  CloudVrmEntry(fileName: 'soyako.vrm',            displayName: 'Soyako',           sizeBytes: 19686968, downloadUrl: '$_kReleaseBase/soyako.vrm'),
  CloudVrmEntry(fileName: 'gemini-pink.vrm',       displayName: 'Gemini (Pink)',    sizeBytes: 20980520, downloadUrl: '$_kReleaseBase/gemini-pink.vrm'),
  CloudVrmEntry(fileName: 'war_boudica.vrm',       displayName: 'War Boudica',      sizeBytes: 21335060, downloadUrl: '$_kReleaseBase/war_boudica.vrm'),
  CloudVrmEntry(fileName: 'frankenstein.vrm',      displayName: 'Frankenstein',     sizeBytes: 22993724, downloadUrl: '$_kReleaseBase/frankenstein.vrm'),
  CloudVrmEntry(fileName: 'superman.vrm',          displayName: 'Superman',         sizeBytes: 32617848, downloadUrl: '$_kReleaseBase/superman.vrm'),
];

/// Manages downloading, caching, and deleting cloud VRM files.
///
/// Downloaded files live in `<documents>/vrm_cache/`. The local HTTP server
/// ([VrmAssetServer]) checks this directory before falling back to bundled assets,
/// so downloaded VRMs are automatically served to the WebView renderer.
class VrmDownloadService {
  static final VrmDownloadService _instance = VrmDownloadService._internal();
  factory VrmDownloadService() => _instance;
  VrmDownloadService._internal();

  // Active downloads: fileName → StreamController<double> (0.0–1.0 progress)
  final Map<String, StreamController<double>> _activeDownloads = {};
  // Cached download status so callers don't hit the filesystem each rebuild.
  final Map<String, bool> _statusCache = {};

  Future<Directory> get _cacheDir async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/vrm_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _cacheFile(String fileName) async =>
      File('${(await _cacheDir).path}/$fileName');

  /// Returns true if [fileName] is already downloaded locally.
  Future<bool> isDownloaded(String fileName) async {
    if (_statusCache.containsKey(fileName)) return _statusCache[fileName]!;
    final file = await _cacheFile(fileName);
    final exists = await file.exists();
    _statusCache[fileName] = exists;
    return exists;
  }

  /// Returns the local [File] for [fileName] if downloaded, otherwise null.
  Future<File?> localFile(String fileName) async {
    final file = await _cacheFile(fileName);
    return await file.exists() ? file : null;
  }

  /// Returns all VRM file names that have been downloaded to the cache.
  Future<List<String>> listDownloaded() async {
    final dir = await _cacheDir;
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.vrm'))
        .map((f) => f.uri.pathSegments.last)
        .toList();
  }

  /// Total bytes used by the VRM cache directory.
  Future<int> cacheSize() async {
    final dir = await _cacheDir;
    int total = 0;
    for (final entity in dir.listSync()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Whether [fileName] is currently being downloaded.
  bool isDownloading(String fileName) => _activeDownloads.containsKey(fileName);

  /// Stream of download progress (0.0–1.0) for [fileName].
  /// Completes when the download finishes or errors.
  Stream<double>? progressStream(String fileName) =>
      _activeDownloads[fileName]?.stream;

  /// Start downloading [entry] to the local cache.
  /// Returns a [Stream<double>] of progress (0.0–1.0).
  /// If already downloading, returns the existing stream.
  Stream<double> download(CloudVrmEntry entry) {
    if (_activeDownloads.containsKey(entry.fileName)) {
      return _activeDownloads[entry.fileName]!.stream;
    }

    final controller = StreamController<double>.broadcast();
    _activeDownloads[entry.fileName] = controller;

    _runDownload(entry, controller);
    return controller.stream;
  }

  Future<void> _runDownload(
    CloudVrmEntry entry,
    StreamController<double> controller,
  ) async {
    try {
      final destFile = await _cacheFile(entry.fileName);
      final tmpFile = File('${destFile.path}.tmp');

      final request = http.Request('GET', Uri.parse(entry.downloadUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? entry.sizeBytes;
      int received = 0;
      final sink = tmpFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) controller.add(received / total);
      }
      await sink.flush();
      await sink.close();

      // Atomic rename: only replace destination if download succeeded fully
      await tmpFile.rename(destFile.path);
      _statusCache[entry.fileName] = true;
      controller.add(1.0);
      controller.close();
    } catch (e) {
      debugPrint('[VRM] Download failed for ${entry.fileName}: $e');
      // Clean up partial file
      try {
        final tmp = await _cacheFile('${entry.fileName}.tmp');
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      controller.addError(e);
      controller.close();
    } finally {
      _activeDownloads.remove(entry.fileName);
    }
  }

  /// Cancel an in-progress download for [fileName].
  void cancelDownload(String fileName) {
    _activeDownloads[fileName]?.close();
    _activeDownloads.remove(fileName);
  }

  /// Delete the cached copy of [fileName].
  Future<void> delete(String fileName) async {
    final file = await _cacheFile(fileName);
    if (await file.exists()) await file.delete();
    _statusCache[fileName] = false;
  }

  /// Clear the status cache so [isDownloaded] re-checks the filesystem.
  void invalidateCache() => _statusCache.clear();
}
