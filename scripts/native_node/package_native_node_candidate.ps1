param(
    [Parameter(Mandatory = $true)]
    [string]$CandidatePath,

    [string]$ExpectedSha256 = "",

    [switch]$AllowUnpinned,

    [string]$DeclaredNodeVersion = "unknown",

    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ExpectedSha256) -and -not $AllowUnpinned) {
    throw "Provide -ExpectedSha256 for the candidate, or pass -AllowUnpinned intentionally for a local-only experiment."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..\..")
$source = Resolve-Path -LiteralPath $CandidatePath
$destinationDir = Join-Path $repoRoot "android\app\src\main\jniLibs\arm64-v8a"
$destination = Join-Path $destinationDir "libplawie_node.so"
$manifestPath = "$destination.manifest.json"

$sourceItem = Get-Item -LiteralPath $source
if ($sourceItem.PSIsContainer) {
    throw "CandidatePath must point to a single Android arm64 Node executable, not a directory."
}

if ($sourceItem.Length -lt 10MB) {
    throw "Candidate is suspiciously small ($($sourceItem.Length) bytes). Refusing to package it as Node."
}

$hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256)) {
    $expected = $ExpectedSha256.Trim().ToLowerInvariant()
    if ($hash -ne $expected) {
        throw "SHA256 mismatch. Expected $expected but got $hash."
    }
}

New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null

if ((Test-Path -LiteralPath $destination) -and -not $Force) {
    throw "Destination already exists at $destination. Pass -Force to replace the local diagnostic candidate."
}

Copy-Item -LiteralPath $source -Destination $destination -Force:$Force

$manifest = [ordered]@{
    artifact = "libplawie_node.so"
    purpose = "Phase 3 native Node smoke runtime candidate"
    sourcePath = $source.Path
    packagedPath = $destination
    sha256 = $hash
    sizeBytes = $sourceItem.Length
    declaredNodeVersion = $DeclaredNodeVersion
    requiredNodeVersion = ">=22.19.0"
    abi = "arm64-v8a"
    packagedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    localOnly = $true
    nextDiagnosticsCommand = "flutter build apk --debug --dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true"
} | ConvertTo-Json -Depth 4

Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding UTF8

Write-Host "Packaged native Node candidate:"
Write-Host "  $destination"
Write-Host "SHA256:"
Write-Host "  $hash"
Write-Host "Manifest:"
Write-Host "  $manifestPath"
Write-Host ""
Write-Host "Next:"
Write-Host "  flutter build apk --debug --dart-define=PLAWIE_NATIVE_GATEWAY_SMOKE_DIAGNOSTICS=true"
