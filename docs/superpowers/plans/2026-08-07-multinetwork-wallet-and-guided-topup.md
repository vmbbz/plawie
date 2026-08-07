# Multi-network Wallet and Guided Provider Funding Plan

**Goal:** Extend the existing secured EVM account to Base and Robinhood Chain
without renaming migration-sensitive modules, then connect insufficient Base
USDC provider top-ups to the canonical foreground funding modal.

**Approved design:**
`docs/superpowers/specs/2026-08-07-multinetwork-wallet-and-guided-topup-design.md`

## Delivery boundaries

- Work in `.worktrees/wallet-reliability` on
  `codex/hybrid-bridge-funding-design`.
- Keep `BaseService`, `BaseScreen`, MethodChannel names, wallet aliases, and
  envelope filenames stable. Rename only user-facing navigation/chrome.
- One EVM identity serves both networks. Never create or copy a second key.
- Provider payments remain Base Mainnet native USDC and require their existing
  exact approval/device-authentication flow.
- Never hardcode a Robinhood USDC contract. Robinhood ordinary token sends are
  limited to the official USDG contract and exact ERC-20 transfer call.
- No automated test or device acceptance spends funds.
- Commit each implementation round; do not commit APKs, RPC keys, logs, or
  generated desktop registrants.

## Task 1: Add the network domain and bounded Robinhood signer policy

**Files:**
- Modify: `lib/services/base_service.dart`
- Modify: `android/app/src/main/kotlin/com/openclaw/plawie/SecureEvmWalletManager.kt`
- Test: `test/wallet_network_policy_test.dart`
- Test: `test/base_transfer_approval_test.dart`
- Test: `test/robinhood_secure_signer_contract_test.dart`

- [x] Define `WalletNetwork` values for Base Mainnet, Robinhood Mainnet, and
  Base Sepolia with exact chain/RPC/explorer/asset policy.
- [x] Migrate the old Sepolia boolean preference into a versioned selected
  network while preserving `useSepolia` and `setNetwork` compatibility.
- [x] Require `ROBINHOOD_RPC_URL` for production internal sends; allow only the
  official public fallback in debug/internal builds.
- [x] Bind ordinary transfer approvals to the selected chain; distinguish Base
  USDC from Robinhood USDG before any signer call.
- [x] Permit Android chain 4663 only for native ETH with empty calldata or the
  official USDG contract's exact transfer call. Show exact network and asset in
  authentication UI and keep x402 Base-only.
- [x] Test policy, migration compatibility, chain-bound approval, and Android
  source contract; run focused analysis and commit.

## Task 2: Convert the Base page into the multi-network Wallet UI

**Files:**
- Modify: `lib/screens/base_screen.dart`
- Modify: `lib/screens/dashboard_screen.dart`
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/widgets/wallet_funded_provider_actions.dart` if copy requires it
- Test: `test/wallet_hub_ui_contract_test.dart`
- Test: existing Base wallet/recovery/readiness tests

- [x] Rename dashboard/page/settings labels to Wallet while preserving class,
  route, and file names.
- [x] Replace the boolean menu with the three-network chooser and show the same
  address across networks.
- [x] Show selected-network ETH and the exact supported stable asset: USDC on
  Base or USDG on Robinhood. Never present them as interchangeable balances.
- [x] Restrict basename resolution to Base, use Robinhood Blockscout history,
  and surface missing production RPC honestly.
- [x] Make AI payments and inbound Base destination controls require exact Base
  Mainnet, not merely `!useSepolia`.
- [x] Run UI/source-contract and wallet regressions; analyze and commit.

## Task 3: Add a resumable funding modal contract

**Files:**
- Modify: `lib/widgets/bridge_funding_panel.dart`
- Modify: `lib/screens/base_screen.dart`
- Test: `test/bridge_funding_panel_test.dart`

- [ ] Add optional initial source-chain preference and completion callback to
  the existing canonical panel; live capabilities remain authoritative.
- [ ] Show the same panel in a safe-area, scroll-controlled Wallet modal with
  provider label and required Base-USDC amount.
- [ ] For Robinhood, offer ETH and USDG only from action-time token/connection
  discovery. Preserve a visible ETH gas reserve and never offer Max ETH as the
  full balance.
- [ ] Pop success only for a completed receipt after Base delivery; partial,
  refund, failure, expiry, and unknown outcomes never continue a provider
  payment.
- [ ] Preserve one-active-intent, no-resubmit, and action-time live capability
  refresh behavior. Test callback single-fire and Robinhood preselection.
- [ ] Run bridge/widget regressions; analyze and commit.

## Task 4: Orchestrate insufficient-balance top-ups safely

**Files:**
- Create: `lib/services/provider_top_up_funding_coordinator.dart`
- Modify: `lib/screens/base_screen.dart`
- Test: `test/provider_top_up_funding_coordinator_test.dart`
- Test: relevant x402 transport/readiness tests

- [ ] Prepare an unsigned challenge and compare exact required units with a
  refreshed Base-USDC balance.
- [ ] If insufficient, reject the challenge before opening funding. Never carry
  a challenge, approval, or signature through a bridge.
- [ ] After completed funding, select Base Mainnet, refresh, require sufficient
  balance, and prepare a fresh challenge.
- [ ] Keep bridge review and x402 approval/device authentication separate.
- [ ] Test sufficient, cancelled, failed, still-insufficient, stale-challenge,
  and successful fresh-challenge sequences; analyze and commit.

## Task 5: Documentation and controlled acceptance

- [ ] Update wallet/provider/bridge docs with the one-identity network model,
  `ROBINHOOD_RPC_URL`, native-ETH-only signer policy, and two-approval top-up.
- [ ] Run the complete bridge, wallet, x402, provider, Gateway, setup, and
  context-invariance regressions plus `flutter analyze`.
- [ ] Build the debug APK with reviewed bridge gates and non-secret release
  configuration; do not commit it.
- [ ] After confirming the user is idle, install with `adb install -r` without
  clearing data, launch once, and verify wallet address persistence.
- [ ] Verify non-spending network switching, Robinhood RPC/balance/history,
  modal cancellation, challenge rejection, return-to-Base, node pairing, and
  native Gateway startup. Mainnet spending requires a separate fresh user
  instruction.
