import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../providers/gateway_provider.dart';
import '../../../services/android_skill_config_form_model.dart';
import '../../../services/skill_provisioning_service.dart';

typedef AndroidSkillConfigApply = Future<SkillProvisioningReport> Function({
  required String skillId,
  required Map<String, String> envValues,
  required Map<String, dynamic> configValues,
});

class AndroidSkillConfigSheet extends StatefulWidget {
  final AndroidSkillConfigFormModel model;
  final AndroidSkillConfigApply? applyConfig;

  const AndroidSkillConfigSheet({
    super.key,
    required this.model,
    this.applyConfig,
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
    for (final field in widget.model.fields) {
      _controllers[field.key] = TextEditingController(
        text: field.inputKind == AndroidSkillConfigInputKind.provider &&
                field.enumOptions.isNotEmpty
            ? field.enumOptions.first
            : '',
      );
      _obscure[field.key] = field.secret;
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
    final missing = widget.model.fields
        .where((field) => field.required)
        .where((field) => _controllers[field.key]!.text.trim().isEmpty)
        .toList(growable: false);
    if (missing.isNotEmpty) {
      setState(
        () => _error =
            'Missing values: ${missing.map((field) => field.label).join(', ')}',
      );
      return;
    }

    final invalidUrls = widget.model.fields
        .where((field) => field.inputKind == AndroidSkillConfigInputKind.url)
        .where((field) {
      final value = _controllers[field.key]!.text.trim();
      return value.isNotEmpty &&
          !value.startsWith('http://') &&
          !value.startsWith('https://');
    }).toList(growable: false);
    if (invalidUrls.isNotEmpty) {
      setState(
        () => _error =
            'Invalid URL: ${invalidUrls.map((field) => field.label).join(', ')}',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final envValues = <String, String>{
        for (final field in widget.model.fields)
          if (field.target == AndroidSkillConfigFieldTarget.env)
            field.key: _controllers[field.key]!.text.trim(),
      };
      final configValues = <String, dynamic>{
        for (final field in widget.model.fields)
          if (field.target == AndroidSkillConfigFieldTarget.config)
            field.key: _controllers[field.key]!.text.trim(),
      };
      final report = await _applyConfig(
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
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(report);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Save failed: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<SkillProvisioningReport> _applyConfig({
    required String skillId,
    required Map<String, String> envValues,
    required Map<String, dynamic> configValues,
  }) {
    final applyConfig = widget.applyConfig;
    if (applyConfig != null) {
      return applyConfig(
        skillId: skillId,
        envValues: envValues,
        configValues: configValues,
      );
    }
    final gateway = Provider.of<GatewayProvider>(context, listen: false);
    return gateway.configureAndroidDefaultSkill(
      skillId: skillId,
      envValues: envValues,
      configValues: configValues,
    );
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
                          model.title,
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
              for (final entry in model.groupedFields.entries) ...[
                const SizedBox(height: 18),
                _SectionLabel(entry.key.toUpperCase()),
                const SizedBox(height: 8),
                for (final field in entry.value) _field(field),
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
                  label: Text(_isSaving ? 'Checking' : 'Save & Check'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(AndroidSkillConfigFieldModel field) {
    if (field.inputKind == AndroidSkillConfigInputKind.provider &&
        field.enumOptions.isNotEmpty) {
      return _providerField(field);
    }

    final isObscured = _obscure[field.key] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: ValueKey('android-skill-config-field-${field.key}'),
        controller: _controllers[field.key],
        obscureText: field.secret && isObscured,
        enableSuggestions: !field.secret,
        autocorrect: false,
        keyboardType: _keyboardTypeFor(field),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: _inputDecoration(
          field,
          suffixIcon: field.secret
              ? IconButton(
                  tooltip: isObscured ? 'Show value' : 'Hide value',
                  icon: Icon(
                    isObscured
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _obscure[field.key] = !isObscured);
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _providerField(AndroidSkillConfigFieldModel field) {
    final current = _controllers[field.key]!.text.trim();
    final value =
        field.enumOptions.contains(current) ? current : field.enumOptions.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey('android-skill-config-field-${field.key}'),
        value: value,
        dropdownColor: const Color(0xFF181B23),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: _inputDecoration(field),
        items: [
          for (final option in field.enumOptions)
            DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() => _controllers[field.key]!.text = value);
        },
      ),
    );
  }

  InputDecoration _inputDecoration(
    AndroidSkillConfigFieldModel field, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: field.label,
      hintText: field.inputHint.isEmpty ? null : field.inputHint,
      helperText: field.helper.isEmpty ? null : field.helper,
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.62),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.28),
        fontSize: 12,
      ),
      helperStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.42),
        fontSize: 10,
      ),
      prefixIcon: Icon(
        _iconForField(field),
        color: _colorForField(field),
        size: 18,
      ),
      suffixIcon: suffixIcon,
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
        borderSide: BorderSide(color: _colorForField(field)),
      ),
    );
  }

  TextInputType _keyboardTypeFor(AndroidSkillConfigFieldModel field) {
    if (field.inputKind == AndroidSkillConfigInputKind.url) {
      return TextInputType.url;
    }
    return TextInputType.text;
  }

  IconData _iconForField(AndroidSkillConfigFieldModel field) {
    if (field.secret) return Icons.key_rounded;
    switch (field.inputKind) {
      case AndroidSkillConfigInputKind.url:
        return Icons.link_rounded;
      case AndroidSkillConfigInputKind.channelId:
        return Icons.tag_rounded;
      case AndroidSkillConfigInputKind.accountId:
        return Icons.badge_rounded;
      case AndroidSkillConfigInputKind.provider:
        return Icons.account_tree_rounded;
      case AndroidSkillConfigInputKind.secret:
      case AndroidSkillConfigInputKind.text:
        return Icons.tune_rounded;
    }
  }

  Color _colorForField(AndroidSkillConfigFieldModel field) {
    if (field.secret) return AppColors.statusAmber;
    if (field.inputKind == AndroidSkillConfigInputKind.url) {
      return Colors.lightBlueAccent;
    }
    return Colors.cyanAccent;
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
