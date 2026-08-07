# Release Configuration

This file records build inputs, not secret values. Project identifiers, RPC
credentials, wallet material, signatures, API keys, callback captures, and
receipts must not be committed, printed in CI logs, or packaged as assets.

## Wallet and bridge inputs

| Define | Required when | Failure behavior |
| --- | --- | --- |
| `REOWN_PROJECT_ID` | Reown EVM or Solana fallback is enabled | Connected wallet capability is unavailable |
| `PLAWIE_DAPP_URL` | Reown is enabled; must be HTTPS | Connected wallet capability is unavailable |
| `ROBINHOOD_RPC_URL` | Production internal Robinhood sends; must be HTTPS | Sends are disabled; rate-limited public reads remain |
| `ENABLE_LIFI_CONNECTED_BRIDGE` | Connected LI.FI execution is approved | Connected execution stays disabled |
| `ENABLE_RELAY_DEPOSIT_BRIDGE` | Relay strict-deposit execution is approved | One-time address stays disabled |
| `ENABLE_REOWN_EVM_WALLETS` | Reown EVM legal/configuration acceptance is complete | EVM wallet connection stays disabled |
| `ENABLE_SOLANA_MWA_WALLETS` | Android MWA legal/device acceptance is complete | Solana MWA stays disabled |
| `ENABLE_REOWN_SOLANA_FALLBACK` | Reown Solana fallback acceptance is complete | Phantom/Solflare Reown fallback stays disabled |
| `ENABLE_BASE_ACCOUNT_MWP` | A separately reviewed production adapter exists | Base Account remains honestly unavailable |

All gates default to `false`. LI.FI public quote/capability requests do not
require an embedded API key. Any future partner credential belongs behind a
controlled backend.

## Production command shape

The release owner must provide values through the environment and must not echo
them. Compose these defines with the native-Gateway release variant required by
that release train.

```powershell
if ([string]::IsNullOrWhiteSpace($env:REOWN_PROJECT_ID)) { throw 'REOWN_PROJECT_ID is required' }
if ([string]::IsNullOrWhiteSpace($env:PLAWIE_DAPP_URL)) { throw 'PLAWIE_DAPP_URL is required' }
if ([string]::IsNullOrWhiteSpace($env:ROBINHOOD_RPC_URL)) { throw 'ROBINHOOD_RPC_URL is required' }

flutter build appbundle --release `
  --dart-define=REOWN_PROJECT_ID=$env:REOWN_PROJECT_ID `
  --dart-define=PLAWIE_DAPP_URL=$env:PLAWIE_DAPP_URL `
  --dart-define=ROBINHOOD_RPC_URL=$env:ROBINHOOD_RPC_URL `
  --dart-define=ENABLE_LIFI_CONNECTED_BRIDGE=true `
  --dart-define=ENABLE_RELAY_DEPOSIT_BRIDGE=true `
  --dart-define=ENABLE_REOWN_EVM_WALLETS=true `
  --dart-define=ENABLE_SOLANA_MWA_WALLETS=true `
  --dart-define=ENABLE_REOWN_SOLANA_FALLBACK=true `
  --dart-define=ENABLE_BASE_ACCOUNT_MWP=false
```

Production enablement also requires stable Android application ID/signing,
Reown project restrictions, the shipped legal/attribution bundle described in
`EXTERNAL_WALLET_BRIDGING.md`, and the controlled checklist below. Missing
evidence means the corresponding gate remains off.

## Debug acceptance

Debug builds may use Robinhood's documented public RPC for read-only and
non-spending checks. Enable only the bridge transports whose non-secret
configuration is actually present. A build with missing Reown values must show
an honest unavailable state rather than a partially working wallet chooser.

No automated test or device smoke test may approve, sign, bridge, transfer, or
submit a Mainnet payment.
