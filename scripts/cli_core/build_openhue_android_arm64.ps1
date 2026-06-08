param(
  [string]$OpenHueRef = '08e940a9cd1c49c2da0a714dc8bb07ee60e9cd21',
  [string]$GoVersion = 'go1.26.4',
  [string]$GoArchiveSha256 = '3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345',
  [string]$BuildDate = '2026-06-08T00:00:00Z',
  [string]$WorkRoot = '',
  [switch]$InstallAsset
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $repoRoot '.tmp\cli-core'
}

$toolRoot = Join-Path $WorkRoot 'toolchains'
$sourceRoot = Join-Path $WorkRoot 'openhue-cli'
$outDir = Join-Path $WorkRoot 'out\openhue-android-arm64'
$outBinary = Join-Path $outDir 'openhue'
$assetBinary = Join-Path $repoRoot 'assets\openclaw\cli-core\bin\openhue'
$goZip = Join-Path $toolRoot "$GoVersion.windows-amd64.zip"
$goRoot = Join-Path $toolRoot 'go'
$goExe = Join-Path $goRoot 'bin\go.exe'

New-Item -ItemType Directory -Path $toolRoot, $outDir -Force | Out-Null

if (!(Test-Path $goZip)) {
  Invoke-WebRequest -Uri "https://go.dev/dl/$GoVersion.windows-amd64.zip" -OutFile $goZip
}

$actualGoSha = (Get-FileHash -Algorithm SHA256 $goZip).Hash.ToLowerInvariant()
if ($actualGoSha -ne $GoArchiveSha256.ToLowerInvariant()) {
  throw "Go archive SHA256 mismatch. Expected $GoArchiveSha256, got $actualGoSha"
}

if (!(Test-Path $goExe)) {
  if (Test-Path $goRoot) {
    Remove-Item -LiteralPath $goRoot -Recurse -Force
  }
  Expand-Archive -Path $goZip -DestinationPath $toolRoot -Force
}

if (Test-Path (Join-Path $sourceRoot '.git')) {
  git -C $sourceRoot fetch --tags origin
} else {
  git clone https://github.com/openhue/openhue-cli.git $sourceRoot
}
git -C $sourceRoot checkout --detach $OpenHueRef

$commit = (git -C $sourceRoot rev-parse HEAD).Trim()
$version = (git -C $sourceRoot describe --tags --always --dirty).Trim()
$date = $BuildDate

$env:GOOS = 'android'
$env:GOARCH = 'arm64'
$env:CGO_ENABLED = '0'
$env:GOMODCACHE = Join-Path $WorkRoot 'gomodcache'
$env:GOCACHE = Join-Path $WorkRoot 'gocache'

& $goExe -C $sourceRoot build `
  -trimpath `
  -ldflags "-s -w -X main.version=$version -X main.commit=$commit -X main.date=$date" `
  -o $outBinary `
  .

$bytes = [System.IO.File]::ReadAllBytes($outBinary)
if ($bytes.Length -lt 1048576) {
  throw "OpenHue payload is unexpectedly small: $($bytes.Length) bytes"
}
if ($bytes[0] -ne 0x7f -or $bytes[1] -ne 0x45 -or $bytes[2] -ne 0x4c -or $bytes[3] -ne 0x46) {
  throw 'OpenHue payload is not an ELF executable'
}
if ($bytes[4] -ne 2 -or $bytes[5] -ne 1) {
  throw 'OpenHue payload is not ELF64 little-endian'
}
$machine = [BitConverter]::ToUInt16($bytes, 18)
if ($machine -ne 183) {
  throw "OpenHue payload is not AArch64. ELF machine=$machine"
}

$payloadSha = (Get-FileHash -Algorithm SHA256 $outBinary).Hash.ToLowerInvariant()

if ($InstallAsset) {
  New-Item -ItemType Directory -Path (Split-Path $assetBinary -Parent) -Force | Out-Null
  Copy-Item -LiteralPath $outBinary -Destination $assetBinary -Force
}

[pscustomobject]@{
  source = 'https://github.com/openhue/openhue-cli'
  commit = $commit
  version = $version
  goVersion = $GoVersion
  goArchiveSha256 = $actualGoSha
  buildDate = $date
  goos = $env:GOOS
  goarch = $env:GOARCH
  cgoEnabled = $env:CGO_ENABLED
  output = $outBinary
  outputBytes = $bytes.Length
  outputSha256 = $payloadSha
  installedAsset = [bool]$InstallAsset
} | ConvertTo-Json
