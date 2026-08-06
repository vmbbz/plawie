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

## First setup

BYOK providers retain the API-key field and secure one-time setup handoff.
Venice and BlockRun show no API-key field. Selecting either records only the
provider ID; it does not create a wallet, choose a model, fund, top up, sign, or
spend. After the Gateway installation completes, the primary action opens the
Base page above the Dashboard so Back returns to the app.

Setup explains the following before installation:

- wallet payments use Base Mainnet and native Base USDC;
- the wallet must be backed up or exported before it is funded;
- some bridge or direct wallet-transfer actions may require Base ETH for gas;
- Venice uses a separately approved prepaid provider top-up;
- BlockRun has no prepaid balance and may request an exact payment per request;
- every later payment still requires visible approval and Android device
  authentication.

## One readiness contract

`WalletFundedProviderReadinessService` is the read-only source used by Chat,
Settings, and Base. Opening a model picker reads wallet status, selected Base
network, cached provider balance, catalog freshness, and authenticated proxy
health. Inspection never opens authentication, signs, or spends.

| Observation | Selection state | Primary action |
|---|---|---|
| No live provider model | Blocked | Refresh models |
| Wallet absent or needs recovery | Blocked | Open Base |
| Device authentication unavailable | Blocked | Manage wallet |
| Keystore is not hardware-backed | Blocked | Review wallet security |
| Base page is on Sepolia | Blocked | Switch to Mainnet |
| Running proxy fails authenticated health | Blocked | Restart Gateway |
| Venice balance missing or older than 15 minutes | Blocked | Check balance |
| Venice balance depleted | Blocked | Top up Venice |
| Venice balance low but spendable | Selectable with warning | Top up Venice |
| Venice balance fresh and spendable | Selectable | Manage |
| BlockRun wallet path is ready | Selectable, never called funded | Fund wallet |

A stopped proxy is not an error: the picker says it starts on selection. A
stale catalog remains visibly cached and can retain selectable live records;
the shipped offline explanation entry is non-live and is always disabled.

## Provider-specific payment behavior

Venice inference consumes a wallet-linked prepaid provider balance. A visible
Chat Send opens one bounded foreground turn lease; it does not approve an
on-chain transaction per inference call. Venice top-up remains a separate exact
x402 approval on the Base page. Balance observations are refreshed after a
successful terminal response or settlement and are never invented locally.

BlockRun may return a valid x402 challenge for an individual request. The
canonical app-scoped approval dialog shows provider, model, exact amount,
recipient, Base Mainnet, reason, resource host, and expiry. Approve only passes
the exact request to the Android signer, which performs separate device
authentication. Reject, expiry, app backgrounding, or obscured-touch defense
failure closes the request without payment. A chat message cannot approve it.

## Management surfaces

- Base is canonical for wallet lifecycle, funding, network switching, Venice
  balance/top-up, BlockRun explanation, bridge quotes, and redacted receipts.
- Chat and Settings use the same grouped/searchable picker and readiness text.
- BYOK key management remains separate and unchanged.
- Provider actions are explicit user taps. Refreshing Venice models or balance
  may request wallet authentication; merely opening a picker never does.

## Recovery and error truth

Catalog, wallet, transport, and balance errors remain distinct. A model cannot
be selected from a non-live fallback, wallet existence cannot mark Venice
ready, and BlockRun is never presented as prepaid or funded. If the paid proxy
is unhealthy, the UI offers an explicit Gateway restart rather than silently
restarting while a user may be chatting.

On clear-data or uninstall, app preferences and the encrypted wallet envelope
are intentionally removed. An ordinary APK update preserves app data and the
Android Keystore-backed wallet. Users remain responsible for retaining a tested
wallet backup before funding.
