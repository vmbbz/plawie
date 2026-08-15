import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app.dart';
import '../models/optional_package.dart';
import '../services/package_service.dart';
import '../widgets/glass_card.dart';
import 'package_install_screen.dart';

/// Lists all optional packages with install/uninstall actions — dark glass redesign.
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  Map<String, bool> _statuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final statuses = await PackageService.checkAllStatuses();
    if (mounted) {
      setState(() {
        _statuses = statuses;
        _loading = false;
      });
    }
  }

  Future<void> _navigateToInstall(OptionalPackage package,
      {bool isUninstall = false}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) =>
              PackageInstallScreen(package: package, isUninstall: isUninstall)),
    );
    if (result == true) _refreshStatuses();
  }

  void _confirmUninstall(OptionalPackage package) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E0E14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Uninstall ${package.name}?',
            style: const TextStyle(color: Colors.white)),
        content: Text('This will remove ${package.name} from the environment.',
            style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToInstall(package, isUninstall: true);
            },
            child:
                Text('Uninstall', style: TextStyle(color: AppColors.statusRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prootPackages = OptionalPackage.prootRollbackExtras;
    final partnerSkills = OptionalPackage.partnerSkills;
    final installedCount =
        prootPackages.where((pkg) => _statuses[pkg.id] == true).length;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const NebulaBg(),
          CustomScrollView(
            slivers: [
              _buildAppBar(context, installedCount),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                  child: _loading
                      ? const SizedBox(
                          height: 200,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.statusGreen)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              accentColor: AppColors.statusGreen,
                              child: Row(
                                children: [
                                  Icon(Icons.extension_rounded,
                                      color: AppColors.statusGreen, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Native Node Gateway needs no downloadable Linux packages. These entries are PRoot rollback extras or partner skills.',
                                      style: GoogleFonts.outfit(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          fontSize: 13,
                                          height: 1.4),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.statusGreen
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: AppColors.statusGreen
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      '$installedCount / ${prootPackages.length}',
                                      style: GoogleFonts.outfit(
                                          color: AppColors.statusGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text('PROOT ROLLBACK EXTRAS',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  color: AppColors.statusGreen
                                      .withValues(alpha: 0.75),
                                )),
                            const SizedBox(height: 12),
                            ...prootPackages
                                .map((pkg) => _buildPackageCard(pkg)),
                            const SizedBox(height: 20),
                            Text('PARTNER SKILLS',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  color: Colors.white.withValues(alpha: 0.45),
                                )),
                            const SizedBox(height: 12),
                            ...partnerSkills
                                .map((pkg) => _buildPackageCard(pkg)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, int installedCount) {
    return SliverAppBar(
      expandedHeight: AppLayout.standardSliverHeaderHeight,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: Colors.white70, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/app_icon_official.svg',
              width: 18,
              height: 18,
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          const SizedBox(width: 10),
          Text('PACKAGES',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 3.0,
                  color: Colors.white)),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: Colors.white54, size: 20),
          onPressed: () {
            setState(() => _loading = true);
            _refreshStatuses();
          },
        ),
      ],
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: FlexibleSpaceBar(
              background:
                  Container(color: Colors.black.withValues(alpha: 0.2))),
        ),
      ),
    );
  }

  Widget _buildPackageCard(OptionalPackage package) {
    final canInstall = package.canInstallFromPackagesPage;
    final installed = canInstall && (_statuses[package.id] ?? false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        accentColor: installed ? AppColors.statusGreen : null,
        child: Row(
          children: [
            // Icon container
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: (installed ? AppColors.statusGreen : Colors.white)
                    .withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (installed ? AppColors.statusGreen : Colors.white)
                      .withValues(alpha: 0.15),
                ),
              ),
              child: Icon(package.icon,
                  color: installed ? AppColors.statusGreen : Colors.white54,
                  size: 20),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(package.name,
                          style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      if (installed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.statusGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.statusGreen
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text('INSTALLED',
                              style: GoogleFonts.outfit(
                                  color: AppColors.statusGreen,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(package.description,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          height: 1.4)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildScopePill(package.scopeLabel, package.color),
                      Text(package.estimatedSize,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(package.releaseNote,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.34),
                          fontSize: 10,
                          height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (!canInstall)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  color: Colors.white.withValues(alpha: 0.04),
                ),
                child: Text('Skills',
                    style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              )
            else if (installed)
              GestureDetector(
                onTap: () => _confirmUninstall(package),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.statusRed.withValues(alpha: 0.4)),
                    color: AppColors.statusRed.withValues(alpha: 0.06),
                  ),
                  child: Text('Remove',
                      style: GoogleFonts.outfit(
                          color: AppColors.statusRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              )
            else
              GestureDetector(
                onTap: () => _navigateToInstall(package),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(colors: [
                      AppColors.statusGreen,
                      AppColors.statusGreen.withValues(alpha: 0.75),
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.statusGreen.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Text('Install',
                      style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              color: color.withValues(alpha: 0.85),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4)),
    );
  }
}
