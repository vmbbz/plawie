# Phase 6A Config Test Connections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Android fresh users save config-gated skill credentials and run safe service-aware connection checks from the Skills config sheet.

**Architecture:** Add a pure `AndroidSkillConfigTestPlan` model that maps each supported config-gated skill to an AgentSkillServer `/api/tools/execute` command and safe input payload. Add an executor service that posts only to the local AgentSkillServer bridge and normalizes success/failure without exposing secrets. Wire the config sheet to show a `Test Connection` action after a successful save when a plan exists.

**Tech Stack:** Flutter/Dart, `flutter_test`, `http`, existing `SkillProvisioningService`, existing `AndroidSkillConfigSheet`, existing AgentSkillServer tool execution contract.

---

### Task 1: Config Test Plan Model

**Files:**
- Create: `lib/services/android_skill_config_test_plan.dart`
- Create: `test/android_skill_config_test_plan_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/android_skill_config_test_plan_test.dart`:

```dart
import 'package:clawa/services/android_skill_config_test_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps safe config-gated skills to AgentSkillServer tool checks', () {
    final slack = AndroidSkillConfigTestPlan.forSkill('slack')!;
    expect(slack.skillId, 'slack');
    expect(slack.toolName, 'slack');
    expect(slack.input, {'source': 'android-skill-config-test'});
    expect(slack.buttonLabel, 'Test Connection');
    expect(slack.risk, AndroidSkillConfigTestRisk.safeRead);

    final github = AndroidSkillConfigTestPlan.forSkill('gh-issues')!;
    expect(github.toolName, 'github');
    expect(github.input, {'source': 'android-skill-config-test'});
    expect(github.successActionLabel, 'GitHub user');

    final notion = AndroidSkillConfigTestPlan.forSkill('notion')!;
    expect(notion.toolName, 'notion');
    expect(notion.input, {
      'source': 'android-skill-config-test',
      'query': 'OpenClaw',
      'limit': 1,
    });
    expect(notion.risk, AndroidSkillConfigTestRisk.queryRead);

    final whisper =
        AndroidSkillConfigTestPlan.forSkill('openai-whisper-api')!;
    expect(whisper.toolName, 'openai-whisper-api');
    expect(whisper.risk, AndroidSkillConfigTestRisk.billableRead);
    expect(whisper.input.keys, containsAll(['audioBase64', 'filename']));
    expect(whisper.input.values.join(' '), isNot(contains('OPENAI_API_KEY')));
  });

  test('does not offer connection checks for config-only placeholders yet', () {
    expect(AndroidSkillConfigTestPlan.forSkill('1password'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('ordercli'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('sag'), isNull);
    expect(AndroidSkillConfigTestPlan.forSkill('voice-call'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/android_skill_config_test_plan_test.dart`

Expected: FAIL because `android_skill_config_test_plan.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `lib/services/android_skill_config_test_plan.dart`:

```dart
import 'dart:convert';

enum AndroidSkillConfigTestRisk {
  safeRead,
  queryRead,
  billableRead,
}

class AndroidSkillConfigTestPlan {
  final String skillId;
  final String toolName;
  final Map<String, dynamic> input;
  final AndroidSkillConfigTestRisk risk;
  final String successActionLabel;
  final String buttonLabel;

  const AndroidSkillConfigTestPlan({
    required this.skillId,
    required this.toolName,
    required this.input,
    required this.risk,
    required this.successActionLabel,
    this.buttonLabel = 'Test Connection',
  });

  static AndroidSkillConfigTestPlan? forSkill(String skillId) {
    final normalized = _normalizeSkillId(skillId);
    const source = 'android-skill-config-test';
    switch (normalized) {
      case 'discord':
        return const AndroidSkillConfigTestPlan(
          skillId: 'discord',
          toolName: 'discord',
          input: {'source': source},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Discord bot',
        );
      case 'github':
      case 'gh-issues':
        return AndroidSkillConfigTestPlan(
          skillId: normalized,
          toolName: 'github',
          input: const {'source': source},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'GitHub user',
        );
      case 'goplaces':
        return const AndroidSkillConfigTestPlan(
          skillId: 'goplaces',
          toolName: 'goplaces',
          input: {'source': source, 'query': 'OpenClaw', 'limit': 1},
          risk: AndroidSkillConfigTestRisk.queryRead,
          successActionLabel: 'Google Places search',
        );
      case 'mcporter':
        return const AndroidSkillConfigTestPlan(
          skillId: 'mcporter',
          toolName: 'mcporter',
          input: {'source': source},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'MCPorter health',
        );
      case 'notion':
        return const AndroidSkillConfigTestPlan(
          skillId: 'notion',
          toolName: 'notion',
          input: {'source': source, 'query': 'OpenClaw', 'limit': 1},
          risk: AndroidSkillConfigTestRisk.queryRead,
          successActionLabel: 'Notion search',
        );
      case 'openai-whisper-api':
        return AndroidSkillConfigTestPlan(
          skillId: 'openai-whisper-api',
          toolName: 'openai-whisper-api',
          input: {
            'source': source,
            'audioBase64': _tinySilentWavBase64,
            'filename': 'openclaw-config-test.wav',
            'model': 'gpt-4o-mini-transcribe',
          },
          risk: AndroidSkillConfigTestRisk.billableRead,
          successActionLabel: 'OpenAI transcription',
        );
      case 'slack':
        return const AndroidSkillConfigTestPlan(
          skillId: 'slack',
          toolName: 'slack',
          input: {'source': source},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Slack auth',
        );
      case 'trello':
        return const AndroidSkillConfigTestPlan(
          skillId: 'trello',
          toolName: 'trello',
          input: {'source': source, 'limit': 1},
          risk: AndroidSkillConfigTestRisk.safeRead,
          successActionLabel: 'Trello boards',
        );
    }
    return null;
  }
}

String _normalizeSkillId(String value) =>
    value.trim().toLowerCase().replaceAll('_', '-');

final String _tinySilentWavBase64 = base64Encode(_tinySilentWavBytes);

const List<int> _tinySilentWavBytes = <int>[
  82, 73, 70, 70, 36, 0, 0, 0, 87, 65, 86, 69, 102, 109, 116, 32,
  16, 0, 0, 0, 1, 0, 1, 0, 64, 31, 0, 0, 128, 62, 0, 0,
  1, 0, 16, 0, 100, 97, 116, 97, 0, 0, 0, 0,
];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/android_skill_config_test_plan_test.dart`

Expected: PASS.

### Task 2: Local AgentSkillServer Test Executor

**Files:**
- Create: `lib/services/android_skill_config_test_service.dart`
- Create: `test/android_skill_config_test_service_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/android_skill_config_test_service_test.dart`:

```dart
import 'dart:convert';

import 'package:clawa/services/android_skill_config_test_plan.dart';
import 'package:clawa/services/android_skill_config_test_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts test plan to local AgentSkillServer tool execution route',
      () async {
    late Map<String, dynamic> capturedBody;
    final service = AndroidSkillConfigTestService(
      baseUri: Uri.parse('http://127.0.0.1:8765'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://127.0.0.1:8765/api/tools/execute');
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'ok': true,
            'payload': {'team': 'OpenClaw', 'token': 'must-not-leak'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.run(AndroidSkillConfigTestPlan.forSkill('slack')!);

    expect(capturedBody, {
      'name': 'slack',
      'input': {'source': 'android-skill-config-test'},
    });
    expect(result.ok, isTrue);
    expect(result.message, 'Slack auth check passed.');
    expect(result.safeSummary, contains('team'));
    expect(jsonEncode(result.toJson()), isNot(contains('must-not-leak')));
  });

  test('normalizes failed bridge results without leaking request input',
      () async {
    final service = AndroidSkillConfigTestService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ok': false,
            'error': {'message': 'Bad token xoxb-secret'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await service.run(AndroidSkillConfigTestPlan.forSkill('slack')!);

    expect(result.ok, isFalse);
    expect(result.message, 'Slack auth check failed.');
    expect(result.safeSummary, contains('Bad token'));
    expect(result.safeSummary, isNot(contains('xoxb-secret')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/android_skill_config_test_service_test.dart`

Expected: FAIL because `android_skill_config_test_service.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `lib/services/android_skill_config_test_service.dart` with:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'android_skill_config_test_plan.dart';

class AndroidSkillConfigTestResult {
  final bool ok;
  final String message;
  final String safeSummary;

  const AndroidSkillConfigTestResult({
    required this.ok,
    required this.message,
    required this.safeSummary,
  });

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'message': message,
        'safeSummary': safeSummary,
      };
}

class AndroidSkillConfigTestService {
  final Uri baseUri;
  final http.Client _client;

  AndroidSkillConfigTestService({
    Uri? baseUri,
    http.Client? client,
  })  : baseUri = baseUri ?? Uri.parse('http://127.0.0.1:8765'),
        _client = client ?? http.Client();

  Future<AndroidSkillConfigTestResult> run(
    AndroidSkillConfigTestPlan plan,
  ) async {
    try {
      final response = await _client
          .post(
            baseUri.replace(path: '/api/tools/execute'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': plan.toolName,
              'input': plan.input,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final decoded = _jsonMap(response.body);
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['ok'] == true;
      return AndroidSkillConfigTestResult(
        ok: ok,
        message:
            '${plan.successActionLabel} check ${ok ? 'passed' : 'failed'}.',
        safeSummary: _safeSummary(decoded),
      );
    } catch (error) {
      return AndroidSkillConfigTestResult(
        ok: false,
        message: '${plan.successActionLabel} check failed.',
        safeSummary: _redact(error.toString()),
      );
    }
  }
}

Map<String, dynamic> _jsonMap(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {'result': decoded};
}

String _safeSummary(Map<String, dynamic> decoded) {
  final selected = <String, dynamic>{};
  final payload = decoded['payload'];
  final error = decoded['error'];
  if (payload is Map) {
    for (final entry in payload.entries.take(8)) {
      selected[entry.key.toString()] = entry.value?.toString();
    }
  } else if (error is Map) {
    selected['error'] = error['message']?.toString() ?? error.toString();
  } else if (error != null) {
    selected['error'] = error.toString();
  } else {
    selected['ok'] = decoded['ok'];
  }
  return _redact(jsonEncode(selected));
}

String _redact(String value) {
  return value
      .replaceAll(RegExp(r'xox[baprs]-[A-Za-z0-9-]+'), '[secret]')
      .replaceAll(RegExp(r'Bearer\\s+[A-Za-z0-9._-]+'), 'Bearer [secret]');
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/android_skill_config_test_service_test.dart`

Expected: PASS.

### Task 3: Config Sheet Test Connection UI

**Files:**
- Modify: `lib/screens/management/skills/android_skill_config_sheet.dart`
- Modify: `test/android_skill_config_sheet_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Extend `test/android_skill_config_sheet_test.dart`:

```dart
testWidgets('successful save reveals test connection action for supported skill',
    (tester) async {
  await _pumpSheet(
    tester,
    _slackModel(),
    applyConfig: ({
      required skillId,
      envValues = const <String, String>{},
      configValues = const <String, dynamic>{},
    }) async => _satisfiedReport(skillId),
    testConnection: (_) async => const AndroidSkillConfigTestResult(
      ok: true,
      message: 'Slack auth check passed.',
      safeSummary: '{"team":"OpenClaw"}',
    ),
  );

  await tester.enterText(_textFieldByLabel('Bot token'), 'xoxb-test-secret');
  await tester.enterText(_textFieldByLabel('Default Slack channel'), 'C123');
  await tester.tap(find.text('Save & Check'));
  await tester.pump();

  expect(find.text('Test Connection'), findsOneWidget);
  await tester.tap(find.text('Test Connection'));
  await tester.pump();

  expect(find.text('Slack auth check passed.'), findsOneWidget);
  expect(find.textContaining('xoxb-test-secret'), findsNothing);
});
```

Also update `_pumpSheet` to accept an injected test callback.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/android_skill_config_sheet_test.dart`

Expected: FAIL because the widget has no test connection callback/action yet.

- [ ] **Step 3: Implement minimal UI**

Add to `AndroidSkillConfigSheet`:

- `AndroidSkillConfigTestApply? testConnection`
- local `AndroidSkillConfigTestPlan? _testPlan`
- local `_lastTestResult`, `_isTesting`
- show a `Test Connection` button only after save success and only when `_testPlan != null`
- invoke `testConnection` when injected, otherwise `AndroidSkillConfigTestService().run(_testPlan!)`
- display only `AndroidSkillConfigTestResult.message` and `safeSummary`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/android_skill_config_sheet_test.dart`

Expected: PASS.

### Task 4: Verification, Docs, Commit

**Files:**
- Modify: `docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`

- [ ] **Step 1: Update GTM doc Phase 6A proof**

Add a Phase 6A first-slice note stating:

```text
Android config unlock now has service-aware Test Connection plans for supported
app-native adapters. Tests route through local AgentSkillServer
/api/tools/execute and do not expose secrets in UI-visible summaries. This does
not change readiness counts by itself.
```

- [ ] **Step 2: Run full focused verification**

Run:

```text
dart format lib/services/android_skill_config_test_plan.dart lib/services/android_skill_config_test_service.dart lib/screens/management/skills/android_skill_config_sheet.dart test/android_skill_config_test_plan_test.dart test/android_skill_config_test_service_test.dart test/android_skill_config_sheet_test.dart
flutter test test/android_skill_config_test_plan_test.dart test/android_skill_config_test_service_test.dart test/android_skill_config_sheet_test.dart
flutter analyze lib/services/android_skill_config_test_plan.dart lib/services/android_skill_config_test_service.dart lib/screens/management/skills/android_skill_config_sheet.dart test/android_skill_config_test_plan_test.dart test/android_skill_config_test_service_test.dart test/android_skill_config_sheet_test.dart
git diff --check
```

Expected: all commands exit 0 except allowed dependency-version advisory text from Flutter.

- [ ] **Step 3: Commit**

Run:

```text
git add lib/services/android_skill_config_test_plan.dart lib/services/android_skill_config_test_service.dart lib/screens/management/skills/android_skill_config_sheet.dart test/android_skill_config_test_plan_test.dart test/android_skill_config_test_service_test.dart test/android_skill_config_sheet_test.dart docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md docs/superpowers/plans/2026-06-10-phase-6a-config-test-connections.md
git commit -m "Add Android config test connection plans"
```
