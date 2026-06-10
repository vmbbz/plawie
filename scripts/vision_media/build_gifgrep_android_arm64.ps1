param(
  [string]$GifgrepRef = '72e2cf8fe685e7baa0535c04c3cf2e238ebfd0bc',
  [string]$GifgrepVersion = '0.3.0',
  [string]$GoVersion = 'go1.25.5',
  [string]$GoArchiveSha256 = 'ae756cce1cb80c819b4fe01b0353807178f532211b47f72d7fa77949de054ebb',
  [string]$WorkRoot = '',
  [string]$ToolRoot = '',
  [switch]$InstallAsset
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = Join-Path $repoRoot '.tmp\vision-media\gifgrep-android-arm64'
}
if ([string]::IsNullOrWhiteSpace($ToolRoot)) {
  $ToolRoot = Join-Path $repoRoot '.tmp\tools'
}

$sourceRoot = Join-Path $WorkRoot 'source'
$outDir = Join-Path $WorkRoot 'out'
$outBinary = Join-Path $outDir 'gifgrep'
$assetBinary = Join-Path $repoRoot 'assets\openclaw\vision-media\bin\gifgrep'
$goZip = Join-Path $ToolRoot "$GoVersion.windows-amd64.zip"
$goRoot = Join-Path $ToolRoot $GoVersion
$goExe = Join-Path $goRoot 'bin\go.exe'

New-Item -ItemType Directory -Path $ToolRoot, $outDir -Force | Out-Null

if (!(Test-Path $goZip)) {
  Invoke-WebRequest -Uri "https://go.dev/dl/$GoVersion.windows-amd64.zip" -OutFile $goZip
}

$actualGoSha = (Get-FileHash -Algorithm SHA256 $goZip).Hash.ToLowerInvariant()
if ($actualGoSha -ne $GoArchiveSha256.ToLowerInvariant()) {
  throw "Go archive SHA256 mismatch. Expected $GoArchiveSha256, got $actualGoSha"
}

if (!(Test-Path $goExe)) {
  $extractRoot = Join-Path $ToolRoot "$GoVersion-extract"
  if (Test-Path $extractRoot) {
    $resolvedExtractRoot = [System.IO.Path]::GetFullPath($extractRoot)
    $resolvedToolRoot = [System.IO.Path]::GetFullPath($ToolRoot)
    if (!$resolvedExtractRoot.StartsWith($resolvedToolRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to remove extraction root outside tool root: $resolvedExtractRoot"
    }
    Remove-Item -LiteralPath $extractRoot -Recurse -Force
  }
  New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
  Expand-Archive -Path $goZip -DestinationPath $extractRoot -Force
  if (Test-Path $goRoot) {
    $resolvedGoRoot = [System.IO.Path]::GetFullPath($goRoot)
    $resolvedToolRoot = [System.IO.Path]::GetFullPath($ToolRoot)
    if (!$resolvedGoRoot.StartsWith($resolvedToolRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to remove Go root outside tool root: $resolvedGoRoot"
    }
    Remove-Item -LiteralPath $goRoot -Recurse -Force
  }
  Move-Item -LiteralPath (Join-Path $extractRoot 'go') -Destination $goRoot
  Remove-Item -LiteralPath $extractRoot -Recurse -Force
}

if (Test-Path (Join-Path $sourceRoot '.git')) {
  git -C $sourceRoot cat-file -e "$GifgrepRef^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) {
    git -C $sourceRoot fetch --tags origin
  }
} else {
  git clone --no-tags --depth 1 https://github.com/steipete/gifgrep.git $sourceRoot
  git -C $sourceRoot cat-file -e "$GifgrepRef^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) {
    git -C $sourceRoot fetch --depth 1 origin $GifgrepRef
  }
}
git -C $sourceRoot checkout --detach $GifgrepRef

$commit = (git -C $sourceRoot rev-parse HEAD).Trim()
$env:GOOS = 'android'
$env:GOARCH = 'arm64'
$env:CGO_ENABLED = '0'
$env:GOTOOLCHAIN = 'local'
$env:GOMODCACHE = Join-Path $WorkRoot 'gomodcache'
$env:GOCACHE = Join-Path $WorkRoot 'gocache'
$env:GOTMPDIR = Join-Path $WorkRoot 'gotmp'
New-Item -ItemType Directory -Path $env:GOMODCACHE, $env:GOCACHE, $env:GOTMPDIR -Force | Out-Null

& $goExe -C $sourceRoot build `
  -trimpath `
  -ldflags '-s -w' `
  -o $outBinary `
  ./cmd/gifgrep

$bytes = [System.IO.File]::ReadAllBytes($outBinary)
if ($bytes.Length -lt (4 * 1024 * 1024)) {
  throw "Gifgrep payload is unexpectedly small: $($bytes.Length) bytes"
}
if ($bytes[0] -ne 0x7f -or $bytes[1] -ne 0x45 -or $bytes[2] -ne 0x4c -or $bytes[3] -ne 0x46) {
  throw 'Gifgrep payload is not an ELF executable'
}
if ($bytes[4] -ne 2 -or $bytes[5] -ne 1) {
  throw 'Gifgrep payload is not ELF64 little-endian'
}
$machine = [BitConverter]::ToUInt16($bytes, 18)
if ($machine -ne 183) {
  throw "Gifgrep payload is not AArch64. ELF machine=$machine"
}

$payloadSha = (Get-FileHash -Algorithm SHA256 $outBinary).Hash.ToLowerInvariant()

if ($InstallAsset) {
  New-Item -ItemType Directory -Path (Split-Path $assetBinary -Parent) -Force | Out-Null
  Copy-Item -LiteralPath $outBinary -Destination $assetBinary -Force
}

[pscustomobject]@{
  source = 'https://github.com/steipete/gifgrep'
  commit = $commit
  version = $GifgrepVersion
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
