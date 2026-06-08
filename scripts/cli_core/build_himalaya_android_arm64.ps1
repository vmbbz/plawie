param(
  [string]$HimalayaRef = '1b70c4e0eaa72dee48353f0211e6cc0f0776fe98',
  [string]$RustVersion = '1.93.0',
  [string]$RustupVersion = '1.29.0',
  [string]$RustupInitSha256 = '86478e53f769379d7f0ebfa7c9aa97cb76ca92233f79aa2cc0dbee2efaac73c7',
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
$rustRoot = Join-Path $toolRoot 'rust'
$cargoHome = Join-Path $rustRoot 'cargo'
$rustupHome = Join-Path $rustRoot 'rustup'
$rustupInit = Join-Path $rustRoot "rustup-init-$RustupVersion.exe"
$sourceRoot = Join-Path $WorkRoot 'himalaya'
$cargoTargetDir = Join-Path $WorkRoot 'out\himalaya-cargo-target'
$outBinary = Join-Path $cargoTargetDir 'aarch64-linux-android\release\himalaya'
$assetBinary = Join-Path $repoRoot 'assets\openclaw\cli-core\bin\himalaya'

New-Item -ItemType Directory -Path $toolRoot, $rustRoot, $cargoHome, $rustupHome -Force | Out-Null

if (!(Test-Path $rustupInit)) {
  Invoke-WebRequest `
    -Uri "https://static.rust-lang.org/rustup/archive/$RustupVersion/x86_64-pc-windows-msvc/rustup-init.exe" `
    -OutFile $rustupInit
}

$actualRustupSha = (Get-FileHash -Algorithm SHA256 $rustupInit).Hash.ToLowerInvariant()
if ($actualRustupSha -ne $RustupInitSha256.ToLowerInvariant()) {
  throw "rustup-init SHA256 mismatch. Expected $RustupInitSha256, got $actualRustupSha"
}

$env:CARGO_HOME = $cargoHome
$env:RUSTUP_HOME = $rustupHome
$env:RUSTUP_INIT_SKIP_PATH_CHECK = 'yes'
$rustupExe = Join-Path $cargoHome 'bin\rustup.exe'

if (!(Test-Path $rustupExe)) {
  & $rustupInit `
    -y `
    --no-modify-path `
    --profile minimal `
    --default-toolchain $RustVersion `
    --target aarch64-linux-android
}

& $rustupExe toolchain install $RustVersion --profile minimal --target aarch64-linux-android
& $rustupExe target add aarch64-linux-android --toolchain $RustVersion

$ndkRoot = Get-ChildItem (Join-Path $AndroidSdkRoot 'ndk') -Directory -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending |
  Select-Object -First 1
if ($null -eq $ndkRoot) {
  throw "Android NDK not found under $AndroidSdkRoot\ndk"
}
$ndkBin = Join-Path $ndkRoot.FullName 'toolchains\llvm\prebuilt\windows-x86_64\bin'
$clang = Join-Path $ndkBin "aarch64-linux-android$AndroidApi-clang.cmd"
$ar = Join-Path $ndkBin 'llvm-ar.exe'
if (!(Test-Path $clang)) {
  throw "Android arm64 clang not found: $clang"
}
if (!(Test-Path $ar)) {
  throw "Android llvm-ar not found: $ar"
}

if (Test-Path (Join-Path $sourceRoot '.git')) {
  git -C $sourceRoot fetch --tags origin
} else {
  git clone https://github.com/pimalaya/himalaya.git $sourceRoot
}
git -C $sourceRoot checkout --detach $HimalayaRef

$commit = (git -C $sourceRoot rev-parse HEAD).Trim()
$version = (git -C $sourceRoot describe --tags --always --dirty).Trim()

$env:PATH = (Join-Path $cargoHome 'bin') + ';' + $ndkBin + ';' + $env:PATH
$env:RUSTUP_TOOLCHAIN = $RustVersion
$env:CARGO_TARGET_DIR = $cargoTargetDir
$env:CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = $clang
$env:CARGO_TARGET_AARCH64_LINUX_ANDROID_AR = $ar
$env:CC_aarch64_linux_android = $clang
$env:AR_aarch64_linux_android = $ar
Remove-Item Env:CC -ErrorAction SilentlyContinue
Remove-Item Env:TARGET_CC -ErrorAction SilentlyContinue
Remove-Item Env:AR -ErrorAction SilentlyContinue

& $rustupExe run $RustVersion cargo build `
  --release `
  --locked `
  --target aarch64-linux-android `
  --manifest-path (Join-Path $sourceRoot 'Cargo.toml')

$bytes = [System.IO.File]::ReadAllBytes($outBinary)
if ($bytes.Length -lt 1048576) {
  throw "Himalaya payload is unexpectedly small: $($bytes.Length) bytes"
}
if ($bytes[0] -ne 0x7f -or $bytes[1] -ne 0x45 -or $bytes[2] -ne 0x4c -or $bytes[3] -ne 0x46) {
  throw 'Himalaya payload is not an ELF executable'
}
if ($bytes[4] -ne 2 -or $bytes[5] -ne 1) {
  throw 'Himalaya payload is not ELF64 little-endian'
}
$machine = [BitConverter]::ToUInt16($bytes, 18)
if ($machine -ne 183) {
  throw "Himalaya payload is not AArch64. ELF machine=$machine"
}

$payloadSha = (Get-FileHash -Algorithm SHA256 $outBinary).Hash.ToLowerInvariant()

if ($InstallAsset) {
  New-Item -ItemType Directory -Path (Split-Path $assetBinary -Parent) -Force | Out-Null
  Copy-Item -LiteralPath $outBinary -Destination $assetBinary -Force
}

[pscustomobject]@{
  source = 'https://github.com/pimalaya/himalaya'
  commit = $commit
  version = $version
  rustVersion = $RustVersion
  rustupVersion = $RustupVersion
  rustupInitSha256 = $actualRustupSha
  androidNdk = $ndkRoot.Name
  androidApi = $AndroidApi
  cc = $env:CC_aarch64_linux_android
  target = 'aarch64-linux-android'
  features = 'default'
  output = $outBinary
  outputBytes = $bytes.Length
  outputSha256 = $payloadSha
  installedAsset = [bool]$InstallAsset
} | ConvertTo-Json
