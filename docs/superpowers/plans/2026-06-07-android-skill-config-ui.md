# Android Skill Config UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a GTM-quality Android Skills config wizard with service-aware fields for all current `needs_config` default skills.

**Architecture:** Keep the existing readiness -> config sheet -> `GatewayProvider` -> `SkillProvisioningService` flow. Add typed field metadata and a catalog to turn raw required keys into polished form fields, then update the bottom sheet to render those fields, validate them, and split env/config payloads.

**Tech Stack:** Flutter, Dart, Provider, existing OpenClaw readiness/provisioning services, Flutter widget tests.

---

## File Structure

- Modify: `lib/services/android_skill_config_form_model.dart`
  - Add `AndroidSkillConfigFieldModel`, target/input enums, grouped field access,
    catalog lookup, and fallback metadata.
- Modify: `lib/screens/management/skills/android_skill_config_sheet.dart`
  - Render model fields, grouped sections, typed controls, validation, and
    `Save & Check`.
- Modify: `test/android_skill_config_form_model_test.dart`
  - Add catalog/fallback coverage.
- Create: `test/android_skill_config_sheet_test.dart`
  - Add widget-level coverage for labels, secret masking, validation, and
    env/config payload splitting.
- Modify: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`
  - Record the wizard implementation and proof after tests/build/device checks.

## Task 1: Field Model Tests

**Files:**
- Modify: `test/android_skill_config_form_model_test.dart`
- Modify after red: `lib/services/android_skill_config_form_model.dart`

- [ ] **Step 1: Add failing Slack metadata test**

Append this test case to `test/android_skill_config_form_model_test.dart`:

```dart
test('slack config form exposes service-aware credential and channel fields', () {
  final readiness = {
    'skills': [
      {
        'skillId': 'slack',
        'androidSupport': 'needs_config',
        'requiredConfig': ['SLACK_BOT_TOKEN', 'channels.slack'],
        'primaryGate': 'missing_native_config',
      },
    ],
  };

  final form = AndroidSkillConfigFormModel.fromReadiness(readiness, 'slack')!;

  expect(form.title, 'Slack');
  expect(form.fields.map((field) => field.key), [
    'SLACK_BOT_TOKEN',
    'channels.slack',
  ]);

  final token = form.fields.firstWhere((field) => field.key == 'SLACK_BOT_TOKEN');
  expect(token.label, 'Bot token');
  expect(token.group, 'Credentials');
  expect(token.target, AndroidSkillConfigFieldTarget.env);
  expect(token.inputKind, AndroidSkillConfigInputKind.secret);
  expect(token.secret, isTrue);

  final channel = form.fields.firstWhere((field) => field.key == 'channels.slack');
  expect(channel.label, 'Default Slack channel');
  expect(channel.group, 'Workspace');
  expect(channel.target, AndroidSkillConfigFieldTarget.config);
  expect(channel.inputKind, AndroidSkillConfigInputKind.channelId);
  expect(channel.secret, isFalse);
});
```

- [ ] **Step 2: Run test and verify RED**

Run:

```powershell
flutter test test/android_skill_config_form_model_test.dart --no-pub
```

Expected: FAIL because `title`, `fields`, `AndroidSkillConfigFieldTarget`, and
`AndroidSkillConfigInputKind` do not exist yet.

- [ ] **Step 3: Add failing MCPorter, Voice Call, and fallback tests**

Append these tests:

```dart
test('mcporter fields use URL endpoint and secret token metadata', () {
  final readiness = {
    'skills': [
      {
        'skillId': 'mcporter',
        'androidSupport': 'needs_config',
        'requiredConfig': ['MCPORTER_ENDPOINT', 'MCPORTER_TOKEN'],
        'primaryGate': 'missing_native_config',
      },
    ],
  };

  final form = AndroidSkillConfigFormModel.fromReadiness(readiness, 'mcporter')!;
  final endpoint =
      form.fields.firstWhere((field) => field.key == 'MCPORTER_ENDPOINT');
  final token = form.fields.firstWhere((field) => field.key == 'MCPORTER_TOKEN');

  expect(endpoint.label, 'MCPorter endpoint');
  expect(endpoint.inputKind, AndroidSkillConfigInputKind.url);
  expect(endpoint.secret, isFalse);
  expect(token.label, 'MCPorter token');
  expect(token.inputKind, AndroidSkillConfigInputKind.secret);
  expect(token.secret, isTrue);
});

test('voice call fields expose provider choices and account metadata', () {
  final readiness = {
    'skills': [
      {
        'skillId': 'voice-call',
        'androidSupport': 'needs_config',
        'requiredConfig': ['VOICE_CALL_PROVIDER', 'VOICE_CALL_ACCOUNT'],
        'primaryGate': 'missing_native_config',
      },
    ],
  };

  final form =
      AndroidSkillConfigFormModel.fromReadiness(readiness, 'voice-call')!;
  final provider =
      form.fields.firstWhere((field) => field.key == 'VOICE_CALL_PROVIDER');
  final account =
      form.fields.firstWhere((field) => field.key == 'VOICE_CALL_ACCOUNT');

  expect(provider.inputKind, AndroidSkillConfigInputKind.provider);
  expect(provider.enumOptions, ['twilio', 'telnyx', 'custom']);
  expect(account.inputKind, AndroidSkillConfigInputKind.accountId);
  expect(account.secret, isFalse);
});

test('unknown required config keys get safe fallback metadata', () {
  final readiness = {
    'skills': [
      {
        'skillId': 'custom-service',
        'androidSupport': 'needs_config',
        'requiredConfig': ['CUSTOM_API_KEY', 'channels.custom'],
        'primaryGate': 'missing_native_config',
      },
    ],
  };

  final form =
      AndroidSkillConfigFormModel.fromReadiness(readiness, 'custom-service')!;
  final apiKey = form.fields.firstWhere((field) => field.key == 'CUSTOM_API_KEY');
  final channel =
      form.fields.firstWhere((field) => field.key == 'channels.custom');

  expect(form.title, 'Custom Service');
  expect(apiKey.target, AndroidSkillConfigFieldTarget.env);
  expect(apiKey.inputKind, AndroidSkillConfigInputKind.secret);
  expect(apiKey.secret, isTrue);
  expect(channel.target, AndroidSkillConfigFieldTarget.config);
  expect(channel.inputKind, AndroidSkillConfigInputKind.text);
  expect(channel.secret, isFalse);
});
```

- [ ] **Step 4: Run test and verify RED**

Run:

```powershell
flutter test test/android_skill_config_form_model_test.dart --no-pub
```

Expected: FAIL for missing model/catalog APIs.

## Task 2: Field Model Implementation

**Files:**
- Modify: `lib/services/android_skill_config_form_model.dart`
- Test: `test/android_skill_config_form_model_test.dart`

- [ ] **Step 1: Add enums and field model**

Add above `AndroidSkillConfigFormModel`:

```dart
enum AndroidSkillConfigFieldTarget { env, config }

enum AndroidSkillConfigInputKind {
  secret,
  text,
  url,
  channelId,
  accountId,
  provider,
}

class AndroidSkillConfigFieldModel {
  final String key;
  final AndroidSkillConfigFieldTarget target;
  final String label;
  final String helper;
  final String inputHint;
  final String group;
  final AndroidSkillConfigInputKind inputKind;
  final bool secret;
  final bool required;
  final List<String> enumOptions;
  final String? validationPattern;

  const AndroidSkillConfigFieldModel({
    required this.key,
    required this.target,
    required this.label,
    required this.helper,
    required this.inputHint,
    required this.group,
    required this.inputKind,
    required this.secret,
    required this.required,
    this.enumOptions = const <String>[],
    this.validationPattern,
  });
}
```

- [ ] **Step 2: Extend form model constructor and getters**

Add fields:

```dart
final String title;
final List<AndroidSkillConfigFieldModel> fields;
```

Add grouped getter:

```dart
Map<String, List<AndroidSkillConfigFieldModel>> get groupedFields {
  final grouped = <String, List<AndroidSkillConfigFieldModel>>{};
  for (final field in fields) {
    grouped.putIfAbsent(field.group, () => <AndroidSkillConfigFieldModel>[]);
    grouped[field.group]!.add(field);
  }
  return grouped;
}
```

Keep `envKeys`, `configKeys`, `allKeys`, and `hasFields` unchanged for callers.

- [ ] **Step 3: Add catalog lookup**

Add a private `_fieldFor` helper that returns explicit metadata for the keys in
the spec. Use skill-specific overrides for Slack channel and service names. Use
fallback helpers for unknown keys.

Minimum required entries:

```dart
case 'SLACK_BOT_TOKEN':
  return _envSecret(key, label: 'Bot token', group: 'Credentials');
case 'channels.slack':
  return _configField(
    key,
    label: 'Default Slack channel',
    group: 'Workspace',
    inputKind: AndroidSkillConfigInputKind.channelId,
  );
case 'MCPORTER_ENDPOINT':
  return _envField(
    key,
    label: 'MCPorter endpoint',
    group: 'Connection',
    inputKind: AndroidSkillConfigInputKind.url,
  );
case 'VOICE_CALL_PROVIDER':
  return _envField(
    key,
    label: 'Provider',
    group: 'Provider',
    inputKind: AndroidSkillConfigInputKind.provider,
    enumOptions: const ['twilio', 'telnyx', 'custom'],
  );
```

Also cover the remaining current config keys from the spec.

- [ ] **Step 4: Update `fromSkill` to create fields**

After splitting `requiredConfig`, build:

```dart
final skillId = skill['skillId']?.toString().trim() ?? 'unknown';
final fields = requiredConfig
    .map((key) => _fieldFor(skillId, key))
    .toList(growable: false);
```

Pass `title: _titleForSkill(skillId)` and `fields: fields` to the constructor.

- [ ] **Step 5: Run model tests and verify GREEN**

Run:

```powershell
flutter test test/android_skill_config_form_model_test.dart --no-pub
```

Expected: all tests in that file PASS.

- [ ] **Step 6: Commit model round**

Run:

```powershell
git add lib/services/android_skill_config_form_model.dart test/android_skill_config_form_model_test.dart
git commit -m "Add Android skill config field metadata"
```

## Task 3: Config Sheet Widget Tests

**Files:**
- Create: `test/android_skill_config_sheet_test.dart`
- Modify after red: `lib/screens/management/skills/android_skill_config_sheet.dart`

- [ ] **Step 1: Add widget test for known labels and secret masking**

Create `test/android_skill_config_sheet_test.dart` with a minimal provider-backed
test harness. Use a fake or mockable gateway provider only if the current
`GatewayProvider` constructor makes direct use impractical; otherwise test the
rendering without pressing save.

Required assertions:

```dart
expect(find.text('Slack'), findsOneWidget);
expect(find.text('Bot token'), findsOneWidget);
expect(find.text('Default Slack channel'), findsOneWidget);
expect(find.byTooltip('Show value'), findsOneWidget);
expect(find.text('SLACK_BOT_TOKEN'), findsNothing);
```

- [ ] **Step 2: Add widget test for validation**

Required assertions:

```dart
await tester.tap(find.text('Save & Check'));
await tester.pump();
expect(find.textContaining('Missing values'), findsOneWidget);
expect(find.textContaining('Bot token'), findsOneWidget);
expect(find.textContaining('Default Slack channel'), findsOneWidget);
```

- [ ] **Step 3: Run widget test and verify RED**

Run:

```powershell
flutter test test/android_skill_config_sheet_test.dart --no-pub
```

Expected: FAIL because the sheet still renders raw key sections and `Apply
Config`.

## Task 4: Config Sheet Implementation

**Files:**
- Modify: `lib/screens/management/skills/android_skill_config_sheet.dart`
- Test: `test/android_skill_config_sheet_test.dart`

- [ ] **Step 1: Initialize controllers from `model.fields`**

Replace loops over `model.allKeys` with `model.fields`. Use field keys for
controllers and field `secret` for `_obscure`.

- [ ] **Step 2: Validate using field labels**

Replace missing-key validation with:

```dart
final missing = widget.model.fields
    .where((field) => field.required)
    .where((field) => _controllers[field.key]!.text.trim().isEmpty)
    .toList(growable: false);
```

Error text should list field labels and avoid values:

```dart
setState(() {
  _error = 'Missing values: ${missing.map((field) => field.label).join(', ')}';
});
```

Add URL validation for fields with `AndroidSkillConfigInputKind.url`:

```dart
final invalidUrls = widget.model.fields
    .where((field) => field.inputKind == AndroidSkillConfigInputKind.url)
    .where((field) {
      final value = _controllers[field.key]!.text.trim();
      return value.isNotEmpty &&
          !value.startsWith('http://') &&
          !value.startsWith('https://');
    })
    .toList(growable: false);
```

- [ ] **Step 3: Split payloads by field target**

Build env/config maps from fields:

```dart
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
```

- [ ] **Step 4: Render grouped sections**

Use `model.groupedFields.entries` and render `_SectionLabel(group.toUpperCase())`
with `_field(field)`. Change button text to `Save & Check`.

- [ ] **Step 5: Render field metadata**

Update `_field` signature:

```dart
Widget _field(AndroidSkillConfigFieldModel field)
```

Use:

```dart
labelText: field.label
helperText: field.helper.isEmpty ? null : field.helper
hintText: field.inputHint.isEmpty ? null : field.inputHint
obscureText: field.secret && isObscured
keyboardType: field.inputKind == AndroidSkillConfigInputKind.url
    ? TextInputType.url
    : TextInputType.text
```

For `provider` fields with `enumOptions`, use a compact dropdown instead of a
free text field.

- [ ] **Step 6: Run widget tests and verify GREEN**

Run:

```powershell
flutter test test/android_skill_config_sheet_test.dart --no-pub
```

Expected: widget tests PASS.

- [ ] **Step 7: Run combined config tests**

Run:

```powershell
flutter test test/android_skill_config_form_model_test.dart test/android_skill_config_sheet_test.dart --no-pub
```

Expected: both files PASS.

- [ ] **Step 8: Commit sheet round**

Run:

```powershell
git add lib/screens/management/skills/android_skill_config_sheet.dart test/android_skill_config_sheet_test.dart
git commit -m "Upgrade Android skill config sheet"
```

## Task 5: Verification and GTM Doc Update

**Files:**
- Modify: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`

- [ ] **Step 1: Run focused readiness/config tests**

Run:

```powershell
flutter test test/android_skill_config_form_model_test.dart test/android_skill_config_sheet_test.dart test/android_skill_readiness_view_model_test.dart --no-pub
```

Expected: all selected tests PASS.

- [ ] **Step 2: Run analyzer for touched Dart files**

Run:

```powershell
flutter analyze lib/services/android_skill_config_form_model.dart lib/screens/management/skills/android_skill_config_sheet.dart test/android_skill_config_form_model_test.dart test/android_skill_config_sheet_test.dart
```

Expected: no issues for touched files.

- [ ] **Step 3: Build debug APK at milestone**

Run only after tests/analyzer pass:

```powershell
flutter build apk --debug
```

Expected: build exits 0. Do not stage APKs or generated build reports.

- [ ] **Step 4: Device smoke when phone is connected**

Use the already preferred forwarding path:

```powershell
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb forward tcp:8765 tcp:8765
```

Open the app Skills page and verify:

```text
Slack config chip opens a service-aware form.
Bot token is masked.
Default Slack channel is visible as a Workspace field.
Save & Check calls the existing provisioning flow.
```

- [ ] **Step 5: Update GTM readiness doc**

Add a concise proof note to
`docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md` with:

```text
Config wizard status:
- all 14 Class B config skills have service-aware fields or safe fallback
- Slack token + channel are actionable in-app
- save path remains GatewayProvider -> SkillProvisioningService
- test/analyzer/build/device proof recorded
- next adapter target remains Slack
```

- [ ] **Step 6: Commit verification/doc round**

Run:

```powershell
git add docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md
git commit -m "Document Android skill config wizard progress"
```

## Self-Review

- Spec coverage: model metadata, sheet UX, security, tests, gateway/provisioning
  flow, and GTM proof are covered by Tasks 1-5.
- Scope: this plan intentionally stops before Slack adapter implementation.
  Slack remains the next adapter after the config wizard milestone.
- Placeholder scan: no task uses deferred work language.
- Type consistency: field enums and model properties are introduced before
  widget code uses them.
