# The Agent Can Reason. The Phone Still Decides.

## Building a human-governed mobile Agent Wallet with Plawie, OpenClaw, KeeperHub, and Android

> **Publication status — 11 August 2026:** Engineering draft. The software
> architecture described below is implemented. The final article must not be
> published as a completed on-chain case study until the physical-device
> KeeperHub onboarding, zero-value Base Sepolia execution, interruption
> recovery, and independently verifiable transaction receipt have been
> captured. Public source and install links are intentionally held until
> Plawie's 12 August release.

AI agents have become surprisingly good at deciding what should happen next.
They can research a market, inspect a task queue, prepare a transaction, and
explain a proposed action in plain language.

The harder problem begins after the decision.

An on-chain action must survive unreliable networks, process death, duplicate
retries, stale state, and ambiguous responses. It also needs an authority model
that does not quietly turn a helpful agent into an unattended hot wallet.

Plawie's answer is deliberately simple:

> **The agent proposes. KeeperHub executes reliably. The phone makes the human
> decision unavoidable.**

This is not an AI wallet that can spend whenever a model emits a tool call. It
is a native Android control surface that lets an agent prepare one bounded
intent, lets KeeperHub simulate and execute it, and requires the person holding
the device to inspect and authenticate the exact request before submission.

That distinction is the product.

---

## The thesis: autonomy needs a visible boundary

Plawie runs OpenClaw as a native-first Android application. The agent can use a
local Gateway, inspect skill readiness, and interact with device capabilities.
Wallet execution, however, crosses a different risk boundary. A persuasive
model response is not authorization.

The KeeperHub integration therefore separates four responsibilities:

| Layer | Responsibility | Explicitly cannot do |
|---|---|---|
| OpenClaw agent | Understand the request, explain it, inspect state, and prepare a bounded proof | Approve, authenticate, sign, submit, retry, revoke credentials, or move mainnet value |
| Plawie | Enforce policy, persist the immutable proposal, display the review, obtain fresh Android authentication, and retain receipts | Silently create an Agent Wallet or execute from background/chat |
| KeeperHub | Provision the organization wallet, simulate the transaction, execute with an idempotency key, expose status, and return receipts | Replace Plawie's human review contract |
| Human | Review network, wallet, recipient, value, reason, simulation, and expiry; then approve or reject | Be bypassed by an agent tool call |

KeeperHub describes itself as an execution and reliability layer between agent
intent and on-chain settlement. Its direct-execution flow supplies the pieces
Plawie needs for the last mile: simulation, idempotent submission, status
polling, and authoritative transaction receipts.

```mermaid
flowchart LR
    A[OpenClaw agent\nreasons and proposes] --> B[Plawie policy boundary\ntyped and bounded intent]
    B --> C[KeeperHub simulation\nexpected effect and risk]
    C --> D[Foreground Wallet review\nexact request displayed]
    D -->|Reject| X[No execution]
    D -->|Approve| E[Fresh Android authentication\nrequest-bound attestation]
    E --> F[KeeperHub execute once\npersisted idempotency key]
    F --> G[Bounded status recovery\nno blind resubmission]
    G --> H[Verified receipt\nexecution ID and transaction]
```

The flow remains human-governed even when the proposal originates in chat. The
agent can get the request to the review boundary; it cannot cross that boundary.

---

## Two wallets, two jobs

Plawie does not ask users to turn their personal wallet into an agent's
execution account.

The Wallet page presents two separate identities:

1. **Personal Wallet** — the user's self-custodial Plawie wallet. Its private
   key is protected by Android Keystore-backed application controls and is used
   for explicit, device-authenticated identity operations.
2. **Agent Execution Wallet** — a distinct KeeperHub organization wallet,
   managed through KeeperHub and Turnkey, intended for bounded execution and
   limited funding.

Plawie uses the product label **Agent Execution Wallet** because it explains
the wallet's job to a mobile user. Technically, the current integration is the
organization wallet created by KeeperHub's headless onboarding flow. It is not
the separate `@keeperhub/wallet` package described in KeeperHub's agentic-wallet
documentation.

That distinction matters. The first-party package has its own `auto`, `ask`,
and `block` safety hook. Plawie instead keeps approval in its native Android UI
and uses the organization credential only through a fixed-origin, allowlisted
REST client. We did not install a generic wallet SDK and hand its methods to the
model.

The execution wallet should be treated like an operational account: optional,
clearly labelled, minimally funded, and separate from the user's primary
assets. A compromised operational credential should never expose the Personal
Wallet.

```mermaid
flowchart TB
    subgraph Device[Plawie on Android]
        P[Personal Wallet\nself-custodial identity]
        U[Visible Wallet UI\nreview and device authentication]
        S[Encrypted app storage\norganization credential]
        R[Redacted local receipts]
    end

    subgraph KeeperHub[KeeperHub]
        O[Organization]
        K[Agent Execution Wallet\nKeeperHub / Turnkey custody]
        E[Simulation and execution]
    end

    P -->|bounded SIWE and key challenge| O
    O --> K
    S -->|fixed-origin authenticated requests| E
    K --> E
    U -->|one reviewed request| E
    E --> R

    A[OpenClaw agent] -. status / receipts / prepare only .-> R
    A -. cannot read credential .- S
    A -. cannot approve or submit .- U
```

---

## Onboarding without a copied API key

A serious mobile onboarding flow cannot require the user to visit a dashboard,
copy a long-lived secret, paste it into chat, and hope it never appears in a
log.

KeeperHub's headless onboarding API makes a better path possible. In Plawie,
the user explicitly taps **Create Agent Execution Wallet**. Nothing is created
during app startup, setup, chat, or card rendering.

The sequence is:

```mermaid
sequenceDiagram
    actor Human
    participant UI as Plawie Wallet UI
    participant Native as Android secure wallet
    participant KH as KeeperHub API
    participant Store as Encrypted app storage

    Human->>UI: Tap Create Agent Execution Wallet
    UI->>Human: Explain separate custody and request consent
    Human->>UI: Continue
    UI->>KH: Request SIWE nonce
    KH-->>UI: Nonce
    UI->>Native: Request exact bounded SIWE signature
    Native->>Human: Android authentication
    Human-->>Native: Authenticate
    Native-->>UI: Address and signature
    UI->>KH: Verify SIWE with trusted Origin
    KH-->>UI: Session and organization context
    UI->>KH: Request organization key creation
    KH-->>UI: Exact wallet step-up challenge
    UI->>Native: Validate and sign exact challenge
    Native->>Human: Fresh Android authentication
    Human-->>Native: Authenticate
    Native-->>UI: Challenge signature
    UI->>KH: Create organization credential
    KH-->>UI: Returned-once organization key
    UI->>Store: Encrypt key and provisioning record
    UI->>KH: Discover separate organization wallet
    KH-->>UI: Agent Execution Wallet address
    UI->>Human: Show both wallets and custody labels
```

Several details are deliberately defensive:

- The KeeperHub origin and API paths are fixed and allowlisted.
- Redirects are rejected instead of followed across origins.
- SIWE cookies live only in the short-lived client instance; they are not
  persisted as application credentials.
- Session-cookie authentication and organization-key authentication cannot be
  mixed in one request.
- Android reconstructs and validates the exact SIWE and key-management
  challenge contract before signing.
- The returned-once organization credential is written to encrypted app
  storage and never placed in OpenClaw configuration, agent context, Gateway
  logs, receipts, or capability payloads.
- If remote wallet provisioning is still pending after the credential is
  issued, Plawie retains an honest recoverable state instead of losing or
  recreating the credential.

Revocation follows the same philosophy. It needs fresh device authentication,
targets the stored organization key ID, and clears the local secret only after
KeeperHub confirms revocation or confirms that the key is already unavailable.
An ambiguous network result becomes `revocationUnknown`; the app keeps the
encrypted credential so the person can safely retry rather than pretending the
remote capability has disappeared.

---

## The agent gets a capability, not a wallet API

The easiest integration would have been to expose KeeperHub's generic execution
surface to OpenClaw. It would also have been the wrong integration.

Plawie exposes four bounded capability commands:

| Command | What it returns or changes |
|---|---|
| `keeperhub.capabilities` | Declares custody, proof network, amount, and every denied authority |
| `keeperhub.status` | Reads redacted connection state and any active execution |
| `keeperhub.receipts` | Reads at most 20 redacted local receipts without credentials or signatures |
| `keeperhub.prepare` | Simulates and persists one zero-value Base Sepolia self-transfer proposal |

`keeperhub.prepare` does **not** open an approval sheet and does **not** submit a
transaction. It returns the next human action: open **Wallet → Agent Execution
Wallet**, then review or discard the prepared proof.

The current proof contract is intentionally narrow:

- network: Base Sepolia;
- chain ID: `84532`;
- asset and amount: `0 ETH`;
- sender and recipient: the same Agent Execution Wallet;
- objective: bounded plain text;
- no arbitrary contract call;
- no generic workflow execution;
- no mainnet value.

This produces a useful first proof without pretending that arbitrary autonomous
spending is production-ready. KeeperHub itself recommends beginning with a real
zero-value Base Sepolia transaction in its headless onboarding guide.

---

## Simulation is useful only if approval is bound to it

Showing a simulation and later submitting a different request is security
theatre. Plawie persists the canonical proof body and derives a stable
idempotency identity from the immutable work fields. The review and Android
attestation are bound to that exact stored request.

The foreground review displays:

- custody and source wallet;
- network and chain ID;
- recipient;
- value;
- human-readable objective;
- simulation outcome;
- request expiry;
- the fact that KeeperHub, not the Personal Wallet, manages the execution key.

The approval broker is one-use and foreground-only. If there is no visible
review host, the request fails closed. If the app backgrounds, the pending
decision is cancelled. KeeperHub reviews and paid-provider payment approvals
share one exclusive, screen-capture-protected surface so two consequential
dialogs cannot overlap or clear each other's secure state.

After the user taps approve, Android asks for fresh authentication and validates
the exact bounded execution fields again. Only then may the coordinator submit
the persisted request.

The Android attestation is an important local control, but we should be precise
about its current limit: KeeperHub does not cryptographically require that
device attestation as an on-chain co-signature. If the organization bearer
credential were stolen outside Plawie, the app's review screen could be
bypassed. That is why the current Agent Execution Wallet remains optional,
separate, and suitable only for tightly limited funds.

The production end state is stronger: a multi-owner Safe in which KeeperHub is
an execution signer and a Plawie-controlled device authority is another owner,
with a threshold above one plus contract/function allowlists and token spending
caps. KeeperHub's current Safe documentation describes a Turnkey EOA as sole
owner with threshold one and optional Zodiac restrictions. In that model, a
compromised sole owner can bypass module restrictions. Multi-owner,
device-co-signed enforcement is therefore a future protocol collaboration, not
something this article claims is already implemented.

---

## Reliability means surviving uncertainty

Mobile execution cannot assume the process stays alive between “submit” and
“confirmed.” A user can switch apps, lose connectivity, kill the process, or
walk into a tunnel after the network accepts the transaction but before the
client receives the response.

A naive retry can submit twice.

Plawie handles that uncertainty as persisted state:

```mermaid
stateDiagram-v2
    [*] --> Proposed: canonical request stored
    Proposed --> SimulationFailed: simulation rejects or reverts
    Proposed --> AwaitingApproval: simulation succeeds
    AwaitingApproval --> Rejected: human rejects / app backgrounds / expires
    AwaitingApproval --> Approved: visible approval + Android authentication
    Approved --> Submitting: submit exact body once
    Submitting --> Polling: KeeperHub execution ID known
    Submitting --> OutcomeUnknown: response ambiguous
    OutcomeUnknown --> Polling: recover with same idempotency key or known ID
    Polling --> Polling: honor bounded poll hint
    Polling --> Completed: authoritative matching receipt verified
    Polling --> Failed: terminal failure
    Completed --> [*]
    Rejected --> [*]
    SimulationFailed --> [*]
    Failed --> [*]
```

Before submission, Plawie persists the canonical body and idempotency key. A
network ambiguity does not trigger a newly constructed transaction. Recovery
replays the same work identity or polls the existing KeeperHub execution ID.
The coordinator honors KeeperHub's polling hint within bounded limits.

Completion is not inferred from a transaction URL or a self-reported hash.
Plawie requires exactly one authoritative KeeperHub receipt whose transaction
hash matches the execution status, whose chain is Base Sepolia, whose receipt
status is successful, and whose verification timestamp is present. A mismatch
becomes `receipt_not_verified`, not a green success card.

That gives the hackathon demo its most important moment: kill the app while it
is polling, reopen it, and show that the same execution is recovered without a
duplicate transaction.

---

## What exists today, and what still needs proof

The implementation is substantial, but a credible technical story must
separate code-complete controls from evidence-complete behavior.

| Capability | Current status on 11 August 2026 |
|---|---|
| Fixed-origin KeeperHub REST client and strict request handling | Implemented |
| Explicit headless SIWE onboarding and organization-key step-up | Implemented |
| Secure returned-once credential storage and restart recovery | Implemented |
| Separate Personal and Agent Execution Wallet UI | Implemented |
| Bounded agent status, receipt, and proof-preparation commands | Implemented |
| Zero-value Base Sepolia self-transfer policy | Implemented |
| Simulation, immutable request binding, one-use approval, and Android authentication | Implemented |
| Persisted idempotency, bounded polling, restart recovery, and verified receipt checks | Implemented |
| Device-authenticated remote organization-key revocation | Implemented |
| Physical-device KeeperHub account and organization acceptance | **Still required** |
| Live reject/cancel and deliberately failing simulation recording | **Still required** |
| Real zero-value Base Sepolia transaction with interruption recovery | **Still required** |
| Tiny non-zero testnet USDC workflow | Stretch after the zero-value proof |
| Paid x402 marketplace workflow through KeeperHub | Stretch; not implemented |
| Multi-owner Safe with on-chain device co-approval | Production direction; not implemented |

The repository contains 38 focused Flutter tests and five Android policy tests
covering such cases as missing foreground UI, cancellation, immutable request
binding, tampered local state, unexpected redirects, mismatched receipts,
ambiguous submission, status-only recovery, unexpected KeeperHub challenges,
and uncertain remote revocation.

During the 11 August publication audit, the local Flutter and Gradle runners
stalled before test execution on the Windows host. No failed assertion was
reported, but this draft does not convert a stalled runner into a passing test
claim. A clean CI/device run remains part of the evidence gate.

---

## The demo that proves the thesis

A winning demo should show controls under stress, not only a transaction that
works on the first attempt.

### Act 1 — Establish separate authority

1. Open Plawie's Wallet page and show the Personal Wallet.
2. Tap **Create Agent Execution Wallet**.
3. Show the custody disclosure and explicit consent.
4. Complete the two Android-authenticated signing moments.
5. Show the Personal Wallet and the distinct KeeperHub-managed Agent Execution
   Wallet side by side.

### Act 2 — Show that the agent cannot spend

1. Ask the OpenClaw agent what KeeperHub can do.
2. Display the capability response with `approve`, `sign`, `submit`, `retry`,
   and `moveMainnetValue` all denied.
3. Ask the agent to prepare the proof.
4. Show that chat reports an inert proposal and directs the user to Wallet.
5. Demonstrate a cancellation: open review, reject it, and prove there is no
   execution.

### Act 3 — Prove safe execution and recovery

1. Prepare a fresh zero-value Base Sepolia proof.
2. Show the exact successful simulation.
3. Approve visibly and complete fresh Android authentication.
4. Interrupt the app or network during polling.
5. Reopen Plawie.
6. Show recovery of the same KeeperHub execution ID.
7. Show one verified receipt and one explorer transaction—never two.

### Act 4 — Explain the honest boundary

End by showing the two-wallet architecture and stating the limitation directly:
the current local human gate is strong, but the long-term target is a
multi-owner Safe where device approval is also an on-chain threshold condition.
Security honesty is more memorable than pretending the risk has vanished.

---

## Why this belongs in Plawie

This integration is not a KeeperHub logo placed beside an API request.

- It turns the phone into a consequential-action boundary for an OpenClaw
  agent.
- It uses KeeperHub's execution semantics where they matter most: simulation,
  idempotency, recovery, and verified receipts.
- It improves onboarding by creating the user, organization credential, and
  managed wallet through explicit in-app SIWE instead of copied secrets.
- It demonstrates a native Android agent experience rather than a terminal
  wrapper.
- It gives the agent useful wallet awareness without giving it signing
  authority.
- It makes failure, cancellation, custody, and recovery visible to ordinary
  users.

The result is a practical answer to the question every agent-wallet product
eventually faces: **when software can act, where does human authority live?**

In Plawie, it lives in a visible, authenticated moment on the device in the
user's hand.

---

## Publication media checklist

Use real device captures only. Do not mock transaction evidence.

1. **Wallet identities:** Personal Wallet and Agent Execution Wallet cards in
   one frame. Shorten addresses in the UI; do not expose secrets or full logs.
2. **Consent:** “Create Agent Execution Wallet?” disclosure before SIWE.
3. **Onboarding:** safe progress state without a credential, cookie, or
   signature visible.
4. **Bounded agent:** chat response showing the four allowed KeeperHub commands
   and denied execution authority.
5. **Review:** the zero-value Base Sepolia approval sheet showing wallet,
   recipient, amount, reason, simulation, and expiry.
6. **Cancellation:** rejected proof with no transaction.
7. **Recovery:** polling or `outcomeUnknown`, followed by the same execution
   recovered after reopening.
8. **Receipt:** verified transaction card plus independently opened Base
   Sepolia explorer page. This is mandatory before describing the workflow as
   executed.
9. **Architecture visual:** export the two Mermaid diagrams above as crisp SVG
   assets for the article and social thread.

Recommended redactions: organization key ID beyond its short prefix, request
headers, signatures, cookies, full device identifiers, and any unrelated wallet
balances.

---

## Suggested social launch

### Single-post version

> We built Plawie around one rule: the agent can propose an on-chain action, but
> the phone still decides. OpenClaw prepares a bounded intent, KeeperHub
> simulates and executes it reliably, and Android forces visible review plus
> fresh human authentication. Then we kill the app mid-flight and recover the
> same execution—without submitting twice. [article link]

### Five-post thread

1. AI agents are good at deciding. The dangerous part is execution under real
   network and process failure. We built Plawie to make that boundary visible.
2. There are two wallets: an Android-protected Personal Wallet for identity and
   a separately custodial, minimally funded KeeperHub Agent Execution Wallet.
3. The OpenClaw agent can inspect, read redacted receipts, and prepare one
   zero-value Base Sepolia proof. It cannot approve, authenticate, sign, submit,
   retry, revoke credentials, or move mainnet value.
4. KeeperHub provides simulation, idempotent execution, status recovery, and
   verified receipts. Plawie binds those to a foreground review and fresh
   Android authentication.
5. The proof is not just a successful transaction: reject one request, fail one
   simulation, approve another, kill the app during polling, and recover the
   same execution without a duplicate. [video] [article]

---

## Primary references

- [KeeperHub overview](https://docs.keeperhub.com/intro/overview)
- [KeeperHub headless onboarding](https://docs.keeperhub.com/api/headless-onboarding)
- [KeeperHub direct execution](https://docs.keeperhub.com/api/direct-execution)
- [KeeperHub API keys](https://docs.keeperhub.com/api/api-keys)
- [KeeperHub Safe model](https://docs.keeperhub.com/wallet-management/safe)
- [KeeperHub agentic wallet](https://docs.keeperhub.com/ai-tools/agentic-wallet)
- [KeeperHub workflow marketplace](https://docs.keeperhub.com/workflows/marketplace)
- [Agents Onchain hackathon](https://dorahacks.io/hackathon/agents-onchain)

