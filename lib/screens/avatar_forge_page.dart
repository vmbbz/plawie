import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/preferences_service.dart';

/// Avatar Forge — Create, mint, or rent 3D AI avatars as NFTs.
class AvatarForgePage extends StatefulWidget {
  const AvatarForgePage({super.key});

  @override
  State<AvatarForgePage> createState() => _AvatarForgePageState();
}

class _AvatarForgePageState extends State<AvatarForgePage> {
  final List<String> _myAvatars = [
    'default_avatar.vrm',
    'gemini.vrm',
    'boruto.vrm'
  ];
  String _equippedAvatar = 'default_avatar.vrm';

  @override
  void initState() {
    super.initState();
    _loadEquipped();
  }

  Future<void> _loadEquipped() async {
    final prefs = PreferencesService();
    await prefs.init();
    setState(() {
      _equippedAvatar = prefs.selectedAvatar;
    });
  }

  Future<void> _equipAvatar(String avatar) async {
    final prefs = PreferencesService();
    await prefs.init();
    await prefs.saveSelectedAvatar(avatar);
    setState(() {
      _equippedAvatar = avatar;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Equipped ${avatar.split('.').first}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'AVATAR FORGE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1B0A2E),
              Color(0xFF0D1B2A),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero section
                _buildHeroSection(),
                const SizedBox(height: 32),

                // My Library
                _buildSectionTitle('MY LIBRARY', Icons.grid_view, Colors.greenAccent),
                const SizedBox(height: 12),
                _buildLibraryGrid(),
                const SizedBox(height: 32),

                // Web Portal CTA
                _buildSectionTitle('WEB PORTAL', Icons.public, Colors.purpleAccent),
                const SizedBox(height: 12),
                _buildWebPortalCard(context),
                const SizedBox(height: 32),

                // Coming soon badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                      color: Colors.purpleAccent.withOpacity(0.08),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rocket_launch, color: Colors.purpleAccent.shade100, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Powered by AgentVRM on Solana',
                          style: TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: _myAvatars.length,
      itemBuilder: (context, index) {
        final avatar = _myAvatars[index];
        final isEquipped = avatar == _equippedAvatar;
        final name = avatar.split('.').first;

        return GestureDetector(
          onTap: () => _equipAvatar(avatar),
          child: Container(
            decoration: BoxDecoration(
              color: isEquipped ? Colors.greenAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEquipped ? Colors.greenAccent : Colors.white.withOpacity(0.1),
                width: isEquipped ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person,
                  size: 40,
                  color: isEquipped ? Colors.greenAccent : Colors.white54,
                ),
                const SizedBox(height: 8),
                Text(
                  name.toUpperCase(),
                  style: TextStyle(
                    color: isEquipped ? Colors.white : Colors.white70,
                    fontSize: 10,
                    fontWeight: isEquipped ? FontWeight.bold : FontWeight.normal,
                    letterSpacing: 1.0,
                  ),
                ),
                if (isEquipped) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('EQUIPPED', style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                  )
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF11001C)],
        ),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.purpleAccent, Colors.deepPurple.shade900],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purpleAccent.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Avatar Forge',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your on-chain identities.\nEquip local avocados or visit the web portal to mint.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }

  Widget _buildWebPortalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(colors: [Color(0xFF7B2FBE), Color(0xFF3A1078)]),
                      ),
                      child: const Icon(Icons.public, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Avatar Forge Web',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'forge.openclaw.com',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Visit the Avatar Forge web portal to create new 3D avatars from scratch, mint them as Core NFTs on Solana, and browse the rental marketplace.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening forge.openclaw.com...')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent.withOpacity(0.2),
                      foregroundColor: Colors.purpleAccent.shade100,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('OPEN WEB PORTAL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
