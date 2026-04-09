import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/native_bridge.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  bool _loading = false;
  String? _error;
  
  final List<String> _logs = [
    'Welcome to OpenClaw Terminal.',
    'Type a command to execute natively via PRoot.'
  ];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    NativeBridge.startTerminalService();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendCommand() async {
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty) return;

    setState(() => _logs.add('\n\$ $cmd'));
    _inputController.clear();
    _focusNode.requestFocus();
    _scrollToBottom();

    setState(() => _loading = true);

    try {
      // executeInShell reuses one persistent PRoot/bash process instead of
      // spawning a new PRoot per command — prevents OOM crashes on mobile.
      // NODE_OPTIONS is pre-set in the persistent shell environment.
      final result = await NativeBridge.executeInShell(cmd, timeoutMs: 60000);

      if (!mounted) return;

      setState(() {
        _logs.addAll(result.split('\n').where((l) => l.trim().isNotEmpty));
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logs.add('Error: $e');
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    NativeBridge.stopTerminalService();
    NativeBridge.destroyShell();
    super.dispose();
  }

  void _copyAll() {
    final text = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied terminal output')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Output',
            onPressed: _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Clear',
            onPressed: () {
              setState(() {
                _logs.clear();
                _logs.add('Terminal cleared.');
                _error = null;
              });
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = false;
                    _error = null;
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Log Output List
        Expanded(
          child: Container(
            color: Colors.black,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final line = _logs[index];
                
                // Extremely basic parsing for UI distinction
                Color textColor = Colors.white70;
                if (line.startsWith('\$ ')) {
                  textColor = theme.colorScheme.primary;
                } else if (line.toLowerCase().contains('error') || line.toLowerCase().contains('fail')) {
                  textColor = Colors.redAccent;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SelectableText(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: textColor,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        if (_loading) const LinearProgressIndicator(),
        
        // Command Input Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Enter command...',
                      hintStyle: const TextStyle(fontFamily: 'monospace'),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: _sendCommand,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
