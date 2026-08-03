import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/android_python_compatibility.dart';

void main() {
  test('scopes the Pydantic v1 compatibility override to Stocks', () {
    expect(
      AndroidPythonCompatibility.requirementFor(
        skillId: 'stocks',
        packageName: 'pydantic',
        requirement: 'pydantic>=2.0.0',
      ),
      AndroidPythonCompatibility.stocksPydanticRequirement,
    );
    expect(
      AndroidPythonCompatibility.isOverride(
        skillId: 'stocks',
        packageName: 'pydantic',
        originalRequirement: 'pydantic>=2.0.0',
        effectiveRequirement:
            AndroidPythonCompatibility.stocksPydanticRequirement,
      ),
      isTrue,
    );
  });

  test('does not weaken other skills or unrelated packages', () {
    expect(
      AndroidPythonCompatibility.requirementFor(
        skillId: 'other-skill',
        packageName: 'pydantic',
        requirement: 'pydantic>=2.0.0',
      ),
      'pydantic>=2.0.0',
    );
    expect(
      AndroidPythonCompatibility.requirementFor(
        skillId: 'stocks',
        packageName: 'requests',
        requirement: 'requests>=2.28.0',
      ),
      'requests>=2.28.0',
    );
  });

  test('keeps the audit aligned with the Chaquopy pandas constraint', () {
    expect(
      AndroidPythonCompatibility.requirementFor(
        skillId: 'stocks',
        packageName: 'pandas',
        requirement: 'pandas>=2.2.0',
      ),
      AndroidPythonCompatibility.chaquopyPandasRequirement,
    );
  });
}
