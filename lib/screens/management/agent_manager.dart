import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';
import '../../app.dart';

class AgentManager extends StatefulWidget {
  const AgentManager({super.key});

  @override
  State<AgentManager> createState() => _AgentManagerState();
}

class _AgentManagerState extends State<AgentManager> {
  bool _isLoading = true;
  List<dynamic> _agents = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAgents();
  }

  Future<void> _fetchAgents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<GatewayProvider>(context, listen: false);
      final result = await provider.invoke('agents.list');
      
      if (result['ok'] == true) {
        final payload = result['payload'];
        if (payload is List) {
          setState(() => _agents = payload);
        } else if (payload is Map && payload['agents'] is List) {
          setState(() => _agents = payload['agents']);
        }
      } else {
        setState(() => _error = result['error']?['message'] ?? 'Failed to fetch agents');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Fleet Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAgents,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement agent creation wizard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agent creation coming soon in Phase 3')),
          );
        },
        backgroundColor: AppColors.statusGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.statusRed),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: _fetchAgents, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchAgents,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _agents.length,
                itemBuilder: (context, index) {
                  final agent = _agents[index];
                  final name = agent['name'] ?? agent['agentId'] ?? 'Unknown Agent';
                  final isDefault = agent['isDefault'] == true;
                  final description = agent['description'] ?? 'No description available';
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isDefault ? AppColors.statusGreen.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                child: Icon(
                                  isDefault ? Icons.verified_user_rounded : Icons.person_rounded,
                                  color: isDefault ? AppColors.statusGreen : Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    if (isDefault)
                                      Text(
                                        'DEFAULT AGENT',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: AppColors.statusGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings_outlined),
                                onPressed: () {
                                  // Nav to agent settings
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                               _buildTag(context, 'MODEL: ${agent['model'] ?? 'default'}'),
                               const SizedBox(width: 8),
                               _buildTag(context, 'TYPE: ${agent['type'] ?? 'core'}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.firaCode(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: AppColors.statusGrey,
        ),
      ),
    );
  }
}
