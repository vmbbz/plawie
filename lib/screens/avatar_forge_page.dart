import 'package:flutter/material.dart';
import 'dart:ui';
import '../app.dart';

/// Avatar Forge — Create, mint, or rent 3D AI avatars as NFTs.
class AvatarForgePage extends StatelessWidget {
  const AvatarForgePage({super.key});

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

                // Action cards
                _buildSectionTitle('CREATE', Icons.auto_fix_high, Colors.purpleAccent),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: 'Forge New Avatar',
                  subtitle: 'Design a unique 3D VRM avatar for your AI agent',
                  description: 'Use our AI-powered generator to create a custom 3D avatar '
                      'from text descriptions or reference images. Your avatar will be '
                      'compatible with VRM standard and can be used across platforms.',
                  icon: Icons.brush,
                  gradient: const [Color(0xFF7B2FBE), Color(0xFF3A1078)],
                  steps: [
                    'Describe your avatar or upload a reference',
                    'AI generates a 3D VRM model',
                    'Preview and customize expressions',
                    'Export or mint as NFT',
                  ],
                ),
                const SizedBox(height: 16),

                _buildSectionTitle('MINT', Icons.diamond_outlined, Colors.cyanAccent),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: 'Mint as NFT',
                  subtitle: 'Own your avatar permanently on-chain',
                  description: 'Mint your custom avatar as an NFT on Solana. '
                      'Your avatar becomes a tradeable digital asset with provable '
                      'ownership. Includes full VRM file and metadata.',
                  icon: Icons.token,
                  gradient: const [Color(0xFF0891B2), Color(0xFF164E63)],
                  steps: [
                    'Connect your Solana wallet',
                    'Choose mint collection (Avatar Forge)',
                    'Set royalty percentage for rentals',
                    'Confirm transaction & mint',
                  ],
                ),
                const SizedBox(height: 16),

                _buildSectionTitle('RENT', Icons.storefront, Colors.amber),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  title: 'Rent from Marketplace',
                  subtitle: 'Browse avatars created by other agents',
                  description: 'Access the Avatar Forge marketplace to rent premium '
                      'avatars created by other users and AI bots. Pay per-day or '
                      'subscribe for unlimited access to curated collections.',
                  icon: Icons.shopping_bag_outlined,
                  gradient: const [Color(0xFFB45309), Color(0xFF78350F)],
                  steps: [
                    'Browse marketplace collections',
                    'Preview avatar in 3D viewer',
                    'Choose rental duration',
                    'Avatar appears in your library',
                  ],
                ),
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
                          'Powered by AgentVRM Protocol',
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
            'Create, own, and trade 3D AI avatars\nas digital assets on the blockchain',
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

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required List<Color> gradient,
    required List<String> steps,
  }) {
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
                        gradient: LinearGradient(colors: gradient),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
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
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ...steps.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: gradient),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
