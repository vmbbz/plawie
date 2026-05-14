import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app.dart';
import '../providers/node_provider.dart';
import '../services/preferences_service.dart';
import '../widgets/node_controls.dart';
import '../widgets/glass_card.dart';
import '../models/node_state.dart';

class NodeScreen extends StatefulWidget {
  const NodeScreen({super.key});

  @override
  State<NodeScreen> createState() => _NodeScreenState();
}

class _NodeScreenState extends State<NodeScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLocal = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = PreferencesService();
    await prefs.init();
    final host = prefs.nodeGatewayHost ?? '127.0.0.1';
    final port = prefs.nodeGatewayPort ?? 18789;
    final token = prefs.nodeGatewayToken ?? '';
    setState(() {
      _isLocal = host == '127.0.0.1' || host == 'localhost';
      _hostController.text = _isLocal ? '' : host;
      _portController.text = _isLocal ? '' : '$port';
      _tokenController.text = _isLocal ? '' : token;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const NebulaBg(),
          CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: _loading
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator(color: AppColors.statusGreen)),
                      )
                    : Consumer<NodeProvider>(
                        builder: (context, provider, _) {
                          final state = provider.state;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Node status section — clean and functional
                                const NodeControls(),
                                const SizedBox(height: 24),

                                _sectionLabel('GATEWAY CONNECTION'),
                                const SizedBox(height: 12),
                                // Pro configuration block
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: Column(
                                    children: [
                                      _glassRadio('Local Gateway', 'Auto-pair with gateway on this device', true, state),
                                      _glassRadio('Remote Gateway', 'Connect to a gateway on another device', false, state),
                                      if (!_isLocal) ...[
                                        const SizedBox(height: 16),
                                        _darkField(_hostController, 'Gateway Host', '192.168.1.100', Icons.dns_rounded),
                                        const SizedBox(height: 12),
                                        _darkField(_portController, 'Gateway Port', '18789', Icons.router_rounded, isNumber: true),
                                        const SizedBox(height: 12),
                                        _darkField(_tokenController, 'Gateway Token', 'Paste token from dashboard URL', Icons.key_rounded, obscure: true),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: _primaryBtn(
                                            'CONNECT',
                                            Icons.link_rounded,
                                            AppColors.statusGreen,
                                            () {
                                              final host = _hostController.text.trim();
                                              final port = int.tryParse(_portController.text.trim()) ?? 18789;
                                              final token = _tokenController.text.trim();
                                              if (host.isNotEmpty) {
                                                provider.connectRemote(host, port, token: token.isNotEmpty ? token : null);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                if (_isLocal) ...[
                                  const SizedBox(height: 32),
                                  _sectionLabel('RESCUE MODE'),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.gpp_maybe_rounded, color: Colors.redAccent.withValues(alpha: 0.7), size: 18),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Handshake Recovery',
                                              style: GoogleFonts.outfit(color: Colors.redAccent.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w700),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'If the node is stuck in a pairing loop or reporting invalid credentials, regenerating the token will reset the secure channel. All active sessions will be terminated.',
                                          style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                                        ),
                                        const SizedBox(height: 20),
                                        _primaryBtn(
                                          'REGENERATE AUTH TOKEN', 
                                          Icons.security_update_warning_rounded, 
                                          Colors.redAccent.withValues(alpha: 0.8), 
                                          () => _showRefreshWarning(context, provider)
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                if (state.pairingCode != null) ...[
                                  const SizedBox(height: 20),
                                  _sectionLabel('PAIRING CODE'),
                                  const SizedBox(height: 10),
                                  GlassCard(
                                    accentColor: AppColors.statusAmber,
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      children: [
                                        Icon(Icons.qr_code_2_rounded, color: AppColors.statusAmber, size: 48),
                                        const SizedBox(height: 12),
                                        Text('Approve this code on the gateway:', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
                                        const SizedBox(height: 12),
                                        SelectableText(
                                          state.pairingCode!,
                                          style: GoogleFonts.firaCode(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.statusAmber,
                                            letterSpacing: 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 20),
                                _sectionLabel('CAPABILITIES'),
                                const SizedBox(height: 10),
                                _capabilitiesGrid(),

                                if (state.deviceId != null) ...[
                                  const SizedBox(height: 24),
                                  _sectionLabel('DEVICE IDENTITY'),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.06),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.fingerprint, color: Colors.white54, size: 20),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: SelectableText(
                                            state.deviceId!,
                                            style: GoogleFonts.firaCode(fontSize: 11, color: Colors.white54),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _sectionLabel('NODE LOGS'),
                                    GestureDetector(
                                      onTap: () {
                                        if (state.logs.isNotEmpty) {
                                          Clipboard.setData(ClipboardData(text: state.logs.join('\n')));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Logs copied'), duration: Duration(seconds: 1)),
                                          );
                                        }
                                      },
                                      child: Icon(Icons.copy_all_rounded, size: 16, color: Colors.white38),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: SizedBox(
                                    height: 180,
                                    child: state.logs.isEmpty
                                        ? Center(child: Text('No logs yet', style: TextStyle(color: Colors.white24, fontSize: 13)))
                                        : ListView.builder(
                                            reverse: true,
                                            itemCount: state.logs.length,
                                            itemBuilder: (context, index) {
                                              final log = state.logs[state.logs.length - 1 - index];
                                              return Text(
                                                log,
                                                style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white54),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRefreshWarning(BuildContext context, NodeProvider provider) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.statusAmber.withValues(alpha: 0.2)),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.statusAmber),
              const SizedBox(width: 12),
              Text('Security Warning', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Text(
            'Refreshing the gateway token will invalidate all current connections to this gateway. \n\nOnly proceed if the node is stuck or you are seeing "Invalid Token" errors.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600)),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  provider.refreshToken();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusAmber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('REFRESH', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 90,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/app_icon_official.svg', width: 22, height: 22, // Consistency with Dashboard
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          const SizedBox(width: 12),
          Text('NODE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2.0, color: Colors.white)),
        ],
      ),
      centerTitle: true,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: FlexibleSpaceBar(background: Container(color: Colors.black.withValues(alpha: 0.2))),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.0,
        color: AppColors.statusGreen.withValues(alpha: 0.75),
      ),
    );
  }

  Widget _glassRadio(String title, String subtitle, bool value, NodeState state) {
    final isSelected = _isLocal == value;
    return GestureDetector(
      onTap: () => setState(() => _isLocal = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.statusGreen.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isSelected ? AppColors.statusGreen.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.statusGreen : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.statusGreen : Colors.white24,
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 10, color: Colors.black) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkField(TextEditingController ctrl, String label, String hint, IconData icon,
      {bool isNumber = false, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.firaCode(color: Colors.white70, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white38, fontSize: 12),
        hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white30, size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.statusGreen, width: 1.2),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        isDense: true,
      ),
    );
  }

  Widget _primaryBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _capabilitiesGrid() {
    const caps = [
      (Icons.camera_alt_rounded, 'Camera', 'Capture photos & clips', AppColors.statusGreen),
      (Icons.web_rounded, 'Canvas', 'Navigate web pages', Colors.blueAccent),
      (Icons.location_on_rounded, 'Location', 'GPS coordinates', Colors.orangeAccent),
      (Icons.screen_share_rounded, 'Screen', 'Record device display', Colors.cyanAccent),
      (Icons.flashlight_on_rounded, 'Torch', 'Toggle flashlight', AppColors.statusAmber),
      (Icons.vibration_rounded, 'Haptics', 'Vibration patterns', Colors.purpleAccent),
      (Icons.sensors_rounded, 'Sensors', 'Accel · Gyro · Mag', Colors.tealAccent),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: caps.map((c) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 50) / 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: c.$4.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.$4.withValues(alpha: 0.15), // Richer
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(c.$1, color: c.$4, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.$2, style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)), // Thicker font
                      Text(c.$3, style: TextStyle(color: Colors.white38, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.check_circle_rounded, color: AppColors.statusGreen.withValues(alpha: 0.6), size: 12), // Subtle check
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
