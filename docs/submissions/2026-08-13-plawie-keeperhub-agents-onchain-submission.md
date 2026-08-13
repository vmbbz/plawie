# Plawie — Human-Governed Agent Wallet

> **KeeperHub Agents Onchain submission dossier · 13 August 2026**
> **Track thesis:** The agent proposes. KeeperHub executes reliably. The phone
> makes the human decision unavoidable.

| Submission field | Value |
|---|---|
| Project | **Plawie — Human-Governed Agent Wallet** |
| Product | Native-first OpenClaw Gateway and companion for Android |
| Website | <https://plawie.app> |
| Source | <https://github.com/vmbbz/plawie/tree/codex/hybrid-bridge-funding-design> |
| Canonical KeeperHub transaction | [Base Mainnet `0xdcf1a13c…73117b04`](https://basescan.org/tx/0xdcf1a13c3e83ded25c8104e5aa654ff300f381269a506a83b69fd9fd73117b04) |
| Supporting KeeperHub transaction | [Base Mainnet `0x9ce5e377…d6def2a9`](https://basescan.org/tx/0x9ce5e37757383b1bd28232bd3a1d72e501671d5557a90aad1ddaca8ed6def2a9) |
| Demo video | **ADD THE FINAL PUBLIC VIDEO URL BEFORE SUBMISSION** |
| Long-form technical article | [The Agent Can Reason. The Phone Still Decides.](../articles/2026-08-11-plawie-human-governed-keeperhub-agent-wallet.md) |
| Detailed evidence runbook | [Live evidence runbook](../HACKATHON_LIVE_EVIDENCE_RUNBOOK.md) |
| Evidence status | Agent-originated inert proposal captured; two intentional sponsored proofs verified on Base Mainnet; one pre-execution rejection recorded |

> [!IMPORTANT]
> The source, transaction, and product links above are ready. The final short
> demo video and a signed-in DoraHacks form review remain mandatory submission
> tasks. Confirm the platform's exact closing time and optional bounty wording
> in the live form; the public event page is protected by an interactive WAF.

---

## Executive summary

Plawie runs the full OpenClaw Gateway natively on Android. It gives a mobile AI
agent useful skills, device tools, model choice, wallets, and a persistent local
control surface without requiring a PC or hosted Gateway.

For on-chain action, Plawie introduces a deliberately different trust model:
the model may understand a request and prepare one tightly bounded intent, but
it cannot approve, authenticate, sign, submit, retry, revoke credentials, or
move non-zero value. KeeperHub supplies the execution and reliability layer:
headless organization-wallet provisioning, simulation, sponsored execution,
stable idempotency, status reconciliation, and authoritative receipts. Plawie
binds those capabilities to a visible foreground review and fresh Android
authentication.

The live proof is a real, sponsored, zero-value Base Mainnet self-transfer from
a separately labelled KeeperHub-managed Agent Execution Wallet. The zero value
is an intentional safety constraint, not a mocked transaction. The canonical
execution settled successfully in block `49,896,836`; Plawie restored its
verified terminal receipt after an app update and relaunch without resubmitting
the work. A second separately authorized intent also settled successfully. A
third simulated proposal was explicitly discarded before authentication and
produced no transaction.

A fourth proposal was then prepared through the real OpenClaw
`keeperhub.prepare` capability. It remains inert in `awaitingApproval`: Plawie
shows **Ready for human review**, with no execution ID and no transaction hash.
This is direct physical-device evidence of the agent/human authority split. It
is intentionally being preserved for the final demo rather than submitted in
the background.

This is the product claim:

> **Plawie turns an Android phone into the human-governed execution boundary
> between an AI agent's intent and KeeperHub's on-chain reliability layer.**

---

## The problem

Agents are increasingly capable of reasoning about consequential actions. The
harder production problem begins after the model decides what should happen:

- a transaction can revert or land with a different outcome than a client
  assumes;
- an interrupted request can tempt a client into a duplicate submission;
- credentials can leak into model context, logs, or generic tool payloads;
- a persuasive model response is not meaningful user authorization;
- mobile processes and networks disappear at inconvenient times;
- wallet custody and approval authority are often blurred into one unsafe hot
  account.

Plawie addresses the boundary rather than pretending those failures disappear.

```mermaid
flowchart LR
    A[OpenClaw agent<br/>reasons and prepares] --> B[Plawie policy<br/>one typed intent]
    B --> C[KeeperHub<br/>simulate]
    C --> D[Android foreground review<br/>exact effect displayed]
    D -->|Discard| X[Rejected<br/>no authentication<br/>no execution]
    D -->|Approve| E[Fresh device authentication<br/>request-bound attestation]
    E --> F[KeeperHub<br/>execute once]
    F --> G[Persisted execution ID<br/>bounded reconciliation]
    G --> H[Authoritative receipt<br/>verified on-chain]
```

---

## Why KeeperHub is essential—not decorative

Plawie already had wallets and a native Android runtime. We did not add
KeeperHub merely to obtain a transaction link. KeeperHub owns the part of the
architecture it is designed to solve: reliable execution after agent intent.

| KeeperHub surface | How Plawie uses it | Why it matters |
|---|---|---|
| Headless onboarding | Android-authenticated SIWE establishes the user and provisions a separate organization execution wallet and credential | No dashboard visit or copied API key is required; the execution account is distinct from the personal wallet |
| Direct simulation | The exact zero-value transfer is simulated before a review can become actionable | The person reviews an effect KeeperHub says will not revert, not an untested model suggestion |
| Stable idempotency | Plawie persists one deterministic work key before submission and never rotates it while the outcome is ambiguous | A dropped response cannot justify broadcasting freshly reconstructed work |
| Sponsored direct execution | KeeperHub broadcasts the approved proof and sponsors gas | The proof is a real Base Mainnet execution without asking the user to fund an operational wallet with ETH |
| Execution status | Plawie retains the returned execution ID and polls with bounded timing | Mobile recovery is based on the original execution, not blind retry |
| Authoritative receipts | Plawie requires a matching re-fetched receipt with a successful status and verification timestamp | A transaction URL alone is not treated as success |
| Remote credential revocation | A separately authenticated flow revokes the organization key before local deletion | “Disconnect” is not a cosmetic local toggle |

This follows KeeperHub's current Direct Execution contract: simulate the same
body, send it once with a stable `Idempotency-Key`, retain the `executionId`,
poll status, and treat the returned receipts as authoritative on-chain proof.

Plawie intentionally did **not** expose KeeperHub's generic write-capable MCP
catalog or organization bearer key to the model. The integration uses a narrow
app-owned REST client because a mobile approval surface is a security boundary,
not an agent tool.

---

## Two wallets, two authorities

| Wallet | Role | Custody | Agent access |
|---|---|---|---|
| Personal Wallet | User identity and Android-authenticated approval authority | Plawie self-custody, protected by Android platform controls | No private-key access; no autonomous signing |
| Agent Execution Wallet | Operational account for bounded KeeperHub execution | KeeperHub/Turnkey-managed organization wallet | Redacted status/receipts and proposal preparation only |

```mermaid
flowchart TB
    subgraph Phone[Plawie on Android]
        P[Personal Wallet<br/>identity and approval]
        U[Foreground Wallet UI<br/>review and authentication]
        S[Encrypted app storage<br/>KeeperHub organization credential]
        R[Redacted receipt ledger]
        A[OpenClaw agent]
    end

    subgraph KH[KeeperHub]
        O[Organization]
        W[Agent Execution Wallet]
        E[Simulation and execution]
        V[Status and verified receipts]
    end

    P -->|bounded SIWE| O
    O --> W
    S -->|fixed-origin requests| E
    U -->|one authenticated approval| E
    W --> E --> V --> R
    A -. capabilities / status / receipts / prepare .-> R
    A -. cannot read .-> S
    A -. cannot cross .-> U
```

The current human gate is app-enforced. The long-term production target is a
multi-owner Safe in which device approval is also an on-chain threshold
condition. Until that integration is available and audited, the managed Agent
Execution Wallet remains optional, clearly labelled, minimally funded, and
separate from personal assets.

---

## Agent authority contract

The OpenClaw capability exports only four commands:

- `keeperhub.capabilities`
- `keeperhub.status`
- `keeperhub.receipts`
- `keeperhub.prepare`

The capability reports these effective permissions:

| Capability | Agent |
|---|---:|
| Read connection status | Allowed |
| Read redacted receipts | Allowed |
| Prepare one zero-value Base Mainnet proof | Allowed |
| Open the approval UI | Denied |
| Approve or authenticate | Denied |
| Sign or submit | Denied |
| Retry a write | Denied |
| Revoke credentials | Denied |
| Execute a generic workflow | Denied |
| Move non-zero value | Denied |

`keeperhub.prepare` calls the same production coordinator used by the Wallet
surface. It simulates and persists an inert proposal, then tells the user to
open **Wallet → Agent Execution Wallet**. Approval remains impossible through
chat, the Gateway, background lifecycle events, or an agent-generated payload.

---

## Live Base Mainnet proof

### Canonical execution

| Evidence field | Value |
|---|---|
| Network | Base Mainnet (`8453`) |
| Agent Execution Wallet | `0x8f04a0b7192b9da472d5a1b63d75ee61fa7cd788` |
| Intent | `kh_99dc92c349164d77b5895bdaf195117e` |
| KeeperHub execution | `59ja3y71gxctnet4zprd8` |
| Action | Exact `0 ETH` self-transfer |
| Simulation | Success; would not revert; estimate `21,000` gas |
| Sponsored | `true` |
| Idempotent replay | `false` |
| Transaction | [`0xdcf1a13c3e83ded25c8104e5aa654ff300f381269a506a83b69fd9fd73117b04`](https://basescan.org/tx/0xdcf1a13c3e83ded25c8104e5aa654ff300f381269a506a83b69fd9fd73117b04) |
| Block | `49,896,836` |
| Gas used | `80,521` |
| KeeperHub receipt | `success`, `verified: true` |
| Public Base RPC | `status: 0x1`, matching transaction and block |
| KeeperHub verification time | `2026-08-13T01:03:41.947Z` |

The public transaction is a sponsored delegated execution envelope. Its outer
sender and target belong to KeeperHub's execution infrastructure; the bounded
Agent Wallet self-transfer is encoded in the call. We state this explicitly so
the proof is not misrepresented as a plain EOA transaction.

### Independent supporting execution

The user separately authorized a second fresh intent. It is supporting evidence,
not a retry of the canonical transaction:

| Evidence field | Value |
|---|---|
| Intent | `kh_d21d76a707a8417b8b3f31a425cf4a99` |
| KeeperHub execution | `vxy25qnik2izi1adeguhs` |
| Transaction | [`0x9ce5e37757383b1bd28232bd3a1d72e501671d5557a90aad1ddaca8ed6def2a9`](https://basescan.org/tx/0x9ce5e37757383b1bd28232bd3a1d72e501671d5557a90aad1ddaca8ed6def2a9) |
| Block | `49,897,134` |
| Gas used | `40,921` |
| KeeperHub receipt | `success`, `verified: true` |
| Public Base RPC | `status: 0x1`, matching transaction and block |
| Idempotent replay | `false` |

### Negative boundary

A third proposal was simulated but deliberately discarded before Android
authentication. Plawie persisted `Rejected before execution`; no third
transaction appeared. This proves the review is a real decision point rather
than a decorative confirmation screen.

### Agent-originated pending proof

The OpenClaw agent successfully invoked `keeperhub.prepare` for a fourth intent,
`kh_e792af590b8c4e00b09bf38151e222f8`. KeeperHub simulation completed and the
record reached `awaitingApproval`, but there is no `executionId` and no
transaction hash. The Wallet exposes only **Review & authorize** or **Discard**;
chat cannot advance the request.

During the model's post-tool narration, Venice returned `403
foreground_turn_required`. Code-path analysis identified Android's
biometric/system authentication overlay as the source of a transient
`inactive` lifecycle state, which erased the paid-provider turn lease before
the continuation. It did not reject or broadcast KeeperHub work. Plawie now
treats `inactive` as temporarily obscured while still erasing the lease on
`paused`, `hidden`, or `detached`.
Focused regression tests preserve all existing expiry, model binding,
single-payment, cancellation, and background fail-closed behavior.

![Agent-prepared proof waiting at the human Wallet boundary](../articles/assets/keeperhub/keeperhub-agent-prepared-for-human-review.png)

![Simulation-bound Base Mainnet proposal awaiting human review](../articles/assets/keeperhub/keeperhub-base-mainnet-review.png)

![Proposal discarded before authentication or execution](../articles/assets/keeperhub/keeperhub-base-mainnet-rejected.png)

![Two separately authorized KeeperHub proofs with verified receipt metadata](../articles/assets/keeperhub/keeperhub-base-mainnet-verified-receipt.png)

---

## Reliability and observability

Plawie persists a canonical state machine around KeeperHub:

```mermaid
stateDiagram-v2
    [*] --> Proposed
    Proposed --> SimulationFailed: invalid or reverting simulation
    Proposed --> AwaitingApproval: safe simulation
    AwaitingApproval --> Rejected: discard, cancel, background, or expiry
    AwaitingApproval --> Approved: visible approval and Android authentication
    Approved --> Submitting: exact body and persisted key
    Submitting --> Polling: execution ID received
    Submitting --> OutcomeUnknown: ambiguous response
    OutcomeUnknown --> Polling: same key or known execution ID
    Polling --> Completed: authoritative receipt verified
    Polling --> Failed: terminal failure
    Completed --> [*]
    Rejected --> [*]
    SimulationFailed --> [*]
    Failed --> [*]
```

The canonical receipt survived a force-stop/relaunch after completion, and the
final debug APK update preserved the Agent Wallet connection, three terminal
records, and the inert agent-originated proposal. We do **not** claim that this
proves the stronger case of
killing the process between broadcast and final receipt. That in-flight stress
test remains a follow-up item; its coordinator paths are automated-tested but
have not yet been recorded live.

### Verification results

| Gate | Result |
|---|---|
| KeeperHub Flutter tests | **41 passed, 0 failed** |
| Paid-provider lifecycle/tool-loop regression tests | **30 passed, 0 failed** |
| Android-native KeeperHub message-policy tests | **5 passed, 0 failed** |
| Dart analyzer for changed production/test files | **No issues** |
| Android arm64 debug build | **Passed** |
| Installed APK equals local artifact | **Exact SHA-256 match** |
| Installed APK SHA-256 | `7F48B540F2D7C708895DB59B7E81B7A7CC3ED7DCA3F44799438BF1C3432162E6` |
| Existing app/wallet data after update | **Preserved**; original install date `2026-07-26` |

The test surface covers headless onboarding, fixed-origin API behavior,
encrypted credential storage, remote revocation, policy parsing, approval
exclusivity, cancellation, simulation failure, attestation mismatch,
idempotency conflict/in-progress handling, ambiguous submission, status-only
recovery, receipt verification, agent capability restrictions, and Wallet UI.

---

## Implementation map

| Concern | Primary source |
|---|---|
| Bounded OpenClaw capability | [`lib/services/capabilities/keeperhub_capability.dart`](../../lib/services/capabilities/keeperhub_capability.dart) |
| Simulation, approval, execution, recovery | [`lib/services/keeperhub/keeperhub_execution_coordinator.dart`](../../lib/services/keeperhub/keeperhub_execution_coordinator.dart) |
| Headless SIWE onboarding and revocation | [`lib/services/keeperhub/keeperhub_headless_onboarding_service.dart`](../../lib/services/keeperhub/keeperhub_headless_onboarding_service.dart) |
| Fixed-origin KeeperHub API client | [`lib/services/keeperhub/keeperhub_api_client.dart`](../../lib/services/keeperhub/keeperhub_api_client.dart) |
| Base Mainnet proof policy and idempotency | [`lib/services/keeperhub/keeperhub_policy.dart`](../../lib/services/keeperhub/keeperhub_policy.dart) |
| Persisted execution/receipt state | [`lib/services/keeperhub/keeperhub_receipt_store.dart`](../../lib/services/keeperhub/keeperhub_receipt_store.dart) |
| Agent Wallet control surface | [`lib/widgets/keeperhub_agent_wallet_card.dart`](../../lib/widgets/keeperhub_agent_wallet_card.dart) |
| Exclusive foreground review | [`lib/widgets/keeperhub_execution_review_dialog.dart`](../../lib/widgets/keeperhub_execution_review_dialog.dart) |
| Android request-bound policy | [`android/app/src/main/kotlin/com/openclaw/plawie/KeeperHubMessagePolicy.kt`](../../android/app/src/main/kotlin/com/openclaw/plawie/KeeperHubMessagePolicy.kt) |
| Flutter regression tests | [`test/`](../../test/) files prefixed `keeperhub_` |
| Android policy tests | [`KeeperHubMessagePolicyTest.kt`](../../android/app/src/test/kotlin/com/openclaw/plawie/KeeperHubMessagePolicyTest.kt) |

---

## Judging strategy

The public event summary reports five judging themes. Lead with evidence in this
order:

| Reported theme | Plawie evidence | How to present it |
|---|---|---|
| Execution | Two successful sponsored Base Mainnet transactions through KeeperHub | Open the canonical BaseScan link, then show the matching verified receipt in Plawie |
| Use of KeeperHub surfaces | Headless onboarding plus simulate/execute/status/receipt APIs | Show that KeeperHub provisions, simulates, broadcasts, sponsors, and verifies; it is not a logo or generic fetch |
| Reliability and observability | Persisted work identity, bounded polling, fail-closed unknown state, terminal receipt restoration, public RPC check | Focus on duplicate prevention and authoritative receipts; state the remaining in-flight live test honestly |
| Originality and usefulness | A native Android human-governed execution boundary for a local OpenClaw agent | Demonstrate that consequential actions become portable without turning the phone into an unattended hot wallet |
| Integration quality | Two-wallet architecture, no copied API key, model cannot approve/submit, exclusive secure review, 41 KeeperHub Flutter + 5 native policy tests, plus 30 paid-provider lifecycle tests | Show the capability denial matrix and the rejection path before the successful proof |

### Positioning

Lead with **human-governed agent execution on a phone**, not with Plawie's broad
feature list. Skills, model providers, bridging, and virtual-companion UI are
useful product context, but they dilute the KeeperHub story if shown first.

The differentiator is not “we made another agent wallet.” It is:

1. the OpenClaw agent runs locally on the phone;
2. KeeperHub supplies a real execution/reliability layer;
3. a separate execution wallet limits custody exposure;
4. the agent can prepare but cannot cross the foreground approval boundary;
5. the resulting receipt is visible, persisted, and independently verifiable.

If the signed-in form exposes a separate **headless onboarding** bounty, opt in
only after confirming its wording. Plawie's in-app SIWE, organization creation,
credential step-up, wallet provisioning, and remote revocation are a strong fit.
Do not claim a KeeperHub x402/MPP integration in this submission: Plawie's paid
model paths use those payment ideas elsewhere, but this live KeeperHub proof
uses Direct Execution.

---

## Demo video storyboard — 2 minutes 30 seconds

The reported event requirement is a short video showing an agent execute
on-chain through KeeperHub. Record a clean vertical phone capture plus a short
desktop/explorer insert. Do not use a mocked receipt.

| Time | Shot | Voiceover / caption | Proof goal |
|---:|---|---|---|
| `0:00–0:12` | Plawie hero/dashboard, then Wallet | “Plawie runs OpenClaw natively on Android. For on-chain action, the agent proposes, KeeperHub executes, and the phone keeps the human in control.” | Product and thesis |
| `0:12–0:28` | Personal Wallet and Agent Execution Wallet | “Personal assets and operational execution are separate. KeeperHub/Turnkey manages the Agent Execution Wallet; the phone remains the approval authority.” | Custody clarity |
| `0:28–0:48` | Chat asks KeeperHub to prepare the proof | “The agent can inspect status and prepare exactly one zero-value Base Mainnet proof. It cannot approve or submit.” | Agent origin and bounded tools |
| `0:48–1:05` | Wallet shows the inert proposal and successful simulation | “KeeperHub simulated the exact request before it became actionable.” | Real KeeperHub simulation |
| `1:05–1:20` | Review sheet with chain, wallets, value, reason, expiry | “The request is immutable and visible. Leaving, rejecting, or expiring stops it.” | Human review contract |
| `1:20–1:35` | Android authentication and bounded progress state | “Fresh device authentication binds this exact approval. The model has no route to this step.” | Non-bypassable app boundary |
| `1:35–1:52` | Verified receipt in Plawie | “KeeperHub executed once, sponsored gas, and returned an authoritative verified receipt.” | Successful execution |
| `1:52–2:05` | Canonical BaseScan transaction | “This is the matching Base Mainnet proof, independently reachable on-chain.” | Required transaction link |
| `2:05–2:18` | Rejected record above the receipts | “A separate simulated proposal was discarded before authentication and produced no transaction.” | Negative-path evidence |
| `2:18–2:30` | Architecture graphic / closing Wallet view | “Plawie makes useful agent autonomy portable while keeping consequential authority visible in the user's hand.” | Memorable close |

### Recording rules

- Use the actual Chat UI to trigger `keeperhub.prepare`; a Wallet-button-only
  video weakens the “agent executing” requirement.
- Keep the transaction amount at exactly `0 ETH` and Base Mainnet chain ID
  `8453`.
- Record the execution ID before switching screens.
- Do not expose API keys, signatures, cookies, full device IDs, private keys, or
  unrelated wallet balances.
- If connectivity is unstable, do not reconstruct a new request as a retry.
  Preserve the original proposal and idempotency identity.
- If an in-flight interruption is not captured cleanly before the deadline,
  omit that claim. The verified mainnet proof is stronger than a staged failure
  presented ambiguously.

---

## Submission-form copy

### Project name

`Plawie — Human-Governed Agent Wallet`

### One-line tagline

`A local OpenClaw agent proposes; KeeperHub executes; Android keeps the human in control.`

### Short description

Plawie runs OpenClaw natively on Android and turns the phone into a
human-governed on-chain execution boundary. The agent can prepare one bounded
intent, KeeperHub simulates and executes it reliably, and only a visible,
freshly authenticated mobile approval can authorize submission.

### Full submission description

Plawie is a native-first Android home for OpenClaw: the full Gateway runs on the
phone, alongside skills, device tools, model choice, a virtual companion, and
wallets. For the KeeperHub Agents Onchain hackathon we built a Human-Governed
Agent Wallet that addresses the dangerous gap between an AI agent's decision
and a real transaction.

The OpenClaw agent can inspect KeeperHub status, read redacted receipts, and
prepare exactly one zero-value Base Mainnet self-transfer. It cannot open the
approval UI, approve, authenticate, sign, submit, retry, revoke credentials, run
generic KeeperHub writes, or move non-zero value. KeeperHub provisions a
separate organization execution wallet through headless SIWE, simulates the
exact transaction, executes it with a persisted idempotency key, sponsors gas,
and exposes status plus authoritative receipts. Plawie displays an immutable
foreground review and requires fresh Android authentication before calling the
execution path.

We proved the integration with two separately authorized sponsored Base
Mainnet executions. The canonical transaction settled successfully in block
49,896,836 and its KeeperHub receipt was independently reconciled through a
public Base RPC. We also recorded a separate proposal being rejected before
authentication with no execution. The result is useful agent autonomy without
silently turning a mobile assistant into an unattended hot wallet.

### What we aimed to prove

1. A local mobile agent can reach a real on-chain execution layer without moving
   its Gateway to a hosted server.
2. KeeperHub can be integrated as execution infrastructure—not a generic wallet
   method exposed to a language model.
3. Agent intent and human authorization can remain separate, visible, and
   testable.
4. Mobile interruption uncertainty can be handled with persisted idempotency,
   execution IDs, status reconciliation, and authoritative receipts.
5. A managed execution wallet can remain distinct from a user's personal
   self-custodial wallet.

### KeeperHub features used

- Headless SIWE onboarding
- Organization wallet provisioning
- Organization-scoped API credential lifecycle
- Direct transfer simulation
- Sponsored Base Mainnet direct execution
- Stable idempotency keys
- Execution status polling
- Re-fetched verified receipts and transaction links
- Remote API-key revocation

### Tech stack

- Flutter / Dart native Android application
- OpenClaw local Gateway and capability protocol
- KeeperHub headless onboarding and Direct Execution REST APIs
- Kotlin Android security/message policy
- Android Keystore-backed authentication and secure storage
- Base Mainnet
- KeeperHub / Turnkey-managed Agent Execution Wallet

### Key accomplishments

- Created a KeeperHub Agent Execution Wallet entirely inside the mobile app
  without asking the user to copy an API key.
- Exposed a deliberately bounded OpenClaw capability with no agent approval or
  submission command.
- Executed and independently verified two sponsored Base Mainnet proofs.
- Recorded a simulation-bound rejection that generated no transaction.
- Persisted verified receipts across process/app updates without wallet loss.
- Passed 41 KeeperHub Flutter tests and five Android-native message-policy tests
  with zero failures.

### Challenges

The hardest part was not broadcasting a transfer. It was defining an authority
contract that stays correct when a model, a mobile lifecycle, and an unreliable
network all interact. We had to keep KeeperHub credentials outside model/Gateway
context, bind simulation to the reviewed request, persist one work identity
before submission, reject ambiguous or mismatched receipts, and make approval a
foreground, freshly authenticated Android operation.

### What is next

- Record and validate the in-flight process-death recovery case on a physical
  device without creating a duplicate execution.
- Collaborate on a multi-owner Safe design so device approval becomes an
  on-chain threshold condition rather than only an app-enforced gate.
- Add audited, typed KeeperHub workflow allowlists rather than exposing a broad
  generic write catalog.
- Explore KeeperHub marketplace payments only through Plawie's existing visible
  human-approval policy.
- Complete Google Play compliance, privacy disclosures, release signing, and
  production acceptance testing.

### Suggested tags

`AI Agents`, `OpenClaw`, `KeeperHub`, `Android`, `Base`, `Agent Wallet`,
`Human-in-the-loop`, `On-chain Execution`, `Wallet Security`

---

## Submission checklist

### Required artifacts reported by the event listing

- [x] Public source branch URL prepared
- [x] Real transaction executed through KeeperHub
- [x] Canonical BaseScan transaction URL prepared
- [ ] Short public demo video uploaded and URL inserted at the top of this file
- [ ] Signed-in DoraHacks form reviewed for exact deadline/timezone and any
      changed requirements

### Evidence quality

- [x] KeeperHub execution ID recorded
- [x] KeeperHub verified receipt recorded
- [x] Public Base RPC independently returned successful receipt status
- [x] Physical-device review screenshot captured
- [x] Physical-device rejection screenshot captured
- [x] Physical-device verified-receipts screenshot captured
- [x] Physical-device agent-originated inert proposal captured
- [x] Separate second intent described as distinct user-authorized work, not a
      replay or accidental duplicate
- [x] Sponsored delegated envelope explained accurately
- [x] Terminal receipt persistence distinguished from unproven in-flight
      recovery
- [ ] Final video records the already-proven agent-originated
      `keeperhub.prepare` path end-to-end
- [ ] Final media redaction review completed

### Repository and release hygiene

- [x] KeeperHub regression suite passes
- [x] Android-native policy suite passes
- [x] Changed Dart files analyze cleanly
- [x] Final APK installed without clearing wallet data
- [x] Local and installed APK hashes match
- [ ] Confirm the pushed source branch is publicly readable from a signed-out
      browser before submitting
- [ ] Add the final public video link; do not submit a placeholder

---

## Honest limitations

- The canonical live transaction was initiated from Plawie's Wallet proof
  control. The agent-facing preparation path is now proven on-device and has
  produced a separate inert proposal, but the final video still needs to record
  that already-observed path end-to-end before a newly authorized execution.
- Completed receipt persistence after force-stop/relaunch is proven. A live
  interruption specifically during polling is not yet recorded.
- The current human approval gate is strongly enforced by Plawie and Android,
  but is not yet a multi-owner on-chain threshold requirement.
- The KeeperHub Agent Execution Wallet is managed through KeeperHub/Turnkey and
  is intentionally separate from Plawie's self-custodial Personal Wallet.
- Arbitrary calldata, generic KeeperHub writes, non-zero KeeperHub transfers,
  and autonomous payment are deliberately out of scope for this slice.
- Plawie existed before the event. The KeeperHub Human-Governed Agent Wallet
  integration, evidence flow, and submission work are the hackathon vertical
  slice; the broader native OpenClaw app is the host product.

These limitations are part of the design story. Plawie is not claiming that
agent-wallet risk has vanished; it demonstrates a narrow, useful execution
contract and shows exactly where stronger protocol enforcement belongs next.

---

## References

### KeeperHub primary sources

- [KeeperHub overview](https://docs.keeperhub.com/)
- [Headless onboarding](https://docs.keeperhub.com/api/headless-onboarding)
- [Direct Execution API](https://docs.keeperhub.com/api/direct-execution)
- [Authentication and organization API keys](https://docs.keeperhub.com/api/authentication)
- [Agentic wallets](https://docs.keeperhub.com/ai-tools/agentic-wallet)
- [Marketplace and agent payments](https://docs.keeperhub.com/workflows/marketplace)
- [KeeperHub for agents](https://keeperhub.com/agents)

### Event

- [KeeperHub Agents Onchain on DoraHacks](https://dorahacks.io/hackathon/agents-onchain)

The signed-in DoraHacks form is the final authority for submission fields,
closing time, eligibility, and optional bounties.
