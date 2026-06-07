# Native Skill Execution War Path

Date: 2026-06-05

Scope: Native/libnode default runtime, OpenClaw Gateway skills, ClawHub-installed skills, dependency provisioning, tool/result UI continuity, and device proof from the stocks skill.

This document is intentionally dense. It records what was proven on device, why the previous failure happened, what the current fix actually does, what it does not yet solve globally, and the full production war path to make Native skill execution industrial-grade for default skills and future ClawHub installs.

GTM correction: this war path is the broad platform roadmap, not the narrower
Android launch gate. The launch plan is now documented in
`docs/GTM_ANDROID_DEFAULT_SKILL_READINESS_PLAN_2026-06-07.md`: keep every
Android-viable default skill in scope, classify desktop-only/config/pack/PRoot
cases explicitly, and require `unexpected_missing_dependency: 0` for the Android
launch set.

2026-06-07 correction: stocks must remain a deterministic required Native
ClawHub skill intent in chat. It is not enough to add a private prompt note that
the model should use `stocks`; explicit finance/ticker prompts must emit
`TOOL_USE:stocks` and `TOOL_RESULT:stocks` through
`NativeClawHubSkillExecutionService` before normal `chat.send` continuation. A
chat answer that merely repeats a stale parity gate such as "missing binary" is
not execution proof.

## Executive Position

Native is the default owner.

PRoot is manual fallback only.

Web/search is not an acceptable fallback for a skill the user explicitly asked to use.

The agent must not merely list installed skills. It must be able to use them. If a skill cannot run, the product must know and show the real gate: disabled, missing dependency, missing binary, missing config, missing env, unsupported native runtime, policy denial, or broken skill package.

The stocks test is now a successful on-device proof:

- The manually installed `stocks` ClawHub skill exists in the Native workspace.
- Its Python dependencies are installed in the Native managed Python runtime.
- The real skill script `scripts/yfinance_ai.py` runs on device.
- Chat UI now shows `Result stocks`.
- Logcat shows `[SKILL-EXEC] stocks native workspace run ok=true`.
- The result is visible in chat with current NVDA/BTC and ETH/AAPL data.
- No web fallback was used.
- No PRoot fallback was used.

That is a critical proof. It is not the end state.

Important count semantics:

- `13/13` is the Android launch-required default-skill release gate.
- It is not the claim that the app can only run 13 skills.
- Current health also reports the broader classified/default manifest count and
  the installed Native workspace count.
- ClawHub-installed skills like `stocks` live in the Native skill execution and
  parity/provisioning layer. They need deterministic execution contracts and
  exact gates, but they are not the same metric as the default Android launch
  set.

The end state is broader: every default skill and every newly installed ClawHub skill gets a deterministic lifecycle:

1. Install.
2. Parse metadata and setup instructions.
3. Resolve dependencies.
4. Provision dependencies safely.
5. Smoke test.
6. Mark ready or blocked with exact gate.
7. Expose a real execution contract.
8. Execute through Native/Gateway.
9. Emit tool/result UI.
10. Preserve chat continuation.
11. Log enough evidence to debug failures without guessing.

## What Was Proven On Device

### Device And Runtime

Observed state:

- ADB serial: `RZCX30KA9AW`
- Package: `com.nxg.openclawproot`
- Runtime: Embedded Native Node Full Gateway Production Runtime
- Gateway health endpoint: `http://127.0.0.1:18789/health`
- Gateway health result: `{"ok":true,"status":"live"}`
- AgentSkillServer bridge: `127.0.0.1:8765`
- Native owner active.
- PRoot wrapper repair skipped during Native startup.

Relevant startup log evidence:

```text
[GATEWAY] [RUNTIME] Gateway runtime: Embedded Native Node Full Gateway Production Runtime
[GATEWAY] Native owner active; skipping PRoot wrapper repair.
[GATEWAY] [INFO] Gateway RPC discovery complete; node auto-connect released.
[NODE] Connect accepted (protocol=v4, methods=177, presence=3, token=...)
```

### Skill Parity And Provisioning State

The readiness matrix ran during startup and again after Gateway readiness.

Observed log evidence:

```text
[GATEWAY] [SKILL-PARITY] native=65 proot=61 missingNative=0 missingProot=4 plugins(native/proot)=1/1 toolsAllowParity=true gates=91 readiness=missing_dependency:32,needs_config:20,ready:13 reason=native pre-start
[GATEWAY] [SKILL-PROVISION] skills=65 changed=false reloadRecommended=false blocked=52 status=missing_binary:49,ready:13,needs_user_config:3 reason=native pre-start
[GATEWAY] [SKILL-PARITY] native=65 proot=61 missingNative=0 missingProot=4 plugins(native/proot)=1/1 toolsAllowParity=true gates=91 readiness=missing_dependency:32,needs_config:20,ready:13 reason=gateway-rpc-ready
[GATEWAY] [SKILL-PROVISION] skills=65 changed=false reloadRecommended=false blocked=52 status=missing_binary:49,ready:13,needs_user_config:3 reason=gateway-rpc-ready
```

Interpretation:

- Native has more installed skills than PRoot in this device state: `native=65`, `proot=61`.
- Native is not missing the stocks skill.
- The system can distinguish ready skills from blocked skills.
- There are still many blocked skills globally, mostly `missing_binary` and `needs_user_config`.
- That is a product-wide war-path item, not a reason for stocks to fail once stocks is ready.

### Stocks Dependency Proof

The installed `stocks` package exists in Native workspace:

```text
files/native-node-embedded/native-home/.openclaw/workspace/skills/stocks/SKILL.md
files/native-node-embedded/native-home/.openclaw/workspace/skills/stocks/requirements.txt
files/native-node-embedded/native-home/.openclaw/workspace/skills/stocks/scripts/yfinance_ai.py
files/native-node-embedded/native-home/.openclaw/workspace/skills/stocks/.venv/bin/python3
files/native-node-embedded/native-home/.openclaw/workspace/skills/stocks/.venv/bin/pip
```

The skill declares:

```text
yfinance>=0.2.66
pandas>=2.2.0
pydantic>=2.0.0
requests>=2.28.0
```

Native dependency receipts exist for Python runtime and packages, including:

- `python-core`
- `yfinance`
- `pandas`
- `pydantic`
- `requests`
- `numpy`
- OpenBLAS/native support packages
- transitive Python wheel dependencies

The Native Python bridge import smoke previously proved:

```text
numpy 1.26.2
pandas 2.1.3
pydantic 2.11.10
requests 2.34.2
```

The installed skill script was executed directly through the Native Python bridge and returned real data:

```text
NVDA - NVIDIA Corporation
Current Price: ...
BTC-USD
Current Price: ...
```

That isolated the failure:

- Dependencies were no longer the blocker.
- The skill package was no longer the blocker.
- Native Python was no longer the blocker.
- The remaining blocker was chat execution exposure.

## The Core Failure We Fixed

Before the fix, chat knew about the `stocks` skill as an active capability, but did not have a deterministic callable execution path for it.

The model was being given context saying the skill existed and should be used. That is not the same as exposing an executable tool or deterministic skill runner.

Observed failure before fix:

```text
I am sorry, but I do not have access to the stocks skill right now, so I cannot fetch the current NVDA and BTC prices for you.
```

At the same time logs proved:

```text
[SKILL-TARGET] targets=stocks,stock,financial-data,finance,market-data ready=true matrix=stocks:ready provisioning=stocks:ready
```

That combination is the important contradiction:

- Readiness said stocks was ready.
- The model still apologized.
- No real tool call happened.

That means the failure was not dependency readiness. It was the absence of an enforced skill execution path in chat.

## What The Current Fix Adds

New file:

```text
lib/services/native_clawhub_skill_execution_service.dart
```

New focused test:

```text
test/native_clawhub_skill_execution_service_test.dart
```

Gateway wiring:

```text
lib/services/gateway_service.dart
```

The new service does these things:

1. Detects finance/stocks intents.
2. Parses stock and crypto symbols from user text.
3. Maps `NVDA` to `get_stock_price(ticker='NVDA')`.
4. Maps `BTC` to `get_crypto_price(symbol='BTC')`.
5. Maps `Ethereum` to `get_crypto_price(symbol='ETH')`.
6. Maps `AAPL` to `get_stock_price(ticker='AAPL')`.
7. Uses the installed Native workspace skill script:
   `workspace/skills/stocks/scripts/yfinance_ai.py`
8. Runs that script through the APK-packaged Native Python bridge.
9. Supplies Native runtime `site-packages` in `pythonPaths`.
10. Emits normal chat chunks:
    `TOOL_USE:stocks`
    `TOOL_RESULT:stocks`
11. Returns visible text to the chat UI.
12. Logs:
    `[SKILL-EXEC] stocks native workspace run ok=true`

This matters because the Chat UI already understands the tool/result chunk protocol. We preserved the user-facing dropdown behavior instead of bypassing the chat tool UI.

## What The Current Fix Does Not Pretend To Solve

This is crucial.

The current fix is a targeted Native execution bridge for the `stocks` skill. It proves the architecture and unblocks the concrete production failure the user was testing.

It is not yet the general all-skills executor.

It does not yet:

- Parse every possible ClawHub skill execution contract.
- Generate runners for arbitrary Python, Node, shell, MCP, HTTP, or hybrid skills.
- Automatically infer every method from every `SKILL.md`.
- Convert every skill into provider tool schema.
- Provide a universal `skills.execute` RPC when the Gateway does not advertise one.
- Repair all 52 currently blocked skills.
- Install arbitrary native system binaries for all future skills.
- Solve all missing user config/env gates.

That is exactly why the war path below exists.

## Why The Current Fix Is Still The Right Step

The stocks failure had two layers:

1. Dependency provisioning had to make the skill ready.
2. Chat execution had to actually invoke the ready skill.

Layer 1 is now working for stocks.

Layer 2 now works for stocks.

This is not a fake hardcoded answer. It is not a canned response. It runs the installed skill's actual script with the installed Native Python packages.

What is targeted is the routing and method selection. The data comes from the skill.

That is acceptable as a first acceptance bridge because:

- The skill author documents the invocation pattern in `SKILL.md`.
- The skill exposes a `Tools` class with methods.
- The user's test specifically used the stocks skill.
- The system emits real tool/result UI.
- Logs prove the native workspace skill ran.
- The path does not use web or PRoot fallback.

But this must now be generalized.

## The War Path

The war path is to replace one-off skill runners with a full Native Skill Execution Platform.

The goal:

Every installed skill becomes either:

- `ready` and executable, or
- blocked by a precise, actionable, repairable gate.

No vague "listed but not executable".

No silent fallback.

No pretending.

No PRoot automatic fallback.

No web substitution when a skill was requested.

## Phase 1: Stabilize The Proven Stocks Path

Objective: make the current stocks path robust enough to keep while the generalized system is built.

Tasks:

1. Commit the current targeted stocks execution bridge.
2. Add log fields for:
   - skill id
   - skill path
   - action count
   - method names
   - duration
   - ok/error
3. Sanitize tool result payloads for UI:
   - keep useful result text
   - truncate huge stderr
   - avoid dumping giant internal payloads
4. Normalize Markdown output:
   - strip stray bold markers in skill strings if the chat renderer mishandles them
   - preserve important financial labels
5. Add a third on-device smoke:
   - market status
   - compare stocks
   - invalid ticker error
6. Verify:
   - `NVDA + BTC`
   - `Ethereum + AAPL`
   - `market status`
   - invalid symbol returns a skill error, not an apology

Acceptance:

```text
[SKILL-EXEC] stocks native workspace run ok=true
```

Visible UI:

```text
Result stocks
Stocks skill result:
NVDA...
BTC...
```

No:

```text
I do not have access
web fallback
PRoot fallback
```

## Phase 2: General Native Skill Execution Contract

Objective: create one product-level contract for installed skills.

Every skill gets a `SkillExecutionDescriptor`.

Suggested structure:

```json
{
  "skillId": "stocks",
  "source": "clawhub",
  "root": ".../.openclaw/workspace/skills/stocks",
  "status": "ready",
  "runtime": "python",
  "entrypoint": "scripts/yfinance_ai.py",
  "executionMode": "python_tools_class",
  "methods": [
    {
      "name": "get_stock_price",
      "description": "Get current stock price",
      "parameters": {
        "ticker": "string"
      }
    }
  ],
  "dependencies": {
    "python": ["yfinance", "pandas", "pydantic", "requests"],
    "bins": [],
    "env": [],
    "config": []
  },
  "lastSmoke": {
    "ok": true,
    "time": "2026-06-05T...",
    "durationMs": 1234
  }
}
```

Descriptor sources:

- `SKILL.md` frontmatter
- `requirements.txt`
- `package.json`
- `pyproject.toml`
- `setup.py`
- shell snippets in setup docs
- known OpenClaw skill metadata
- `.clawhub/origin.json`
- `_meta.json`
- script inspection
- user-provided config
- generated local execution adapters

The descriptor must be deterministic and persisted.

Do not rely only on prompt text.

## Phase 3: Skill Metadata Parser

Objective: parse what the skill author says the skill needs.

Inputs to parse:

- YAML frontmatter in `SKILL.md`
- Markdown setup sections
- fenced shell blocks
- `requirements.txt`
- `package.json`
- `pyproject.toml`
- explicit runtime markers
- scripts folder layout
- MCP server configs
- executable files
- common class/function patterns

Extraction targets:

- runtime type:
  - python
  - node
  - shell
  - mcp
  - http
  - hybrid
  - prompt-only
- required packages
- required native bins
- required env
- required config
- plugin requirements
- network requirements
- filesystem requirements
- dangerous operations
- user approval requirements
- callable methods
- smoke-test candidates

For the stocks skill, parser should infer:

```text
runtime=python
requirements=yfinance,pandas,pydantic,requests
entrypoint=scripts/yfinance_ai.py
class=Tools
method candidates=get_stock_price,get_crypto_price,...
setup=python3 -m venv .venv; .venv/bin/python3 -m pip install -r requirements.txt
```

## Phase 4: Dependency Provisioning Expansion

Objective: make dependency repair real for all supported classes of dependencies.

Current state:

- Python dependency pack system exists and can satisfy stocks.
- Native Python runner is APK-embedded.
- Python library packs are installed into Native runtime paths.
- `.venv/bin/python3` and pip shims exist.

Needed expansion:

### Python

Support:

- `requirements.txt`
- pinned versions
- compatible version override receipts
- transitive wheels
- native wheels
- import smoke tests
- package metadata verification
- ABI-specific packs
- rollback on failed verify
- receipts for every installed package

Rules:

- Runtime executable stays APK-embedded.
- Downloaded content is libraries/data, not arbitrary executable binaries in app home.
- Import smoke must pass before `ready`.

### Node

Support:

- `package.json`
- local package installs
- verified npm pack cache
- lockfile-aware installs
- native module policy
- `node-gyp` gates
- package smoke test

Need a Native Node dependency strategy:

- pure JS packages can install into Native workspace
- native modules need ABI/build support or prebuilt packs
- unsupported native module becomes a real gate, not a vague failure

### System Binaries

Many blocked skills currently show `missing_binary`.

We need a binary pack registry:

```json
{
  "id": "ffmpeg-arm64-v8a",
  "provides": ["ffmpeg"],
  "abi": "arm64-v8a",
  "version": "...",
  "sha256": "...",
  "installPath": ".../.openclaw/dependencies/bin/ffmpeg",
  "smoke": ["ffmpeg", "-version"]
}
```

Important Android constraint:

- API 29+ has restrictions around executing files from writable app directories.
- The architecture must prefer APK-embedded runners or carefully validated execution locations/policies.
- For binaries that cannot legally/reliably execute from app data, we need either APK packaging, an embedded runner, or mark unsupported_native with exact reason.

### Env And Config

Config/env must be first-class:

- `needs_user_config`
- show exact key
- tell UI where to configure
- do not call skill until configured
- re-audit after save
- smoke test after save

Examples:

```text
OPENAI_API_KEY missing
TWILIO_ACCOUNT_SID missing
skills.marketData.accountId missing
```

### Plugins

Plugin requirements must be tracked:

- installed plugin id
- plugin tools exposed
- plugin version
- plugin health
- skill-to-plugin dependency mapping

## Phase 5: Universal Execution Adapter System

Objective: convert every ready skill into a callable adapter.

Adapter types:

### Python Tools Class Adapter

For stocks-style packages:

- import script/module
- instantiate `Tools`
- list async methods
- infer parameter names from signatures
- expose method catalog
- execute selected method
- return string/json result

### Python CLI Adapter

For skills whose usage is a command:

- run script through Native Python bridge
- pass args
- capture stdout/stderr
- parse JSON if possible
- otherwise return text

### Node Module Adapter

For JS/TS skills:

- execute with Native Node
- import module
- call function
- capture result

### Shell Recipe Adapter

For simple documented commands:

- execute only safe commands
- map `python/python3/pip` through Native managed runner
- reject unsupported destructive shell patterns
- return exact failure gate

### MCP Adapter

For skills that expose MCP servers:

- start server if dependencies ready
- list tools/resources
- expose MCP tools to Gateway/chat
- preserve tool/result chunks

### HTTP Adapter

For skills that expose local HTTP endpoints:

- start local service
- health check
- call endpoint
- stop/restart policy

## Phase 6: Gateway Integration

Objective: make skill execution part of Gateway/chat, not an afterthought.

Current problem:

- Some Gateway builds expose `skills.status`.
- Current Native build does not advertise `skills.register` for Flutter-local helpers.
- `skills.execute` is not reliably advertised.
- Active skills can be listed without a direct page RPC.

Needed product contract:

1. Gateway active skills remain source of truth for installed skill registry.
2. Native app owns dependency readiness and local execution adapters.
3. Chat must get executable skill tools, not just inventory text.
4. When Gateway exposes `skills.execute`, use it.
5. When Gateway does not expose `skills.execute`, provide a Native skill execution bridge that is still Gateway-first in policy and visible in chat.

Important distinction:

- App-native tools: avatar, TTS, device, camera, flashlight.
- OpenClaw/Gateway skills: ClawHub packages like stocks.
- Gateway primitive tools: nodes, shell, browser, search, file, etc.

Do not collapse these categories again.

## Phase 7: Tool Schema Export

Objective: expose ready skills as real callable tools.

For each ready skill adapter, generate schemas:

```json
{
  "name": "stocks.get_stock_price",
  "description": "Get current stock price via installed stocks skill",
  "parameters": {
    "type": "object",
    "properties": {
      "ticker": {
        "type": "string"
      }
    },
    "required": ["ticker"]
  }
}
```

Then either:

- register with Gateway when method exists
- inject into provider tool schema when Gateway route supports it
- route through deterministic pre-model execution for required commands
- expose through a local skill execution endpoint that Gateway can call

The model must see executable capabilities as executable, not just as prose.

## Phase 8: Chat Continuation After Skill Results

Objective: skill output should be useful in conversation.

Current stocks path directly returns visible skill output. That is fine for price queries.

For more complex skill results, chat should continue:

1. User asks a task.
2. Skill executes.
3. Result appears as dropdown.
4. Assistant summarizes or reasons from the result.

Examples:

- "Compare NVDA and AMD and tell me which has better valuation."
- "Get my location and tell me where we are."
- "Take a photo and describe it."
- "Run healthcheck and tell me what is broken."

This needs a continuation engine that can feed tool result back into the assistant without timing out or losing output.

Do not lose background responses.

## Phase 9: UI And Diagnostics

Objective: make the system explain itself without confusing users.

Chat UI must show:

- `Tool stocks`
- `Result stocks`
- ready/blocked status if failure
- no giant raw internal payload by default
- expandable technical result
- concise visible answer

Diagnostics must show:

- `[SKILL-PARITY]`
- `[SKILL-PROVISION]`
- `[DEPS]`
- `[SKILL-EXEC]`
- `[TOOLS]`
- `[NODE]`
- `[TTS]`
- `[AVATAR]`
- `[VRMA]`

But logs should not become noise:

- summarize inventories
- show targeted skill gates when relevant
- preserve full details in diagnostics export

## Phase 10: Healthcheck As A Real Skill/Tool

The user tested healthcheck and got failures before.

Healthcheck must become a real executable path:

- Gateway health
- Node health
- skill parity
- dependency readiness
- permissions
- TTS provider/backoff
- avatar renderer status
- camera/flashlight availability
- storage paths
- native Python smoke
- native Node smoke

Output should be structured:

```json
{
  "ok": false,
  "sections": {
    "gateway": {"ok": true},
    "node": {"ok": true},
    "skills": {"ready": 13, "blocked": 52},
    "tts": {"ok": false, "reason": "quota_backoff"},
    "dependencies": {"missingBinary": 49}
  }
}
```

The assistant must summarize from this result, not just say the tool ran.

## Phase 11: Dependency Pack Registry For Future ClawHub Skills

Objective: future-proof skill installs.

A new user should be able to install a skill and have the app:

1. Inspect requirements.
2. Match known dependency packs.
3. Download verified packs.
4. Smoke test.
5. Mark ready.
6. If blocked, explain exact missing pack/config.

Pack registry fields:

```json
{
  "id": "python-yfinance",
  "version": "0.2.66",
  "abi": "arm64-v8a",
  "runtime": "python",
  "provides": {
    "pythonPackages": ["yfinance"]
  },
  "dependencies": ["python-pandas", "python-requests", "python-curl-cffi"],
  "url": "https://...",
  "sha256": "...",
  "size": 123456,
  "smoke": {
    "type": "python_import",
    "imports": ["yfinance"]
  }
}
```

Install rules:

- download to temp
- verify SHA256
- extract to staging
- smoke test
- promote atomically
- write receipt
- rollback on failure

Receipt fields:

```json
{
  "id": "python-yfinance",
  "version": "0.2.66",
  "installedAt": "...",
  "sha256": "...",
  "smokePassed": true,
  "source": "dependency-pack"
}
```

## Phase 12: Skill Install Hook

Objective: ClawHub install automatically triggers provisioning.

Current path:

- `NativeClawHubSkillInstaller` installs the skill.
- provisioning hook exists.
- stocks dependency repair now works.

Needed:

- after every install:
  - parse descriptor
  - provision dependencies
  - run smoke
  - reload Gateway if needed
  - update UI state
  - report exact result

Install output should not merely say "installed".

It should say:

```text
Installed stocks.
Provisioned python-core.
Provisioned yfinance, pandas, pydantic, requests.
Smoke passed.
Skill ready.
```

Or:

```text
Installed video-edit.
Blocked: ffmpeg pack missing for arm64-v8a.
Action: download dependency pack or mark unsupported_native.
```

## Phase 13: Security Policy

Objective: power without chaos.

Rules:

- No automatic PRoot fallback.
- No silent web fallback.
- No arbitrary execution of downloaded binaries from unsafe locations.
- No destructive shell commands from skill setup without explicit policy.
- No hidden credential use.
- No unverified dependency packs.
- No huge base64 blobs in chat dropdowns.
- No leaking secrets in logs.

Skill execution must carry:

- skill id
- source
- runtime
- adapter
- input
- output summary
- error gate
- duration
- whether user approval was required

## Phase 14: Test Matrix

### Static Tests

- parse `SKILL.md` frontmatter
- parse `requirements.txt`
- parse setup code blocks
- detect Python Tools class
- detect Node package
- detect required bins
- detect env/config
- build descriptors
- resolve packs
- reject bad SHA
- rollback failed smoke
- idempotent receipts

### Unit Tests

- stocks intent parser:
  - NVDA/BTC
  - Ethereum/AAPL
  - market status
  - compare tickers
  - invalid ticker
- Native Python runner payload shape
- tool/result chunk formatting
- readiness gate prevents execution
- ready skill executes
- blocked skill reports gate

### Integration Tests

- install stocks
- provision stocks
- execute stocks
- restart app
- execute again from receipts
- install a second Python skill
- install a Node skill
- install a config-gated skill
- install a missing-binary skill

### Device Smoke

Run through actual Chat UI:

1. `Use stocks skill for NVDA and BTC prices. No web fallback.`
2. `Use stocks skill for Ethereum and AAPL prices. No web fallback.`
3. `Use stocks skill to compare AAPL, MSFT, and GOOGL.`
4. `Use stocks skill for market status.`
5. `Run healthcheck and tell me what is broken.`
6. `Take a photo and describe it.`
7. `Check location and tell me where we are.`
8. `Turn on flashlight, then turn it off.`
9. `Cross leg sit for 30 seconds then bow 2.`
10. Install a new ClawHub skill, provision it, and use it.

Acceptance logs:

```text
[SKILL-EXEC] <skill> ... ok=true
[DEPS] <skill> ... installed
[SKILL-PROVISION] ... ready
TOOL_USE
TOOL_RESULT
```

Rejection logs:

```text
[SKILL-EXEC] <skill> blocked status=needs_config gate=...
[SKILL-PROVISION] <skill> missing_pack ...
```

## Current Known Non-Blocking Observation: TTS Quota

During the successful stocks test, TTS hit quota/backoff:

```text
[GATEWAY] [TTS] talk.speak provider/account error; suppressing retries for 5m: Exception: TTS conversion failed: google: Google TTS failed (429)...
```

Interpretation:

- TTS quota/backoff is real.
- It did not block stocks skill execution.
- The chat text and tool result still appeared.
- This belongs to TTS visual health/backoff polish, not stocks execution.

Needed:

- NOB should indicate TTS unavailable/backoff.
- TTS modal should show provider quota/backoff.
- Normal TTS state should not make the NOB ugly.
- TTS failure should not poison skill/tool execution.

## Current Code References

Primary files:

```text
lib/services/native_clawhub_skill_execution_service.dart
lib/services/gateway_service.dart
lib/services/skill_parity_audit_service.dart
lib/services/skill_provisioning_service.dart
lib/services/agent_skill_server.dart
lib/services/native_bridge.dart
android/app/src/main/python/openclaw_python_runner.py
android/app/src/main/kotlin/com/nxg/openclawproot/NativeNodeEmbeddedService.kt
```

Focused test:

```text
test/native_clawhub_skill_execution_service_test.dart
```

Important current behavior:

- `GatewayService` detects targeted native ClawHub skill intent.
- It checks for blocking readiness gates.
- It invokes `NativeClawHubSkillExecutionService`.
- It yields tool use/result chunks.
- It returns visible skill output.

## The Product Rule Going Forward

For every default skill:

```text
It should be installed, provisioned, smoke-tested, and ready on a fresh Native install unless it truly requires user-specific config or unsupported platform resources.
```

For every manually installed ClawHub skill:

```text
The app should inspect the skill, provision what it can, smoke test it, then either make it usable or report the exact remaining gate.
```

For chat:

```text
If the user asks to use a ready skill, the system must run the skill.
```

Not:

```text
I can list it but cannot execute it.
```

Not:

```text
I will use web instead.
```

Not:

```text
I will quietly use PRoot.
```

## Immediate Next Engineering Sprint

### Sprint Goal

Generalize the stocks proof into the first version of the Native Skill Execution Platform.

### Deliverables

1. `SkillExecutionDescriptor`
2. `SkillExecutionDescriptorBuilder`
3. `NativeSkillAdapter` interface
4. `PythonToolsClassAdapter`
5. `PythonScriptAdapter`
6. `SkillExecutionRegistry`
7. Descriptor persistence
8. Skill install hook integration
9. Chat execution using registry
10. Healthcheck command using matrix/registry

### Concrete First PR Shape

Files to add:

```text
lib/services/skill_execution_descriptor.dart
lib/services/skill_execution_descriptor_builder.dart
lib/services/native_skill_adapter.dart
lib/services/native_skill_execution_registry.dart
lib/services/adapters/python_tools_class_adapter.dart
lib/services/adapters/python_script_adapter.dart
test/skill_execution_descriptor_builder_test.dart
test/native_skill_execution_registry_test.dart
```

Files to update:

```text
lib/services/native_clawhub_skill_installer.dart
lib/services/skill_provisioning_service.dart
lib/services/gateway_service.dart
lib/services/agent_skill_server.dart
lib/screens/management/skills_manager.dart
```

### Migration Rule

The current stocks bridge should become a descriptor-backed adapter, not remain permanent special routing.

Temporary:

```text
message -> stocks intent parser -> NativeClawHubSkillExecutionService
```

Target:

```text
message -> target skill detector -> SkillExecutionRegistry -> adapter -> tool/result -> continuation
```

## Final Definition Of Done

This phase is done when:

1. A clean install can start Native Gateway by default.
2. Default skills are audited and provisioned.
3. `stocks` installs and runs without manual intervention.
4. A second ClawHub skill installs, provisions, and runs.
5. Blocked skills show exact gates.
6. Chat uses tool/result dropdowns for every skill/tool call.
7. No skill request falls into "listed but not executable" when a ready execution contract exists.
8. No PRoot automatic fallback occurs.
9. No web fallback occurs for explicit skill requests.
10. Device smoke proves camera, location, flashlight, avatar sequence, stocks, healthcheck, and one new ClawHub skill.

## Bottom Line

The stocks result proves the Native dependency and execution stack can work.

The previous chat failure was caused by execution exposure, not by stocks being fake or impossible.

The current fix proves the shortest real path:

```text
Chat request -> ready skill intent -> Native workspace skill script -> Native Python runtime -> tool/result UI -> visible result
```

The war path is to make that path universal, metadata-driven, dependency-aware, Gateway-visible, and testable for every default and installed ClawHub skill.
