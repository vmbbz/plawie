import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../providers/gateway_provider.dart';
import '../../../services/android_skill_config_form_model.dart';
import '../../../services/skill_provisioning_service.dart';

class AndroidSkillConfigSheet extends StatefulWidget {
  final AndroidSkillConfigFormModel model;

  const AndroidSkillConfigSheet({
    super.key,
    required this.model,
  });

  @override
  State<AndroidSkillConfigSheet> createState() =>
      _AndroidSkillConfigSheetState();
}

class _AndroidSkillConfigSheetState extends State<AndroidSkillConfigSheet> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _obscure = {};
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final key in widget.model.allKeys) {
      _controllers[key] = TextEditingController();
      _obscure[key] = widget.model.envKeys.contains(key);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _apply() async {
    final missing = widget.model.allKeys
        .where((key) => _controllers[key]!.text.trim().isEmpty)
        .toList(growable: false);
    if (missing.isNotEmpty) {
      setState(() => _error = 'Missing values: ${missing.join(', ')}');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final gateway = Provider.of<GatewayProvider>(context, listen: false);
      final envValues = <String, String>{
        for (final key in widget.model.envKeys)
          key: _controllers[key]!.text.trim(),
      };
      final configValues = <String, dynamic>{
        for (final key in widget.model.configKeys)
          key: _controllers[key]!.text.trim(),
      };
      final report = await gateway.configureAndroidDefaultSkill(
        skillId: widget.model.skillId,
        envValues: envValues,
        configValues: configValues,
      );
      if (!mounted) return;
      final result = report.results.isEmpty ? null : report.results.first;
      final ready = result?.status == SkillProvisioningStatus.ready ||
          result?.status == SkillProvisioningStatus.satisfied;
      final gate = result?.primaryGate ??
          result?.status.wireName ??
          widget.model.runtimeGateLabel;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ready
                ? '${widget.model.skillId} config applied.'
                : '${widget.model.skillId} config saved; gate: $gate.',
          ),
          backgroundColor:
              ready ? AppColors.statusGreen : AppColors.statusAmber,
        ),
      );
      Navigator.of(context).pop(report);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Save failed: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
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
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.statusAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.statusAmber.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Icon(
                      Icons.key_rounded,
                      color: AppColors.statusAmber,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.skillId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Runtime gate: ${model.runtimeGateLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!model.configOnlyCanSatisfy) ...[
                const SizedBox(height: 14),
                _Notice(
                  color: AppColors.statusAmber,
                  icon: Icons.report_problem_rounded,
                  text:
                      'Config can be saved, but this skill still has a native runtime gate.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                _Notice(
                  color: AppColors.statusRed,
                  icon: Icons.error_outline_rounded,
                  text: _error!,
                ),
              ],
              if (model.envKeys.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionLabel('ENV CREDENTIALS'),
                const SizedBox(height: 8),
                for (final key in model.envKeys) _field(key, secret: true),
              ],
              if (model.configKeys.isNotEmpty) ...[
                const SizedBox(height: 14),
                _SectionLabel('CONFIG VALUES'),
                const SizedBox(height: 8),
                for (final key in model.configKeys) _field(key),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _apply,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isSaving ? 'Applying' : 'Apply Config'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String key, {bool secret = false}) {
    final isObscured = _obscure[key] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _controllers[key],
        obscureText: secret && isObscured,
        enableSuggestions: !secret,
        autocorrect: false,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: key,
          labelStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(
            secret ? Icons.key_rounded : Icons.tune_rounded,
            color: secret ? AppColors.statusAmber : Colors.cyanAccent,
            size: 18,
          ),
          suffixIcon: secret
              ? IconButton(
                  tooltip: isObscured ? 'Show value' : 'Hide value',
                  icon: Icon(
                    isObscured
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _obscure[key] = !isObscured);
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.055),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.statusAmber),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.52),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Notice({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
