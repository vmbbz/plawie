# Multi-Wallet And External Financial Skill Policy

Status: implemented release boundary, 16 August 2026  
Applies to: Plawie Android native Gateway preview  
Primary code: `external_financial_skill_policy.dart`, `skills_service.dart`,
`agent_skill_server.dart`, `app_native_chat_tool_router.dart`, Wallet UI, Skills
Manager, and Help

## Decision

Plawie may coexist with several wallets, but it must never present them as one
wallet, silently choose between them, copy keys between them, or imply that one
provider inherits another provider's approvals.

Every wallet has a stable owner, custody model, address, chain set, capability
set, and approval route. A financial operation is invalid unless its wallet is
named explicitly and the operation reaches that wallet's approved execution
surface.

The current product therefore supports **multiple named wallet surfaces**, not
an interchangeable “agent wallet” pool.

## Current Wallet And Account Surfaces

| Surface | Custody / owner | Current role | Agent access | Current write path |
| --- | --- | --- | --- | --- |
| Plawie Personal Wallet | Android Keystore-backed app wallet; user-controlled | Base/Robinhood balances and ordinary transfers; Base destination for funding; Plawie x402 signer | Address, balance, history, resolution, and network status; transfer requests cannot manufacture approval | Exact Wallet UI review -> one-use non-serializable approval -> Android authentication -> exact send |
| KeeperHub Agent Execution Wallet | KeeperHub/Turnkey-managed organization wallet | Separate managed execution identity | Status, redacted receipts, capabilities, and preparation of one bounded zero-value Base Mainnet proof | Agent prepares inert proposal -> user opens Wallet -> exact simulation review -> Android authentication -> KeeperHub submission |
| External source wallet | The user's Reown-compatible EVM wallet or Solana MWA wallet | Source of a direct Base transfer or reviewed bridge | No session secret, seed, or generic signing tool is exposed to the agent | Explicit funding UI -> external wallet confirmation; never the Plawie internal signer |
| AgentCard account | External virtual-card provider account | Read-only connector preview | Balance/status only when separately configured | Card creation, refill, funding, and spend are not exposed by Plawie |
| MoonPay CLI wallet | Separate local HD wallet and MoonPay credentials | Read-only connector preview | Portfolio, token prices, and DCA status only when separately configured | Buy, sell, swap, bridge, transfer, signing, and DCA creation are blocked from Plawie |
| Coinbase AgentKit wallet provider | Not integrated | Roadmap only | None | None |

The Personal Wallet and KeeperHub wallet already coexist safely because their
tool names and execution coordinators are different. KeeperHub does not replace
the Personal Wallet, and the Personal Wallet does not become KeeperHub's custody
key. The current KeeperHub capability is intentionally much narrower than a
general spending wallet.

## What Happens When A User Tries To Install Another Wallet Skill

### MoonPay

An in-app install request for the known `moonpay` slug now fails before ClawHub
or the selected Gateway owner mutates the workspace. The UI explains that
MoonPay CLI creates or imports a separate HD wallet and that its writes do not
pass through Plawie's approval broker.

The bundled Plawie `moonpay` adapter remains available only as a read-only
connector contract. Its advertised and accepted methods are:

- `get_portfolio`;
- `get_price`;
- `dca_list`.

All other methods fail closed before `GatewaySkillProxy` can invoke an installed
Gateway skill. The local HTTP partner routes no longer map swap, bridge, buy, or
sell endpoints. Deterministic chat routing no longer turns write-like MoonPay
language into an app-native financial call.

This does **not** delete a MoonPay CLI wallet or uninstall a skill that the user
installed outside Plawie. A manually installed Gateway skill can have its own
tool or shell behavior outside the app-native adapter. Until the Gateway gains a
financial-skill permission firewall, such a manual install must be treated as a
separate high-trust runtime chosen by the user, not as a Plawie-mediated wallet.

MoonPay's current documentation says its CLI can create/import BIP-39 HD
wallets, signs locally, and can execute swaps, bridges, transfers, DCA, and fiat
flows. Its own server/MCP safety guidance requires simulation and explicit user
confirmation. See [MoonPay CLI for AI agents](https://support.moonpay.com/en/articles/586583-moonpay-cli-for-ai-agents).

The bare `moonpay` ClawHub listing inspected on 16 August 2026 was a
community-published wrapper, not a package published under an identity that
Plawie had independently authenticated as MoonPay. ClawHub also reported a
security warning for the selected version. A working slug is not a provenance
or safety guarantee.

### Coinbase AgentKit

Plawie's previous Partner Skills tile was incorrect: it labelled the community
ClawHub slug `x402-client` as “Coinbase AgentKit.” Inspection on 16 August 2026
showed that `x402-client` is a third-party instruction-only x402 skill by a
community publisher. Its instructions describe paying an HTTP 402 challenge
from an agent wallet and explicitly say that no human is in the loop. It is not
the `@coinbase/agentkit` runtime, not a CDP wallet provider, and not a Plawie
approval adapter.

That false mapping has been removed. In-app installation of `x402-client` and
common AgentKit-like slugs is blocked in this preview. Plawie does not ask for a
CDP key and does not create a Coinbase wallet.

Coinbase's actual AgentKit is a wallet-provider-agnostic SDK. An application
must instantiate it with one explicit wallet provider, such as CDP, Privy, or a
custom provider, then attach action providers. Supporting more than one provider
in the broader application is possible, but each AgentKit instance/action route
still needs an unambiguous provider and secure persistence. See
[AgentKit wallet management](https://docs.cdp.coinbase.com/agent-kit/core-concepts/wallet-management)
and [AgentKit architecture](https://docs.cdp.coinbase.com/agent-kit/core-concepts/architecture-explained).

### AgentCard

The AgentCard tile is a bundled **read-only connector**, not another Plawie
wallet and not an installable autonomous payment system. Its app-native tool
advertises and accepts only `get_balance`. Card creation and refill calls fail
closed before Gateway proxy execution. The UI no longer offers inert Add Funds
or refill controls.

## Can The Agent Use Multiple Wallets?

The answer depends on what “use” means:

- **Read from multiple named wallets:** yes. The model can inspect the Plawie
  wallet, KeeperHub state, and a separately configured read-only external
  connector when each named tool is available.
- **Prepare work for different wallets:** yes, only through each wallet's bounded
  prepare/quote contract. A quote or proposal is not approval.
- **Spend from multiple wallets automatically:** no. Plawie currently exposes no
  generic default-wallet selector and no serializable approval that an agent can
  reuse across wallets.
- **Use KeeperHub for ordinary Plawie x402/top-up payments:** no. Those payments
  remain bound to the internal Base wallet. KeeperHub currently supports only
  its separately governed proof flow.
- **Use MoonPay or AgentKit as a silent fallback:** no. Provider fallback must
  never change custody or signer identity.

## Routing Invariants

1. `base-chain.*` always means the Android-owned Personal Wallet.
2. `keeperhub.*` always means the KeeperHub-managed Agent Execution Wallet.
3. `moonpay.*` and `agent-card.*` always mean separately configured external
   accounts and are read-only in the app-native tool catalog.
4. External funding adapters sign only in the chosen external wallet and return
   bounded transaction evidence; they do not become agent wallets.
5. A wallet address, provider ID, chain ID, quote fingerprint, and operation ID
   must be visible before any future third-party wallet write can be approved.
6. Chat text such as “yes,” “use any wallet,” or “try another wallet” is never an
   approval or a wallet-selection capability.
7. Installing a skill never changes the Plawie payment wallet, merges balances,
   imports an existing Plawie key, or grants access to KeeperHub credentials.
8. A missing, stale, ambiguous, or unsupported wallet route fails closed.

## Why A Generic Default Wallet Is Unsafe

An implicit default creates four classes of failure:

- the agent can quote against one address and submit from another;
- network/asset assumptions can change while a provider falls back;
- the user can approve a Personal Wallet action while an external wallet signs;
- receipts can attribute custody, fees, or balances to the wrong provider.

Plawie therefore does not implement “first funded wallet wins,” “last connected
wallet wins,” or provider fallback based only on available balance.

## Production Multi-Wallet Architecture

Future value-moving external integrations require a common registry and approval
envelope, not extra prompt text.

### Wallet registry record

Each record should contain only non-secret routing metadata:

```text
walletId
providerId
displayName
custodyClass
accountAddress
supportedChainIds
supportedAssets
capabilities: read | quote | simulate | sign | broadcast
approvalAdapterId
connectionState
lastVerifiedAt
```

Secret keys, wallet exports, session secrets, API secrets, and authorization
private keys must never enter this record, model context, telemetry, or receipts.

### Write intent envelope

Every write must bind:

```text
intentId
walletId + providerId
chainId + asset
operation + canonical arguments
recipient / payTo
amount + platform/provider/network fees
quote/simulation fingerprint
expiry
one-use approval nonce
```

Changing any bound field invalidates the approval. A provider retry may reuse an
idempotency key only for the identical operation and must reconcile the prior
outcome first.

### Selection UX

- Show a wallet picker only when more than one **eligible** wallet supports the
  exact operation.
- Display custody, provider, chain, address suffix, balance freshness, and fee
  source in the review sheet.
- Persist a preference only for a narrowly named operation class, never as an
  unrestricted global signer.
- Never select a wallet solely because it has funds.
- Never fail over after the user approves; return to review with a new quote.

### External skill admission

Before removing an install block, Plawie needs:

1. verified publisher and immutable package/version evidence;
2. an inventory of binaries, network origins, credentials, files, and wallet
   material the skill can reach;
3. read/write method separation;
4. simulation and canonical request parsing;
5. a Plawie-owned foreground approval adapter with Android authentication;
6. idempotency, outcome-unknown recovery, and redacted receipts;
7. uninstall/revocation and orphaned-wallet guidance;
8. physical-device rejection, process-death, and duplicate-submission tests.

## Known Limitation

The in-app denylist protects known misleading catalog routes. It is not a global
security verdict for all  community skills. A differently named financial skill
may still be discoverable, and a user with direct Gateway/filesystem access can
install software outside the app. Production readiness therefore still requires
a Gateway-level permission model that can classify financial tools and deny
unmediated writes regardless of package name.

## Acceptance Tests

- MoonPay/AgentCard tool schemas contain read methods only.
- Direct calls to blocked write methods fail before Gateway proxy execution.
- In-app installs of `moonpay`, `x402-client`, and AgentKit aliases fail before
  workspace mutation for native and PRoot owners.
- The Partner Skills catalog no longer maps AgentKit to `x402-client`.
- AgentCard and MoonPay UI contain no active refill, buy, sell, swap, bridge,
  signing, or DCA-creation affordance.
- Existing Base transfer tests still prove one-use visible approval.
- Existing KeeperHub tests still prove that the agent cannot approve, sign,
  submit, retry, revoke, or move non-zero value.
- Help and architecture documentation identify all wallets as separate custody
  surfaces.

