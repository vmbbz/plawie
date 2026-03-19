import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';
import '../../app.dart';

/// AgentManager — fetches agents.list RPC and also config.get for model info.
/// Official agents.list response: { defaultId, mainKey, scope, agents:[{id, name, identity:{name,theme,emoji}}] }
/// Model info comes from config.get → agents.defaults.model.primary
class AgentManager extends StatefulWidget {
  const AgentManager({super.key});

  @override
  State<AgentManager> createState() => _AgentManagerState();
}

class _AgentManagerState extends State<AgentManager> {
  bool _isLoading = true;
  List<dynamic> _agents = [];
  String? _error;
  String _defaultId = '';
  String _primaryModel = 'default';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<GatewayProvider>(context, listen: false);

      // Fetch agents list and config in parallel
      final results = await Future.wait([
        provider.invoke('agents.list'),
        provider.invoke('config.get'),
      ]);

      final agentsResult = results[0];
      final configResult = results[1];

      // Parse agents
      if (agentsResult['ok'] == true) {
        final payload = agentsResult['payload'];
        if (payload is Map) {
          final agents = payload['agents'];
          if (agents is List) setState(() => _agents = agents);
          _defaultId = (payload['defaultId'] ?? '').toString();
        } else if (payload is List) {
          setState(() => _agents = payload);
        }
      } else {
        setState(() => _error = agentsResult['error']?['message'] ?? 'Failed to fetch agents');
      }

      // Parse primary model from config
      if (configResult['ok'] == true) {
        final cfg = configResult['payload']?['config'];
        if (cfg is Map) {
          final model = cfg['agents']?['defaults']?['model']?['primary'];
          if (model is String && model.isNotEmpty) {
            setState(() => _primaryModel = model);
          }
        }
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
            onPressed: _fetchData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agent creation wizard coming in Phase 3')),
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
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.statusRed),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                            onPressed: _fetchData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _agents.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _agents.length,
                        itemBuilder: (context, index) =>
                            _buildAgentCard(context, _agents[index], isDark),
                      ),
                    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 64, color: AppColors.statusGrey),
          const SizedBox(height: 16),
          Text(
            'No agents found',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ensure the OpenClaw gateway is running.',
            style: TextStyle(color: AppColors.statusGrey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(BuildContext context, dynamic agent, bool isDark) {
    final theme = Theme.of(context);

    // Official protocol: identity.name is the display name; fallback to name, then id
    final identity = agent['identity'] as Map<String, dynamic>?;
    final displayName = identity?['name'] as String?
        ?? agent['name'] as String?
        ?? agent['id'] as String?
        ?? 'Unknown Agent';

    final agentId = (agent['id'] ?? '').toString();
    final isDefault = agentId == _defaultId || agent['isDefault'] == true;

    // Emoji avatar from identity, fallback to robot emoji
    final emoji = identity?['emoji'] as String? ?? '🤖';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Emoji avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDefault
                        ? AppColors.statusGreen.withOpacity(0.12)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (isDefault)
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'DEFAULT AGENT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.statusGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {},
                ),
              ],
            ),
            const Divider(height: 28),
            // Model and type tags
            Row(
              children: [
                _buildTag(context, 'MODEL: ${_shortModel(_primaryModel)}'),
                const SizedBox(width: 8),
                _buildTag(context, 'TYPE: GATEWAY AGENT'),
                const SizedBox(width: 8),
                _buildTag(context, 'ID: ${agentId.length > 12 ? '${agentId.substring(0, 12)}…' : agentId}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shorten "google/gemini-3.1-pro-preview" → "gemini-3.1-pro"
  String _shortModel(String model) {
    final parts = model.split('/');
    final name = parts.length > 1 ? parts[1] : model;
    // Trim '-preview' suffix for brevity
    return name.replaceAll('-preview', '').toUpperCase();
  }

  Widget _buildTag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
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
