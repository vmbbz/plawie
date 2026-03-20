import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app.dart';
import '../../../services/local_llm_service.dart';

class LocalLlmScreen extends StatefulWidget {
  const LocalLlmScreen({super.key});

  @override
  State<LocalLlmScreen> createState() => _LocalLlmScreenState();
}

class _LocalLlmScreenState extends State<LocalLlmScreen> {
  final _service = LocalLlmService();
  LocalLlmState _state = const LocalLlmState();
  LocalLlmModel? _selectedModel;
  final Map<String, bool> _downloadedModels = {};

  @override
  void initState() {
    super.initState();
    _state = _service.state;
    _service.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _checkDownloadedModels();
    // Default selection to the recommended model
    _selectedModel = _service.catalog.firstWhere(
      (m) => m.quality == 'Recommended',
      orElse: () => _service.catalog.first,
    );
  }

  Future<void> _checkDownloadedModels() async {
    for (final m in _service.catalog) {
      final downloaded = await _service.isModelDownloaded(m);
      if (mounted) {
        setState(() => _downloadedModels[m.id] = downloaded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(
        children: [
          // Ambient glow patches — unified dark space aesthetic
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusCard(),
                      const SizedBox(height: 20),
                      _buildToggleRow(),
                      const SizedBox(height: 20),
                      _buildThreadSlider(),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Model Library'),
                      const SizedBox(height: 12),
                      ..._service.catalog.map(_buildModelCard),
                      const SizedBox(height: 28),
                      _buildDeviceSpecCard(),
                      const SizedBox(height: 28),
                      _buildAgentPromptGuide(),
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
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
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
      LocalLlmStatus.ready => (AppColors.statusGreen, Icons.check_circle_rounded, 'Running'),
      LocalLlmStatus.starting => (Colors.amber, Icons.hourglass_top_rounded, 'Starting...'),
      LocalLlmStatus.downloading => (Colors.blueAccent, Icons.cloud_download_rounded, 'Downloading'),
      LocalLlmStatus.installing => (Colors.purpleAccent, Icons.terminal_rounded, 'Compiling (10-25 min)'),
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
                'llama-server · port 8081',
                style: GoogleFonts.outfit(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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
              label: const Text('Reset', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleRow() {
    final isRunning = _state.status == LocalLlmStatus.ready;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Route to local model',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isRunning
                    ? 'openclaw.json patched — agent uses local provider'
                    : 'Start a model first to enable',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        Switch(
          value: _state.isEnabled,
          onChanged: isRunning
              ? (v) async {
                  await _service.setEnabled(
                    v,
                    modelId: _state.activeModelId,
                  );
                }
              : null,
          activeThumbColor: AppColors.statusGreen,
        ),
      ],
    );
  }

  Widget _buildThreadSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CPU Threads',
              style: GoogleFonts.outfit(
                  color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_state.threads}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.statusGreen,
            inactiveTrackColor: Colors.white12,
            thumbColor: AppColors.statusGreen,
            overlayColor: AppColors.statusGreen.withValues(alpha: 0.15),
          ),
          child: Slider(
            min: 1,
            max: 8,
            divisions: 7,
            value: _state.threads.toDouble(),
            onChanged: (v) => _service.setThreads(
              v.toInt(),
              currentModel: _selectedModel,
            ),
          ),
        ),
        const Text(
          'Higher threads = faster tokens but more heat. 4 is optimal for most phones.',
          style: TextStyle(color: Colors.white30, fontSize: 10),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                if (isActive) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.statusGreen, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              model.description,
              style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _specChip('${model.fileSizeMb} MB download'),
                const SizedBox(width: 6),
                _specChip('${(model.requiredRamMb / 1024).toStringAsFixed(1)} GB RAM'),
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
      child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
    );
  }

  Widget _buildActionButton(LocalLlmModel model, bool isDownloaded, bool isActive) {
    if (isActive) {
      return TextButton.icon(
        onPressed: _service.stop,
        icon: const Icon(Icons.stop_rounded, size: 14, color: Colors.redAccent),
        label: const Text('Stop', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    if (isDownloaded) {
      return TextButton.icon(
        onPressed: _state.status == LocalLlmStatus.starting
            ? null
            : () => _service.startWithModel(model),
        icon: const Icon(Icons.play_arrow_rounded, size: 14, color: AppColors.statusGreen),
        label: const Text('Start', style: TextStyle(color: AppColors.statusGreen, fontSize: 11)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          backgroundColor: AppColors.statusGreen.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return TextButton.icon(
      onPressed: _state.status == LocalLlmStatus.idle ||
              _state.status == LocalLlmStatus.error
          ? () {
              setState(() => _selectedModel = model);
              _service.downloadAndStart(model);
            }
          : null,
      icon: const Icon(Icons.cloud_download_rounded, size: 14, color: Colors.blueAccent),
      label: const Text('Download', style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
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
              const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Text(
                'Device Requirements',
                style: GoogleFonts.outfit(
                    color: Colors.amber, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _specRow('Minimum', '8 GB RAM · Snapdragon 8 Gen 1 · ~4–8 tok/s'),
          _specRow('Recommended', '12 GB RAM · 8 Gen 2 · ~10–18 tok/s'),
          _specRow('Optimal', '16 GB RAM · 8 Gen 3 / Elite · ~20–30 tok/s'),
          const SizedBox(height: 8),
          const Text(
            'Inference uses CPU only (GPU acceleration inside PRoot is not stable). '
            'Expect 30–50% battery drain during active inference. '
            'Models are stored inside the PRoot filesystem and survive app updates.',
            style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.5),
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
                    color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(spec,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentPromptGuide() {
    const prompt = '''When using the local LLM skill (llama-server · 127.0.0.1:8081):

- You are running as Qwen2.5-Instruct via llama-server on-device.
- Your context window may be limited (8K–32K tokens). Keep system prompts concise.
- For tool use, strictly output valid JSON inside <tool_call> tags.
- If a tool call fails, retry once with simplified parameters before reporting the error.
- Warn the user if a task requires more reasoning than a 1.5B model can reliably provide.
- Always prefer small, focused tool calls over large multi-step ones to stay within context.''';

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
              const Icon(Icons.smart_toy_outlined, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(
                'Agent System Prompt Snippet',
                style: GoogleFonts.outfit(
                    color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            prompt,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white54,
              fontSize: 10,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
