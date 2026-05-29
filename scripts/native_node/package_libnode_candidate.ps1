param(
    [Parameter(Mandatory = $true)]
    [string]$CandidatePath,

    [string]$ExpectedSha256 = "",
    [string]$DeclaredNodeVersion = "22.22.3",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$source = Resolve-Path $CandidatePath
$destinationDir = Join-Path $repoRoot "android\app\src\main\jniLibs\arm64-v8a"
$destination = Join-Path $destinationDir "libnode.so"
$manifestPath = Join-Path $destinationDir "libnode.so.manifest.json"

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
if ($ExpectedSha256 -and $hash -ne $ExpectedSha256.ToLowerInvariant()) {
    throw "SHA256 mismatch. Expected $ExpectedSha256 but got $hash"
}

if ((Test-Path -LiteralPath $destination) -and -not $Force) {
    throw "Destination exists: $destination. Pass -Force to overwrite."
}

New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
Copy-Item -LiteralPath $source -Destination $destination -Force:$Force

$packagedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash.ToLowerInvariant()
$artifact = Get-Item -LiteralPath $destination

$manifest = [ordered]@{
    artifact = "libnode.so"
    runtime = "embedded-libnode"
    nodeVersion = $DeclaredNodeVersion
    source = $source.Path
    sourceSha256 = $hash
    packagedSha256 = $packagedHash
    packagedBytes = $artifact.Length
    packagedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    note = "Ignored by git. Required only for local embedded native Node smoke builds."
}

($manifest | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "Packaged $destination"
Write-Host "SHA256 $packagedHash"
Write-Host "Manifest $manifestPath"
