import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/gateway_provider.dart';
import '../app.dart';

class BotMethodsScreen extends StatefulWidget {
  const BotMethodsScreen({super.key});

  @override
  State<BotMethodsScreen> createState() => _BotMethodsScreenState();
}

class _BotMethodsScreenState extends State<BotMethodsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, dynamic> _results = {};
  final Map<String, bool> _loading = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _invokeMethod(String method) async {
    setState(() {
      _loading[method] = true;
    });

    try {
      final provider = Provider.of<GatewayProvider>(context, listen: false);
      final result = await provider.invoke(method);
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
        title: const Text('OpenClaw Methods'),
        actions: [
           IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
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
              Expanded(
                child: ListView.builder(
                  itemCount: methods.length,
                  itemBuilder: (context, index) {
                    final method = methods[index];
                    final isLoading = _loading[method] ?? false;
                    final result = _results[method];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        leading: Icon(
                          _getIconForMethod(method),
                          color: isLoading ? AppColors.statusAmber : AppColors.statusGrey,
                        ),
                        title: Text(
                          method,
                          style: GoogleFonts.firaCode(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        trailing: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () => _invokeMethod(method),
                              ),
                        children: [
                          if (result != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'RESULT',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.statusGreen,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () => setState(() => _results.remove(method)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    const JsonEncoder.withIndent('  ').convert(result),
                                    style: GoogleFonts.firaCode(
                                      fontSize: 12,
                                      color: result.containsKey('error') || (result['ok'] == false)
                                          ? AppColors.statusRed
                                          : theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (result == null && !isLoading)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Tap play to fetch data from the bot.',
                                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
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
    if (method.contains('status') || method.contains('health')) return Icons.health_and_safety;
    return Icons.settings_ethernet;
  }
}
