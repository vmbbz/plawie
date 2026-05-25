import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clawa/app.dart';
import 'package:clawa/services/gateway_service.dart';
import 'package:clawa/services/local_llm_service.dart';
import 'package:clawa/services/ndk_gateway_bridge_service.dart';
import 'package:clawa/services/native_bridge.dart';
import 'package:clawa/services/preferences_service.dart';

class LocalLlmScreen extends StatefulWidget {
  const LocalLlmScreen({super.key});

  @override
  State<LocalLlmScreen> createState() => _LocalLlmScreenState();
}

class _LocalLlmScreenState extends State<LocalLlmScreen>
    with WidgetsBindingObserver {
  final _service = LocalLlmService();
  final _bridge = NdkGatewayBridgeService();
  LocalLlmState _state = const LocalLlmState();
  NdkGatewayBridgeState _bridgeState = const NdkGatewayBridgeState();
  LocalLlmModel? _selectedModel;
  final Map<String, bool> _downloadedModels = {};

  // Diagnostics state
  final _testPromptController = TextEditingController(
      text: 'Hello, what model are you? Tell me a brief joke.');
  final _testResponseNotifier = ValueNotifier<String>('');
  bool _isTesting = false;
  double _tokensPerSec = 0;
  DateTime? _testStartTime;
  int _tokenCount = 0;
  String _healthStatus = '';
  bool _isCheckingHealth = false;

  // Thread slider state
  int _cpuCoreCount = 8; // default; refined at initState from /proc/cpuinfo

  StreamSubscription? _serviceSub;
  StreamSubscription? _bridgeSub;
  StreamSubscription<String>? _ndkTestSub;
  bool _isConfiguringBridge = false;
  bool _localChatModeEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state = _service.state;
    _serviceSub = _service.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _bridgeState = _bridge.state;
    _bridgeSub = _bridge.stateStream.listen((s) {
      if (mounted) setState(() => _bridgeState = s);
    });
    _checkDownloadedModels();
    _readCpuCoreCount();
    _loadLocalChatMode();
    // Default selection to the recommended model
    final toolCatalog =
        _service.catalog.where((m) => m.supportsToolCalls).toList();
    _selectedModel = toolCatalog.firstWhere(
      (m) => m.quality == 'Recommended',
      orElse: () => toolCatalog.first,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceSub?.cancel();
    _bridgeSub?.cancel();
    _ndkTestSub?.cancel();
    _testPromptController.dispose();
    _testResponseNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> _readCpuCoreCount() async {
    try {
      final result = await NativeBridge.runInProot(
        'grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "8"',
        timeout: 5,
      );
      final count = int.tryParse(result.trim()) ?? 8;
      final clampedCount = count.clamp(2, 12);
      if (_state.threads > 4 && !_service.isInferring) {
        // Keep first-run local inference friendly to average phones. Users can
        // still raise this manually, but old persisted 6+ thread settings are
        // too aggressive while Gateway + Flutter are also alive.
        await _service.setThreads(4, currentModel: _selectedModel);
      }
      if (mounted) setState(() => _cpuCoreCount = clampedCount);
    } catch (_) {
      // Default 8 already set — no crash
    }
  }

  Future<void> _checkDownloadedModels() async {
    for (final m in _service.catalog) {
      final downloaded = await _service.isModelDownloaded(m);
      if (mounted) {
        setState(() => _downloadedModels[m.id] = downloaded);
      }
    }
  }

  Future<void> _loadLocalChatMode() async {
    final prefs = PreferencesService();
    await prefs.init();
    if (mounted) {
      setState(() => _localChatModeEnabled = prefs.localChatModeEnabled);
    }
  }

  Future<void> _setLocalChatMode(bool enabled) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.localChatModeEnabled = enabled;
    if (!mounted) return;
    setState(() => _localChatModeEnabled = enabled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Local NDK chat enabled. Chat can now route to local-llm.'
              : 'Local NDK chat disabled. Chat is now gateway/cloud only.',
        ),
      ),
    );
  }

  Future<void> _toggleBridge() async {
    if (_bridgeState.isRunning) {
      await _bridge.stop();
    } else {
      final ok = await _bridge.start();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bridge failed: ${_bridge.state.errorMessage}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _configureGatewayBridge() async {
    if (_isConfiguringBridge) return;
    setState(() => _isConfiguringBridge = true);
    try {
      if (!_bridgeState.isRunning) {
        final ok = await _bridge.start();
        if (!ok) throw Exception(_bridge.state.errorMessage ?? 'bridge failed');
      }
      await GatewayService().configureNdkGatewayBridge(
        setAsPrimary: true,
        reloadIfRunning: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NDK bridge configured for Gateway experiment.'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bridge config failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfiguringBridge = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Ambient glow patches
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0097A7).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A3A5C).withValues(alpha: 0.15),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 20),
                      _buildThreadSlider(),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Model Library'),
                      const SizedBox(height: 12),
                      ..._service.catalog
                          .where((m) => m.supportsToolCalls)
                          .map(_buildModelCard),
                      const SizedBox(height: 16),
                      _buildModelInstructions(),
                      const SizedBox(height: 28),
                      _buildDeviceSpecCard(),
                      const SizedBox(height: 28),
                      _buildAgentPromptGuide(),
                      const SizedBox(height: 28),
                      _buildOfflineModeSection(),
                      const SizedBox(height: 28),
                      if (_state.status == LocalLlmStatus.ready) ...[
                        _buildSectionLabel('Diagnostics Playground'),
                        const SizedBox(height: 12),
                        _buildDiagnosticsPanel(),
                      ],
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Local LLM',
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            'BETA',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.amber,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final (Color color, IconData icon, String label) = switch (_state.status) {
      LocalLlmStatus.ready => (
          AppColors.statusGreen,
          Icons.check_circle_rounded,
          'Running'
        ),
      LocalLlmStatus.starting => (
          Colors.amber,
          Icons.hourglass_top_rounded,
          'Starting...'
        ),
      LocalLlmStatus.downloading => (
          Colors.blueAccent,
          Icons.cloud_download_rounded,
          'Downloading'
        ),
      LocalLlmStatus.installing => (
          Colors.purpleAccent,
          Icons.memory_rounded,
          'Activating...'
        ),
      LocalLlmStatus.error => (Colors.redAccent, Icons.error_rounded, 'Error'),
      LocalLlmStatus.idle => (Colors.white30, Icons.circle_outlined, 'Offline'),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                'NDK Direct Mode  ·  fllama',
                style: GoogleFonts.outfit(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_state.status == LocalLlmStatus.ready &&
              _state.activeModelId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Model: ${_state.activeModelId}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          if (_state.status == LocalLlmStatus.downloading ||
              _state.status == LocalLlmStatus.installing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _state.downloadProgress,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            if (_state.errorMessage != null)
              Text(
                _state.errorMessage!,
                style: TextStyle(color: color, fontSize: 11),
                textAlign: TextAlign.center,
              )
            else
              Text(
                '${(_state.downloadProgress * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontSize: 11),
              ),
          ],
          if (_state.status == LocalLlmStatus.error &&
              _state.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _state.errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _service.stop();
              }),
              icon: const Icon(Icons.refresh, size: 14, color: Colors.white54),
              label: const Text('Reset',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThreadSlider() {
    final int threads = _state.threads;
    final bool isInferring = _service.isInferring;
    final bool aboveCoreCount = threads > _cpuCoreCount;
    final int sliderMax = _cpuCoreCount;
    // Clamp display value to slider max to avoid assertion error
    final double sliderValue =
        threads.toDouble().clamp(1.0, sliderMax.toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CPU Threads',
              style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                if (isInferring)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.lock_outline,
                        color: Colors.white38, size: 13),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: aboveCoreCount
                        ? Colors.amber.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: aboveCoreCount
                        ? Border.all(color: Colors.amber.withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Text(
                    '$threads / $_cpuCoreCount cores',
                    style: TextStyle(
                      color: aboveCoreCount ? Colors.amber : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Slider — disabled during inference
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: isInferring
                ? Colors.white24
                : (aboveCoreCount ? Colors.amber : AppColors.statusGreen),
            inactiveTrackColor: Colors.white12,
            thumbColor: isInferring
                ? Colors.white24
                : (aboveCoreCount ? Colors.amber : AppColors.statusGreen),
            overlayColor: isInferring
                ? Colors.transparent
                : AppColors.statusGreen.withValues(alpha: 0.15),
            disabledActiveTrackColor: Colors.white24,
            disabledThumbColor: Colors.white24,
          ),
          child: Slider(
            min: 1,
            max: sliderMax.toDouble(),
            divisions: sliderMax - 1,
            value: sliderValue,
            onChanged: isInferring
                ? null
                : (v) {
                    final newThreads = v.toInt();
                    _service.setThreads(newThreads,
                        currentModel: _selectedModel);
                  },
          ),
        ),
        // Inference lock notice
        if (isInferring)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Slider locked — model is generating. Changes take effect after the current response.',
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
        // Above-core-count warning
        if (aboveCoreCount && !isInferring)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Thread count exceeds detected core count ($_cpuCoreCount). '
                    'This can slow inference — the OS must context-switch across fewer real cores.',
                    style: const TextStyle(color: Colors.amber, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        // Guidance text — split by inference path
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt, color: Colors.white30, size: 11),
                const SizedBox(width: 3),
                const Expanded(
                  child: Text(
                    'fllama: Takes effect immediately on the next message.',
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.speed_rounded, color: Colors.white30, size: 11),
                SizedBox(width: 3),
                Expanded(
                  child: Text(
                    'Recommended default: 2-4 threads. More threads can slow the UI, Gateway health checks, and pairing on average phones.',
                    style: TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ),
              ],
            ),
            if (threads == 1)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  'Tip: 1 thread focuses on the highest-frequency performance core — fastest on many phones.',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        color: AppColors.statusGreen.withValues(alpha: 0.8),
      ),
    );
  }

  Widget _buildModelCard(LocalLlmModel model) {
    final isDownloaded = _downloadedModels[model.id] ?? false;
    final isSelected = _selectedModel?.id == model.id;
    final isActive = _state.activeModelId == model.id;
    final isDownloading = _state.status == LocalLlmStatus.downloading &&
        isSelected &&
        !isDownloaded;

    final qualityColor = switch (model.quality) {
      'Minimum' => Colors.amber,
      'Recommended' => AppColors.statusGreen,
      'Optimal' => Colors.purpleAccent,
      _ => Colors.white54,
    };

    return GestureDetector(
      onTap: () => setState(() => _selectedModel = model),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? AppColors.statusGreen.withValues(alpha: 0.5)
                : isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.name,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isActive) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.statusGreen.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.statusGreen)),
                        const SizedBox(width: 4),
                        Text('RUNNING',
                            style: TextStyle(
                                color: AppColors.statusGreen,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      model.quality,
                      style: TextStyle(
                          color: qualityColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              model.description,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _specChip('${model.fileSizeMb} MB download'),
                const SizedBox(width: 6),
                _specChip(
                    '${(model.requiredRamMb / 1024).toStringAsFixed(1)} GB RAM'),
                const SizedBox(width: 6),
                _specChip('${model.contextWindow ~/ 1024}K ctx'),
                const Spacer(),
                if (isDownloading)
                  SizedBox(
                    width: 80,
                    child: LinearProgressIndicator(
                      value: _state.downloadProgress,
                      backgroundColor: Colors.white10,
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.blueAccent),
                      minHeight: 4,
                    ),
                  )
                else
                  _buildActionButton(model, isDownloaded, isActive),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _specChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white38, fontSize: 9)),
    );
  }

  Widget _buildActionButton(
      LocalLlmModel model, bool isDownloaded, bool isActive) {
    final anotherModelRunning = _state.activeModelId != null && !isActive;
    final isStartingThis = _state.status == LocalLlmStatus.starting &&
        _selectedModel?.id == model.id;

    // Active model → Stop
    if (isActive) {
      return TextButton.icon(
        onPressed: _service.stop,
        icon: const Icon(Icons.stop_rounded, size: 14, color: Colors.redAccent),
        label: const Text('Stop',
            style: TextStyle(color: Colors.redAccent, fontSize: 11)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // Starting spinner
    if (isStartingThis) {
      return TextButton.icon(
        onPressed: null,
        icon: const SizedBox(
            width: 14,
            height: 14,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
        label: const Text('Starting...',
            style: TextStyle(color: Colors.amber, fontSize: 11)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: Colors.amber.withValues(alpha: 0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // Downloaded → Start or Switch
    if (isDownloaded) {
      final isSwitch = anotherModelRunning;
      return TextButton.icon(
        onPressed: _state.status == LocalLlmStatus.starting
            ? null
            : () {
                setState(() => _selectedModel = model);
                _service.startWithModel(model);
              },
        icon: Icon(
            isSwitch ? Icons.swap_horiz_rounded : Icons.play_arrow_rounded,
            size: 14,
            color: isSwitch ? Colors.amber : AppColors.statusGreen),
        label: Text(
          isSwitch ? 'Switch' : 'Start',
          style: TextStyle(
              color: isSwitch ? Colors.amber : AppColors.statusGreen,
              fontSize: 11),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: (isSwitch ? Colors.amber : AppColors.statusGreen)
              .withValues(alpha: 0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // Not downloaded → Download
    return TextButton.icon(
      onPressed: _state.status == LocalLlmStatus.idle ||
              _state.status == LocalLlmStatus.error
          ? () {
              setState(() => _selectedModel = model);
              _service.downloadAndStart(model);
            }
          : null,
      icon: const Icon(Icons.cloud_download_rounded,
          size: 14, color: Colors.blueAccent),
      label: const Text('Download',
          style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDeviceSpecCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Text(
                'Device Requirements',
                style: GoogleFonts.outfit(
                    color: Colors.amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _specRow('Minimum', '8 GB RAM · Snapdragon 8 Gen 1 · ~4–8 tok/s'),
          _specRow('Recommended', '12 GB RAM · 8 Gen 2 · ~10–18 tok/s'),
          _specRow('Optimal', '16 GB RAM · 8 Gen 3 / Elite · ~20–30 tok/s'),
          const SizedBox(height: 8),
          const Text(
            'Inference uses CPU only — GPU acceleration inside PRoot is not stable. '
            'Expect 30–50% battery drain during active inference. '
            'Models are stored inside the PRoot filesystem and survive app updates.',
            style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.5),
          ),
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'About VRAM vs RAM on phones',
              style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            iconColor: Colors.amber,
            collapsedIconColor: Colors.white38,
            children: const [
              Text(
                'Android phones have NO discrete VRAM. '
                'The Adreno (Qualcomm), Mali, and Immortalis GPUs all share the same LPDDR5X '
                'system RAM pool with the CPU — there is no separate GPU memory.\n\n'
                'Desktop model cards that list "8 GB VRAM" refer to high-bandwidth GDDR6 VRAM '
                'on a discrete GPU. On mobile, the same model uses system RAM instead, '
                'which is slower — that\'s why 7B models run at 4–8 tok/s here vs 50+ tok/s '
                'on a desktop GPU.\n\n'
                'The "Required RAM" figures in each model card below already account for this: '
                'they are the total system RAM (model weights + KV cache + Android OS overhead) '
                'needed for stable inference on CPU. No VRAM is needed or used.',
                style:
                    TextStyle(color: Colors.white54, fontSize: 10, height: 1.6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specRow(String tier, String spec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(tier,
                style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(spec,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildModelInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.blueAccent, size: 15),
            const SizedBox(width: 8),
            Text('How to use local models',
                style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          _instructionStep('1  Download',
              'Tap Download on the model card above to save it to your device (~1–2 GB).'),
          const SizedBox(height: 6),
          _instructionStep('2  Direct Mode',
              'Tap Start to load via the on-device NDK (fllama). This provides a high-speed, direct LLM experience with 100% offline Voice — bypassing the gateway for maximum privacy.'),
          const SizedBox(height: 6),
          _instructionStep('3  Cloud Agent',
              'For full tools, skills, web dashboard, and multi-step planning: use a Gateway cloud model in Chat with your provider API key. Keep local NDK for private/offline turns.'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.bolt_rounded,
                  color: Colors.blueAccent, size: 13),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NDK Direct = Pure offline Voice & high-speed LLM. Not connected to the OpenClaw Gateway. Optimized for direct performance.',
                  style: const TextStyle(
                      color: Colors.blueAccent, fontSize: 10, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _instructionStep(String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildAgentPromptGuide() {
    const info =
        'NDK Direct Mode provides a "Sovereign AI" experience. Unlike the Gateway, '
        'fllama (llama.cpp NDK) interacts directly with your device processor for '
        'maximum speed and privacy. It features built-in offline Voice and '
        'supports essential tools without needing the OpenClaw Gateway or '
        'multi-step agentic loops. This is a pure, direct LLM implementation.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.offline_bolt_outlined,
                  color: Colors.blueAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                'NDK Direct — Direct LLM Experience',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            info,
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 10,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('OFFLINE MODE'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.statusGreen.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.memory_rounded,
                        color: AppColors.statusGreen, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NDK Direct is the local runtime',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'No cloud daemon, no 1.30 GB runtime, no hidden proxy.',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'PRIVATE',
                      style: TextStyle(
                        color: AppColors.statusGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Cloud Agent Mode uses the OpenClaw Gateway with your chosen provider key. Private Offline Mode uses fllama directly inside the app. These paths are deliberately separate so local inference cannot overload gateway pairing or background stability.',
                style: TextStyle(
                    color: Colors.white60, fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded,
                        color: AppColors.statusGreen, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Use Local NDK for Chat Routing',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: _localChatModeEnabled,
                      onChanged: _setLocalChatMode,
                      activeThumbColor: AppColors.statusGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildModelActionRow(
                icon: Icons.cloud_done_rounded,
                title: 'Need tools, skills, or dashboard?',
                subtitle:
                    'Use Chat -> model picker with Gemini, Claude, OpenAI, Grok, OpenRouter, or Groq.',
                trailing: const Icon(Icons.verified_user_rounded,
                    color: Colors.blueAccent, size: 18),
              ),
              const SizedBox(height: 8),
              _buildModelActionRow(
                icon: Icons.phone_android_rounded,
                title: 'Need private/offline chat?',
                subtitle:
                    'Download a GGUF above, enable "Use Local NDK for Chat Routing", then pick local-llm in Chat.',
                trailing: const Icon(Icons.lock_rounded,
                    color: AppColors.statusGreen, size: 18),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _bridgeState.isRunning
                              ? Icons.lan_rounded
                              : Icons.science_rounded,
                          color: _bridgeState.isRunning
                              ? AppColors.statusGreen
                              : Colors.blueAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gateway Bridge Experiment',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _bridgeState.status.name.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            color: _bridgeState.isRunning
                                ? AppColors.statusGreen
                                : Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'OpenAI-compatible local endpoint: ${_bridgeState.url}. Use only for testing Gateway -> NDK routing after a model is active.',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                    if (_bridgeState.errorMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _bridgeState.errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _toggleBridge,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _bridgeState.isRunning
                                  ? Colors.redAccent
                                  : Colors.blueAccent,
                              side: BorderSide(
                                color: (_bridgeState.isRunning
                                        ? Colors.redAccent
                                        : Colors.blueAccent)
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              _bridgeState.isRunning
                                  ? 'Stop Bridge'
                                  : 'Start Bridge',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isConfiguringBridge
                                ? null
                                : _configureGatewayBridge,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.blueAccent.withValues(alpha: 0.18),
                              foregroundColor: Colors.blueAccent,
                            ),
                            child: _isConfiguringBridge
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blueAccent,
                                    ),
                                  )
                                : const Text('Use In Gateway'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.query_stats_rounded,
                  color: AppColors.statusGreen, size: 18),
              const SizedBox(width: 10),
              Text(
                'Test Inference',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_isTesting)
                Text(
                  '${_tokensPerSec.toStringAsFixed(1)} tok/s',
                  style: GoogleFonts.jetBrainsMono(
                    color: AppColors.statusGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Endpoint: http://127.0.0.1:8081',
                style: GoogleFonts.jetBrainsMono(
                    color: Colors.white24, fontSize: 9),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isCheckingHealth ? null : _checkHealth,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isCheckingHealth
                      ? const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white38))
                      : Text('Engine Status',
                          style: GoogleFonts.jetBrainsMono(
                              color: Colors.white38, fontSize: 9)),
                ),
              ),
            ],
          ),
          if (_healthStatus.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _healthStatus,
              style: GoogleFonts.jetBrainsMono(
                color: _healthStatus.contains('healthy')
                    ? AppColors.statusGreen
                    : Colors.redAccent,
                fontSize: 9,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _testPromptController,
            maxLines: 3,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter test prompt...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isTesting ? null : _runTestInference,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen.withValues(alpha: 0.1),
              foregroundColor: AppColors.statusGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 45),
            ),
            child: _isTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.statusGreen))
                : const Text('Execute Test',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ValueListenableBuilder<String>(
            valueListenable: _testResponseNotifier,
            builder: (context, response, _) {
              if (response.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      response,
                      style: GoogleFonts.outfit(
                          color: Colors.white70, fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkHealth() async {
    setState(() {
      _isCheckingHealth = true;
      _healthStatus = '';
    });
    final bool healthy = _service.state.status == LocalLlmStatus.ready;
    if (mounted) {
      setState(() {
        _isCheckingHealth = false;
        _healthStatus = healthy ? 'Engine is healthy' : 'Engine is offline';
      });
    }
  }

  Future<void> _runTestInference() async {
    _ndkTestSub?.cancel();
    _testResponseNotifier.value = '';
    setState(() {
      _isTesting = true;
      _tokensPerSec = 0;
      _tokenCount = 0;
      _testStartTime = DateTime.now();
    });

    _ndkTestSub = _service.testInference(_testPromptController.text).listen(
      (token) {
        _testResponseNotifier.value += token;
        _tokenCount++;
        final duration =
            DateTime.now().difference(_testStartTime!).inMilliseconds / 1000;
        if (duration > 0 && mounted) {
          setState(() => _tokensPerSec = _tokenCount / duration);
        }
      },
      onDone: () {
        if (mounted) setState(() => _isTesting = false);
      },
      onError: (e) {
        _testResponseNotifier.value = 'Error: $e';
        if (mounted) setState(() => _isTesting = false);
      },
      cancelOnError: true,
    );
  }

  Widget _buildModelActionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: Colors.white30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white30, fontSize: 10)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
