import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/optional_package.dart';
import '../services/native_bridge.dart';
import '../services/terminal_service.dart';
import '../services/openclaw_service.dart';
import '../widgets/glass_card.dart';

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
    if (!widget.package.canInstallFromPackagesPage) {
      _loading = false;
      _error =
          '${widget.package.name} is managed from Bot Management > Skills, not installed as a Linux package.';
      return;
    }
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
          widget.isUninstall
              ? widget.package.uninstallCommand
              : widget.package.installCommand);

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

    final newLines =
        data.split('\n').where((line) => line.trim().isNotEmpty).toList();
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          NebulaBg(),
          CustomScrollView(
            slivers: [
              _buildAppBar(context, action),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPitchHeader(context, action),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                child: Column(
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
                                Icon(Icons.error_outline,
                                    size: 48, color: theme.colorScheme.error),
                                const SizedBox(height: 16),
                                Text('Error: $_error',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: theme.colorScheme.error)),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String action) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
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
            '${action.toUpperCase()} PACKAGE',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 3.0,
              color: Colors.white,
            ),
          ),
        ],
      ),
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

  Widget _buildPitchHeader(BuildContext context, String action) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$action\n${widget.package.name}',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.package.description,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.package.releaseNote,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.45),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
