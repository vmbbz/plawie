import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/native_bridge.dart';
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
  final List<OutputLine> _output = [];
  bool _isRunning = false;
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _addOutput('🚀 Plawie Stable Terminal ready.\nType openclaw commands below.\n', isSystem: true);
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
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty || _isRunning) return;

    _addOutput('> $cmd\n', isSystem: true);
    _history.insert(0, cmd);
    _historyIndex = -1;
    _inputController.clear();
    setState(() => _isRunning = true);

    try {
      final result = await NativeBridge.runInProot(cmd, timeout: 120);
      _addOutput(result, isError: false);
    } catch (e) {
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
                                               ? AppColors.statusGreen.withValues(alpha: 0.8)
                                               : Colors.white.withValues(alpha: 0.9),
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
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                onKey: (event) {
                                  if (event is RawKeyDownEvent) {
                                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                      _navigateHistory(1);
                                    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                      _navigateHistory(-1);
                                    }
                                  }
                                },
                                child: TextField(
                                  controller: _inputController,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter command...',
                                    hintStyle: GoogleFonts.jetBrainsMono(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      fontSize: 13,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    prefixIcon: Icon(Icons.chevron_right, color: AppColors.statusGreen),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  child: Icon(Icons.keyboard_arrow_up, size: 20, color: Colors.white.withValues(alpha: 0.5)),
                                ),
                                GestureDetector(
                                  onTap: () => _navigateHistory(-1),
                                  child: Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.white.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.statusGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.statusGreen.withValues(alpha: 0.3)),
                              ),
                              child: IconButton(
                                onPressed: _isRunning ? null : _runCommand,
                                icon: Icon(Icons.send_rounded, color: AppColors.statusGreen),
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

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Copied all output')));
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
