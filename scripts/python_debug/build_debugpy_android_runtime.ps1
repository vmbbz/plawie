param(
    [string]$Version = "1.8.21",
    [string]$ExpectedSha256 = "b1e37d333663c8851516a47364ef473da127f9caebe4417e6df6f5825a7e9a92",
    [switch]$InstallAsset
)

$ErrorActionPreference = "Stop"

# pinned requirement: debugpy==1.8.21
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$workDir = Join-Path $repoRoot ".tmp\python-debug-runtime"
$assetDir = Join-Path $repoRoot "assets\openclaw\python-debug-runtime\wheels"
$Requirement = "debugpy==$Version"
$wheelName = "debugpy-$Version-py2.py3-none-any.whl"
$wheelUrl = "https://files.pythonhosted.org/packages/95/51/67e7cf11a53e40694f720457d5b3a1cdaaa3d5a9a633e482f225456b93ff/$wheelName"
$wheelPath = Join-Path $workDir $wheelName
$assetPath = Join-Path $assetDir $wheelName

New-Item -ItemType Directory -Force -Path $workDir | Out-Null

if (-not (Test-Path -LiteralPath $wheelPath)) {
    Invoke-WebRequest -UseBasicParsing -Uri $wheelUrl -OutFile $wheelPath
}

$actualSha = (Get-FileHash -Algorithm SHA256 -LiteralPath $wheelPath).Hash.ToLowerInvariant()
if ($actualSha -ne $ExpectedSha256) {
    throw "debugpy wheel sha256 mismatch. expected=$ExpectedSha256 actual=$actualSha"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($wheelPath)
try {
    $names = @($zip.Entries | ForEach-Object { $_.FullName })
    if ($names -notcontains "debugpy/__init__.py") {
        throw "debugpy/__init__.py missing from wheel"
    }
    $metadataName = "debugpy-$Version.dist-info/METADATA"
    $metadata = $zip.Entries | Where-Object { $_.FullName -eq $metadataName } | Select-Object -First 1
    if ($null -eq $metadata) {
        throw "$metadataName missing from wheel"
    }
    $reader = New-Object System.IO.StreamReader($metadata.Open())
    try {
        $metadataText = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
    }
    if ($metadataText -notmatch "(?m)^Name:\s*debugpy\s*$" -or
        $metadataText -notmatch "(?m)^Version:\s*$Version\s*$") {
        throw "debugpy wheel metadata does not declare debugpy $Version"
    }
} finally {
    $zip.Dispose()
}

if ($InstallAsset) {
    New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
    Copy-Item -Force -LiteralPath $wheelPath -Destination $assetPath
}

[ordered]@{
    package = "debugpy"
    requirement = $Requirement
    version = $Version
    url = $wheelUrl
    sha256 = $actualSha
    bytes = (Get-Item -LiteralPath $wheelPath).Length
    installedAsset = [bool]$InstallAsset
} | ConvertTo-Json
