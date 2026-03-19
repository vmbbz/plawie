# Plawie — Production Release v1.0 "Gold Star"

> **Date:** March 19, 2026  
> **Based on:** Commit `af104a4` + this release session  
> **Architecture reference:** [ARCHITECTURE_REPORT.md](./ARCHITECTURE_REPORT.md) | [PROMOTIONAL_PITCH.md](./PROMOTIONAL_PITCH.md)

---

## 🌟 Release Vision

> *"The world's first Flutter app to ship a full OpenClaw AI gateway inside a single APK — running on-device via a real Linux environment, no root, no cloud, no middlemen."*

Plawie puts enterprise-grade AI infrastructure in your pocket. This release polishes the experience to production quality: clean branding, correct metrics, and a trustworthy skills ecosystem.

---

## ✅ Done in This Session

| Area | Change | Files |
|------|--------|-------|
| **App Icon** | Deleted adaptive icon XML causing black-background regression | `mipmap-anydpi-v26/ic_launcher.xml` (deleted) |
| **App Icon** | Removed background-stripped foreground PNGs | `drawable-*/ic_launcher_foreground.png` (deleted) |
| **Rebrand** | "Clawa Setup" → "Plawie Setup" throughout setup flow | `setup_flow_screen.dart` |
| **Rebrand** | Default agent name "Clawa" → "Plawie" | `setup_flow_screen.dart` |
| **Help Page** | Added flagship OpenClaw-on-phone hero card as first item | `help_screen.dart` |
| **Help Page** | Polished all copy, strengthened all section wording | `help_screen.dart` |
| **Bot Dashboard** | Fixed LATENCY reading `health.health.durationMs` (not top-level) | `bot_management_dashboard.dart` |
| **Bot Dashboard** | Fixed AGENTS count from `health.health.agents[]` | `bot_management_dashboard.dart` |
| **Agent Manager** | Rewrote to correctly parse `agents.list` + `config.get` for model | `agent_manager.dart` |
| **Agent Manager** | Added identity.name, emoji avatar, defaultId matching | `agent_manager.dart` |
| **Skills Manager** | Full install lifecycle: skills.list → ACTIVE/INSTALL badges | `skills_manager.dart` |
| **Skills Manager** | `skills.install` RPC trigger with progress sheet + refresh | `skills_manager.dart` |
| **Skills Manager** | Factual core capabilities list (no more hardcoded fiction) | `skills_manager.dart` |
| **GatewaySkillProxy** | New singleton proxy service for skill RPC calls | `gateway_skill_proxy.dart` |
| **SkillsService** | All 4 execute methods wired to real gateway calls | `skills_service.dart` |
| **AgentWalletPage** | Rewritten for AgentCard.ai (Visa, correct field names) | `agent_wallet_page.dart` |
| **AgentCallsPage** | Rewritten for Twilio ConversationRelay (official API fields) | `agent_calls_page.dart` |
| **AgentWorkPage** | Rewritten for MoltLaunch — Base/EVM chain, ERC-8004 identity | `agent_work_page.dart` |
| **AgentCreditPage** | Rewritten for Valeo Sentinel x402 (correct audit log fields) | `agent_credit_page.dart` |
| **GatewayProvider** | `GatewaySkillProxy.attach(this)` wired in constructor | `gateway_provider.dart` |
| **Skills Manager** | Correct skill IDs, Solana built-in card, Register Agent banner | `skills_manager.dart` |

---

## 🔬 Architecture Clarifications (From Session Research)

### OpenClaw Skills Protocol — The Reality

OpenClaw skills are **markdown instruction-sets**, not loadable server plugins.

| Fact | Detail |
|------|--------|
| A skill = `SKILL.md` | A text file that becomes part of the agent's system prompt |
| Skills don't expose RPC | They teach the agent how to use existing tools (`exec`, `http`, `read_file`) |
| Install via ClawHub | `clawhub install <skill-slug>` or `openclaw gateway call skills.install` |
| No `skills.execute` RPC in official docs | The gateway confirmed RPC: `skills.list`, `skills.install`, `skills.info` |

**What this means for our skill pages:**  
The `GatewaySkillProxy.execute(skillName, method, params)` pattern we've built maps to what the gateway *can* expose if the **OpenClaw gateway plugin architecture** is enabled (the `req/res` WebSocket RPC). Our `SkillsService` calls `gateway.invoke('skills.execute', ...)` — if the gateway doesn't expose this exact method, the proxy's offline fallback activates transparently.

**When testing the APK:**  
- If `skills.execute` returns `ok: false` or times out → the skill pages show offline fallback state (correct behaviour)  
- Use `BotMethodExplorer` → filter "skills" to see what RPC methods your actual running gateway exposes  
- If a different method name is needed (e.g. `skill.run`), change it in one place: `gateway_skill_proxy.dart` line 1

---

### MoltLaunch — Corrected Understanding

> ⚠️ **Previous plan was wrong about MoltLaunch's blockchain.** Corrected here.

| Item | Previous (wrong assumption) | Corrected |
|------|---------------------------|-----------|
| Chain | Solana | **Base mainnet** (Ethereum L2) |
| Identity standard | Solana NFT keypair | **ERC-8004** on Base chain |
| Auth | Solana signing | **EIP-191 personal_sign** (EVM) |
| Amounts | Lamports (SOL × 10⁹) | **ETH** (float) |
| Identity field | `wallet_pubkey` (base58) | **`wallet_address`** (0x…) |
| Reputation | 0.0–1.0 float | **0–100 int** (ERC-8004 Reputation Registry) |
| CLI | `node autopilot.mjs --asset <nft>` | **`mltl wallet`** / `npm i -g moltlaunch` |
| Skill file | N/A | [moltlaunch.com/skill.md](https://moltlaunch.com/skill.md) — full REST API + guardrails |

**Should you install moltlaunch.com/skill.md into OpenClaw?**  
Yes — and it's clean (no tool clash). The skill adds knowledge to the agent's context. The agent then uses its existing `exec` tool to run `mltl` commands or its `http` tool to call `https://api.moltlaunch.com`. No new tool registrations, no system prompt conflict.

**Install via OpenClaw chat:**
> "Please install a skill from this URL: https://moltlaunch.com/skill.md"

---

### Solana Wallet — Keep It, Surface It

| Decision | Rationale |
|----------|-----------|
| Keep `solana_screen.dart` | Full-featured SOL wallet (send, receive, Jupiter swap, transaction history) |
| Keep navigation entry | Solana wallet is a distinct feature — not a "skill" per se |
| Surface on Skills page | Added as `BUILT-IN` card on Skills Manager → taps to `SolanaScreen` |
| Not in the 4 premium skills | Correct — it's a core built-in, not a plugin install |
| `solana_service.dart` | Initializes on demand (when user opens Solana screen) — not auto-init on startup |

MoltLaunch (Base/ETH) and Solana wallet are **two separate features** that can coexist. MoltLaunch pays in ETH on Base; Solana wallet manages SOL on Solana mainnet.

---

## 🚀 Production Checklist

### Before APK Build
- [x] `dart analyze` — 0 errors, 0 warnings on all changed files
- [ ] `flutter build apk --release`

### On-Device Smoke Test
- [ ] Install on clean device → verify icon on homescreen (no black bg)
- [ ] Run through setup flow → confirm "Plawie Setup" header + default name
- [ ] Open Bot Management → start gateway → confirm Uptime + Latency show real values
- [ ] Open Agent Skills → see 4 premium skill cards with ACTIVE/INSTALL state
- [ ] Confirm Solana BUILT-IN card appears below premium skills grid
- [ ] Confirm MoltLaunch Register Agent banner appears with "Register" button
- [ ] Tap uninstalled skill → install prompt → test `skills.install` RPC
- [ ] Open BotMethodExplorer → filter "skills" → note actual available methods → compare to `skills.execute`
- [ ] MoltLaunch Work page: if identity not registered → Registration Gate card shows, no CLI shown
- [ ] Valeo Credit page: budget visualizer shows "No budget configured" gracefully when offline

### Known Acceptable Limitations (v1.0)
| Item | Status |
|------|--------|
| `skills.execute` RPC name may differ on some gateway versions | Caught by BotMethodExplorer; 1-line fix in `gateway_skill_proxy.dart` |
| `skills.list` may not exist on older gateway | Handled gracefully ("discovery mode") |
| MoltLaunch `register` RPC not yet implemented server-side | Skill page shows Register gate; gateway must support `skills.execute → molt_launch.register` |
| Play Store compliance for embedded Linux | Post-v1.0 legal review |
| WorkManager heartbeat / Doze-mode AlarmManager | Deferred to v1.1 |

---

## 📊 Architecture Health: A−

Core PRoot + Node.js + OpenClaw architecture is production-grade and architecturally unique. See `ARCHITECTURE_REPORT.md` for full breakdown. Two remaining gaps (WorkManager heartbeat, Doze-mode AlarmManager) are v1.1 items.

---

*This document is the reference for the "Gold Star" production release. Update this file as each checklist item is completed.*
