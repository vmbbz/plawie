import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';
import '../../app.dart';

class BotMethodExplorer extends StatefulWidget {
  final String initialFilter;
  const BotMethodExplorer({super.key, this.initialFilter = ''});

  @override
  State<BotMethodExplorer> createState() => _BotMethodExplorerState();
}

class _BotMethodExplorerState extends State<BotMethodExplorer> {
  final TextEditingController _searchController = TextEditingController();
  late String _searchQuery;
  final Map<String, dynamic> _results = {};
  final Map<String, bool> _loading = {};
  // Per-method JSON param editors (only shown when expanded)
  final Map<String, TextEditingController> _paramControllers = {};
  // Track which tiles are expanded so we can dispose controllers correctly
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialFilter;
    if (widget.initialFilter.isNotEmpty) {
      _searchController.text = widget.initialFilter;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String method) {
    return _paramControllers.putIfAbsent(method, () => TextEditingController(text: '{}'));
  }

  Future<void> _invokeMethod(String method) async {
    // Parse optional params from the JSON editor
    Map<String, dynamic>? params;
    final raw = _paramControllers[method]?.text.trim() ?? '{}';
    if (raw.isNotEmpty && raw != '{}') {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          params = decoded;
        } else {
          setState(() {
            _results[method] = {'error': 'Params must be a JSON object — got ${decoded.runtimeType}'};
          });
          return;
        }
      } catch (e) {
        setState(() {
          _results[method] = {'error': 'Invalid JSON: $e'};
        });
        return;
      }
    }

    setState(() {
      _loading[method] = true;
      _results.remove(method);
    });

    try {
      final provider = Provider.of<GatewayProvider>(context, listen: false);
      final result = await provider.invoke(method, params?.isEmpty == false ? params : null);
      setState(() {
        _results[method] = result;
      });
    } catch (e) {
      setState(() {
        _results[method] = {'error': e.toString()};
      });
    } finally {
      setState(() {
        _loading[method] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialFilter.isEmpty
            ? 'All Methods'
            : '${widget.initialFilter.toUpperCase()} Methods'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh method list',
            onPressed: () {
              Provider.of<GatewayProvider>(context, listen: false)
                  .refreshRpcDiscovery();
              setState(() {});
            },
          ),
        ],
      ),
      body: Consumer<GatewayProvider>(
        builder: (context, provider, _) {
          final methods = provider.supportedMethods
              .where((m) => m.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search methods...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              if (provider.supportedMethods.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.power_off_rounded, size: 14, color: AppColors.statusAmber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gateway offline — connect to load available methods',
                            style: TextStyle(fontSize: 12, color: AppColors.statusAmber),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: methods.isEmpty
                    ? Center(child: Text('No methods found for "$_searchQuery"'))
                    : ListView.builder(
                        itemCount: methods.length,
                        itemBuilder: (context, index) {
                          final method = methods[index];
                          final isLoading = _loading[method] ?? false;
                          final result = _results[method];
                          final paramController = _controllerFor(method);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            child: ExpansionTile(
                              key: ValueKey(method),
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  if (expanded) {
                                    _expanded.add(method);
                                  } else {
                                    _expanded.remove(method);
                                  }
                                });
                              },
                              leading: Icon(
                                _getIconForMethod(method),
                                color: isLoading
                                    ? AppColors.statusAmber
                                    : AppColors.statusGrey,
                              ),
                              title: Text(
                                method,
                                style: GoogleFonts.firaCode(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                _describeMethod(method),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : null,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // ── Param editor ────────────────────
                                      Text(
                                        'PARAMS (JSON)',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white38,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: paramController,
                                        maxLines: 3,
                                        style: GoogleFonts.firaCode(
                                            fontSize: 12),
                                        decoration: InputDecoration(
                                          hintText: '{}',
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.all(10),
                                          isDense: true,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // ── Invoke button ────────────────────
                                      ElevatedButton.icon(
                                        onPressed: isLoading
                                            ? null
                                            : () => _invokeMethod(method),
                                        icon: const Icon(Icons.play_arrow,
                                            size: 16),
                                        label: const Text('RUN'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.purpleAccent.withValues(
                                                  alpha: 0.2),
                                          foregroundColor:
                                              Colors.purpleAccent,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      ),
                                      // ── Result ───────────────────────────
                                      if (result != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.black26
                                                : Colors.black
                                                    .withValues(alpha: 0.05),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    result.containsKey(
                                                                'error') ||
                                                            result['ok'] ==
                                                                false
                                                        ? 'ERROR'
                                                        : 'RESULT',
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: result.containsKey(
                                                                  'error') ||
                                                              result['ok'] ==
                                                                  false
                                                          ? AppColors
                                                              .statusRed
                                                          : AppColors
                                                              .statusGreen,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.close,
                                                        size: 14),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    onPressed: () =>
                                                        setState(() =>
                                                            _results.remove(
                                                                method)),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              SelectableText(
                                                const JsonEncoder.withIndent(
                                                        '  ')
                                                    .convert(result),
                                                style: GoogleFonts.firaCode(
                                                  fontSize: 11,
                                                  color: result.containsKey(
                                                              'error') ||
                                                          result['ok'] == false
                                                      ? AppColors.statusRed
                                                      : theme.textTheme
                                                          .bodyMedium?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getIconForMethod(String method) {
    if (method.startsWith('agents.')) return Icons.person_search;
    if (method.startsWith('config.')) return Icons.settings_applications;
    if (method.startsWith('node.')) return Icons.device_hub;
    if (method.startsWith('chat.')) return Icons.chat;
    if (method.startsWith('usage.')) return Icons.bar_chart;
    if (method.startsWith('skills.')) return Icons.extension;
    if (method.startsWith('cron.')) return Icons.schedule;
    if (method.contains('status') || method.contains('health')) {
      return Icons.health_and_safety;
    }
    return Icons.settings_ethernet;
  }

  String _describeMethod(String method) {
    const hints = {
      'health': 'Get gateway health status',
      'chat.send': 'Send a chat message (requires model, message params)',
      'skills.status': 'List installed skills with eligibility and requirements',
      'skills.search': 'Search ClawHub registry for skills',
      'skills.execute': 'Execute a skill by name',
      'skills.install': 'Install a skill by slug',
      'skills.update': 'Update installed skills',
      'agents.list': 'List available agents',
      'config.get': 'Read current gateway config',
      'config.set': 'Update gateway config (requires key, value params)',
      'usage.stats': 'Get provider usage statistics',
      'node.restart': 'Restart the OpenClaw Node.js process',
    };
    return hints[method] ?? 'No description available';
  }
}
