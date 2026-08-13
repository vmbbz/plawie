# KeeperHub submission video — asset and edit manifest

> **Status:** five physical-device evidence recordings are available: wallet
> onboarding, a Wallet-first proof, the canonical GLM-5 agent-originated proof,
> a separate GLM-5.2 capability/status/receipt read, and a fresh GLM-5.2
> prepare/authorize/verified proof. The public submission video is available at
> <https://youtu.be/jcZN3e34LVs>. Raw MP4 files remain outside Git by design.

## Deliverables

| Deliverable | Target | Status |
|---|---|---|
| Judge demo | Public submission cut | [Published on YouTube](https://youtu.be/jcZN3e34LVs) |
| Captioned backup | Same cut with burned-in English captions | Raw clips ready; edit pending |
| Social cut | `45–75` seconds, `1080×1920` | Optional |
| Public URL | YouTube unlisted/public or another signed-out-accessible host | [Published](https://youtu.be/jcZN3e34LVs) |
| Public video access check | Opens without account, region prompt, or download permission | Passed by signed-out HTTP request on 13 August 2026 |

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
| `V01` | Onboarding disclosure, Connected state, and persistent Agent Wallet address | `keeperhub-agent-wallet-create-video-proof.mp4` | Full clip, `01:53` | Review required; secure SIWE/auth prompt is intentionally absent |
| `V02` | GLM-5 chat prompt and `keeperhub.prepare` tool result | `chat-page-agent-initiated-keeperhub-self-transfer.mp4` | Full clip, `03:01` | Review required |
| `V03` | Wallet showing the inert simulated proposal | `chat-page-agent-initiated-keeperhub-self-transfer.mp4` | Select canonical review segment | Review required |
| `V04` | Exact review: Base Mainnet, Agent Wallet self-recipient, `0 ETH`, simulation success | `walletpage-keeperhub-self-transfer.mp4` and canonical chat clip | Select review segment | Review required |
| `V05` | Human taps authorize; protected authentication transition | `chat-page-agent-initiated-keeperhub-self-transfer.mp4` | Select authorization segment | Review required; do not fabricate a biometric frame |
| `V06` | Wallet returns **Verified on-chain** for `0x6b18c0e5…991430a` | `chat-page-agent-initiated-keeperhub-self-transfer.mp4` | Select completion segment | Review required |
| `V07` | BaseScan transaction and confirmed block `49,916,321` | `walletpage-keeperhub-self-transfer.mp4` | Select explorer segment | Review required |
| `V08` | Rejected-before-execution records with no transaction | `walletpage-keeperhub-self-transfer.mp4` | Select receipt-history segment | Review required |
| `V09` | GLM-5.2 reads capability, status, and receipts without preparing | `chat-page-keeperhub=tools-status-check.mp4` | Full clip, `03:20`; final successful turn near end | Review required; trim earlier failed retry |
| `V10` | Fresh GLM-5.2 `keeperhub.prepare` → Wallet authorization → verified sponsored receipt `0x249fcef5…0cad58` | `keeperhub-a3-reject-prepare-authorize-verified.mp4` | Full clip, `07:29`; select Chat → Wallet → BaseScan → verified receipt sequence and trim initial protected/black transition | Preliminary contact-sheet review passed; final edit/redaction review required. The visible rejection is an earlier persisted record, not a fresh rejection in this clip. |

The five named user files are in `C:\Users\cosyc\Downloads` and must be
uploaded as submission assets, not committed to the source repository.

`V10` intake identity: `412,180,140` bytes, H.264/AAC, `1080×2340`, duration
`449.571646` seconds, SHA-256
`5AC4EDBB425045DD98CAF081FC9BD599BE16F011F03B29491E19BEF9C70C56A5`.
Its persisted KeeperHub execution is `qfhbatqx6tez060s6mwww`; its independently
verified Base Mainnet transaction is
[`0x249fcef5…0cad58`](https://basescan.org/tx/0x249fcef5bf20ebc598f105ee2d6efbc11893fea70eeca7c07b0694f4f80cad58),
block `49,921,458`, status `0x1`, zero value, and `40,933` gas.

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

- [x] Every supplied raw clip is inventoried above.
- [x] The five supplied raw clips are mapped to proof beats.
- [x] A separate capability/status/receipt recording exists on the device.
- [x] The latest A3 clip has a recorded SHA-256 and independently reconciled
      receipt/transaction identity.
- [ ] The canonical flow visibly begins in Chat with GLM-5.
- [ ] The review visibly says Base Mainnet and `0 ETH`.
- [ ] Human authorization occurs only in Wallet.
- [ ] The final receipt hash is `0x6b18c0e5475a97996f5a9654392050bf7cc754aa1b31c6f2492645750991430a`.
- [ ] The BaseScan envelope explanation is included.
- [ ] No in-flight recovery claim is made unless that separate stress test is
      actually present in the footage.
- [ ] Captions are legible on a phone at normal playback size.
- [x] The final URL opens from a signed-out request without authentication.
- [x] The public URL is inserted into the submission dossier and DoraHacks
      BUIDL page.
