# Multi-network Wallet and Guided Provider Funding Design

Status: approved by user direction

Date: 2026-08-07

## Decision

Plawie will present one Android-secured EVM account across Base Mainnet, Base
Sepolia, and Robinhood Chain Mainnet. It will not create a second Robinhood key
or copy the private key between network-specific stores. The existing
`BaseService`, `BaseScreen`, Android wallet manager, route names, and persisted
wallet envelope remain in place for migration safety; user-facing navigation is
renamed from `Base` to `Wallet`.

AI-provider settlement remains Base Mainnet native USDC. Robinhood Chain is a
wallet network and funding source, not a newly authorized provider-payment rail.
When a provider top-up lacks Base USDC, Plawie opens one guided funding modal,
preselects Robinhood when live support exists, tracks delivery to Base, switches
the management view back to Base Mainnet, obtains a fresh provider challenge,
and asks for a separate x402 approval plus Android authentication.

## Verified network facts and operational boundary

Official Robinhood documentation identifies Robinhood Chain Mainnet as an
EVM-compatible Arbitrum L2 with chain ID `4663`, ETH gas, RPC
`https://rpc.mainnet.chain.robinhood.com`, and Blockscout explorer
`https://robinhoodchain.blockscout.com`. Robinhood lists LI.FI and Relay among
cross-chain options. Its public RPC is rate-limited and not recommended for
production, so production transaction enablement requires an HTTPS
`ROBINHOOD_RPC_URL` release define. Debug/internal builds may use the official
public endpoint as a bounded fallback and must show that it is not a production
RPC configuration.

Robinhood's official token-contract page currently lists WETH and USDG but does
not list canonical USDC. Plawie therefore does not invent or hardcode a
Robinhood USDC contract. It may allow ordinary USDG reads and sends only against
Robinhood's published USDG contract
`0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168`; USDG is never relabelled as USDC
or accepted as a direct provider-payment asset.

Funding assets remain action-time route driven. A live verification on
2026-08-07 found Robinhood Chain in both LI.FI and Relay capability responses,
and LI.FI returned connections for both Robinhood native ETH -> Base native
USDC and Robinhood USDG -> Base native USDC. That observation is not shipped as
a permanent availability promise: the modal exposes ETH or USDG only when the
selected transport returns a live token and connection match.

## Wallet identity and persistence

- One secp256k1 key and one EVM address are protected by the existing
  auth-per-use Android Keystore envelope.
- Creating/importing/restoring the wallet creates one EVM identity usable on
  every explicitly supported EVM network; it does not create per-chain keys.
- A versioned wallet-network preference stores `baseMainnet`,
  `robinhoodMainnet`, or `baseSepolia` and migrates the historical
  `base_use_sepolia` preference without changing wallet material.
- Signed APK updates preserve the envelope and selected network. Clear data or
  uninstall retains the existing documented destructive behavior.
- Existing filenames, channel method names, envelope filenames, and aliases are
  not renamed in this phase because that would create avoidable wallet-migration
  risk.

## Network and signer policy

The Dart network definition owns display name, chain ID, RPC, explorer,
testnet/mainnet state, native symbol, and supported ordinary assets. The Android
signer independently enforces the same bounded policy:

| Network | Chain ID | Ordinary native send | Ordinary token send | x402 |
|---|---:|---|---|---|
| Base Mainnet | 8453 | ETH | native Base USDC | allowed by existing exact policy |
| Robinhood Chain | 4663 | ETH | official USDG transfer only | forbidden |
| Base Sepolia | 84532 | ETH | test USDC | forbidden |

Robinhood signing accepts only either `kind=eth` with empty calldata and
positive value, or `kind=usdg` with the official USDG contract, zero native
value, and the exact ERC-20 `transfer(address,uint256)` selector. Both paths
require bounded gas and chain ID 4663. It cannot sign arbitrary contracts,
bridge calldata, arbitrary token transfers, typed messages, provider payments,
or x402 payloads. The Android authentication summary names the exact network
and asset.

The visible transfer approval remains exact, one-use, expiring, and chain-bound.
Switching networks invalidates its use. `.base.eth` resolution is offered only
on Base networks; Robinhood sends require an explicit `0x` address.

## Wallet user experience

- Dashboard/home and page chrome say `Wallet`; implementation classes keep
  their current names.
- The network chooser lists Base Mainnet, Robinhood Chain, and Base Sepolia.
- The header explains that the same address is used across supported EVM
  networks and displays only balances supported by the selected network.
- Robinhood shows ETH and official USDG separately. Its send action says USDG,
  never USDC; any other token is read-only or absent rather than implicitly
  trusted.
- AI payments and the Base-funding destination are available only when Base
  Mainnet is selected. On Robinhood or Sepolia, the panel offers one explicit
  switch to Base Mainnet.
- History uses Basescan-compatible endpoints for Base and the official
  Robinhood Blockscout API for chain 4663. Failure is empty/error state, never a
  fabricated history.

## Guided provider top-up

The top-up coordinator owns this sequence:

```text
Prepare unsigned provider challenge
  -> compare exact required Base-USDC units with refreshed Base balance
  -> sufficient: show the normal exact x402 approval
  -> insufficient: reject and destroy that challenge
       -> open foreground funding modal
       -> preselect Robinhood if live; user chooses live ETH or USDG source
       -> preserve enough ETH for Robinhood gas and review the quoted output
       -> external wallet or strict Relay flow receives its own review(s)
       -> persist and track bridge/deposit receipt
       -> require completed Base delivery
       -> switch Wallet view to Base Mainnet and refresh Base USDC
       -> require sufficient balance
       -> obtain a new provider challenge
       -> show a separate exact x402 approval and Android authentication
```

The funding modal receives only provider label, required Base-USDC units,
preferred source chain, the canonical bridge controller/capabilities, and a
completion callback. It never receives a reusable payment approval or signed
provider payload. Closing, backgrounding, rejection, bridge failure, partial
delivery, or insufficient final balance clears the in-memory return intent and
does not submit a provider payment.

Bridge completion never implies provider top-up completion. Bridge and x402
receipts remain separate, and both visible approvals are mandatory. Agents may
read redacted status and direct users to Wallet, but cannot open the modal,
switch networks, create a Relay instruction, approve, sign, or submit.

## Recovery and rollback

- An active bridge receipt resumes status only; it never repeats a wallet
  request. Returning to a top-up after process death requires the user to tap
  Top up again and obtains a fresh challenge.
- A provider challenge is rejected before a funding modal opens, preventing a
  stale or nearly expired challenge from surviving a bridge.
- Robinhood wallet reads/sends and Robinhood source funding can be disabled
  independently from Base wallet/x402 operation.
- Missing production RPC configuration disables Robinhood internal sends while
  leaving the address, external-wallet funding, Base, Gateway, and provider
  features intact.

## Non-goals

- No Robinhood brokerage account integration or custodial account creation.
- No separate Robinhood private key or wallet envelope.
- No hardcoded Robinhood Wallet app path; compatible wallets are discovered by
  Reown protocol/capabilities.
- No guessed Robinhood USDC contract, arbitrary ERC-20 transfer, or arbitrary
  internal-wallet bridge calldata. The only Robinhood ERC-20 send is the
  published USDG contract's exact transfer call.
- No direct Robinhood x402/provider payment until a future live challenge and
  explicit signer/payment review authorize it.
