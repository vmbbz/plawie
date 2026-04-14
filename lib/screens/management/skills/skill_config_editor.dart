import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/native_bridge.dart';
import '../../../app.dart';

/// Skill configuration editor.
///
/// Probes multiple real on-device paths in priority order:
///
///   1. CUSTOM workspace skill  — `/root/.openclaw/workspace/skills/ID/SKILL.yaml`
///   2. CUSTOM workspace skill  — `/root/.openclaw/workspace/skills/ID/SKILL.md`
///   3. INSTALLED npm skill     — `/root/.openclaw/node_modules/@openclaw/ID/skill.yaml`
///   4. INSTALLED npm skill     — `/root/.openclaw/node_modules/openclaw-skill-ID/skill.yaml`
///   5. INSTALLED npm skill     — `/root/.openclaw/node_modules/ID/skill.yaml`  (bare name)
///   6. Legacy native md        — `/root/.openclaw/skills/ID.md`
///
/// Gateway-bundled skills (paths 3–5) are shown with an amber notice explaining
/// that saving creates a workspace override loaded instead of the npm default.
class SkillConfigEditor extends StatefulWidget {
  final String skillId;

  const SkillConfigEditor({
    super.key,
    required this.skillId,
  });

  @override
  State<SkillConfigEditor> createState() => _SkillConfigEditorState();
}

class _SkillConfigEditorState extends State<SkillConfigEditor> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String? _resolvedPath;   // The path where the file was actually found
  bool _isCustomSkill = false; // true = workspace custom, false = npm/bundled

  @override
  void initState() {
    super.initState();
    _fetchSkillConfig();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Probe multiple known locations for the skill config, in priority order.
  Future<void> _fetchSkillConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _resolvedPath = null;
    });

    final id = widget.skillId;

    // Priority-ordered list of (path, isCustom) tuples
    final candidates = <(String, bool)>[
      // ── Custom workspace skills (user created) ──────────────────────────
      ('/root/.openclaw/workspace/skills/$id/SKILL.yaml', true),
      ('/root/.openclaw/workspace/skills/$id/SKILL.md', true),
      // ── Installed npm skills (OpenClaw default / ClawHub installed) ─────
      // @openclaw scoped package
      ('/root/.openclaw/node_modules/@openclaw/$id/skill.yaml', false),
      ('/root/.openclaw/node_modules/@openclaw/$id/SKILL.yaml', false),
      // openclaw-skill-<id> pattern
      ('/root/.openclaw/node_modules/openclaw-skill-$id/skill.yaml', false),
      // bare name fallback (older skills, community)
      ('/root/.openclaw/node_modules/$id/skill.yaml', false),
      ('/root/.openclaw/node_modules/$id/SKILL.yaml', false),
      // ── Legacy native md ────────────────────────────────────────────────
      ('/root/.openclaw/skills/$id.md', false),
    ];

    try {
      for (final (path, isCustom) in candidates) {
        final result = await NativeBridge.runInProot(
          'test -f "$path" && cat "$path" || echo "::NOT_FOUND::"',
          timeout: 8,
        );
        final trimmed = result.trim();
        if (trimmed.isNotEmpty &&
            !trimmed.contains('::NOT_FOUND::') &&
            !trimmed.contains('No such file')) {
          _controller.text = trimmed;
          setState(() {
            _resolvedPath = path;
            _isCustomSkill = isCustom;
            _isLoading = false;
          });
          return;
        }
      }

      // Nothing found — offer to create a custom workspace file
      setState(() {
        _error = 'No SKILL.yaml found for "$id".\n\n'
            'This skill is managed by the OpenClaw gateway and does not expose '
            'a local config file. You can create a workspace override below — '
            'it will be loaded instead of the gateway default.';
        _resolvedPath = '/root/.openclaw/workspace/skills/$id/SKILL.yaml';
        _isCustomSkill = true;
        _controller.text = _defaultSkillYaml(id);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to probe skill paths: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSkillConfig() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final text = _controller.text.trim();
      if (text.isEmpty) throw Exception('Cannot save empty configuration');

      final targetPath = _resolvedPath!;

      // Ensure the directory exists (for workspace custom skills & new overrides)
      final dir = targetPath.substring(0, targetPath.lastIndexOf('/'));
      await NativeBridge.runInProot('mkdir -p "$dir"', timeout: 5);

      // Base64-encode content to safely handle multiline YAML through bash
      final encoded = Uri.encodeComponent(text);
      final script = 'require("fs").writeFileSync('
          '"$targetPath",'
          'decodeURIComponent("$encoded"))';

      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js '
        '--max-old-space-size=256" && node -e \'$script\'',
        timeout: 15,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Saved to $targetPath'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
        setState(() => _isCustomSkill = true); // now it's a real file
      }
    } catch (e) {
      setState(() => _error = 'Failed to save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Save failed: $e'),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Default SKILL.yaml template for new workspace overrides.
  String _defaultSkillYaml(String id) => '''# Workspace override for: $id
# This file is loaded by OpenClaw instead of the gateway default.
# Edit the system_prompt to customize how the agent uses this skill.

name: $id
version: 1.0.0

system_prompt: |
  You have the "$id" skill available.
  Use it to help the user when relevant.

# Optional: restrict which gateway tools this skill can invoke
# tools:
#   - ${id}.command_name
''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNpmSkill = _resolvedPath != null && !_isCustomSkill;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.skillId.toUpperCase(),
          style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, color: AppColors.statusGreen),
              onPressed: _isSaving ? null : _saveSkillConfig,
              tooltip: 'Save',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Source badge ──────────────────────────────────────────
                  if (_resolvedPath != null) ...[
                    _SourceBadge(
                      path: _resolvedPath!,
                      isCustom: _isCustomSkill,
                      isNpm: isNpmSkill,
                    ),
                    const SizedBox(height: 10),
                  ],
                  // ── npm read-only notice ──────────────────────────────────
                  if (isNpmSkill)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.statusAmber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.statusAmber.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: AppColors.statusAmber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is a gateway-managed skill. '
                              'Changes you save here create a workspace override '
                              'that OpenClaw loads instead of the npm default. '
                              'Run "openclaw reload" in terminal to apply.',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.statusAmber, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // ── Error / info message ──────────────────────────────────
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.statusAmber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.statusAmber.withValues(alpha: 0.2)),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.statusAmber, fontSize: 12, height: 1.5)),
                    ),
                  // ── Editor ───────────────────────────────────────────────
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        style: GoogleFonts.firaCode(fontSize: 12, height: 1.6),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Source badge widget — shows where the file was loaded from
// ─────────────────────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  final String path;
  final bool isCustom;
  final bool isNpm;

  const _SourceBadge({
    required this.path,
    required this.isCustom,
    required this.isNpm,
  });

  @override
  Widget build(BuildContext context) {
    final label = isCustom ? 'CUSTOM WORKSPACE' : 'GATEWAY NPM SKILL';
    final color = isCustom ? AppColors.statusGreen : AppColors.statusAmber;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            path.replaceFirst('/root/.openclaw/', '~/.openclaw/'),
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.35),
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
