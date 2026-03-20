import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../../app.dart';
import '../../services/preferences_service.dart';

/// Avatar Forge — Manage 3D AI avatar identities and equip on-chain VRM models.
class AvatarForgePage extends StatefulWidget {
  const AvatarForgePage({super.key});

  @override
  State<AvatarForgePage> createState() => _AvatarForgePageState();
}

class _AvatarForgePageState extends State<AvatarForgePage>
    with SingleTickerProviderStateMixin {
  final List<String> _myAvatars = [
    'default_avatar.vrm',
    'gemini.vrm',
    'boruto.vrm',
  ];
  String _equippedAvatar = 'default_avatar.vrm';
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadEquipped();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadEquipped() async {
    final prefs = PreferencesService();
    await prefs.init();
    setState(() => _equippedAvatar = prefs.selectedAvatar);
  }

  Future<void> _equipAvatar(String avatar) async {
    final prefs = PreferencesService();
    await prefs.init();
    prefs.selectedAvatar = avatar;
    setState(() => _equippedAvatar = avatar);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Equipped ${avatar.split('.').first.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.statusGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D1A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'AVATAR FORGE',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF13082A), Color(0xFF080C14)],
              ),
            ),
          ),
          // Ambient purple/teal glow patches
          Positioned(
            top: -60,
            left: -40,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (_, __) => Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7B2FBE)
                      .withValues(alpha: 0.06 + 0.04 * _glowController.value),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00B4D8).withValues(alpha: 0.06),
              ),
            ),
          ),
          // Scrollable content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroSection(),
                  const SizedBox(height: 32),
                  _buildSectionLabel('MY LIBRARY', Icons.grid_view_rounded, Colors.greenAccent),
                  const SizedBox(height: 12),
                  _buildLibraryGrid(),
                  const SizedBox(height: 32),
                  _buildSectionLabel('WEB PORTAL', Icons.public_rounded, Colors.purpleAccent),
                  const SizedBox(height: 12),
                  _buildWebPortalCard(context),
                  const SizedBox(height: 28),
                  _buildChainBadge(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF13082A)],
        ),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withValues(alpha: 0.12),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (_, child) => Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFAB5CFE), Color(0xFF6A0DAD)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent
                        .withValues(alpha: 0.3 + 0.2 * _glowController.value),
                    blurRadius: 20 + 10 * _glowController.value,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Avatar Forge',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Equip local identities or mint on-chain VRM NFTs\nthrough the Avatar Forge web portal.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.outfit(
            color: color.withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _myAvatars.length,
      itemBuilder: (context, index) {
        final avatar = _myAvatars[index];
        final isEquipped = avatar == _equippedAvatar;
        final name = avatar.split('.').first;

        return GestureDetector(
          onTap: () => _equipAvatar(avatar),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isEquipped
                  ? AppColors.statusGreen.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEquipped
                    ? AppColors.statusGreen.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08),
                width: isEquipped ? 1.5 : 1,
              ),
              boxShadow: isEquipped
                  ? [
                      BoxShadow(
                        color: AppColors.statusGreen.withValues(alpha: 0.15),
                        blurRadius: 16,
                      )
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isEquipped
                                ? [
                                    AppColors.statusGreen,
                                    AppColors.statusGreen.withValues(alpha: 0.5),
                                  ]
                                : [
                                    Colors.white12,
                                    Colors.white.withValues(alpha: 0.04),
                                  ],
                          ),
                        ),
                        child: Icon(
                          Icons.smart_toy_rounded,
                          size: 26,
                          color: isEquipped ? Colors.white : Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        name.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: isEquipped ? Colors.white : Colors.white54,
                          fontSize: 10,
                          fontWeight: isEquipped ? FontWeight.w800 : FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isEquipped) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.statusGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'EQUIPPED',
                            style: TextStyle(
                              color: AppColors.statusGreen,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebPortalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0E3A), Color(0xFF110C20)],
        ),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2FBE), Color(0xFF3A1078)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purpleAccent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.public_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Avatar Forge Web',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.statusGreen,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'forge.openclaw.com',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2FBE).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF7B2FBE)
                                .withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'SOON',
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Create new 3D avatars from scratch, mint them as Core NFTs on Solana, and browse the ERC-8004 identity rental marketplace.',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 18),
                // Feature chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Mint VRM NFT', Icons.auto_fix_high_rounded),
                    _chip('Rent Identity', Icons.key_rounded),
                    _chip('Browse Market', Icons.storefront_rounded),
                    _chip('On-Chain Forge', Icons.link_rounded),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening forge.openclaw.com...'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.purpleAccent.withValues(alpha: 0.15),
                      foregroundColor: Colors.purpleAccent.shade100,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                            color: Colors.purpleAccent.withValues(alpha: 0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.open_in_new_rounded, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'OPEN WEB PORTAL',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.purpleAccent.shade100),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildChainBadge() {
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: Colors.purpleAccent.withValues(alpha: 0.25)),
          color: Colors.purpleAccent.withValues(alpha: 0.07),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch_rounded,
                color: Colors.purpleAccent.shade100, size: 16),
            const SizedBox(width: 8),
            Text(
              'Powered by AgentVRM · Solana',
              style: GoogleFonts.outfit(
                color: Colors.purpleAccent.shade100,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
