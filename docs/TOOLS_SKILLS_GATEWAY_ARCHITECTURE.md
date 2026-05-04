# Tools, Skills & Gateway Intelligence Architecture

> **Last updated:** 2026-05-04
> **Scope:** How the OpenClaw gateway receives tool and skill context, what `tools.allow` does, which
> commits broke full tool access, and how to avoid regressing it again.

Engineers touching `gateway_service.dart`, `openclaw_service.dart`, or the Skills Manager screen must
read this before making changes.

---

## The Three Layers (Do Not Confuse Them)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  LAYER 1 — Gateway Primitives  (tools.allow in openclaw.json)                │
│  Built-in OS-level capabilities the gateway exposes directly to the AI.      │
│  Valid IDs: browser · computer · files · memory · search · image · canvas · shell │
│  With NO tools block in config → gateway defaults to ALL primitives allowed. │
├──────────────────────────────────────────────────────────────────────────────┤
│  LAYER 2 — npm Skills  (openclaw skills install <name>)                      │
│  Node.js packages that give the AI new capabilities (weather, github, …).    │
│  These are NOT gateway primitives. Do NOT write their slugs to tools.allow.  │
│  The gateway loads them via its own npm registry at startup.                 │
├──────────────────────────────────────────────────────────────────────────────┤
│  LAYER 3 — Device-native Skills  (skills.register RPC + AgentSkillServer)   │
│  Flutter-side capabilities wired to Android hardware (avatar, TTS, camera).  │
│  Registered over WebSocket via skills.register when the gateway supports it. │
│  Callback URL: http://127.0.0.1:8765  (AgentSkillServer on port 8765)       │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## `tools.allow` — The Strict Gateway Allowlist

`tools.allow` in `/root/.openclaw/openclaw.json` is a **strict allowlist** of gateway primitive IDs.

| State | Effect |
|---|---|
| Block absent (correct default) | AI has access to **all** built-in gateway primitives |
| `"allow": ["browser", "files"]` | AI can only use browser and files primitives |
| `"allow": ["weather", "camera"]` | Gateway warns "unknown entries" — AI gets **zero** tools |

**The working state is NO `tools.allow` block.** The gateway's default is full access. Only write the
block when you intentionally want to restrict primitives.

### Valid primitive IDs (the only values that belong here)

```
browser   computer   files   memory   search   image   canvas   shell
```

### IDs that must NEVER be written to tools.allow

| ID | Type | Correct home |
|---|---|---|
| weather, twilio, crypto, base, calculator, calendar | npm skill slugs | gateway auto-loads from npm |
| camera, location, screen, haptic, sensor | device capabilities | `gateway.nodes.allowCommands` |

---

## The Regression — Exact Commits and Diffs

### Commit `35be95e` (2026-05-04 00:01) — root cause introduced

`lib/screens/management/skills_manager.dart` renamed `'solana'` to `'base'` in `_toolCatalog` and
added it alongside `calculator`, `calendar`, `weather`, `twilio`, `crypto`, `camera`, `location`,
`screen`, `haptic`, `sensor` — all mixed into the same catalog as real gateway primitives.

`_toggle()` in `_ToolsTabState` writes **every toggled ID** straight to `tools.allow` with no filter:
```dart
await OpenClawCommandService.saveToolsAllow(newSet.toList()..sort());
```

When the user opened the Tools tab and toggled anything, npm-skill slugs landed in `tools.allow`.
The gateway then warned on every agent run:
```
tools.allow allowlist contains unknown entries (base, calculator, calendar, crypto, sensor, twilio, weather)
```
and the AI received **zero tools** — every run produced only a single text chunk with no tool calls.

### Commit `a924f55` (2026-05-01 00:31) — compounding regression

`gateway_service.dart` removed the `supported.contains('skills.register')` guard:
```dart
- if (catalog.isNotEmpty && supported.contains('skills.register')) {
+ if (catalog.isNotEmpty) {
```
This caused every 30-second health check to call `skills.register` unconditionally, registering only
our 3–4 device skills (avatar, TTS, camera). On gateways that do support the RPC, this overwrote the
npm-skill tool context, making weather/github/etc. invisible to the AI even if tools.allow was clean.

### Commit `a976510` (2026-05-04 03:58) — partial fix (guard restored, but tools.allow still broken)

Restored the `skills.register` guard. Also changed `config.remove('tools')` to a comment — but this
preserved the already-poisoned `tools.allow` with invalid entries on disk.

### Commit `(current HEAD)` — complete fix

Two targeted changes:

**`lib/services/openclaw_service.dart` — `saveToolsAllow()` now filters to primitives only:**
```dart
static const _kGatewayPrimitives = {
  'browser', 'computer', 'files', 'memory', 'search', 'image', 'canvas', 'shell',
};

static Future<bool> saveToolsAllow(List<String> tools) async {
  final valid = tools.where(_kGatewayPrimitives.contains).toList()..sort();
  if (valid.isEmpty) {
    // Remove block entirely — gateway defaults to all tools allowed
    config['tools']?.remove('allow');
    if (config['tools'] is Map && config['tools'].isEmpty) config.remove('tools');
  } else {
    config['tools']['allow'] = valid;
  }
  // write to disk ...
}
```

**`lib/services/gateway_service.dart` — `configureOllama()` sanitizes disk state on every write:**
```dart
const validPrimitives = {
  'browser', 'computer', 'files', 'memory', 'search', 'image', 'canvas', 'shell',
};
final existingAllow = config['tools']?['allow'];
if (existingAllow is List) {
  final sanitized = existingAllow.map((e) => e.toString())
      .where(validPrimitives.contains).toList();
  if (sanitized.isEmpty) {
    config['tools']?.remove('allow');
    if (config['tools'] is Map && config['tools'].isEmpty) config.remove('tools');
  } else {
    config['tools']['allow'] = sanitized;
  }
}
```

---

## Log Signatures — Working vs Broken

### Working state (May 1 at 2AM — commit `2555bb0` and earlier)

```
[CONN] Gateway connected
[SKILLS] Registered 3 device skills with gateway
[AGENT] Run started — model: ollama/qwen2.5:latest
[TOOL] browser: fetching https://...
[TOOL] search: query="..."
[AGENT] Run complete
```

Key: tool call entries appear in the run. No `tools.allow` warnings.
The openclaw.json at this state had **no `tools.allow` block** and device capabilities in
`gateway.nodes.allowCommands`.

### Broken state (after commit `35be95e` with Tools tab toggling)

```
[WARN] tools.allow allowlist contains unknown entries (base, calculator, calendar, crypto, sensor, twilio, weather)
[AGENT] Run started — model: ollama/qwen2.5:latest
[AGENT] Run complete
```

Key: **no `[TOOL]` lines at all** between Run started and Run complete. Single text chunk output.
AI says "I don't have tool access" or similar. The warning above fires on every single agent run.

---

## `skills.register` — When to Call It

The `skills.register` RPC registers device-native skills (avatar, TTS, hardware) with the gateway so
the AI can invoke them via tool calls dispatched to `AgentSkillServer` on port 8765.

**Rule:** Only call it when the gateway explicitly declares support:
```dart
final supported = _connection?.supportedMethods ?? const <String>[];
if (!supported.contains('skills.register')) return;
```

**Why this guard matters:** Calling unconditionally on gateways that DO support the RPC overwrites the
session's full npm-skill tool context (weather, github, etc.) with only our 3–4 device skills. The
guard ensures we only call when safe and supported.

**`reregisterSkills()`** in `gateway_service.dart` is called:
- On every successful gateway connect
- When a skill is toggled in the Skills Manager (via `skillToggled` event)

---

## Device Capabilities — Correct Config Section

Camera, location, sensor, haptic, and screen sharing are Android device capabilities. They belong in:
```json
{
  "gateway": {
    "nodes": {
      "allowCommands": ["camera", "flash", "location", "sensor", "haptic"]
    }
  }
}
```

This is a completely separate section from `tools.allow`. Never put device capability names in
`tools.allow`.

---

## Invariants to Never Break

1. **No `tools.allow` block = correct default.** The gateway allows all primitives when the block is
   absent. Only add the block to intentionally restrict.

2. **`saveToolsAllow()` must filter.** If passing IDs from `_toolCatalog` (which mixes primitives,
   npm slugs, and device names), the function at `openclaw_service.dart` filters to `_kGatewayPrimitives`
   before writing. Do not bypass this filter.

3. **`configureOllama()` sanitizes on write.** Every gateway config write passes through
   `gateway_service.dart:configureOllama()` which removes invalid `tools.allow` entries. This self-heals
   bad state from earlier bugs without user action.

4. **`skills.register` is guarded.** The guard in `reregisterSkills()` and the connect handler checks
   `supported.contains('skills.register')` before calling. Removing this guard causes npm skill context
   to be overwritten with only device skills.

5. **`agents.defaults.systemPrompt` must never be written to config.** The gateway rejects it with
   "Unrecognized keys" and skips the entire config hot-reload. Context is injected per-message via
   `_buildSystemContext()` instead.
