param(
  [string]$WacliRef = 'be2d22fe9d8ca99bf4c027708ae494e9035fe489',
  [string]$GoVersion = 'go1.26.4',
  [string]$GoArchiveSha256 = '3ca8fb4630b07c419cbdd51f754e31363cfcfb83b3a5354d9e895c90be2cc345',
  [string]$AndroidApi = '29',
  [string]$WorkRoot = '',
  [string]$AndroidSdkRoot = '',
  [switch]$InstallAsset
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $repoRoot '.tmp\cli-core'
}
if ([string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
  $sdkCandidates = @(
    $env:ANDROID_SDK_ROOT,
    $env:ANDROID_HOME,
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
  ) | Where-Object { ![string]::IsNullOrWhiteSpace($_) }
  $AndroidSdkRoot = $sdkCandidates |
    Where-Object { Test-Path (Join-Path $_ 'ndk') } |
    Select-Object -First 1
  if ([string]::IsNullOrWhiteSpace($AndroidSdkRoot)) {
    $AndroidSdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
  }
}

$toolRoot = Join-Path $WorkRoot 'toolchains'
$sourceRoot = Join-Path $WorkRoot 'wacli'
$outDir = Join-Path $WorkRoot 'out\wacli-android-arm64'
$outBinary = Join-Path $outDir 'wacli'
$assetBinary = Join-Path $repoRoot 'assets\openclaw\cli-core\bin\wacli'
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

$ndkRoot = Get-ChildItem (Join-Path $AndroidSdkRoot 'ndk') -Directory -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending |
  Select-Object -First 1
if ($null -eq $ndkRoot) {
  throw "Android NDK not found under $AndroidSdkRoot\ndk"
}
$clang = Join-Path $ndkRoot.FullName "toolchains\llvm\prebuilt\windows-x86_64\bin\aarch64-linux-android$AndroidApi-clang.cmd"
if (!(Test-Path $clang)) {
  throw "Android arm64 clang not found: $clang"
}

if (Test-Path (Join-Path $sourceRoot '.git')) {
  git -C $sourceRoot fetch --tags origin
} else {
  git clone https://github.com/openclaw/wacli.git $sourceRoot
}
git -C $sourceRoot checkout --detach $WacliRef

$commit = (git -C $sourceRoot rev-parse HEAD).Trim()
$version = (git -C $sourceRoot describe --tags --always --dirty).Trim()

$env:GOOS = 'android'
$env:GOARCH = 'arm64'
$env:CGO_ENABLED = '1'
$env:CC = $clang
$env:CGO_CFLAGS = '-Wno-error=missing-braces'
$env:GOMODCACHE = Join-Path $WorkRoot 'gomodcache'
$env:GOCACHE = Join-Path $WorkRoot 'gocache'

& $goExe -C $sourceRoot build `
  -trimpath `
  -tags sqlite_fts5 `
  -ldflags "-s -w -X main.version=$version" `
  -o $outBinary `
  .\cmd\wacli

$bytes = [System.IO.File]::ReadAllBytes($outBinary)
if ($bytes.Length -lt 1048576) {
  throw "Wacli payload is unexpectedly small: $($bytes.Length) bytes"
}
if ($bytes[0] -ne 0x7f -or $bytes[1] -ne 0x45 -or $bytes[2] -ne 0x4c -or $bytes[3] -ne 0x46) {
  throw 'Wacli payload is not an ELF executable'
}
if ($bytes[4] -ne 2 -or $bytes[5] -ne 1) {
  throw 'Wacli payload is not ELF64 little-endian'
}
$machine = [BitConverter]::ToUInt16($bytes, 18)
if ($machine -ne 183) {
  throw "Wacli payload is not AArch64. ELF machine=$machine"
}

$payloadSha = (Get-FileHash -Algorithm SHA256 $outBinary).Hash.ToLowerInvariant()

if ($InstallAsset) {
  New-Item -ItemType Directory -Path (Split-Path $assetBinary -Parent) -Force | Out-Null
  Copy-Item -LiteralPath $outBinary -Destination $assetBinary -Force
}

[pscustomobject]@{
  source = 'https://github.com/openclaw/wacli'
  commit = $commit
  version = $version
  goVersion = $GoVersion
  goArchiveSha256 = $actualGoSha
  androidNdk = $ndkRoot.Name
  androidApi = $AndroidApi
  cc = $env:CC
  goos = $env:GOOS
  goarch = $env:GOARCH
  cgoEnabled = $env:CGO_ENABLED
  cgoCflags = $env:CGO_CFLAGS
  tags = 'sqlite_fts5'
  output = $outBinary
  outputBytes = $bytes.Length
  outputSha256 = $payloadSha
  installedAsset = [bool]$InstallAsset
} | ConvertTo-Json
