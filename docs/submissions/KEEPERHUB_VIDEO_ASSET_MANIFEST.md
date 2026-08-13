# KeeperHub submission video — asset and edit manifest

> **Status:** the canonical GLM-5 execution was recorded on the physical device.
> Raw files and a public video URL are still pending. This manifest is the
> handoff contract for the final edit; it must not be marked complete from
> screenshots alone.

## Deliverables

| Deliverable | Target | Status |
|---|---|---|
| Judge demo | `2:00–2:30`, `1920×1080`, H.264 MP4, 30 fps, AAC audio | Awaiting raw clips |
| Captioned backup | Same cut with burned-in English captions | Awaiting raw clips |
| Social cut | `45–75` seconds, `1080×1920` | Optional |
| Public URL | YouTube unlisted/public or another signed-out-accessible host | Pending |
| DoraHacks URL check | Opens without account, region prompt, or download permission | Pending |

Keep vertical phone footage at its native aspect ratio inside a branded
horizontal frame. Use the free side area for short proof labels and the
architecture diagram. Never zoom so aggressively that the model name, chain,
amount, approval state, or transaction hash becomes unreadable.

## Raw clip intake

Place attachments outside Git first and record their original filenames below.
Do not commit unreviewed videos: system notifications, wallet balances, device
identifiers, or a brief authentication overlay can leak more than a screenshot.

| ID | Required content | Raw filename | Useful time range | Redaction status |
|---|---|---|---|---|
| `V01` | Plawie dashboard and native OpenClaw context | Pending | Pending | Pending |
| `V02` | GLM-5 chat prompt and `keeperhub.prepare` tool result | Pending | Pending | Pending |
| `V03` | Wallet showing the inert simulated proposal | Pending | Pending | Pending |
| `V04` | Exact review: Base Mainnet, Agent Wallet self-recipient, `0 ETH`, simulation success | Pending | Pending | Pending |
| `V05` | Human taps authorize; authentication transition without sensitive biometric imagery | Pending | Pending | Pending |
| `V06` | Wallet returns **Verified on-chain** for `0x6b18c0e5…991430a` | Pending | Pending | Pending |
| `V07` | BaseScan transaction and confirmed block `49,916,321` | Pending | Pending | Pending |
| `V08` | Separate rejected proposal with no execution ID/hash | Pending | Pending | Pending |
| `V09` | Optional onboarding/custody disclosure | Pending | Pending | Pending |

## Final cut

The GLM-5 recording is the spine. Supporting clips should clarify—not interrupt—the
single agent-originated execution.

| Time | Picture | On-screen proof label | Voiceover |
|---:|---|---|---|
| `0:00–0:10` | Plawie dashboard → Chat | `OPENCLAW · NATIVE ANDROID` | “Plawie runs the full OpenClaw Gateway on Android. For on-chain work, the agent may propose; the phone keeps the human decision.” |
| `0:10–0:32` | GLM-5 invokes `keeperhub.prepare` | `AGENT AUTHORITY: PREPARE ONLY` | “GLM-5 calls one bounded KeeperHub capability. It can simulate and persist a proposal, but it cannot approve, authenticate, sign, submit, retry, or move non-zero value.” |
| `0:32–0:49` | Chat directs the user to Wallet | `NO APPROVAL UI IN CHAT` | “The agent stops here. The proposal is inert until a person opens the foreground Wallet.” |
| `0:49–1:10` | Wallet proposal and simulation | `BASE MAINNET · 0 ETH · SELF-TRANSFER` | “KeeperHub simulated the exact Base Mainnet request. The sender and recipient are the separate Agent Execution Wallet, and the value is exactly zero.” |
| `1:10–1:27` | Review and human authorization | `VISIBLE REVIEW · FRESH DEVICE AUTH` | “Plawie shows the immutable effect and requires a fresh device-authenticated approval. The model has no route across this boundary.” |
| `1:27–1:47` | Polling → verified receipt | `SPONSORED · VERIFIED · ONE RECEIPT` | “KeeperHub sponsors execution, returns one execution ID, and Plawie accepts success only after a matching re-fetched receipt.” |
| `1:47–2:05` | BaseScan + transaction anatomy inset | `0x6b18c0e5…991430a · BLOCK 49,916,321` | “BaseScan shows the sponsored relay envelope. Inside its decoded call, the Agent Wallet is both target and recipient and the value is zero.” |
| `2:05–2:18` | Rejected record | `REJECTED BEFORE EXECUTION` | “A different simulated proposal was discarded before authentication and produced no transaction.” |
| `2:18–2:30` | Two-wallet diagram / Wallet close | `THE AGENT PROPOSES. THE PHONE DECIDES.` | “KeeperHub makes execution reliable. Plawie makes human authority visible in the device already in your hand.” |

## BaseScan explanation card

Show this for three to five seconds beside the explorer clip:

```text
Sponsored relay       0x7b70…9684
        ↓ calls
Execution contract    0x5af5…f07d
        ↓ execute(target, recipient, amount)
Agent Wallet          0x8f04…d788
Recipient             0x8f04…d788
Amount                0 wei
```

The Personal Wallet `0xab29…b434` should be labelled **local approval authority**,
not transaction sender. It authenticates the app boundary and intentionally
does not appear as BaseScan's top-level `from` address.

## Redaction gate

Reject the edit if any frame exposes:

- a seed phrase, private key, exported key dialog, signature, or authentication
  challenge body;
- a KeeperHub `kh_` organization API key, key ID beyond an approved short
  prefix, cookie, bearer token, or request header;
- an x402 payment header or unrelated provider API key;
- a full Android device identifier, notification containing personal data, or
  unrelated wallet balance;
- raw logs that have not been searched for secrets first.

Public wallet addresses, intent IDs, execution IDs, transaction hashes, block
numbers, and the zero-value proof amount are expected evidence and may remain.

## Acceptance gate

- [ ] Every raw clip is inventoried above.
- [ ] The canonical flow visibly begins in Chat with GLM-5.
- [ ] The review visibly says Base Mainnet and `0 ETH`.
- [ ] Human authorization occurs only in Wallet.
- [ ] The final receipt hash is `0x6b18c0e5475a97996f5a9654392050bf7cc754aa1b31c6f2492645750991430a`.
- [ ] The BaseScan envelope explanation is included.
- [ ] No in-flight recovery claim is made unless that separate stress test is
      actually present in the footage.
- [ ] Captions are legible on a phone at normal playback size.
- [ ] The final URL opens in a private browser window without authentication.
- [ ] The public URL is inserted into the submission dossier and DoraHacks form.
