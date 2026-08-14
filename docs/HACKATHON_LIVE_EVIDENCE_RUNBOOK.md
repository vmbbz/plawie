# Plawie live evidence runbook

**Status — 13 August 2026:** canonical evidence captured. KeeperHub onboarding,
one complete agent-originated execution, three supporting separately authorized
sponsored Base Mainnet proofs, bridge settlement, BlockRun paid chat, Venice
top-up, and Venice chat have been observed on the physical device. The evidence
table distinguishes verified settlement from a successful provider response
whose payment receipt is still unavailable.

## Objective

Produce the minimum defensible evidence for Plawie's KeeperHub hackathon
submission and validate the two wallet-funded model paths without exposing a
seed, private key, signature, organization credential, cookie, or payment
header.

The required KeeperHub proof is a zero-value Base Mainnet self-transfer from
the dedicated KeeperHub Agent Execution Wallet. It is a real mainnet
transaction, but it cannot move non-zero value, target an arbitrary recipient,
include calldata, or grant the agent a generic execution API.

```text
OpenClaw prepares an inert proof
          -> KeeperHub simulates it
          -> Plawie shows the exact foreground review
          -> human approves and authenticates on Android
          -> KeeperHub executes once with an idempotency key
          -> Plawie stores one verified receipt
          -> completed receipt survives app restart without resubmission
```

Deliberately interrupting the app *during* polling remains a separate,
unrecorded reliability stretch. It is not required to describe the completed
agent-originated proof, and completed-receipt persistence must not be presented
as equivalent evidence.

## Scope and safety invariants

- Do not install, clear, export, or rotate the Personal Wallet while running
  this checklist.
- Only a person holding the device may accept an Android authentication prompt
  or a payment/bridge approval. A test operator must not tap through one on the
  user's behalf.
- The KeeperHub proof must remain `Base Mainnet (8453)`, amount `0`, and
  recipient equal to the Agent Execution Wallet. Stop immediately if the
  rendered review shows another network, value, recipient, contract call, or
  expiry that is unexpectedly short.
- Preserve the same generated proposal through interruption recovery. Never
  create a fresh proposal as a "retry" after an ambiguous submission.
- For paid-provider tests, the app must display the live x402 charge and
  receive a fresh visible approval. A background or repeated request must fail
  instead of silently charging again.
- Screenshots may show shortened public addresses and transaction hashes, but
  must not show a seed phrase, private key, full Android/device ID, signature,
  cookie, `kh_` organization key, or `X-402-Payment` header.

## Funding decision

| Test | Funding required | What to fund | Why |
| --- | --- | --- | --- |
| KeeperHub zero-value proof | `0 ETH` value; gas is still required | Prefer KeeperHub sponsorship. If unavailable, fund only the **Agent Execution Wallet** with the minimum Base ETH needed for gas. | Base Mainnet is sponsorship-supported when the organization has gas credits; sponsorship pays gas, not transferred value. |
| BlockRun paid chat | `$3` is the test budget, not a hard-coded price | Plawie's **Personal Wallet** on Base (`8453`) | Proceed only when the fresh `402` price and available Base USDC fit the funded balance. |
| Venice top-up + chat | At least the current `$5` top-up plus bridge/transaction headroom | Plawie's **Personal Wallet** on Base (`8453`) | The 12 August 2026 top-up challenge required `5,000,000` USDC base units (`$5`). A `$3` balance cannot complete that top-up. |

Phantom-held USDC on Solana is not spendable by the current in-app Base signer.
Use Plawie's bridge flow to send it to the Personal Wallet's Base address, and
retain enough SOL in Phantom for the source-chain transaction fee. Do not send
USDC or discretionary production funds to the Agent Execution Wallet for this
proof. If sponsorship is unavailable, stop and fund only the minimum Base ETH
gas amount after checking the simulation.

Venice officially supports Base and Solana wallet authentication, but Plawie's
current x402 payment policy intentionally accepts only Base Mainnet for its
hardware-backed EIP-3009 authorization. This keeps the first production payment
surface narrow and auditable.

## Device preflight

1. Install the verified debug/release artifact with an in-place update. Do not
   uninstall the existing package and do not clear its data.
2. Record the app version, version code, Git commit, artifact SHA-256, and test
   result in the evidence table below.
3. Open **Wallet** and verify that the Personal Wallet address is present and
   that Base Mainnet is shown as the default network.
4. Confirm the live device has connectivity and device authentication enabled.
5. Start a redacted log capture before consequential actions:

   ```powershell
   adb logcat -c
   adb logcat -v threadtime | Select-String -Pattern 'KeeperHub|X402|BlockRun|Venice|PaidProvider|Flutter'
   ```

   Stop the capture before sharing it and remove any accidental secret-bearing
   headers or signatures.

## A. KeeperHub evidence proof

### A1. Onboard the separate Agent Execution Wallet

1. In **Wallet**, tap **Create Agent Execution Wallet**.
2. Capture the custody disclosure before consent.
3. Read the SIWE request. Confirm it describes the fixed KeeperHub origin and
   the identity operation, then authenticate on the device.
4. Read the separate organization-key step-up request and authenticate again.
5. Wait for the recovery-safe completion state. Capture Personal Wallet and
   Agent Execution Wallet together, with shortened addresses.

If the workflow reports that the organization wallet is not yet available,
leave the app state intact and use its recovery action. Do not create a second
organization or key.

> **Recording note:** Android may intentionally omit the SIWE/device-auth
> surface from screenshots and screen recordings. Do not weaken secure-window
> protections to obtain a frame. A defensible onboarding evidence set is the
> recorded custody disclosure and Connected transition, the persistent Agent
> Wallet address shown after onboarding (`0x8f04a0…7cd788`), and a later
> KeeperHub receipt whose decoded target/recipient is that address. KeeperHub's
> Turnkey organization wallet is provisioned before any chain write; creation
> therefore has no expected Base transaction. The first on-chain evidence is
> an actual execution, not wallet creation.

### A2. Establish the agent boundary

1. From chat, request KeeperHub capability/status information.
2. Capture the result showing that the agent may inspect `capabilities`,
   `status`, and `receipts`, and may `prepare` the proof, but cannot approve,
   sign, submit, retry, revoke a credential, or move non-zero value.
3. Ask it to prepare the proof. The expected result is an inert proposal that
   directs the human to **Wallet**; it must not open a payment sheet or submit.

**Captured 13 August 2026:** GLM-5.2 invoked `keeperhub.status`,
`keeperhub.capabilities`, and `keeperhub.receipts` and rendered the permission
boundary plus the latest verified receipt. Device logs showed exactly those
three read-only calls and no `keeperhub.prepare` in that turn. Preparation is
demonstrated separately in the canonical agent-originated transaction video.

### A3. Cancel once, then execute once

1. Open the prepared proof in **Wallet** and reject it. Capture the terminal
   cancelled state and confirm no execution ID or transaction is shown.
2. Prepare a fresh proof.
3. Inspect the simulation and exact review fields:

   | Field | Required value |
   | --- | --- |
   | Chain | Base Mainnet |
   | Chain ID | `8453` |
   | Sender | Agent Execution Wallet |
   | Recipient | Same Agent Execution Wallet |
   | Amount | `0 ETH` |
   | Action | bounded self-transfer only |
   | Simulation | success, not reverted |

4. If the simulation reports insufficient gas and sponsorship is unavailable,
   stop. Fund only the displayed **Agent Execution Wallet** with the minimum
   Base Mainnet ETH needed for gas, then re-simulate. Never substitute USDC or
   broaden the transfer amount.
5. Approve from the foreground review and authenticate on Android.
6. Once the UI is polling, deliberately interrupt the app: force-close it or
   disable connectivity. Record the displayed execution ID before interruption
   when it is available.
7. Reopen the app and choose recovery/resume. Confirm that the same execution
   ID is polled, with no second submission or second request ID.
8. Capture the completed card, the verified receipt, and the independent Base
   Mainnet explorer transaction page. There must be exactly one transaction
   hash and one successful receipt matching the execution.

**Captured 13 August 2026:** the latest GLM-5.2 recording shows a fresh
`keeperhub.prepare` call stopping at an inert simulated proposal, the user
moving to Wallet, the exact `0 ETH` Base Mainnet review, human authorization,
and a verified sponsored receipt for
[`0x249fcef5…0cad58`](https://basescan.org/tx/0x249fcef5bf20ebc598f105ee2d6efbc11893fea70eeca7c07b0694f4f80cad58).
The receipt is bound to intent `kh_f99a…1aaa0` and KeeperHub execution
`qfhbat…6mwww`; a public Base RPC independently returned status `0x1`, block
`49,921,458`, `40,933` gas, and zero value. The recording also displays an
earlier persisted **Rejected before execution** record. It does not show a new
reject action performed in that same clip, so rejection remains evidenced by
the separate rejection recording and screenshot. In-flight interruption was
not recorded and is not claimed.

## B. BlockRun Base-USDC chat

1. Use the bridge UI to send `$3` USDC from Phantom/Solana to the displayed
   Personal Wallet Base address. Keep source-chain fee headroom; record the
   bridge result separately from the model-payment receipt.
2. Verify the Base USDC balance in Wallet after settlement.
3. Select BlockRun from the dynamically discovered providers/models list.
4. Send a minimal prompt such as: `Reply with exactly: BLOCKRUN PAID TEST OK.`
5. Inspect the first payment review. It must disclose the live price, Base
   network, USDC asset, recipient/resource, and request expiry.
6. Approve and authenticate on device. Capture the chat response and its
   linked/recorded receipt.
7. Test one failure boundary: cancel another proposed paid request or background
   the app before approval. Verify there is no signature and no charged retry.

Do not rely on a static price. BlockRun's own discovery docs state that each
`402` response and `/api/v1/models` are the price source of truth.

## C. Venice prepaid credit and chat

1. Bridge at least `$5` USDC plus a small Base fee/route cushion to the Personal
   Wallet. The currently observed Venice top-up challenge was exactly `$5`, but
   the app must use the fresh server challenge as the authority.
2. Select Venice, then initiate the visible top-up flow.
3. Verify that the review renders Base Mainnet, Base USDC, exact amount,
   intended top-up endpoint, payee, and expiry. Reject if any field differs
   from the just-received challenge.
4. Approve and authenticate once. Wait for the top-up receipt and wallet-linked
   spendable balance to refresh.
5. Select a dynamically discovered Venice model and send a small one-sentence
   chat prompt.
6. Capture the response and the reduced balance/ledger receipt. Do not show the
   `X-Sign-In-With-X` header or a raw signature in evidence.

## Evidence table

Fill this during the real run; a blank or `not run` cell is honest and blocks a
claim of completion.

| Item | Result | Evidence reference | Notes |
| --- | --- | --- | --- |
| Artifact version / SHA-256 | Hackathon preview installed with wallet data preserved | `439EA31D00F6336CFA4F16BB873081C9495154A61B80330445B8427B9A4FED92` | version `2.3.0` (`13`); original 26 July app data preserved; release `v2.3.0-hackathon-preview.1` |
| Current debug refresh / SHA-256 | Built, package metadata verified, and APK credential audit passed | `8EB38114FB0EF28FE6A4DF813D866840D7CD8B8AD0387B7994E1509D2904FC39` | version `2.3.0` (`14`); release `v2.3.0-hackathon-preview.2`; debug test artifact, not the Play-signed production build |
| KeeperHub regression suite | 41 Flutter + 5 Android passed | local test output | 13 Aug 2026; zero failures |
| Paid-provider biometric continuation suite | 30 focused tests passed | local test output | transient Android `inactive` preserves the inert expiring turn lease; real background still erases it |
| Live Venice top-up challenge | Parsed, no signature | local live 402 check | 12 Aug 2026; the provider omits `resource`, so Plawie binds only its catalogued Venice HTTPS endpoint before it can display approval |
| Agent Wallet disclosure | Observed | physical device | separate KeeperHub-managed execution wallet and Android-owned approver visible |
| KeeperHub SIWE onboarding | Completed; secure prompt not screen-capturable | `keeperhub-agent-wallet-create-video-proof.mp4` + physical device | disclosure and Connected transition recorded; Agent Wallet `0x8f04a0…7cd788` persisted; no wallet-creation transaction is expected because provisioning is off-chain |
| Separate agent wallet visible | Connected | physical device | Agent Wallet `0x8f04a0…7cd788` |
| Agent capability/status/receipt read | Passed | separate GLM-5.2 screen recording + device log | exactly `keeperhub.status`, `keeperhub.capabilities`, and `keeperhub.receipts`; no prepare, approval, or execution in the turn |
| Agent capability boundary | Passed end-to-end through `keeperhub.prepare` | [`keeperhub-agent-originated-base-mainnet-verified.png`](articles/assets/keeperhub/keeperhub-agent-originated-base-mainnet-verified.png) | GLM-5 created intent `kh_44dc…`; Wallet alone exposed review/approval; KeeperHub execution `ti85uq…` completed only after human authentication |
| Rejected proof / no execution | Passed; three rejected records visible | [`keeperhub-base-mainnet-rejected.png`](articles/assets/keeperhub/keeperhub-base-mainnet-rejected.png) and wallet recording | simulated intents were explicitly discarded before authorization; no execution ID or transaction followed |
| Proof simulation | Passed | [`keeperhub-base-mainnet-review.png`](articles/assets/keeperhub/keeperhub-base-mainnet-review.png) | exact `0 ETH`, chain `8453`, self-recipient, non-reverting, `21,000` gas estimate |
| Zero-value Base Mainnet submission | Passed four times as separately authorized intents | KeeperHub executions `ti85uq…`, `59ja3y…`, `vxy25q…`, and `qfhbat…` | all sponsored; all `idempotentReplay: false`; `ti85uq…` is the canonical agent-originated path |
| Latest A3 prepare / authorize / verify proof | Passed | [`0x249fcef5…0cad58`](https://basescan.org/tx/0x249fcef5bf20ebc598f105ee2d6efbc11893fea70eeca7c07b0694f4f80cad58) + `keeperhub-a3-reject-prepare-authorize-verified.mp4` | GLM-5.2 prepared intent `kh_f99a…`; execution `qfhbat…` completed after Wallet authorization; block `49,921,458`; public RPC status `0x1`; video SHA-256 `5AC4EDBB425045DD98CAF081FC9BD599BE16F011F03B29491E19BEF9C70C56A5` |
| Interrupted polling recovery | Not run |  | terminal receipt persistence after force-stop/relaunch passed; do not claim in-flight recovery |
| One verified receipt / explorer hash | Passed for canonical agent-originated intent | [`0x6b18c0e5…991430a`](https://basescan.org/tx/0x6b18c0e5475a97996f5a9654392050bf7cc754aa1b31c6f2492645750991430a) | status success; block `49,916,321`; `40,933` gas; public Base RPC status `0x1`; decoded call binds the Agent Wallet as target and recipient with zero amount |
| Phantom to Base bridge | Passed | destination `0x2c456dcf…f3254252` | `3.0` Solana USDC produced `2.9925` Base USDC; a later `2.1` USDC route produced `2.09475` Base USDC |
| BlockRun approved paid chat | Model response passed; settlement proof incomplete | local receipt `7a0326c0…` | HTTP `200`; paid retry consumed once; provider omitted a payment receipt, so state remains `uncertain` rather than falsely settled |
| BlockRun cancellation boundary | Passed | local receipt `5ae6847c…` | backgrounded approval recorded as rejected before payment |
| Venice approved top-up | Passed | [`0x030dd39b…f50e7f9`](https://basescan.org/tx/0x030dd39b1c23c90e01f3e8bd81836dfc844cd22f64bff0af66cd06c7ff50e7f9) | `5.00` Base USDC; HTTP `200`; settlement stored |
| Venice funded chat / ledger | Chat passed; post-use balance refresh pending | session `780d0d51-509a-4bab-8e55-c307f063db1d` | provider `venice`; model `gemini-3-6-flash`; exact reply `VENICE_OK` |

## Submission gate

The hackathon submission can now truthfully describe both the implemented
architecture and a **completed live Base Mainnet proof**. The stronger
interruption-recovery demonstration is not complete until every remaining gate
below passes:

- [x] physical-device onboarding evidence;
- [x] an agent-originated proposal that stopped at the Wallet boundary and
      completed only after human review and authentication;
- [x] an explicitly rejected proposal with no execution;
- [x] a completed zero-value Base Mainnet transaction;
- [x] a verified receipt and independently reachable explorer transaction;
- [ ] in-flight interruption/restart evidence that preserves one execution
      identity without a second submission;
- [x] raw physical-device video of the canonical agent-originated flow recorded;
- [x] latest A3 prepare → Wallet authorization → verified receipt video
      recorded and reconciled with the persisted receipt and public Base RPC;
- [ ] final short video edited, redacted, uploaded, and checked while signed out;
- [ ] a final redaction review of screenshots, logs, and the article.

BlockRun and Venice are meaningful product validation but are not prerequisites
for the KeeperHub zero-value proof. Keep them as separate evidence tracks so a
provider outage cannot delay the hackathon transaction.

## References

- [KeeperHub platform reference](https://docs.keeperhub.com/platform-reference)
- [KeeperHub direct execution](https://docs.keeperhub.com/api/direct-execution)
- [KeeperHub gas and sponsorship](https://docs.keeperhub.com/wallet-management/gas)
- [KeeperHub supported chains](https://docs.keeperhub.com/api/chains)
- [Venice x402 integration](https://docs.venice.ai/guides/integrations/x402-venice-api)
- [BlockRun x402 endpoints](https://blockrun.ai/docs/x402/endpoints)
