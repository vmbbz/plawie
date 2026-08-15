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
    # Plawie packages arm64 only. Supplying Flutter's target explicitly keeps
    # code-asset plugins such as fllama from compiling unused arm and x64
    # native binaries during every Android build.
    '--target-platform=android-arm64',
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
    $rpcUri = $null
    if (-not [Uri]::TryCreate(
        $env:ROBINHOOD_RPC_URL,
        [UriKind]::Absolute,
        [ref]$rpcUri
    ) -or
        $rpcUri.Scheme -ne 'https' -or
        -not [string]::IsNullOrEmpty($rpcUri.UserInfo) -or
        -not [string]::IsNullOrEmpty($rpcUri.Query) -or
        -not [string]::IsNullOrEmpty($rpcUri.Fragment) -or
        ($rpcUri.AbsolutePath -ne '' -and $rpcUri.AbsolutePath -ne '/')) {
        throw 'ROBINHOOD_RPC_URL must be a credential-free public HTTPS origin. Private RPC credentials cannot be protected inside an APK.'
    }
    $arguments += "--dart-define=ROBINHOOD_RPC_URL=$($env:ROBINHOOD_RPC_URL)"
}

$postHogHostPresent =
    -not [string]::IsNullOrWhiteSpace($env:PLAWIE_POSTHOG_HOST)
$postHogProjectKeyPresent =
    -not [string]::IsNullOrWhiteSpace($env:PLAWIE_POSTHOG_PROJECT_KEY)
if ($postHogHostPresent -xor $postHogProjectKeyPresent) {
    throw 'Product analytics configuration is incomplete. Supply both PLAWIE_POSTHOG_HOST and PLAWIE_POSTHOG_PROJECT_KEY, or neither.'
}
if ($postHogHostPresent) {
    $postHogUri = $null
    if (-not [Uri]::TryCreate(
        $env:PLAWIE_POSTHOG_HOST,
        [UriKind]::Absolute,
        [ref]$postHogUri
    ) -or
        $postHogUri.Scheme -ne 'https' -or
        -not [string]::IsNullOrEmpty($postHogUri.UserInfo) -or
        -not [string]::IsNullOrEmpty($postHogUri.Query) -or
        -not [string]::IsNullOrEmpty($postHogUri.Fragment) -or
        ($postHogUri.AbsolutePath -ne '' -and $postHogUri.AbsolutePath -ne '/')) {
        throw 'PLAWIE_POSTHOG_HOST must be the credential-free HTTPS ingest origin, without a path, query, userinfo, or fragment.'
    }

    $postHogProjectKey = $env:PLAWIE_POSTHOG_PROJECT_KEY.Trim()
    if ($postHogProjectKey.Length -lt 8 -or
        $postHogProjectKey.Length -gt 200 -or
        $postHogProjectKey -match '\s' -or
        $postHogProjectKey -match '^ph[svx]_') {
        throw 'PLAWIE_POSTHOG_PROJECT_KEY must be a public project token, never a personal or secret API key.'
    }

    $arguments +=
        "--dart-define=PLAWIE_POSTHOG_HOST=$($postHogUri.GetLeftPart([UriPartial]::Authority))"
    $arguments +=
        "--dart-define=PLAWIE_POSTHOG_PROJECT_KEY=$postHogProjectKey"
}

if (-not [string]::IsNullOrWhiteSpace($env:PLAWIE_RELEASE_CHANNEL)) {
    $releaseChannel = $env:PLAWIE_RELEASE_CHANNEL.Trim()
    if ($releaseChannel -notmatch '^[A-Za-z0-9._-]{1,32}$') {
        throw 'PLAWIE_RELEASE_CHANNEL must use 1-32 letters, numbers, dots, underscores, or hyphens.'
    }
    $arguments += "--dart-define=PLAWIE_RELEASE_CHANNEL=$releaseChannel"
}

if (-not [string]::IsNullOrWhiteSpace($env:PLAWIE_APP_VERSION)) {
    $analyticsAppVersion = $env:PLAWIE_APP_VERSION.Trim()
    if ($analyticsAppVersion -notmatch '^[A-Za-z0-9.+_-]{1,64}$') {
        throw 'PLAWIE_APP_VERSION must use 1-64 version-safe characters.'
    }
    $arguments += "--dart-define=PLAWIE_APP_VERSION=$analyticsAppVersion"
}

if ($Mode -eq 'release') {
    $requiredSigningEnvironment = @(
        'PLAWIE_UPLOAD_STORE_FILE',
        'PLAWIE_UPLOAD_STORE_PASSWORD',
        'PLAWIE_UPLOAD_KEY_ALIAS',
        'PLAWIE_UPLOAD_KEY_PASSWORD'
    )
    $missing = @(
        $requiredSigningEnvironment | Where-Object {
            [string]::IsNullOrWhiteSpace(
                [Environment]::GetEnvironmentVariable($_)
            )
        }
    )
    if ($missing.Count -gt 0) {
        throw "Release signing is incomplete. Missing: $($missing -join ', ')."
    }
}

& flutter @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$artifactPath = if ($Bundle) {
    "build/app/outputs/bundle/$Mode/app-$Mode.aab"
} else {
    "build/app/outputs/flutter-apk/app-$Mode.apk"
}

& "$PSScriptRoot/audit_android_artifact_secrets.ps1" `
    -ArtifactPath $artifactPath
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
