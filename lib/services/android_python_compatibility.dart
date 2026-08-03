/// Android-only Python requirement adjustments for skills whose upstream
/// dependency graph cannot run in the embedded Chaquopy runtime.
///
/// These overrides are deliberately skill-scoped. They must never silently
/// weaken an arbitrary third-party skill's requirements.
class AndroidPythonCompatibility {
  AndroidPythonCompatibility._();

  /// The Stocks script only uses the Pydantic v1-compatible API surface:
  /// BaseModel, Field, and validator. Pydantic v2 adds the native
  /// pydantic-core dependency, for which no approved Android wheel exists.
  static const stocksPydanticRequirement = 'pydantic>=1.10.15,<2.0.0';
  static const chaquopyPandasRequirement = 'pandas<2.2';

  static String requirementFor({
    required String skillId,
    required String packageName,
    required String requirement,
  }) {
    final normalizedPackage = packageName.trim().toLowerCase();
    if (normalizedPackage == 'pandas') {
      // Chaquopy 13.x cannot load pandas >=2.2 due to its incompatible C
      // extension ABI. Provisioning has always applied this constraint; the
      // readiness audit must evaluate the same effective requirement.
      return chaquopyPandasRequirement;
    }
    if (skillId.trim().toLowerCase() == 'stocks' &&
        normalizedPackage == 'pydantic' &&
        _requiresPydanticV2(requirement)) {
      return stocksPydanticRequirement;
    }
    return requirement;
  }

  static bool isOverride({
    required String skillId,
    required String packageName,
    required String originalRequirement,
    required String effectiveRequirement,
  }) {
    return effectiveRequirement != originalRequirement &&
        requirementFor(
              skillId: skillId,
              packageName: packageName,
              requirement: originalRequirement,
            ) ==
            effectiveRequirement;
  }

  static bool _requiresPydanticV2(String requirement) {
    final normalized = requirement.replaceAll(' ', '').toLowerCase();
    return normalized.contains('pydantic>=2') ||
        normalized.contains('pydantic>2') ||
        normalized.contains('pydantic==2') ||
        normalized.contains('pydantic~=2');
  }
}
