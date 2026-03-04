import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  Process? _process;
  bool _loading = true;
  String? _error;
  
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    NativeBridge.startTerminalService();
    _startProcess();
  }

  Future<void> _startProcess() async {
    try {
      final config = await TerminalService.getProotShellConfig();
      final args = TerminalService.buildProotArgs(
        config,
        columns: 120,
        rows: 40,
      );

      _process = await Process.start(
        config['executable']!,
        args,
        environment: TerminalService.buildHostEnv(config),
      );

      _process!.stdout.transform(utf8.decoder).listen((data) {
        _handleOutput(data);
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        _handleOutput(data, isError: true);
      });

      _process!.exitCode.then((code) {
        _handleOutput('\n[Process exited with code $code]\n');
      });

      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to start terminal: $e';
        });
      }
    }
  }

  void _handleOutput(String data, {bool isError = false}) {
    if (!mounted) return;
    
    // Split incoming blob into lines, skipping empty ones
    final newLines = data.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (newLines.isEmpty) return;

    setState(() {
      _logs.addAll(newLines);
      if (_logs.length > 5000) {
        _logs.removeRange(0, _logs.length - 5000);
      }
    });

    // Auto-scroll to bottom
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

  void _sendCommand() {
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty || _process == null) return;

    // Echo command to the UI
    setState(() => _logs.add('\$ $cmd'));
    
    // Send to process stdin
    _process!.stdin.writeln(cmd);
    
    _inputController.clear();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _process?.kill();
    _scrollController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    NativeBridge.stopTerminalService();
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
            tooltip: 'Restart',
            onPressed: () {
              _process?.kill();
              setState(() {
                _logs.clear();
                _loading = true;
                _error = null;
              });
              _startProcess();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting shell...'),
          ],
        ),
      );
    }

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
                    _loading = true;
                    _error = null;
                  });
                  _startProcess();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
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
