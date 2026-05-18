import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart';
import '../services/vrm_download_service.dart';
import '../services/preferences_service.dart';
import '../widgets/glass_card.dart';

/// Full-screen VRM avatar store: browse, download, equip, and delete avatars.
///
/// Bundled avatars (gemini.vrm, boruto.vrm) are always shown as installed.
/// Cloud avatars come from [kCloudVrmCatalog] and are downloaded on demand.
class VrmStoreScreen extends StatefulWidget {
  const VrmStoreScreen({super.key});

  @override
  State<VrmStoreScreen> createState() => _VrmStoreScreenState();
}

class _VrmStoreScreenState extends State<VrmStoreScreen> {
  final _svc = VrmDownloadService();
  final _prefs = PreferencesService();

  // fileName → download progress (null = not downloading)
  final Map<String, double> _progress = {};
  // fileName → is downloaded
  final Map<String, bool> _downloaded = {};
  // Active stream subscriptions keyed by fileName
  final Map<String, StreamSubscription<double>> _subs = {};

  String _equippedAvatar = 'gemini.vrm';
  int _cacheBytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _loadState() async {
    await _prefs.init();
    _svc.invalidateCache();

    final downloaded = <String, bool>{};
    for (final entry in kCloudVrmCatalog) {
      downloaded[entry.fileName] = await _svc.isDownloaded(entry.fileName);
    }
    final cacheSize = await _svc.cacheSize();

    if (!mounted) return;
    setState(() {
      _downloaded.addAll(downloaded);
      _equippedAvatar = _prefs.selectedAvatar;
      _cacheBytes = cacheSize;
      _loading = false;
    });
  }

  void _startDownload(CloudVrmEntry entry) {
    if (_subs.containsKey(entry.fileName)) return;

    setState(() => _progress[entry.fileName] = 0.0);

    final stream = _svc.download(entry);
    _subs[entry.fileName] = stream.listen(
      (p) {
        if (mounted) setState(() => _progress[entry.fileName] = p);
      },
      onDone: () async {
        _subs.remove(entry.fileName);
        final cacheSize = await _svc.cacheSize();
        if (mounted) {
          setState(() {
            _progress.remove(entry.fileName);
            _downloaded[entry.fileName] = true;
            _cacheBytes = cacheSize;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${entry.displayName} downloaded'),
            backgroundColor: AppColors.statusGreen,
            duration: const Duration(seconds: 2),
          ));
        }
      },
      onError: (e) {
        _subs.remove(entry.fileName);
        if (mounted) {
          setState(() => _progress.remove(entry.fileName));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ));
        }
      },
      cancelOnError: true,
    );
  }

  void _cancelDownload(CloudVrmEntry entry) {
    _subs[entry.fileName]?.cancel();
    _subs.remove(entry.fileName);
    _svc.cancelDownload(entry.fileName);
    if (mounted) setState(() => _progress.remove(entry.fileName));
  }

  Future<void> _deleteVrm(CloudVrmEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete avatar?'),
        content: Text(
          '${entry.displayName} (${entry.sizeLabel}) will be removed from your device. '
          'You can re-download it later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _svc.delete(entry.fileName);

    // If this avatar was equipped, fall back to the default
    if (_equippedAvatar == entry.fileName) {
      _prefs.selectedAvatar = 'gemini.vrm';
    }

    final cacheSize = await _svc.cacheSize();
    if (!mounted) return;
    setState(() {
      _downloaded[entry.fileName] = false;
      _cacheBytes = cacheSize;
      if (_equippedAvatar == entry.fileName) _equippedAvatar = 'gemini.vrm';
    });
  }

  void _equipAvatar(String fileName) {
    _prefs.selectedAvatar = fileName;
    setState(() => _equippedAvatar = fileName);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Equipped ${_labelFor(fileName)}'),
      backgroundColor: AppColors.statusGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  String _labelFor(String fileName) {
    if (fileName == 'gemini.vrm') return 'Gemini';
    if (fileName == 'boruto.vrm') return 'Boruto';
    for (final e in kCloudVrmCatalog) {
      if (e.fileName == fileName) return e.displayName;
    }
    return fileName.replaceAll('.vrm', '');
  }

  String _cacheSizeLabel() {
    if (_cacheBytes < 1024 * 1024) return '${(_cacheBytes / 1024).toStringAsFixed(0)} KB';
    return '${(_cacheBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const NebulaBg(),
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.statusGreen)),
                )
              else ...[
                SliverToBoxAdapter(child: _buildBundledSection()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          'CLOUD AVATARS',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: Colors.white38,
                          ),
                        ),
                        const Spacer(),
                        if (_cacheBytes > 0)
                          Text(
                            '${_cacheSizeLabel()} downloaded',
                            style: const TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: SliverList.builder(
                    itemCount: kCloudVrmCatalog.length,
                    itemBuilder: (ctx, i) => _buildCloudTile(kCloudVrmCatalog[i]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'AVATAR STORE',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 3.0,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBundledSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUNDLED',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: AppColors.statusGreen.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          for (final fileName in kBundledVrms)
            _buildBundledTile(fileName),
        ],
      ),
    );
  }

  Widget _buildBundledTile(String fileName) {
    final isEquipped = _equippedAvatar == fileName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        blurStrength: 20,
        innerTint: isEquipped
            ? AppColors.statusGreen.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.statusGreen.withValues(alpha: 0.15),
            child: const Icon(Icons.person_outline_rounded, color: AppColors.statusGreen, size: 20),
          ),
          title: Text(
            _labelFor(fileName),
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          subtitle: const Text('Built-in', style: TextStyle(fontSize: 11, color: Colors.white38)),
          trailing: isEquipped
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.statusGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'EQUIPPED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.statusGreen,
                      letterSpacing: 1.0,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () => _equipAvatar(fileName),
                  child: const Text('Equip'),
                ),
        ),
      ),
    );
  }

  Widget _buildCloudTile(CloudVrmEntry entry) {
    final isDownloaded = _downloaded[entry.fileName] ?? false;
    final isDownloading = _progress.containsKey(entry.fileName);
    final progress = _progress[entry.fileName] ?? 0.0;
    final isEquipped = _equippedAvatar == entry.fileName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        blurStrength: 20,
        innerTint: isEquipped
            ? AppColors.statusGreen.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: isDownloaded
                    ? AppColors.statusGreen.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                child: Icon(
                  isDownloaded ? Icons.person_rounded : Icons.cloud_download_outlined,
                  color: isDownloaded ? AppColors.statusGreen : Colors.white38,
                  size: 20,
                ),
              ),
              title: Text(
                entry.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
              subtitle: Text(
                entry.sizeLabel,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
              trailing: _buildTileAction(entry, isDownloaded, isDownloading, isEquipped),
            ),
            if (isDownloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(AppColors.statusGreen),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% — ${entry.sizeLabel}',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTileAction(
    CloudVrmEntry entry,
    bool isDownloaded,
    bool isDownloading,
    bool isEquipped,
  ) {
    if (isDownloading) {
      return IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white54),
        tooltip: 'Cancel',
        onPressed: () => _cancelDownload(entry),
      );
    }

    if (isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isEquipped)
            TextButton(
              onPressed: () => _equipAvatar(entry.fileName),
              child: const Text('Equip'),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.4)),
              ),
              child: Text(
                'EQUIPPED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.statusGreen,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 18),
            tooltip: 'Delete',
            onPressed: () => _deleteVrm(entry),
          ),
        ],
      );
    }

    // Not downloaded
    return IconButton(
      icon: const Icon(Icons.download_rounded, color: AppColors.statusGreen),
      tooltip: 'Download ${entry.sizeLabel}',
      onPressed: () => _startDownload(entry),
    );
  }
}
