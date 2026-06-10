param(
  [string]$SongseeRef = '41d27ea22771ba447bdfb8b6adac2e6599601634',
  [string]$SongseeVersion = 'v0.1.1-10-g41d27ea',
  [string]$GoVersion = 'go1.25.4',
  [string]$GoArchiveSha256 = '6dad204d42719795f22067553b2b042c0e710b32c5a00f6c67892865167fdfd0',
  [string]$WorkRoot = '',
  [switch]$InstallAsset
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $repoRoot '.tmp\audio-runtime'
}

$toolRoot = Join-Path $WorkRoot 'toolchains'
$sourceRoot = Join-Path $WorkRoot 'songsee'
$outDir = Join-Path $WorkRoot 'out\songsee-android-arm64'
$outBinary = Join-Path $outDir 'songsee'
$assetBinary = Join-Path $repoRoot 'assets\openclaw\audio-runtime\bin\songsee'
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
    $resolvedGoRoot = [System.IO.Path]::GetFullPath($goRoot)
    $resolvedToolRoot = [System.IO.Path]::GetFullPath($toolRoot)
    if (!$resolvedGoRoot.StartsWith($resolvedToolRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to remove Go root outside tool root: $resolvedGoRoot"
    }
    Remove-Item -LiteralPath $goRoot -Recurse -Force
  }
  Expand-Archive -Path $goZip -DestinationPath $toolRoot -Force
}

if (Test-Path (Join-Path $sourceRoot '.git')) {
  git -C $sourceRoot cat-file -e "$SongseeRef^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) {
    git -C $sourceRoot fetch --tags origin
  }
} else {
  git clone --no-tags --depth 1 https://github.com/steipete/songsee.git $sourceRoot
  git -C $sourceRoot cat-file -e "$SongseeRef^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) {
    git -C $sourceRoot fetch --depth 1 origin $SongseeRef
  }
}
git -C $sourceRoot checkout --detach $SongseeRef

$commit = (git -C $sourceRoot rev-parse HEAD).Trim()
$version = $SongseeVersion

$env:GOOS = 'android'
$env:GOARCH = 'arm64'
$env:CGO_ENABLED = '0'
$env:GOMODCACHE = Join-Path $WorkRoot 'gomodcache'
$env:GOCACHE = Join-Path $WorkRoot 'gocache'

& $goExe -C $sourceRoot build `
  -trimpath `
  -ldflags "-s -w -X main.version=$version" `
  -o $outBinary `
  ./cmd/songsee

$bytes = [System.IO.File]::ReadAllBytes($outBinary)
if ($bytes.Length -lt (2 * 1024 * 1024)) {
  throw "Songsee payload is unexpectedly small: $($bytes.Length) bytes"
}
if ($bytes[0] -ne 0x7f -or $bytes[1] -ne 0x45 -or $bytes[2] -ne 0x4c -or $bytes[3] -ne 0x46) {
  throw 'Songsee payload is not an ELF executable'
}
if ($bytes[4] -ne 2 -or $bytes[5] -ne 1) {
  throw 'Songsee payload is not ELF64 little-endian'
}
$machine = [BitConverter]::ToUInt16($bytes, 18)
if ($machine -ne 183) {
  throw "Songsee payload is not AArch64. ELF machine=$machine"
}

$payloadSha = (Get-FileHash -Algorithm SHA256 $outBinary).Hash.ToLowerInvariant()

if ($InstallAsset) {
  New-Item -ItemType Directory -Path (Split-Path $assetBinary -Parent) -Force | Out-Null
  Copy-Item -LiteralPath $outBinary -Destination $assetBinary -Force
}

[pscustomobject]@{
  source = 'https://github.com/steipete/songsee'
  commit = $commit
  version = $version
  goVersion = $GoVersion
  goArchiveSha256 = $actualGoSha
  goos = $env:GOOS
  goarch = $env:GOARCH
  cgoEnabled = $env:CGO_ENABLED
  output = $outBinary
  outputBytes = $bytes.Length
  outputSha256 = $payloadSha
  installedAsset = [bool]$InstallAsset
} | ConvertTo-Json
