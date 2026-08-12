# Plawie live evidence runbook

**Status:** ready for physical-device execution. Update the evidence table only
after each item is observed on a real device. This document deliberately makes
no claim that a transaction, paid request, or settlement has happened yet.

## Objective

Produce the minimum defensible evidence for Plawie's KeeperHub hackathon
submission and validate the two wallet-funded model paths without exposing a
seed, private key, signature, organization credential, cookie, or payment
header.

The required KeeperHub proof is a zero-value, Base Sepolia self-transfer from
the dedicated KeeperHub Agent Execution Wallet. It is not a mainnet transfer,
it cannot target an arbitrary recipient, and it does not grant the agent a
generic execution API.

```text
OpenClaw prepares an inert proof
          -> KeeperHub simulates it
          -> Plawie shows the exact foreground review
          -> human approves and authenticates on Android
          -> KeeperHub executes once with an idempotency key
          -> app is interrupted during polling
          -> Plawie recovers one execution and one verified receipt
```

## Scope and safety invariants

- Do not install, clear, export, or rotate the Personal Wallet while running
  this checklist.
- Only a person holding the device may accept an Android authentication prompt
  or a payment/bridge approval. A test operator must not tap through one on the
  user's behalf.
- The KeeperHub proof must remain `Base Sepolia (84532)`, amount `0`, and
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
| KeeperHub zero-value proof | Usually no mainnet funds | Base Sepolia ETH only if KeeperHub gas sponsorship is unavailable | A `0 ETH` EVM transaction still consumes testnet gas. |
| BlockRun paid chat | `$3` Base USDC is suitable | Plawie's **Personal Wallet** on Base (`8453`) | BlockRun charges per accepted request; price is discovered from the live `402` response, not hard-coded. |
| Venice top-up + chat | At least the current `$5` top-up plus bridge/transaction headroom | Plawie's **Personal Wallet** on Base (`8453`) | The 12 August 2026 top-up challenge required `5,000,000` USDC base units (`$5`). A `$3` balance cannot complete that top-up. |

Phantom-held USDC on Solana is not spendable by the current in-app Base signer.
Use Plawie's bridge flow to send it to the Personal Wallet's Base address, and
retain enough SOL in Phantom for the source-chain transaction fee. Do not fund
the Agent Execution Wallet with production funds for this proof.

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

### A2. Establish the agent boundary

1. From chat, request KeeperHub capability/status information.
2. Capture the result showing that the agent may inspect `capabilities`,
   `status`, and `receipts`, and may `prepare` the proof, but cannot approve,
   sign, submit, retry, revoke a credential, or move mainnet value.
3. Ask it to prepare the proof. The expected result is an inert proposal that
   directs the human to **Wallet**; it must not open a payment sheet or submit.

### A3. Cancel once, then execute once

1. Open the prepared proof in **Wallet** and reject it. Capture the terminal
   cancelled state and confirm no execution ID or transaction is shown.
2. Prepare a fresh proof.
3. Inspect the simulation and exact review fields:

   | Field | Required value |
   | --- | --- |
   | Chain | Base Sepolia |
   | Chain ID | `84532` |
   | Sender | Agent Execution Wallet |
   | Recipient | Same Agent Execution Wallet |
   | Amount | `0 ETH` |
   | Action | bounded self-transfer only |
   | Simulation | success, not reverted |

4. If the simulation or execution reports insufficient gas and no sponsorship
   is available, use a Base Sepolia ETH faucet to fund the **Agent Execution
   Wallet**. Re-simulate; do not substitute mainnet funds.
5. Approve from the foreground review and authenticate on Android.
6. Once the UI is polling, deliberately interrupt the app: force-close it or
   disable connectivity. Record the displayed execution ID before interruption
   when it is available.
7. Reopen the app and choose recovery/resume. Confirm that the same execution
   ID is polled, with no second submission or second request ID.
8. Capture the completed card, the verified receipt, and the independent Base
   Sepolia explorer transaction page. There must be exactly one transaction
   hash and one successful receipt matching the execution.

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
| Artifact version / SHA-256 | Not run |  |  |
| Focused automated suite | 112 passed | local test output | 12 Aug 2026 |
| Live Venice top-up challenge | Parsed, no signature | local live 402 check | 12 Aug 2026; the provider omits `resource`, so Plawie binds only its catalogued Venice HTTPS endpoint before it can display approval |
| Agent Wallet disclosure | Not run |  |  |
| KeeperHub SIWE onboarding | Not run |  |  |
| Separate agent wallet visible | Not run |  |  |
| Agent capability boundary | Not run |  |  |
| Rejected proof / no execution | Not run |  |  |
| Proof simulation | Not run |  |  |
| Zero-value Base Sepolia submission | Not run |  |  |
| Interrupted polling recovery | Not run |  |  |
| One verified receipt / explorer hash | Not run |  |  |
| Phantom to Base bridge | Not run |  |  |
| BlockRun approved paid chat | Not run |  |  |
| BlockRun cancellation boundary | Not run |  |  |
| Venice approved top-up | Not run |  |  |
| Venice funded chat / ledger | Not run |  |  |

## Submission gate

The hackathon submission can truthfully describe the implemented architecture
now. It may describe a **completed live proof** only after the following are
all present:

- physical device onboarding evidence;
- a completed zero-value Base Sepolia transaction;
- interruption/restart evidence that preserves one execution identity;
- a verified receipt and independently reachable explorer transaction;
- a short video or ordered screenshots showing the consent, review, recovery,
  and receipt sequence;
- a redaction review of screenshots, logs, and the article.

BlockRun and Venice are meaningful product validation but are not prerequisites
for the KeeperHub zero-value proof. Keep them as separate evidence tracks so a
provider outage cannot delay the hackathon transaction.

## References

- [KeeperHub platform reference](https://docs.keeperhub.com/platform-reference)
- [KeeperHub direct execution](https://docs.keeperhub.com/api/direct-execution)
- [KeeperHub pricing and sponsored gas](https://keeperhub.com/pricing)
- [Venice x402 integration](https://docs.venice.ai/guides/integrations/x402-venice-api)
- [BlockRun x402 endpoints](https://blockrun.ai/docs/x402/endpoints)
