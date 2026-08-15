import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/native_bridge.dart';
import 'setup_wizard_screen.dart';
import '../widgets/glass_card.dart';
import '../app.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});
  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _historyFocusNode = FocusNode();
  final List<OutputLine> _output = [];
  bool _isRunning = false;
  bool? _rollbackReady;
  String? _rollbackStatusError;
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _addOutput(
      'Plawie rollback terminal.\n'
      'Checking the optional PRoot environment...\n',
      isSystem: true,
    );
    unawaited(_refreshRollbackStatus());
  }

  Future<void> _refreshRollbackStatus() async {
    try {
      final status = await NativeBridge.getBootstrapStatus();
      if (!mounted) return;
      final ready = status['binBashExists'] == true;
      setState(() {
        _rollbackReady = ready;
        _rollbackStatusError = null;
      });
      _addOutput(
        ready
            ? 'PRoot rollback is installed. It starts only when you run a command.\n'
            : 'PRoot rollback is not installed. Native Gateway remains active; open rollback setup only if you want this shell.\n',
        isSystem: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _rollbackReady = false;
        _rollbackStatusError = error.toString();
      });
      _addOutput('Could not verify rollback status: $error', isError: true);
    }
  }

  Future<void> _openRollbackSetup() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
    );
    if (mounted) await _refreshRollbackStatus();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _historyFocusNode.dispose();
    super.dispose();
  }

  void _addOutput(String text, {bool isError = false, bool isSystem = false}) {
    setState(() {
      _output.add(OutputLine(
        text: text,
        isError: isError,
        isSystem: isSystem,
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateHistory(int offset) {
    if (_history.isEmpty) return;

    final newIndex = _historyIndex + offset;
    if (newIndex >= -1 && newIndex < _history.length) {
      setState(() {
        _historyIndex = newIndex;
        if (_historyIndex == -1) {
          _inputController.clear();
        } else {
          _inputController.text = _history[_historyIndex];
          // Move cursor to end
          _inputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _inputController.text.length),
          );
        }
      });
    }
  }

  Future<void> _runCommand() async {
    if (_rollbackReady != true) {
      await _openRollbackSetup();
      return;
    }
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty || _isRunning) return;

    _addOutput('> $cmd\n', isSystem: true);
    _history.insert(0, cmd);
    _historyIndex = -1;
    _inputController.clear();
    setState(() => _isRunning = true);

    try {
      final result = await NativeBridge.runInProot(
        cmd,
        timeout: 120,
      );
      if (!mounted) return;
      _addOutput(
        result.trim().isEmpty ? '(command completed)\n' : result,
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      _addOutput('ERROR: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
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
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      if (_rollbackReady != true) _buildRollbackReadinessCard(),
                      Expanded(
                        child: GlassCard(
                          blurStrength: 30,
                          innerTint: Colors.black.withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _output.length,
                              itemBuilder: (context, index) {
                                final line = _output[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    line.text,
                                    style: GoogleFonts.jetBrainsMono(
                                      color: line.isError
                                          ? Colors.redAccent
                                          : line.isSystem
                                              ? AppColors.statusGreen
                                                  .withValues(alpha: 0.8)
                                              : Colors.white
                                                  .withValues(alpha: 0.9),
                                      fontSize: 12,
                                      height: 1.2,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      if (_isRunning) const LinearProgressIndicator(),

                      // Input bar
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: KeyboardListener(
                                focusNode: _historyFocusNode,
                                onKeyEvent: (event) {
                                  if (event is KeyDownEvent) {
                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.arrowUp) {
                                      _navigateHistory(1);
                                    } else if (event.logicalKey ==
                                        LogicalKeyboardKey.arrowDown) {
                                      _navigateHistory(-1);
                                    }
                                  }
                                },
                                child: TextField(
                                  controller: _inputController,
                                  enabled:
                                      _rollbackReady == true && !_isRunning,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _rollbackReady == null
                                        ? 'Checking rollback shell...'
                                        : _rollbackReady == true
                                            ? 'Enter command...'
                                            : 'Rollback shell not installed',
                                    hintStyle: GoogleFonts.jetBrainsMono(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    prefixIcon: Icon(Icons.chevron_right,
                                        color: AppColors.statusGreen),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  onSubmitted: (_) => _runCommand(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _navigateHistory(1),
                                  child: Icon(Icons.keyboard_arrow_up,
                                      size: 20,
                                      color:
                                          Colors.white.withValues(alpha: 0.5)),
                                ),
                                GestureDetector(
                                  onTap: () => _navigateHistory(-1),
                                  child: Icon(Icons.keyboard_arrow_down,
                                      size: 20,
                                      color:
                                          Colors.white.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.statusGreen
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.statusGreen
                                        .withValues(alpha: 0.3)),
                              ),
                              child: IconButton(
                                onPressed: _rollbackReady == true && !_isRunning
                                    ? _runCommand
                                    : null,
                                icon: Icon(Icons.send_rounded,
                                    color: AppColors.statusGreen),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildRollbackReadinessCard() {
    final checking = _rollbackReady == null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (checking)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.shield_outlined, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checking
                      ? 'Checking rollback shell'
                      : 'Optional rollback shell not installed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  checking
                      ? 'Verifying the local fallback without starting it.'
                      : _rollbackStatusError ??
                          'Plawie remains native-first. Install the separate Ubuntu PRoot environment only if you want this manual fallback terminal.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.3,
                  ),
                ),
                if (!checking) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _openRollbackSetup,
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Open rollback setup'),
                      ),
                      TextButton(
                        onPressed: _refreshRollbackStatus,
                        child: const Text('Check again'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: AppLayout.standardSliverHeaderHeight,
      floating: false,
      pinned: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/app_icon_official.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Text(
            'TERMINAL',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 3.0,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.copy), onPressed: _copyAllOutput),
        IconButton(icon: const Icon(Icons.clear_all), onPressed: _clearOutput),
      ],
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: FlexibleSpaceBar(
            background: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
      ),
    );
  }

  void _copyAllOutput() {
    final allText = _output.map((e) => e.text).join('\n');
    Clipboard.setData(ClipboardData(text: allText));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('✅ Copied all output')));
  }

  void _clearOutput() {
    setState(() => _output.clear());
  }
}

class OutputLine {
  final String text;
  final bool isError;
  final bool isSystem;
  OutputLine({required this.text, this.isError = false, this.isSystem = false});
}
