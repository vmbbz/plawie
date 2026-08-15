# Wallet-Funded Model Providers

Status: implemented; controlled Base Mainnet settlement proof still required

Date: 2026-08-06

## Product boundary

Venice and BlockRun are cloud model providers reached through the native
OpenClaw Gateway. They do not receive a fabricated BYOK credential and Chat
does not bypass OpenClaw:

```text
Chat and conversation context
        -> native OpenClaw Gateway
        -> authenticated 127.0.0.1 paid-provider proxy
        -> Venice or BlockRun
```

The loopback proxy preserves the Gateway-owned conversation, tools, skills, and
streaming response. Dynamic provider metadata is descriptive only and cannot
change Plawie's context or tool-policy limits.

## Provider networks versus Plawie's selected rail

Verified on 2026-08-07 using official documentation and live unsigned 402
challenges:

- Venice top-up currently advertises both Base USDC and Solana USDC.
- BlockRun's default `blockrun.ai` gateway advertises Base USDC, while its
  separate `sol.blockrun.ai` gateway advertises Solana USDC.
- BlockRun also documents a separate `nano.blockrun.ai` Circle Gateway surface
  for Polygon, Arbitrum, Optimism, and Unichain. That surface is not part of
  Plawie's first-release provider transport; prices and accepted settlement
  must always be read from the live `402` challenge rather than hard-coded.
- Neither provider advertises Robinhood Chain as a payment network.

Plawie's production payment rail remains the Android-owned Base Mainnet wallet.
This is a deliberate product and security boundary, not a claim that Venice or
BlockRun supports only Base or only the gateway surfaces currently integrated
by Plawie. Ethereum, Robinhood Chain, or Solana funds may
reach the Plawie wallet through the separately reviewed funding flow; provider
top-up or per-request payment begins only after Base USDC is present.

The guided top-up sequence preserves two separate approvals:

```text
Choose provider top-up
  -> obtain an unsigned provider challenge and refresh Base USDC exactly
  -> Base USDC is insufficient
  -> reject and destroy that challenge
  -> open the foreground Wallet funding modal
  -> default to direct Base USDC from another wallet; choose another live source when needed
  -> review and approve the exact source-chain bridge
  -> track settlement into the same Plawie Base address
  -> switch the Wallet view to Base and freshly verify native Base USDC
  -> obtain and validate a new provider challenge
  -> separately approve the Base x402 payment and authenticate on Android
```

Settlement does not authorize the following provider purchase. A bridge receipt
and provider-payment receipt remain different records, and no chat message can
approve either transaction.

The app must parse each fresh provider challenge and continue accepting only
the exact Base network and native Base USDC contract. Provider support for
Solana does not authorize the bridge signer to make a provider payment. A
future direct-Solana payment mode requires its own approval, identity, receipt,
and recovery design.

## First setup

BYOK providers retain the API-key field and secure one-time setup handoff.
Venice and BlockRun show no API-key field. Selecting either records only the
provider ID; it does not create a wallet, choose a model, fund, top up, sign, or
spend. After the Gateway installation completes, the primary action opens the
Wallet page above the Dashboard so Back returns to the app.

Setup explains the following before installation:

- Plawie's selected wallet-payment rail uses Base Mainnet and native Base USDC;
- the wallet must be backed up or exported before it is funded;
- some bridge or direct wallet-transfer actions may require Base ETH for gas;
- Venice uses a separately approved prepaid provider top-up;
- BlockRun has no prepaid balance and may request an exact payment per request;
- every later payment still requires visible approval and Android device
  authentication.

## One readiness contract

`WalletFundedProviderReadinessService` is the read-only source used by Chat,
Settings, and Wallet. Opening a model picker reads wallet status, selected Base
network, cached provider balance, catalog freshness, and authenticated proxy
health. Inspection never opens authentication, signs, or spends.

| Observation | Selection state | Primary action |
|---|---|---|
| No live provider model | Blocked | Refresh models |
| Wallet absent or needs recovery | Blocked | Open Wallet |
| Device authentication unavailable | Blocked | Manage wallet |
| Keystore is not hardware-backed | Blocked | Review wallet security |
| Wallet is on Robinhood or Base Sepolia | Blocked | Switch to Base Mainnet |
| Running proxy fails authenticated health | Blocked | Restart Gateway |
| Venice balance missing or older than 15 minutes | Blocked | Check balance |
| Venice balance depleted | Blocked | Top up Venice |
| Venice balance low but spendable | Selectable with warning | Top up Venice |
| Venice balance fresh and spendable | Selectable | Manage |
| BlockRun wallet has no Base USDC | Selectable, payment approval cannot yet settle | Add Base USDC |
| BlockRun wallet has Base USDC | Selectable and ready for pay-per-request | None |

A stopped proxy is not an error: the picker says it starts on selection. A
stale catalog remains visibly cached and can retain selectable live records;
the shipped offline explanation entry is non-live and is always disabled.

## Provider-specific payment behavior

Venice inference consumes a wallet-linked prepaid provider balance. A visible
Chat Send opens one bounded foreground turn lease; it does not approve an
on-chain transaction per inference call. Venice top-up remains a separate exact
x402 approval on the Wallet page. Balance observations are refreshed after a
successful terminal response or settlement and are never invented locally.

BlockRun may return a valid x402 challenge for an individual request. The
canonical app-scoped approval dialog shows provider, model, exact amount,
recipient, Base Mainnet, reason, resource host, and expiry. Approve only passes
the exact request to the Android signer, which performs separate device
authentication. Reject, expiry, app backgrounding, or obscured-touch defense
failure closes the request without payment. A chat message cannot approve it.
One visible Chat Send may open at most one BlockRun payment approval. Gateway
retries, changed request bodies, and tool loops cannot mint another approval
inside that message. If another paid model call is needed, the turn stops and
the user must send a new foreground message. This preserves exact per-call
payment review without allowing an internal retry cascade to create repeated
charges or dialogs.

The x402 v2 payment payload echoes the validated challenge resource and
extensions, preserves provider attribution, and serializes EIP-3009 integer
fields in the facilitator-compatible decimal-string wire form. The paid retry
reuses the exact request bytes once; a second `402` is terminal and is never
converted into another payment approval.

## Management surfaces

- Wallet (the existing Base module) is canonical for wallet lifecycle, funding,
  network switching, Venice
  balance/top-up, BlockRun explanation, bridge quotes, and redacted receipts.
- Chat and Settings use the same grouped/searchable picker and readiness text.
- BYOK key management remains separate and unchanged.
- Provider actions are explicit user taps. Refreshing Venice models or balance
  may request wallet authentication; merely opening a picker never does.

## Recovery and error truth

Catalog, wallet, transport, and balance errors remain distinct. A model cannot
be selected from a non-live fallback, wallet existence cannot mark Venice
ready, and BlockRun is never presented as a prepaid provider balance. Wallet
funding is shown separately as Base USDC available for exact per-request
payments. If the paid proxy
is unhealthy, the UI offers an explicit Gateway restart rather than silently
restarting while a user may be chatting.

## Settlement confirmation and receipts

A terminal bridge remains visible as a Base funding confirmation instead of
resetting immediately to a blank funding form. The confirmation shows source
and received amounts, source and destination chains, route, update time,
destination address, full transaction identifiers, and trusted explorer links.
The user explicitly chooses **Add more funds** before a new form replaces it.
Provider top-up and generic **Add Base USDC** actions use that same funding
surface, but enter a fresh transfer form with Base Mainnet USDC selected by
default. The user may then choose another supported source chain. A completed
direct Base transfer is recorded in the same Wallet transaction history by its
Base source transaction hash.

Settlement uses the fail-closed Base-USDC balance reader. A bridge receipt does
not clear `balanceRefreshPending` unless that exact token read succeeds.
Recovered in-flight receipts deliver the same completion callback as receipts
started in the current view, without resending a transaction. Completed bridge
receipts also appear in Wallet transaction history; x402 provider-payment
receipts remain a separate ledger because bridge settlement is not provider
payment approval.

On clear-data or uninstall, app preferences and the encrypted wallet envelope
are intentionally removed. An ordinary APK update preserves app data and the
Android Keystore-backed wallet. Users remain responsible for retaining a tested
wallet backup before funding.
