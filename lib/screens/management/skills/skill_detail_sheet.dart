import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app.dart';
import '../../../models/clawhub_skill.dart';
import '../../../services/clawhub_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Factory — call this to open the sheet from anywhere in skills_manager.
// Returns true if the user tapped Install (so the caller can refresh state).
// ─────────────────────────────────────────────────────────────────────────────

Future<bool> showSkillDetailSheet(
  BuildContext context, {
  required String slug,
  String? initialName,
  String? initialDescription,
  bool isInstalled = false,
  Color accentColor = AppColors.statusGreen,
  IconData icon = Icons.extension_rounded,
  Future<void> Function(String slug, String name)? onInstall,
  VoidCallback? onEdit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SkillDetailSheet(
      slug: slug,
      initialName: initialName,
      initialDescription: initialDescription,
      isInstalled: isInstalled,
      accentColor: accentColor,
      icon: icon,
      onInstall: onInstall,
      onEdit: onEdit,
    ),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet widget
// ─────────────────────────────────────────────────────────────────────────────

class _SkillDetailSheet extends StatefulWidget {
  final String slug;
  final String? initialName;
  final String? initialDescription;
  final bool isInstalled;
  final Color accentColor;
  final IconData icon;
  final Future<void> Function(String slug, String name)? onInstall;
  final VoidCallback? onEdit;

  const _SkillDetailSheet({
    required this.slug,
    this.initialName,
    this.initialDescription,
    required this.isInstalled,
    required this.accentColor,
    required this.icon,
    this.onInstall,
    this.onEdit,
  });

  @override
  State<_SkillDetailSheet> createState() => _SkillDetailSheetState();
}

class _SkillDetailSheetState extends State<_SkillDetailSheet> {
  ClawHubSkill? _skill;
  bool _fetchingStats = true;
  bool _installing = false;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final result = await ClawHubService.instance.infoFromApi(
      widget.slug,
      isInstalled: widget.isInstalled,
    );
    if (mounted) {
      setState(() {
        _skill = result;
        _fetchingStats = false;
      });
    }
  }

  Future<void> _install() async {
    if (widget.onInstall == null) return;
    setState(() => _installing = true);
    await widget.onInstall!(
      widget.slug,
      _skill?.name ?? widget.initialName ?? widget.slug,
    );
    if (mounted) {
      setState(() => _installing = false);
      Navigator.of(context).pop(true);
    }
  }

  void _openOnClawHub() {
    final url = Uri.parse('https://clawhub.ai/skills/${widget.slug}');
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final name        = _skill?.name        ?? widget.initialName        ?? widget.slug;
    final description = _skill?.description ?? widget.initialDescription ?? '';
    final version     = _skill?.version ?? '';
    final author      = _skill?.author ?? _skill?.ownerHandle ?? '';
    final stars       = _skill?.stars;
    final downloads   = _skill?.downloadCount;
    final installs    = _skill?.currentInstalls;
    final ownerAvatar = _skill?.ownerAvatarUrl;
    final color       = widget.accentColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.52, 0.75],
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header: icon + name + badges ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(widget.icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (version.isNotEmpty)
                            _badge('v$version', Colors.white24, Colors.white54),
                          if (widget.isInstalled)
                            _badge('ACTIVE', color.withValues(alpha: 0.15),
                                color),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Stats row ────────────────────────────────────────────────
            if (_fetchingStats)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                    child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )),
              )
            else if (stars != null || downloads != null || installs != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (stars != null)
                      _statTile(Icons.star_rounded, _formatNum(stars), 'Stars',
                          const Color(0xFFFFC107)),
                    if (downloads != null)
                      _statTile(Icons.download_rounded, _formatNum(downloads),
                          'Downloads', const Color(0xFF2196F3)),
                    if (installs != null)
                      _statTile(Icons.devices_rounded, _formatNum(installs),
                          'Active now', AppColors.statusGreen),
                  ],
                ),
              ),

            const SizedBox(height: 18),

            // ── Description ───────────────────────────────────────────────
            if (description.isNotEmpty) ...[
              Text(
                'About',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ── Author ────────────────────────────────────────────────────
            if (author.isNotEmpty)
              Row(
                children: [
                  if (ownerAvatar != null)
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: NetworkImage(ownerAvatar),
                      backgroundColor: Colors.white10,
                    )
                  else
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Text(
                        author.substring(0, min(1, author.length)).toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '@${_skill?.ownerHandle ?? author}',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.35)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openOnClawHub,
                    child: Text(
                      'clawhub.ai →',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // ── Slug copy row ──────────────────────────────────────────────
            GestureDetector(
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: 'openclaw skills install ${widget.slug}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Install command copied!')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.terminal_rounded,
                        size: 13, color: Colors.white.withValues(alpha: 0.35)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'openclaw skills install ${widget.slug}',
                        style: GoogleFonts.firaCode(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Icon(Icons.copy_rounded,
                        size: 13, color: Colors.white.withValues(alpha: 0.25)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Action buttons ────────────────────────────────────────────
            Row(
              children: [
                // View on ClawHub
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openOnClawHub,
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: const Text('ClawHub'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                if (widget.onEdit != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onEdit!();
                      },
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white60,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
                if (!widget.isInstalled && widget.onInstall != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _installing ? null : _install,
                      icon: _installing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ))
                          : const Icon(Icons.download_rounded, size: 16),
                      label: Text(_installing ? 'Installing…' : 'Install'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      );

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: fg,
            letterSpacing: 0.8,
          ),
        ),
      );

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
