import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/optional_package.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../services/openclaw_service.dart';

class PackageInstallScreen extends StatefulWidget {
  final OptionalPackage package;
  final bool isUninstall;

  const PackageInstallScreen({
    super.key,
    required this.package,
    this.isUninstall = false,
  });

  @override
  State<PackageInstallScreen> createState() => _PackageInstallScreenState();
}

class _PackageInstallScreenState extends State<PackageInstallScreen> {
  Process? _process;
  bool _loading = true;
  bool _finished = false;
  String? _error;

  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

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

      // Adapt command based on OpenClaw version
      final adaptedCommand = await OpenClawCommandService.adaptSkillCommand(
        widget.isUninstall ? widget.package.uninstallCommand : widget.package.installCommand
      );

      final cmdArgs = List<String>.from(args);
      cmdArgs.removeLast(); 
      cmdArgs.removeLast(); 
      cmdArgs.addAll(['/bin/bash', '-lc', adaptedCommand]);

      _process = await Process.start(
        config['executable']!,
        cmdArgs,
        environment: TerminalService.buildHostEnv(config),
      );

      final sentinel = widget.isUninstall
          ? widget.package.uninstallSentinel
          : widget.package.completionSentinel;

      _process!.stdout.transform(utf8.decoder).listen((data) {
        _handleOutput(data, sentinel);
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        _handleOutput(data, sentinel);
      });

      _process!.exitCode.then((code) {
        _handleOutput('\n[Process exited with code $code]\n', sentinel);
        if (mounted && !_finished) {
          setState(() => _finished = true);
        }
      });

      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to start: $e';
        });
      }
    }
  }

  void _handleOutput(String data, String sentinel) {
    if (!mounted) return;
    
    final newLines = data.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (newLines.isEmpty) return;

    setState(() {
      _logs.addAll(newLines);
      if (_logs.length > 2000) {
        _logs.removeRange(0, _logs.length - 2000);
      }
    });

    if (!_finished && data.contains(sentinel)) {
      setState(() => _finished = true);
    }

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

  @override
  void dispose() {
    _process?.kill();
    _scrollController.dispose();
    NativeBridge.stopTerminalService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.isUninstall ? 'Uninstall' : 'Install';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('$action ${widget.package.name}'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          if (_loading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Starting task...'),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Expanded(
               child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text('Error: $_error', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                            _finished = false;
                            _logs.clear();
                          });
                          _startProcess();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else 
            Expanded(
               child: Container(
                 color: Colors.black,
                 child: ListView.builder(
                   controller: _scrollController,
                   padding: const EdgeInsets.all(12),
                   itemCount: _logs.length,
                   itemBuilder: (context, index) {
                     return Padding(
                       padding: const EdgeInsets.only(bottom: 2),
                       child: SelectableText(
                         _logs[index],
                         style: const TextStyle(
                           fontFamily: 'monospace',
                           color: Colors.white70,
                           fontSize: 12,
                           height: 1.3,
                         ),
                       ),
                     );
                   },
                 ),
               ),
            ),
          
          if (_finished)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
