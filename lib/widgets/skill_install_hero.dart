import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/skills_service.dart';
import 'dart:ui';

class SkillInstallHero extends StatefulWidget {
  final Skill skill;
  final VoidCallback onInstalled;

  const SkillInstallHero({
    super.key,
    required this.skill,
    required this.onInstalled,
  });

  @override
  State<SkillInstallHero> createState() => _SkillInstallHeroState();
}

class _SkillInstallHeroState extends State<SkillInstallHero> {
  bool _isInstalling = false;

  Future<void> _handleInstall() async {
    setState(() => _isInstalling = true);
    
    // Simulate some installation work (e.g. provisioning on-chain or network check)
    await Future.delayed(const Duration(seconds: 2));
    
    await SkillsService().toggleSkill(widget.skill.id, true);
    
    if (mounted) {
      widget.onInstalled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(),
          const SizedBox(height: 32),
          Text(
            widget.skill.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.skill.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          _buildFeatureList(),
          const SizedBox(height: 60),
          _buildInstallButton(),
          const SizedBox(height: 20),
          Text(
            'Requires Internet & Active Node',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        _getSkillIcon(),
        size: 48,
        color: Colors.blueAccent,
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = _getSkillFeatures();
    return Column(
      children: features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 12),
            Text(
              f,
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildInstallButton() {
    return SizedBox(
      width: 240,
      height: 56,
      child: ElevatedButton(
        onPressed: _isInstalling ? null : _handleInstall,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isInstalling
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'INITIALIZE SKILL',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }

  IconData _getSkillIcon() {
    switch (widget.skill.id) {
      case 'twilio_voice': return Icons.phone_android_outlined;
      case 'agent_card': return Icons.credit_card_outlined;
      case 'molt_launch': return Icons.rocket_launch_outlined;
      case 'valeo_sentinel': return Icons.security_outlined;
      default: return Icons.extension_outlined;
    }
  }

  List<String> _getSkillFeatures() {
    switch (widget.skill.id) {
      case 'twilio_voice':
        return ['AI Voice Bridging', 'Conversation Relay', 'Dual-Channel Audio'];
      case 'agent_card':
        return ['Virtual Visa/MC', 'Instant Issuance', 'Spend Controls'];
      case 'molt_launch':
        return ['Job Coordination', 'On-Chain Reputation', 'Automated Escrow'];
      case 'valeo_sentinel':
        return ['Budget Enforcement', 'Compliance Auditing', 'Safe Spend Policies'];
      default:
        return ['Native Integration', 'AI Tool Compatibility', 'Auto-Discovery'];
    }
  }
}
