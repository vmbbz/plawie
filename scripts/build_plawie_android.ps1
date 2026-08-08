param(
    [ValidateSet('debug', 'release')]
    [string]$Mode = 'debug',

    [switch]$Bundle
)

$ErrorActionPreference = 'Stop'

$artifact = if ($Bundle) { 'appbundle' } else { 'apk' }
$arguments = @(
    'build',
    $artifact,
    "--$Mode",
    '--dart-define=ENABLE_LIFI_CONNECTED_BRIDGE=true',
    '--dart-define=ENABLE_RELAY_DEPOSIT_BRIDGE=true',
    '--dart-define=ENABLE_REOWN_EVM_WALLETS=true',
    '--dart-define=ENABLE_SOLANA_MWA_WALLETS=true',
    '--dart-define=ENABLE_REOWN_SOLANA_FALLBACK=true',
    '--dart-define=ENABLE_BASE_ACCOUNT_MWP=false'
)

# Public metadata has reviewed source defaults. Environment values are optional
# rotation overrides and are passed only when deliberately supplied.
if (-not [string]::IsNullOrWhiteSpace($env:REOWN_PROJECT_ID)) {
    $arguments += "--dart-define=REOWN_PROJECT_ID=$($env:REOWN_PROJECT_ID)"
}
if (-not [string]::IsNullOrWhiteSpace($env:PLAWIE_DAPP_URL)) {
    $arguments += "--dart-define=PLAWIE_DAPP_URL=$($env:PLAWIE_DAPP_URL)"
}
if (-not [string]::IsNullOrWhiteSpace($env:ROBINHOOD_RPC_URL)) {
    $arguments += "--dart-define=ROBINHOOD_RPC_URL=$($env:ROBINHOOD_RPC_URL)"
}

& flutter @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
