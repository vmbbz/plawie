// lib/pages/agent_skills_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/skills_service.dart';
import '../constants/openclaw_paths.dart';
import '../services/native_bridge.dart';

class AgentSkillsPage extends StatefulWidget {
  const AgentSkillsPage({super.key});
  @override
  State<AgentSkillsPage> createState() => _AgentSkillsPageState();
}

class _AgentSkillsPageState extends State<AgentSkillsPage> with SingleTickerProviderStateMixin {
  final SkillsService _skills = SkillsService();
  late TabController _tabController;
  
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _discoverResults = [];
  bool _isSearching = false;

  final List<Map<String, dynamic>> _installedCatalog = [
    {
      'id': 'gestures',
      'name': 'Gestures & Avatar',
      'desc': 'Full-body VRMA + limb layering (waves, bows, sits). 30+ mocap animations.',
      'installed': true,
      'icon': Icons.accessibility_new_rounded,
      'color': Colors.blueAccent,
    },
    {
      'id': 'voice',
      'name': 'Voice & TTS',
      'desc': 'Switch voices and engines (Piper, ElevenLabs, OpenAI).',
      'installed': true,
      'icon': Icons.record_voice_over_rounded,
      'color': Colors.purpleAccent,
    },
    {
      'id': 'device-node',
      'name': 'Phone Tools',
      'desc': 'Camera, flashlight, vibrate, location, and hardware sensors.',
      'installed': true,
      'icon': Icons.phonelink_setup_rounded,
      'color': Colors.orangeAccent,
    },
    {
      'id': 'weather',
      'name': 'Weather & Forecast',
      'desc': 'Live weather updates and global forecasts.',
      'installed': false,
      'icon': Icons.wb_sunny_rounded,
      'color': Colors.cyanAccent,
    },
    {
      'id': 'search',
      'name': 'Web Search',
      'desc': 'Powerful real-time web search and information retrieval.',
      'installed': true,
      'icon': Icons.search_rounded,
      'color': Colors.greenAccent,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _performClawHubSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);

    try {
      // Primary search pattern: JSON output with download sorting
      String result = await NativeBridge.runInProot(
        '$kOpenClawCommand skills search "$query" --json --limit 20 --sort downloads',
      );

      // Fallback strategy: If first pattern fails or returns empty, try broad search
      if (result.trim().isEmpty || result.contains('error')) {
        result = await NativeBridge.runInProot(
          '$kOpenClawCommand skills search "$query" --json --limit 10',
        );
      }

      if (result.isNotEmpty) {
        final List<dynamic> parsed = json.decode(result);
        setState(() => _discoverResults = parsed);
      } else {
        setState(() => _discoverResults = []);
      }
    } catch (e) {
      setState(() => _discoverResults = []);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ClawHub connection issue. Try again later.")));
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _showSkillProfile(Map<String, dynamic> skill) async {
    final profile = await _skills.getSkillProfile(skill['id'] ?? skill['slug'] ?? '');

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.cyan.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 10),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                gradient: LinearGradient(
                  colors: [Color(0xFF00FFFF), Color(0xFFFF00FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Image.network(
                    profile['iconUrl'] ?? '',
                    width: 48, height: 48,
                    errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, size: 48, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      skill['name'] ?? skill['slug'] ?? 'Unknown Skill',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  if (profile['verified'] == true)
                    const Chip(
                      label: Text('✓ Verified by ClawHub', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                      backgroundColor: Colors.white,
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile['description'] ?? skill['description'] ?? 'No description.', style: const TextStyle(fontSize: 17, height: 1.4, color: Colors.white)),
                    const SizedBox(height: 24),
                    const Text("Capabilities", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    const SizedBox(height: 12),
                    ...?profile['tools']?.map((tool) => ListTile(
                          leading: const Icon(Icons.check_circle_outline, color: Colors.cyan),
                          title: Text(tool, style: const TextStyle(color: Colors.white70)),
                          dense: true,
                        )),
                    const SizedBox(height: 24),
                    const Text("Try saying...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                      child: Text(
                        profile['examples'] ?? "Plawie, help me with this skill!",
                        style: const TextStyle(fontSize: 16, color: Colors.cyanAccent, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _skills.installSkill(skill['slug'] ?? skill['id']);
                        await _skills.ensureAgentAwareness();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("INSTALL / EQUIP", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _skills.uninstallSkill(skill['slug'] ?? skill['id']);
                        await _skills.ensureAgentAwareness();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("UNINSTALL", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Plawie's Skills & Tools", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "EQUIPPED", icon: Icon(Icons.bolt_rounded)),
            Tab(text: "DISCOVER", icon: Icon(Icons.explore_rounded)),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1E293B).withValues(alpha: 0.5), const Color(0xFF0F172A)],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildEquippedTab(),
            _buildDiscoverTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildEquippedTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _installedCatalog.length,
      itemBuilder: (context, index) {
        final skill = _installedCatalog[index];
        final bool isInstalled = skill['installed'];
        final Color accentColor = skill['color'];
        return _buildSkillCard(skill, isInstalled, accentColor);
      },
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search ClawHub (e.g. github, camera)",
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.cyanAccent),
                onPressed: () => _performClawHubSearch(_searchController.text),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onSubmitted: _performClawHubSearch,
          ),
        ),
        if (_isSearching)
          const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)))
        else if (_discoverResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _discoverResults.length,
              itemBuilder: (context, i) {
                final skill = _discoverResults[i];
                return _buildDiscoverListItem(skill);
              },
            ),
          )
        else
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore_outlined, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Text("Explore community skills on ClawHub", style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSkillCard(Map<String, dynamic> skill, bool isInstalled, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: accentColor.withValues(alpha: isInstalled ? 0.2 : 0.05), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: const Color(0xFF1E293B),
          child: InkWell(
            onTap: () => _showSkillProfile(skill),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: accentColor.withValues(alpha: isInstalled ? 0.5 : 0.1), width: 2)),
                    child: Icon(skill['icon'] ?? Icons.auto_awesome, size: 32, color: isInstalled ? accentColor : Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Text(skill['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Expanded(child: Text(skill['desc'], style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, height: 1.3), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis)),
                  const SizedBox(height: 12),
                  _buildEquipButton(skill, isInstalled, accentColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverListItem(Map<String, dynamic> skill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _showSkillProfile(skill),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
        ),
        title: Text(skill['name'] ?? skill['slug'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(skill['description'] ?? skill['summary'] ?? 'ClawHub Community Skill', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: ElevatedButton(
          onPressed: () async {
            await _skills.installSkill(skill['slug'] ?? skill['id']);
            await _skills.ensureAgentAwareness();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Skill equipped! Plawie is ready."), behavior: SnackBarBehavior.floating));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text("EQUIP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ),
    );
  }

  Widget _buildEquipButton(Map<String, dynamic> skill, bool isInstalled, Color accentColor) {
    return GestureDetector(
      onTap: () async {
        bool success;
        if (isInstalled) {
          success = await _skills.uninstallSkill(skill['id']);
        } else {
          success = await _skills.installSkill(skill['id']);
        }
        if (success) {
          await _skills.ensureAgentAwareness();
          if (!mounted) return;
          setState(() => skill['installed'] = !isInstalled);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${skill['name']} ${isInstalled ? 'removed' : 'equipped'}!'), backgroundColor: isInstalled ? Colors.redAccent : Colors.greenAccent, behavior: SnackBarBehavior.floating));
        }
      },
      child: Container(
        width: double.infinity, height: 36,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: isInstalled ? LinearGradient(colors: [Colors.redAccent, Colors.red.shade800]) : LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.7)])),
        child: Center(child: Text(isInstalled ? 'Uninstall' : 'Equip Skill', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
      ),
    );
  }
}
