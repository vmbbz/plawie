# Plawie v2.3.0 — Hackathon Preview 8

Plawie v2.3.0 Preview 8 updates the model provider catalog to the official 2026 ground-truth models with full tool support, integrates the Plawie Guardian Safety Shield card across Base Wallet and Chat surfaces, and completes the KeeperHub hackathon proof path.

## Key Changes in Preview 8

### 1. Official 2026 Model Catalog Upgrade
- **Google Gemini**: Added `google/gemini-3.8-flash` (latest 2026 Flash agentic model), `google/gemini-3.7-flash`, `google/gemini-3.1-pro`, `google/gemini-2.5-pro`, `google/gemini-2.5-flash`.
- **Anthropic Claude**: Added `anthropic/claude-fable-5-1` (frontier Generation 5 reasoning model), `anthropic/claude-opus-5`, `anthropic/claude-sonnet-5`, `anthropic/claude-haiku-4-5`, `anthropic/claude-3-7-sonnet-20250219`.
- **OpenAI**: Added `openai/gpt-5.6` (flagship 2026 unified model), `openai/gpt-5.5`, `openai/gpt-5.4`, `openai/gpt-4o`.
- **xAI Grok**: Added `xai/grok-4-6` (500K context, vision & agentic coding), `xai/grok-4-5`, `xai/grok-4-1-fast`.
- **Groq**: Added `groq/openai/gpt-oss-120b`, `groq/openai/gpt-oss-20b`, `groq/llama-3.3-70b-versatile`.
- **OpenRouter**: Added `openrouter/meta-llama/llama-3.3-70b-instruct:free`, `openrouter/deepseek/deepseek-r1:free`, `openrouter/auto`.
- **Automatic Migration**: `canonicalizeModelId` maps all legacy model selections (`gpt-4`, `o3-mini`, `gemini-1.5-pro`, `claude-opus-4-6`) to their official 2026 equivalents. Bumped snapshot cache key to `v3` for immediate on-device refresh.

### 2. Plawie Guardian Safety Shield & Wallet Real-time Spending Bounds
- Top-pinned `<GuardianPolicyCard />` integrated in Base Wallet screen and Chat screen overlay with overflow controls and real-time `policyStream` updates.
- Added demo reset button (`SibylMemoryService().clearPolicy()`) to clear active policy state on camera without clearing wallet credentials or app history.
- Fully aligned `AiPaymentsCapability` to enforce single-transaction limits derived from active Guardian policies (`payments.send_usdc`, `payments.send_eth`, `base-chain.send_usdc`, `base-chain.send_eth`).

### 3. Layout & Overflow Cleanup
- Refactored `GuardianPolicyCard` and `KeeperHubAgentWalletCard` spend counters with responsive `Wrap` and text ellipsis controls to eliminate rendering overflows.

## Installation & Release Artifacts
- Download `Plawie-v2.3.0-hackathon-preview.8-arm64-v8a-debug.apk` attached to this release.
- SHA-256 Checksum: `2067F0030A7C03D26A95083BE8B4EA4FB6DA512452AB853F6E0E5B7C88B63C59`
- Install over an existing Plawie build to preserve setup state, wallet keys, and transaction history.
