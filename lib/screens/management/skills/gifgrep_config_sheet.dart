import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../providers/gateway_provider.dart';
import '../../../services/capabilities/native_env.dart';
import '../../../services/skill_provisioning_service.dart';

Future<bool?> showGifgrepConfigSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const GifgrepConfigSheet(),
  );
}

class GifgrepConfigSheet extends StatefulWidget {
  const GifgrepConfigSheet({super.key});

  @override
  State<GifgrepConfigSheet> createState() => _GifgrepConfigSheetState();
}

class _GifgrepConfigSheetState extends State<GifgrepConfigSheet> {
  final _giphyController = TextEditingController();
  final _klipyController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _obscureGiphy = true;
  bool _obscureKlipy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExistingValues();
  }

  Future<void> _loadExistingValues() async {
    final values = await Future.wait([
      NativeEnv.readFirst(['GIPHY_API_KEY']),
      NativeEnv.readFirst(['KLIPY_API_KEY']),
    ]);
    if (!mounted) return;
    _giphyController.text = values[0] ?? '';
    _klipyController.text = values[1] ?? '';
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _giphyController.dispose();
    _klipyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final values = <String, String>{};
    if (_giphyController.text.trim().isNotEmpty) {
      values['GIPHY_API_KEY'] = _giphyController.text.trim();
    }
    if (_klipyController.text.trim().isNotEmpty) {
      values['KLIPY_API_KEY'] = _klipyController.text.trim();
    }
    if (values.isEmpty) {
      setState(
          () => _error = 'Enter at least one provider key, or use Clear keys.');
      return;
    }
    await _apply(values: values);
  }

  Future<void> _clear() async {
    await _apply(
      clearKeys: const ['GIPHY_API_KEY', 'KLIPY_API_KEY'],
      closeAfter: true,
    );
  }

  Future<void> _apply({
    Map<String, String> values = const <String, String>{},
    List<String> clearKeys = const <String>[],
    bool closeAfter = false,
  }) async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final gateway = Provider.of<GatewayProvider>(context, listen: false);
      final report = await gateway.configureOptionalNativeEnvironment(
        skillId: 'gifgrep',
        values: values,
        clearKeys: clearKeys,
      );
      final unsupported = report.results.any((result) =>
          result.status == SkillProvisioningStatus.unsupportedNative);
      if (!mounted) return;
      if (unsupported) {
        setState(() => _error = 'The Native environment rejected this key.');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(closeAfter
              ? 'gifgrep provider keys cleared.'
              : 'gifgrep provider keys saved. Resend your search request.'),
          backgroundColor: AppColors.statusGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save gifgrep configuration.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 620),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1117),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  Icon(Icons.gif_box_rounded,
                      color: AppColors.statusAmber, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Configure gifgrep search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Online search needs one provider key. Local still frames and contact sheets remain key-free. Keys are stored only in the Native OpenClaw environment.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                _secretField(
                  controller: _giphyController,
                  label: 'GIPHY API key',
                  hint: 'Optional for GIPHY search',
                  obscure: _obscureGiphy,
                  onToggle: () =>
                      setState(() => _obscureGiphy = !_obscureGiphy),
                ),
                const SizedBox(height: 10),
                _secretField(
                  controller: _klipyController,
                  label: 'KLIPY API key',
                  hint: 'Optional for KLIPY/Tenor search',
                  obscure: _obscureKlipy,
                  onToggle: () =>
                      setState(() => _obscureKlipy = !_obscureKlipy),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(_saving ? 'Saving' : 'Save provider keys'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _saving ? null : _clear,
                  child: const Text('Clear saved provider keys'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _secretField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(obscure
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded),
        ),
      ),
    );
  }
}
