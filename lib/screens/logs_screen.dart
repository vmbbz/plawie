import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart';
import '../widgets/glass_card.dart';
import '../providers/gateway_provider.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _autoScroll = true;
  String _filter = '';

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Filter logs...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            suffixIcon: _filter.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _filter = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) => setState(() => _filter = value),
                        ),
                      ),
                      Expanded(
                        child: Consumer<GatewayProvider>(
                          builder: (context, provider, _) {
                            final logs = provider.state.logs;
                            final filtered = _filter.isEmpty
                                ? logs
                                : logs
                                    .where((l) => l
                                        .toLowerCase()
                                        .contains(_filter.toLowerCase()))
                                    .toList();

                            if (filtered.isEmpty) {
                              return Center(
                                child: Text(
                                  logs.isEmpty
                                      ? 'No logs yet. Start the gateway.'
                                      : 'No matching logs.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            }

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_autoScroll && _scrollController.hasClients) {
                                _scrollController.jumpTo(
                                  _scrollController.position.maxScrollExtent,
                                );
                              }
                            });

                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final line = filtered[index];
                                return Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.035),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.3,
                                      height: 1.25,
                                      color: _logColor(line, theme),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
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
            'GATEWAY LOGS',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 2.7,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _autoScroll
                ? Icons.vertical_align_bottom
                : Icons.vertical_align_top,
          ),
          tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
          onPressed: () => setState(() => _autoScroll = !_autoScroll),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy all logs',
          onPressed: () => _copyLogs(context),
        ),
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

  Color _logColor(String line, ThemeData theme) {
    final lower = line.toLowerCase();
    if (lower.contains('tool-policy') &&
        (lower.contains('nodes') ||
            lower.contains('tts') ||
            lower.contains('cron'))) {
      return AppColors.statusAmber;
    }
    if (lower.contains('iserror=false')) {
      return theme.colorScheme.onSurface;
    }
    if (line.contains('[ERR]') ||
        line.contains('ERROR') ||
        lower.contains('[error]')) {
      return theme.colorScheme.error;
    }
    if (line.contains('[WARN]') ||
        line.contains('WARNING') ||
        lower.contains('[warn]')) {
      return AppColors.statusAmber;
    }
    if (lower.contains('[plugins]') || lower.contains('[skills]')) {
      return AppColors.statusGreen;
    }
    if (lower.contains('[chat]') || lower.contains('[provider]')) {
      return Colors.cyanAccent;
    }
    if (lower.contains('[tts]') || lower.contains('[tools]')) {
      return Colors.purpleAccent;
    }
    if (line.contains('[INFO]') ||
        lower.contains('[health]') ||
        lower.contains('[startup]')) {
      return AppColors.mutedText;
    }
    return theme.colorScheme.onSurface;
  }

  void _copyLogs(BuildContext context) {
    final provider = context.read<GatewayProvider>();
    final text = provider.state.logs.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }
}
