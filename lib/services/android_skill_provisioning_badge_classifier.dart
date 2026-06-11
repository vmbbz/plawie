class AndroidSkillProvisioningBadgeOverride {
  final String status;
  final String label;
  final String detail;

  const AndroidSkillProvisioningBadgeOverride({
    required this.status,
    required this.label,
    required this.detail,
  });
}

AndroidSkillProvisioningBadgeOverride? classifyAndroidSkillProvisioningBadge(
  Map<String, dynamic> skill,
) {
  final androidSupport = skill['androidSupport']?.toString() ?? '';
  final runtimeStatus = skill['runtimeStatus']?.toString() ?? '';
  final unsupportedReason = skill['unsupportedReason']?.toString().trim() ?? '';

  if (skill['ready'] == true && runtimeStatus == 'app_native_ready') {
    return const AndroidSkillProvisioningBadgeOverride(
      status: 'app_native_ready',
      label: 'READY',
      detail: 'Android app-native path ready',
    );
  }

  return switch (androidSupport) {
    'unsupported_on_android' => AndroidSkillProvisioningBadgeOverride(
        status: androidSupport,
        label: 'OUTSIDE GTM',
        detail: unsupportedReason.isNotEmpty
            ? unsupportedReason
            : 'Not supported by Android native runtime.',
      ),
    'manual_proot_compat' => AndroidSkillProvisioningBadgeOverride(
        status: androidSupport,
        label: 'MANUAL PROOT',
        detail: unsupportedReason.isNotEmpty
            ? unsupportedReason
            : 'Available only through a manual PRoot compatibility path.',
      ),
    'hidden_desktop_only' => AndroidSkillProvisioningBadgeOverride(
        status: androidSupport,
        label: 'DESKTOP ONLY',
        detail: unsupportedReason.isNotEmpty
            ? unsupportedReason
            : 'desktop-only skill hidden from the Android GTM lane.',
      ),
    _ => null,
  };
}
