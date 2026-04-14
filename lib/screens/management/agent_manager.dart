import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/gateway_provider.dart';
import '../../services/preferences_service.dart';
import '../../app.dart';
import '../../widgets/glass_card.dart';

/// AgentManager — fetches agents.list RPC and config.get for model info.
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

      final results = await Future.wait([
        provider.invoke('agents.list'),
        provider.invoke('config.get'),
      ]);

      final agentsResult = results[0];
      final configResult = results[1];

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
        setState(() => _error = null); // Let the UI handle empty gracefully
      }

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
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Agent Fleet',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Agent creation wizard coming in Phase 3'),
              backgroundColor: const Color(0xFF1A1A2E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        backgroundColor: AppColors.statusGreen.withValues(alpha: 0.15),
        foregroundColor: AppColors.statusGreen,
        elevation: 0,
        label: const Text('New Agent', style: TextStyle(fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.add_rounded),
        extendedTextStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700),
      ),
      body: Stack(
        children: [
          // Nebula background
          const NebulaBg(),
          // Content
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.statusGreen))
                : _error != null
                    ? _buildErrorState()
                    : _agents.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _fetchData,
                            color: AppColors.statusGreen,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                              itemCount: _agents.length,
                              itemBuilder: (context, index) =>
                                  _buildAgentCard(context, _agents[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.statusRed),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRed.withValues(alpha: 0.15),
                foregroundColor: AppColors.statusRed,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined, size: 64, color: Colors.white.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text(
            'No agents found',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ensure the OpenClaw gateway is running.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen.withValues(alpha: 0.12),
              foregroundColor: AppColors.statusGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(BuildContext context, dynamic agent) {
    final identity = agent['identity'] as Map<String, dynamic>?;
    final agentId = (agent['id'] ?? '').toString();
    final isDefault = agentId == _defaultId || agent['isDefault'] == true;
    
    // Fallbacks: 1. identity name, 2. native name, 3. custom preferences name if default, 4. non-empty ID
    final displayName = identity?['name'] as String?
        ?? agent['name'] as String?
        ?? (isDefault || agentId == 'main' ? PreferencesService().agentName : null)
        ?? (agentId.isNotEmpty ? agentId : 'Unknown Agent');

    final emoji = identity?['emoji'] as String? ?? '🤖';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        accentColor: isDefault ? AppColors.statusGreen : null,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Emoji avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDefault
                        ? AppColors.statusGreen.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDefault
                          ? AppColors.statusGreen.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
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
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (isDefault)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.statusGreen.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'DEFAULT AGENT',
                            style: TextStyle(
                              color: AppColors.statusGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: Colors.white.withValues(alpha: 0.4), size: 20),
                  onPressed: () {},
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildTag('MODEL: ${_shortModel(_primaryModel)}', Colors.cyanAccent),
                _buildTag('TYPE: GATEWAY AGENT', Colors.white38),
                _buildTag(
                  'ID: ${agentId.length > 12 ? '${agentId.substring(0, 12)}…' : agentId}',
                  Colors.white30,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortModel(String model) {
    final parts = model.split('/');
    final name = parts.length > 1 ? parts[1] : model;
    return name.replaceAll('-preview', '').toUpperCase();
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.firaCode(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
