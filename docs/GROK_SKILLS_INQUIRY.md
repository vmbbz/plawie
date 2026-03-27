# Technical Inquiry: OpenClaw Skills Installation & Management

**Prepared for:** xAI / Grok Senior Engineering Review
**Date:** 2026-03-27
**Component:** `lib/screens/management/skills_manager.dart` + `lib/services/openclaw_service.dart`
**Severity:** P1 — Premium skill installation non-functional; all 4 premium skills fail to install

---

## 1. Current Architecture

### What Skills Are and How They Work

Skills are OpenClaw gateway plugins — npm packages that extend the AI agent's capabilities. Each skill is an npm module that the OpenClaw Node.js process loads at runtime, exposing new tool/function endpoints.

The app surfaces 4 premium skills in the Bot Management screen:

| UI Title | Internal ID (`skill.id`) | Description |
|----------|--------------------------|-------------|
| Wallet | `agent-card` | AgentCard.ai — virtual Visa cards for AI agents |
| Work | `molt-launch` | MoltLaunch — on-chain AI job marketplace |
| Credit | `valeo-sentinel` | x402 spending policy / budget caps |
| Calls | *(not shown)* | Voice/phone calling capability |

### Install Flow

```
UI "Install" tap
  ↓
OpenClawCommandService.getSkillInstallCommand(skill.id)
  ↓ detects OpenClaw version via `openclaw --version`
  ↓ returns either "openclaw skill install <id>" or "openclaw skills install <id>"
  ↓
Stage 1: NativeBridge.runInProot('openclaw skill install <id>')
  → try/catch (throws on non-zero exit)
  ↓ if throws:
Stage 2: NativeBridge.runInProot('npx clawhub install <id>')
  → if still fails → show error toast
  ↓ if either succeeds:
Stage 3: provider.invoke('skills.install', {...}) — hot-reload in running gateway
```

### Key File: `openclaw_service.dart`

`OpenClawCommandService` performs version detection by running `openclaw --version` inside PRoot and parsing the semver output. It decides which CLI syntax to use based on whether the version is ≥ `2026.1.30`.

---

## 2. Error Observed in Production

**UI error:** `Could not install Wallet`

**Full `PlatformException` output:**
```
PlatformException(PROOT_ERROR, Command failed (exit code 1):
npm warn exec The following package was not found and will be installed: clawhub@0.9.0
- Resolving agent-card
X Skill not found (remaining: 178/180, reset in 48s)
Error: Skill not found (remaining: 178/180, reset in 48s)
, null, null)
```

**Interpretation:**
1. Stage 1 (`openclaw skill install agent-card`) failed silently (threw `PlatformException`, caught)
2. Stage 2 (`npx clawhub install agent-card`) ran
3. `clawhub@0.9.0` was auto-installed by npx (not previously in node_modules)
4. clawhub searched its registry for `agent-card`
5. clawhub returned `Skill not found`
6. Rate limit counter shows `178/180 remaining` — 2 API calls consumed this window
7. `runInProot` saw exit code 1 from clawhub → threw `PlatformException`

---

## 3. Problem Analysis

### Problem 3.1 — Skill slug `agent-card` may not exist in the clawhub registry

The most likely root cause: `agent-card` is the internal app identifier, not the clawhub registry slug. These might be different.

**Evidence:**
- clawhub explicitly outputs `- Resolving agent-card` then `X Skill not found`
- This is not a network error — clawhub connected to the registry and received a definitive "not found" response
- The `agent-card` ID was defined in the Flutter app's `_premiumSkills` catalog, possibly before verifying what the actual clawhub slug is

**Questions for Grok:**
1. What is the correct clawhub slug for the AgentCard.ai skill? Is it `agent-card`, `agentcard`, `@agentcard/openclaw`, something else?
2. Does clawhub have a public registry that can be searched? (`npx clawhub search agent` or similar?)
3. Do the other skills (`molt-launch`, `valeo-sentinel`) have confirmed clawhub slugs?

### Problem 3.2 — Stage 1 version detection runs `openclaw --version` on every install

`OpenClawCommandService.getSkillInstallCommand()` calls `detectOpenClawVersion()` which runs `openclaw --version` via `runInProot` on **every** tap of the Install button. This:
- Adds ~2–5 seconds latency before the install even starts
- Creates an extra `runInProot` call that could fail (e.g. if the gateway is running and PRoot is busy)
- Is fragile: if `openclaw --version` outputs an unexpected format, `RegExp(r'(\d+\.\d+\.\d+)')` returns `null` → falls back to `0.0.0` → uses old syntax → fails

**Current version regex:**
```dart
final versionMatch = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(result);
return versionMatch?.group(1) ?? '0.0.0';
```

**Question for Grok:**
What does `openclaw --version` actually output? For example, does it output `2026.3.27` (semver without leading chars) or `OpenClaw v2026.3.27` or `v2026.3.27-alpha`? The regex is correct for bare semver but would fail on version strings with `v` prefix if the number group matched differently.

### Problem 3.3 — Both install paths may fail for different reasons

The two-stage fallback assumes either `openclaw skill install` OR `npx clawhub install` will work. But there are scenarios where both fail for independent reasons:

| Stage | Failure Reason | Observed? |
|-------|---------------|-----------|
| Stage 1 | `openclaw skill` not recognised (old gateway) | Yes |
| Stage 1 | `openclaw skill install` recognised but skill not in npm registry | Possible |
| Stage 2 | clawhub registry doesn't have the slug | **Yes — confirmed for `agent-card`** |
| Stage 2 | clawhub rate-limited | Possible (180/window) |
| Stage 2 | clawhub network error | Possible |
| Stage 2 | npx can't install clawhub itself (npm registry down) | Possible |

There is no third fallback. If both fail, the user gets `Could not install <skill>` with the raw `PlatformException`.

**Question for Grok:**
Is there a third install path? For example, direct npm install: `npm install -g @agentcard/openclaw-skill` or similar? Or a GitHub-based install: `openclaw skill add https://github.com/...`?

### Problem 3.4 — Rate limiting on clawhub API

The error shows `remaining: 178/180, reset in 48s`. This means each `npx clawhub install` call consumes at least 2 API credits. The window resets every 48 seconds. If a user taps Install 4+ times in quick succession (common when debugging), they can exhaust the rate limit and have all calls fail for 48 seconds.

**Question for Grok:**
- Is 180/48s the standard clawhub rate limit? Is there an authenticated tier with higher limits?
- Does the rate limit apply per-IP or per-API-key? Could we pass an API key to clawhub?

### Problem 3.5 — Gateway RPC hot-reload: skill format unknown

After CLI install succeeds, the app invokes:
```dart
provider.invoke('skills.install', {
  'name': skill.id,
  'installId': '${skill.id}_${DateTime.now().millisecondsSinceEpoch}',
});
```

**Questions for Grok:**
1. Is `skills.install` the correct RPC method name? Or is it `skill.install` (singular) in newer gateway versions?
2. What does `installId` do? Is it required? The current implementation generates a timestamp-suffixed ID.
3. Is the RPC call necessary at all if the CLI install already placed the module in the gateway's `node_modules`? Does the gateway auto-discover new skills on file change, or does it require an explicit hot-reload call?

---

## 4. Current Code State

### `skills_manager.dart` install handler (simplified)

```dart
// Stage 1: Try the version-appropriate CLI command
String cliResult;
try {
  cliResult = await NativeBridge.runInProot(
    'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && $installCmd',
    timeout: 45,
  );
} catch (_) {
  cliResult = 'error:'; // force fallback
}

// Stage 2: Fallback to clawhub
if (cliResult.toLowerCase().contains('error:') || ...) {
  cliResult = await NativeBridge.runInProot(
    'export NODE_OPTIONS="--require /root/.openclaw/bionic-bypass.js" && npx clawhub install ${skill.id}',
    timeout: 60,
  );
}
```

### `openclaw_service.dart` version detection

```dart
static Future<String> getSkillInstallCommand(String skillName, ...) async {
  final useNewSyntax = await isNewSkillSyntax(); // calls openclaw --version via PRoot
  return useNewSyntax
      ? 'openclaw skill install $skillName'    // v2026.1.30+
      : 'openclaw skills install $skillName';  // older
}
```

### Skill ID catalog (in `skills_manager.dart`)

```dart
const _premiumSkills = [
  _SkillEntry(id: 'agent-card',      title: 'Wallet',  ...),
  _SkillEntry(id: 'molt-launch',     title: 'Work',    ...),
  _SkillEntry(id: 'valeo-sentinel',  title: 'Credit',  ...),
  _SkillEntry(id: 'local-llm',       title: 'Local LLM', ...),
];
```

---

## 5. Questions Summary for Grok

| # | Question | Priority |
|---|----------|----------|
| 1 | What is the correct clawhub registry slug for `agent-card` (Wallet)? | **P0** |
| 2 | What are the correct slugs for `molt-launch`, `valeo-sentinel`? | **P0** |
| 3 | Does clawhub have a search command to find skills? | P1 |
| 4 | What is the actual output format of `openclaw --version`? | P1 |
| 5 | Is `skills.install` the correct RPC method for gateway hot-reload? | P1 |
| 6 | Is there a third install path beyond `openclaw skill install` and `npx clawhub install`? | P1 |
| 7 | Is the clawhub rate limit (180/48s) per-IP? Is there an auth token path? | P2 |
| 8 | Does the OpenClaw gateway auto-discover skills, or does the RPC call trigger re-scan? | P2 |

---

## 6. What We Need to Proceed

**Minimum viable:** Correct clawhub slugs for the 4 premium skills. Once we have those, we can either:
- (a) Update the `id` field in `_premiumSkills` to use the clawhub slug directly, OR
- (b) Add a `clawhubSlug` field to `_SkillEntry` separate from `id`, so the internal ID and registry slug can differ

**Ideal:** Full install command confirmation from Grok:
```
openclaw skill install <slug>   ← confirm this works end-to-end on v2026.x
npx clawhub install <slug>      ← confirm this is the right fallback
```

---

*Document prepared 2026-03-27. Related: `TECHNICAL_INCIDENT_REPORT_LOCAL_LLM.md`, `GROK_ALIGNMENT_CHECKLIST.md`.*
