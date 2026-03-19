import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../../services/skills_service.dart';
import '../../../widgets/skill_install_hero.dart';
import '../../../app.dart';

/// Agent Calls — powered by Twilio ConversationRelay
/// Orchestrates inbound/outbound voice calls through the OpenClaw AI gateway.
///
/// Data fetched via: SkillsService.executeSkill('twilio_voice', {method: 'get_status'})
///
/// Twilio REST API field names (official docs, voice/api/call-resource):
///   phone_number         - E.164 format e.g. '+12125551234' (incoming Twilio number)
///   status               - 'active' | 'suspended' | 'disconnected'
///   concurrent_sessions  - int, active call legs right now
///   inbound_count        - total inbound calls this period
///   total_duration_h     - total talk time (hours float)
///   transcription_enabled - bool (ConversationRelay deepgramSmartFormat)
///   relay_enabled        - bool (ConversationRelay WebSocket relay active)
///   call_logs            - list of call records:
///     sid          - 'CA...' Twilio call SID
///     from         - E.164 caller number
///     to           - E.164 called number
///     direction    - 'inbound' | 'outbound'
///     duration     - seconds (int)
///     status       - 'completed' | 'in-progress' | 'failed' | 'busy' | 'no-answer'
///     summary      - AI-generated summary from ConversationRelay transcript
///     date_created - ISO 8601 timestamp

class AgentCallsPage extends StatefulWidget {
  const AgentCallsPage({super.key});

  @override
  State<AgentCallsPage> createState() => _AgentCallsPageState();
}

class _AgentCallsPageState extends State<AgentCallsPage> {
  Map<String, dynamic> _data = {
    'phone_number': '',
    'status': 'LOADING',
    'concurrent_sessions': 0,
    'inbound_count': 0,
    'total_duration_h': 0,
    'transcription_enabled': false,
    'relay_enabled': false,
    'call_logs': [],
  };
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  bool get _isEnabled {
    final skill = SkillsService().getSkill('twilio_voice');
    return skill?.enabled ?? false;
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    final result = await SkillsService()
        .executeSkill('twilio_voice', parameters: {'method': 'get_status'});

    if (!mounted) return;
    if (result.success) {
      final raw = result.data;
      if (raw is Map<String, dynamic>) {
        setState(() { _data = raw; _loading = false; });
      } else {
        setState(() { _loading = false; });
      }
    } else {
      setState(() {
        _loading = false;
        _error = result.error ?? 'Could not load call data';
      });
    }
  }

  Future<void> _setRelayEnabled(bool value) async {
    await SkillsService().executeSkill('twilio_voice',
        parameters: {'method': 'set_relay', 'enabled': value});
    _refreshData();
  }

  Future<void> _setTranscriptionEnabled(bool value) async {
    await SkillsService().executeSkill('twilio_voice',
        parameters: {'method': 'set_transcription', 'enabled': value});
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: !_isEnabled
          ? _buildInstallHero(context)
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(context),
                  if (_error != null)
                    SliverToBoxAdapter(child: _buildErrorBanner(context)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 80),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildNumberCard(context),
                                const SizedBox(height: 32),
                                _buildSectionHeader(context, 'Voice Orchestration'),
                                const SizedBox(height: 16),
                                _buildRelayToggles(context),
                                const SizedBox(height: 32),
                                _buildSectionHeader(context, 'Recent Conversations'),
                                const SizedBox(height: 16),
                                _buildCallLogs(context),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInstallHero(BuildContext context) {
    final skill = SkillsService().getSkill('twilio_voice');
    if (skill == null) return const Center(child: Text('Skill not found'));
    return Stack(
      children: [
        Positioned(
          top: 40, left: 10,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        SafeArea(
          child: SkillInstallHero(skill: skill, onInstalled: () => setState(() {})),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statusAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.statusAmber, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_error ?? 'Gateway offline',
                style: const TextStyle(color: AppColors.statusAmber, fontSize: 12)),
          ),
          TextButton(onPressed: _refreshData, child: const Text('Retry', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100.0,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Agent Calls',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color)),
        background: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
                color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phoneNumber = (_data['phone_number'] ?? '').toString();
    final displayNumber = phoneNumber.isEmpty ? 'Not Provisioned' : phoneNumber;
    final activeSessions = (_data['concurrent_sessions'] ?? 0) as num;
    final inbound = (_data['inbound_count'] ?? 0) as num;
    final durationH = (_data['total_duration_h'] ?? 0) as num;
    final durationDisplay = durationH == 0 ? '--' : '${durationH.toStringAsFixed(1)}h';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.phone_in_talk_rounded, color: Colors.redAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Virtual Number',
                        style: TextStyle(color: AppColors.statusGrey, fontSize: 11)),
                    Text(
                      displayNumber,
                      style: GoogleFonts.firaCode(
                          fontSize: phoneNumber.isEmpty ? 14 : 20,
                          fontWeight: FontWeight.bold,
                          color: phoneNumber.isEmpty ? AppColors.statusGrey : null),
                    ),
                  ],
                ),
              ),
              if (phoneNumber.isNotEmpty)
                const Icon(Icons.verified_user_rounded, color: AppColors.statusGreen, size: 18),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat('Inbound', '$inbound'),
              const VerticalDivider(width: 1),
              _buildMiniStat('Active', '${activeSessions.toInt()}'),
              const VerticalDivider(width: 1),
              _buildMiniStat('Duration', durationDisplay),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.statusGrey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.statusGrey.withValues(alpha: 0.8),
          ),
    );
  }

  Widget _buildRelayToggles(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final relayEnabled = _data['relay_enabled'] == true;
    final transcriptionEnabled = _data['transcription_enabled'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // Twilio ConversationRelay — WebSocket bidirectional audio relay
          _buildToggleRow('ConversationRelay', relayEnabled, Icons.hub_rounded,
              subtitle: 'Twilio WebSocket audio relay', onChanged: _setRelayEnabled),
          const Divider(height: 24),
          // deepgramSmartFormat transcription
          _buildToggleRow('Transcription', transcriptionEnabled, Icons.subtitles_rounded,
              subtitle: 'Deepgram speech-to-text', onChanged: _setTranscriptionEnabled),
          const Divider(height: 24),
          // Human handoff — future feature, shown as static UI
          _buildToggleRow('Human Escalation', false, Icons.person_add_rounded,
              subtitle: 'Hand off to human agent on request',
              onChanged: null,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.statusGrey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('SOON', style: TextStyle(fontSize: 9, color: AppColors.statusGrey, fontWeight: FontWeight.bold)),
              )),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, bool value, IconData icon,
      {String? subtitle, ValueChanged<bool>? onChanged, Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: value ? AppColors.statusGreen : AppColors.statusGrey),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.statusGrey)),
            ],
          ),
        ),
        trailing ??
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.statusGreen,
            ),
      ],
    );
  }

  Widget _buildCallLogs(BuildContext context) {
    final logs = _data['call_logs'];
    final List<dynamic> callList = (logs is List) ? logs : [];

    if (callList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.call_missed_rounded, size: 36,
                color: AppColors.statusGrey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              _isEnabled ? 'No calls yet' : 'Install skill to see call history',
              style: const TextStyle(color: AppColors.statusGrey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: callList.take(10).map((log) {
        final Map<String, dynamic> call = (log is Map<String, dynamic>)
            ? log
            : Map<String, dynamic>.from(log as Map);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCallCard(context, call),
        );
      }).toList(),
    );
  }

  Widget _buildCallCard(BuildContext context, Map<String, dynamic> call) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Twilio call fields: from, to, direction, duration (seconds), status, summary
    final direction = (call['direction'] ?? 'inbound').toString();
    final isInbound = direction == 'inbound';
    final fromNum = (call['from'] ?? '').toString();
    final toNum = (call['to'] ?? '').toString();
    final displayNumber = isInbound ? fromNum : toNum;
    final durationSec = (call['duration'] ?? 0) as num;
    final mins = (durationSec ~/ 60).toString().padLeft(1, '0');
    final secs = (durationSec % 60).toInt().toString().padLeft(2, '0');
    final durationDisplay = durationSec > 0 ? '${mins}m ${secs}s' : '--';
    final summary = (call['summary'] ?? '').toString();
    final status = (call['status'] ?? 'completed').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isInbound ? Icons.call_received_rounded : Icons.call_made_rounded,
                    size: 14,
                    color: isInbound ? Colors.blueAccent : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayNumber.isNotEmpty ? displayNumber : direction,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Text(durationDisplay,
                  style: GoogleFonts.firaCode(fontSize: 11, color: AppColors.statusGrey)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                direction.toUpperCase(),
                style: TextStyle(
                    color: isInbound ? Colors.blueAccent : Colors.orangeAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (status != 'completed')
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      color: status == 'failed' ? AppColors.statusRed : AppColors.statusAmber,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: TextStyle(color: AppColors.statusGrey, fontSize: 11, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
