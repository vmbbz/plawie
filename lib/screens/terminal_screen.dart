import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/native_bridge.dart';
import '../services/diagnostic_service.dart';

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

  Future<void> _runCommand() async {
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty || _isRunning) return;

    _addOutput('> $cmd\n', isSystem: true);
    _history.insert(0, cmd);
    _historyIndex = -1;
    _inputController.clear();
    setState(() => _isRunning = true);

    try {
      // Using runInProot for maximum stability on Android without PTY state issues.
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
      appBar: AppBar(
        title: const Text('Stable Terminal'),
        actions: [
          IconButton(icon: const Icon(Icons.copy), onPressed: _copyAllOutput),
          IconButton(icon: const Icon(Icons.clear_all), onPressed: _clearOutput),
        ],
      ),
      body: Column(
        children: [
          // Output area
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _output.length,
                itemBuilder: (context, index) {
                  final line = _output[index];
                  return Text(
                    line.text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: line.isError
                          ? Colors.redAccent
                          : line.isSystem
                               ? Colors.cyanAccent
                               : Colors.white,
                      fontSize: 13,
                    ),
                  );
                },
              ),
            ),
          ),

          if (_isRunning) const LinearProgressIndicator(),

          // Input bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'openclaw devices approve ...',
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _runCommand(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isRunning ? null : _runCommand,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
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
