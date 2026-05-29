param(
    [string]$WorkDir = "$env:TEMP\plawie-nodejs-mobile-audit",
    [string]$MobileRepo = "https://github.com/nodejs-mobile/nodejs-mobile.git",
    [string]$MobileRef = "106c51f95d55d1010de56a2ffd09bfb4ba819a47",
    [string]$UpstreamRepo = "https://github.com/nodejs/node.git",
    [string]$UpstreamTag = "v22.9.0",
    [string]$OutputDir = "build\native-node\nodejs-mobile-audit"
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path (Get-Location) $Path
}

$resolvedWorkDir = Resolve-FullPath $WorkDir
$resolvedOutputDir = Resolve-FullPath $OutputDir

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required for this audit helper."
}

if (-not (Test-Path $resolvedWorkDir)) {
    New-Item -ItemType Directory -Path (Split-Path $resolvedWorkDir -Parent) -Force | Out-Null
    git clone --depth 1 $MobileRepo $resolvedWorkDir
}

git -C $resolvedWorkDir fetch --depth 1 origin $MobileRef
git -C $resolvedWorkDir checkout --detach FETCH_HEAD

$upstreamExists = git -C $resolvedWorkDir remote | Select-String -SimpleMatch "upstream"
if (-not $upstreamExists) {
    git -C $resolvedWorkDir remote add upstream $UpstreamRepo
}

git -C $resolvedWorkDir fetch --depth 1 upstream $UpstreamTag

New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

$statPath = Join-Path $resolvedOutputDir "nodejs-mobile-$UpstreamTag-diff-stat.txt"
$corePatchPath = Join-Path $resolvedOutputDir "nodejs-mobile-$UpstreamTag-android-core.patch"
$namesPath = Join-Path $resolvedOutputDir "nodejs-mobile-$UpstreamTag-name-status.txt"

git -C $resolvedWorkDir diff --stat FETCH_HEAD..HEAD |
    Set-Content -Path $statPath -Encoding UTF8

git -C $resolvedWorkDir diff --name-status FETCH_HEAD..HEAD |
    Set-Content -Path $namesPath -Encoding UTF8

git -C $resolvedWorkDir diff FETCH_HEAD..HEAD -- `
    android_configure.py `
    android-configure `
    common.gypi `
    node.gyp `
    tools/android_build.sh `
    tools/copy_libnode_headers.sh `
    deps/v8/src/trap-handler/trap-handler.h `
    tools/v8_gypfiles/v8.gyp `
    tools/v8_gypfiles/toolchain.gypi |
    Set-Content -Path $corePatchPath -Encoding UTF8

Write-Host "Nodejs-mobile patch audit exported:"
Write-Host "  $statPath"
Write-Host "  $namesPath"
Write-Host "  $corePatchPath"
Write-Host ""
Write-Host "This helper only writes local build artifacts. It does not patch Plawie."
