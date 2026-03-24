import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../../../services/native_bridge.dart';
import '../../../app.dart';

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

  Future<void> _fetchSkillConfig() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final yamlPath = '/root/.openclaw/workspace/skills/${widget.skillId}/SKILL.yaml';
      final mdPath = '/root/.openclaw/workspace/skills/${widget.skillId}/SKILL.md';
      final nativeMdPath = '/root/.openclaw/skills/${widget.skillId}.md';
      
      // Attempt YAML mapping first, fallback to markdown mapping per OpenClaw docs
      String content = await NativeBridge.runInProot('cat $yamlPath');
      
      if (content.contains('No such file') || content.trim().isEmpty) {
        content = await NativeBridge.runInProot('cat $mdPath');
      }

      // Fallback to globally populated native android skills
      if (content.contains('No such file') || content.trim().isEmpty) {
        content = await NativeBridge.runInProot('cat $nativeMdPath');
      }

      if (content.contains('No such file') || content.trim().isEmpty) {
        setState(() {
          _error = 'Skill configuration file not found in workspace.';
          _isLoading = false;
        });
        return;
      }

      _controller.text = content;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch files involved: $e';
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
      final text = _controller.text;
      if (text.isEmpty) throw Exception('Cannot save empty configuration');
      
      final yamlPath = '/root/.openclaw/workspace/skills/${widget.skillId}/SKILL.yaml';
      final mdPath = '/root/.openclaw/workspace/skills/${widget.skillId}/SKILL.md';
      final nativeMdPath = '/root/.openclaw/skills/${widget.skillId}.md';

      String targetPath = '';
      final checkYaml = await NativeBridge.runInProot('test -f $yamlPath && echo "found"');
      if (checkYaml.trim() == 'found') {
        targetPath = yamlPath;
      } else {
        final checkMd = await NativeBridge.runInProot('test -f $mdPath && echo "found"');
        if (checkMd.trim() == 'found') {
          targetPath = mdPath;
        } else {
          final checkNative = await NativeBridge.runInProot('test -f $nativeMdPath && echo "found"');
          if (checkNative.trim() == 'found') {
            targetPath = nativeMdPath;
          } else {
            throw Exception('Could not determine target save path; original file not found.');
          }
        }
      }

      // Base64 encode to safely transmit multi-line scripts bypassing bash escaped EOF clashes
      final encodedContent = Uri.encodeComponent(text);
      final script = '''
const fs = require('fs');
const content = decodeURIComponent('$encodedContent');
fs.writeFileSync('$targetPath', content);
''';

      await NativeBridge.runInProot(
        'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js --max-old-space-size=256" && node -e "${script.replaceAll('"', '\\"')}"',
        timeout: 15,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuration saved. Agent capabilities updated.'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save configuration: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Save failed: $e'),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Edit \${widget.skillId}'.toUpperCase(),
          style: GoogleFonts.firaCode(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded, color: AppColors.statusGreen),
              onPressed: _isSaving ? null : _saveSkillConfig,
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.statusAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.statusAmber)),
                    ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        style: GoogleFonts.firaCode(
                          fontSize: 13,
                          height: 1.5,
                        ),
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
